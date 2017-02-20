# Include referenced utility scripts
$utilityDir = $($MyInvocation.MyCommand.Definition) | Split-Path
. "$utilityDir/common.ps1"

Function GenerateCustomizedScriptPackagesConfig([string]$outputFilePath, [object]$task)
{
    $packageConfigXmlTemplate = @'
<?xml version="1.0" encoding="utf-8"?>
<packages></packages>
'@

    $packageConfigXml = [xml]$packageConfigXmlTemplate
    $packageNode = $packageConfigXml.CreateElement("package")
    $packageNode.SetAttribute("id", $task.id)
    $packageNode.SetAttribute("version", $task.version)
    $packageNode.SetAttribute("targetFramework", $task.target_framework)
    $packageConfigXml.SelectSingleNode("packages").AppendChild($packageNode)

    if (IsPathExists($outputFilePath))
    {
        Remove-Item $outputFilePath -Force
    }

    $packageConfigXml.Save($outputFilePath)
}

Function GenerateNugetConfig([string]$nugetConfigDestination, [string]$nugetFeed, [string]$packageId)
{
    $nugetConfigXmlTemplate = @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageRestore>
    <!-- Allow NuGet to download missing packages -->
    <add key="enabled" value="True" />
    <!-- Automatically check for missing packages during build in Visual Studio -->
    <add key="automatic" value="True" />
  </packageRestore>
  <!--
  Used to specify the default Sources for list, install and update.
  See: NuGet.exe help list
  See: NuGet.exe help install
  See: NuGet.exe help update
  -->
  <packageSources>
  </packageSources>
  <!-- Used to store credentials -->
  <packageSourceCredentials />
  <!-- Used to specify which one of the sources are active -->
  <activePackageSource>
    <!-- this tells only one given source is active -->
    <!-- <add key="NuGet official package source" value="https://nuget.org/api/v2/" /> -->
    <!-- this tells that all of them are active -->
    <add key="All" value="(Aggregate source)" />
  </activePackageSource>
</configuration>
'@

    $nugetConfig = [xml]$nugetConfigXmlTemplate
    $packageSourceNode = $nugetConfig.CreateElement("add")
    $packageSourceNode.SetAttribute("key", "customizedScript.$packageId")
    $packageSourceNode.SetAttribute("value", "$nugetFeed")

    $nugetConfig.SelectSingleNode("configuration").SelectSingleNode("packageSources").AppendChild($packageSourceNode)

    if (IsPathExists($nugetConfigDestination))
    {
        Remove-Item $nugetConfigDestination -Force
    }

    $nugetConfig.Save($nugetConfigDestination)
}

Function ExecuteEntryPointScript([string]$entryPointScriptDestination, [hashtable]$ParameterDictionary)
{
    & $entryPointScriptDestination $ParameterDictionary
    
    if ($LASTEXITCODE -ne 0)
    {
        $errorMessage = "Failed to run script $entryPointScriptDestination with exit code $LASTEXITCODE"
        LogSystemWarning -logFilePath $ParameterDictionary.environment.logFile -message $errorMessage -source $(GetCurrentScriptFile) -line $(GetCurrentLine)
        ConsoleWarning($errorMessage) (1)
    }
}

Function NugetRestore([object]$task, [string]$taskDestinationFolder, [string]$nugetConfigDestination, [hashtable]$ParameterDictionary)
{
    if ($task.version -eq "latest" -or $task.version -eq "latest-prerelease")
    {
        $requestedVersion = $task.version
        $usePrereleasePackage = $requestedVersion -eq "latest-prerelease"
        $maxRetryCount = $ParameterDictionary.environment.systemDefaultVariables.DefaultMaxRetryCount
        $nugetExeDestination = $ParameterDictionary.environment.nugetExeDestination
        $environmentResources = $ParameterDictionary.environment.EnvironmentResources

        # Get latest package version
        $task.version = GetPackageLatestVersion($nugetExeDestination) ($task.id) ($nugetConfigDestination) ($maxRetryCount) ($usePrereleasePackage) ($environmentResources.PackageVersion)

        Write-HostWithTimestamp "Using version $($task.version) for package $($task.id) (requested: $requestedVersion)"
    }

    $packagesDestination = JoinPath($taskDestinationFolder) (@("packages.config"))
    GenerateCustomizedScriptPackagesConfig($packagesDestination) ($task)

    $process = RestorePackage($ParameterDictionary.environment.nugetExeDestination) ($packagesDestination) ($taskDestinationFolder) ($nugetConfigDestination)
    if ($process.ExitCode -ne 0)
    {
        $errorMessage = "Restore nuget package $packagesDestination in folder:$packagesDirectory failed, possibly due to transient errors from nuget servers. Please retry building your content again. If the issue still happens, open a ticket in http://MSDNHelp. Detailed error: $($process.StandardError)"
        LogSystemWarning -logFilePath $ParameterDictionary.environment.logFile -message $errorMessage -source $(GetCurrentScriptFile) -line $(GetCurrentLine)
        ConsoleWarning($errorMessage) ($process.ExitCode)
        return $false
    }

    return $true
}

