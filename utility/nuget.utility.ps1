# Include referenced utility scripts
$utilityDir = $($MyInvocation.MyCommand.Definition) | Split-Path
. "$utilityDir/log.utility.ps1"

Function RestorePackage([string]$nugetExeDestination, [string]$packagesDestination, [string]$packagesDirectory, [string]$nugetConfigDestination)
{
    return RunExeProcess($nugetExeDestination) ("restore ""$packagesDestination"" -PackagesDirectory ""$packagesDirectory"" -ConfigFile ""$nugetConfigDestination"" ") ($packagesDirectory)
}

Function RestorePackageWithLog([string]$nugetExeDestination, [string]$packagesDestination, [string]$packagesDirectory, [string]$nugetConfigDestination, [string]$reportFilePath)
{
    $process = RestorePackage($nugetExeDestination) ($packagesDestination) ($packagesDirectory) ($nugetConfigDestination)
    if ($process.ExitCode -ne 0)
    {
        $errorMessage = "Restore nuget package $packagesDestination in folder:$packagesDirectory failed, possibly due to transient errors from nuget servers. Please retry building your content again. If the issue still happens, open a ticket in http://MSDNHelp. Detailed error: $($process.StandardError)"
        LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $(GetCurrentScriptFile) -line $(GetCurrentLine)
        exit ConsoleErrorAndExit($errorMessage) ($process.ExitCode)
    }
}

Function GetPackageLatestVersion([string]$nugetExeDestination, [string]$packageName, [string]$nugetConfigDestination, [int]$maxRetryCount, [bool]$usePrereleasePackage = $false, [object[]]$cachedPackageVersions = $null)
{
    $currentRetryIteration = 0;
    $retryIntervalInSeconds = 0;
    $retryIncrementalIntervalInSeconds = 10;

    do
    {
        Try
        {
            Write-HostWithTimestamp "Use prerelease package for $packageName : $usePrereleasePackage"

            $cachedPackageVersionString = "latest";
            if ($usePrereleasePackage)
            {
                $cachedPackageVersionString = "latest-prerelease"
            }

            $cachedPackageVersion = FindResource($cachedPackageVersions) ($packageName) ($cachedPackageVersionString)
            if ($cachedPackageVersion)
            {
                Write-HostWithTimestamp "Package version for $packageName loaded from cache: $cachedPackageVersion"
                return $cachedPackageVersion.Location
            }

            if ($usePrereleasePackage)
            {
                $filteredPackages = (& "$nugetExeDestination" list $packageName -Prerelease -ConfigFile "$nugetConfigDestination") -split "\n"
            }
            else
            {
                $filteredPackages = (& "$nugetExeDestination" list $packageName -ConfigFile "$nugetConfigDestination") -split "\n"
            }

            if ($LASTEXITCODE -eq 0)
            {
                foreach ($filteredPackage in $filteredPackages)
                {
                    $segments = $filteredPackage -split " "
                    if ($segments.Length -eq 2 -and $segments[0] -eq $packageName)
                    {
                        return $segments[1]
                    }
                }
            }

            Write-HostWithTimestamp "Call iteration '$currentRetryIteration', cannot find latest version for $packageName, filtered packages: $filteredPackages"
        }
        Catch
        {
            Write-HostWithTimestamp "Call iteration '$currentRetryIteration', cannot find latest version for $packageName, exception: $($_.Exception.Message)"
        }

        if ($currentRetryIteration -ne $maxRetryCount)
        {
            $retryIntervalInSeconds += $retryIncrementalIntervalInSeconds
            Write-HostWithTimestamp "List package version failed, sleep $retryIntervalInSeconds seconds..."
            Start-Sleep -Seconds $retryIntervalInSeconds
        }
    } while (++$currentRetryIteration -le $maxRetryCount)

    Write-HostWithTimestamp "Current nuget package list service is busy, please retry the build in 10 minutes"
    exit 1
}