Function DownloadScriptFromURL([string]$url, [string]$scriptDestination)
{
    # Download remote script to local
    Invoke-WebRequest $url -OutFile "$scriptDestination"

    if (-Not (IsPathExists($scriptDestination)))
    {
        return $false
    }

    return $true
}

Function RestoreDependentPackage([object]$task, [hashtable]$ParameterDictionary, [string]$taskDestinationFolder)
{
    # Generate Nuget.Config
    $nugetConfigDestination = JoinPath($taskDestinationFolder) (@("Nuget.Config"))
    GenerateNugetConfig($nugetConfigDestination) ($task.nuget_feed) ($task.id)

    # Restore nuget package from user customized nuget feed
    Write-HostWithTimestamp "Restore package: $($task.id) with version $($task.version) from feed source $($task.nuget_feed)"
    $restoreSucceeded = NugetRestore($task) ($taskDestinationFolder) ($nugetConfigDestination) ($ParameterDictionary)
    if (!$restoreSucceeded)
    {
        return $false
    }

    return $true
}

Function ExecuteCustomizedScriptCore([string]$scriptRelativeDestination, [hashtable]$ParameterDictionary)
{
    $scriptDestination = JoinPath($ParameterDictionary.environment.repositoryRoot) (@($scriptRelativeDestination))
    if (-Not (IsPathExists($scriptDestination)))
    {
        $errorMessage = "Cannot find local script file $scriptDestination"
        LogSystemWarning -logFilePath $ParameterDictionary.environment.logFile -message $errorMessage -source $(GetCurrentScriptFile) -line $(GetCurrentLine)
        ConsoleWarning($errorMessage) (1)
        return
    }

    Try
    {
        Write-HostWithTimestamp "Run script in repository $scriptRelativeDestination in step $($ParameterDictionary.context.runStep)"
        ExecuteEntryPointScript($scriptDestination) ($ParameterDictionary)
    }
    Catch
    {
        $errorMessage = "Error happened in execute customized script: $($_.Exception.Message)"
        LogSystemWarning -logFilePath $ParameterDictionary.environment.logFile -message $errorMessage -source $(GetCurrentScriptFile) -line $(GetCurrentLine)
        ConsoleWarning($errorMessage) (1)
    }
}

Function ExecuteCustomizedScript([object[]]$customizedTasks, [hashtable]$ParameterDictionary)
{
    ArgumentNotNull($customizedTasks) ('$customizedTasks')

    foreach ($customizedTask in $customizedTasks)
    {
        # Support both shorthand format and complete format
        # Shorthand form: "string array" in task execution, e.g. [ "task_first", "task_second", "task_third" ]
        # Complete form: "dictionary array" in task execution, e.g. [ { "task": "task_first" }, { "task": "task_second" }, { "task": "task_third" } ]
        if ($customizedTask -is [System.String])
        {
            $scriptRelativeDestination = $customizedTask
        }
        elseif ($customizedTask -is [System.Management.Automation.PSCustomObject])
        {
            $scriptRelativeDestination = $customizedTask.script
        }
        else
        {
            $type = $customizedTask.GetType()
            $errorMesage = "Type $type of task $customizedTask is not supported"
            LogUserWarning -logFilePath $ParameterDictionary.environment.logFile -message $errorMesage -source $(GetCurrentScriptFile) -line $(GetCurrentLine)
            ConsoleWarning($errorMesage) (1)

            continue
        }

        # Check task configure from property customized_task_definition
        if ([System.String]::IsNullOrEmpty($scriptRelativeDestination))
        {
            $errorMesage = "$scriptRelativeDestination should be provided in property customized_task_definition correctly"
            LogUserWarning -logFilePath $ParameterDictionary.environment.logFile -message $errorMesage -source $(GetCurrentScriptFile) -line $(GetCurrentLine)
            ConsoleWarning($errorMesage) (1)
            
            continue
        }

        ExecuteCustomizedScriptCore($scriptRelativeDestination) ($ParameterDictionary)
    }
}
