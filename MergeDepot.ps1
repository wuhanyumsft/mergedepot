echo "Hello World."

Function RetryCommand
{
    param (
        [Parameter(Mandatory=$true)][string]$command,
        [Parameter(Mandatory=$true)][hashtable]$args,
        [Parameter(Mandatory=$false)][int]$maxRetryCount = $systemDefaultVariables.DefaultMaxRetryCount,
        [Parameter(Mandatory=$false)][ValidateScript({$_ -ge 0})][int]$retryIncrementalIntervalInSeconds = 10
    )

    # Setting ErrorAction to Stop is important. This ensures any errors that occur in the command are 
    # treated as terminating errors, and will be caught by the catch block.
    $args.ErrorAction = "Stop"

    $currentRetryIteration = 1
    $retryIntervalInSeconds = 0

    Write-HostWithTimestamp ("Start to run command [{0}] with args [{1}]." -f $command, $($args | Out-String))
    do{
        try
        {
            Write-HostWithTimestamp "Calling iteration $currentRetryIteration"
            & $command @args

            Write-HostWithTimestamp "Command ['$command'] succeeded at iteration $currentRetryIteration."
            return
        }
        Catch
        {
            Write-HostWithTimestamp "Calling iteration $currentRetryIteration failed, exception: '$($_.Exception.Message)'"
        }

        if ($currentRetryIteration -ne $maxRetryCount)
        {
            $retryIntervalInSeconds += $retryIncrementalIntervalInSeconds
            Write-HostWithTimestamp "Command ['$command'] failed. Retrying in $retryIntervalInSeconds seconds."
            Start-Sleep -Seconds $retryIntervalInSeconds
        }
    } while (++$currentRetryIteration -le $maxRetryCount)

    Write-HostWithTimestamp "Command ['$command'] failed. Maybe the network issues, please retry the build later."
    exit 1
}

Function CreateFolderIfNotExists([string]$folder)
{
    if(!(Test-Path "$folder"))
    {
        New-Item "$folder" -ItemType Directory
    }
}

Function DownloadFile([string]$source, [string]$destination, [bool]$forceDownload, [int]$timeoutSec = -1)
{
    if($forceDownload -or !(IsPathExists($destination)))
    {
        Write-HostWithTimestamp "Download file to $destination from $source with force: $forceDownload"
        $destinationFolder = Split-Path -Parent $destination
        CreateFolderIfNotExists($destinationFolder)
        if ($timeoutSec -lt 0)
        {
            RetryCommand -Command 'Invoke-WebRequest' -Args @{ Uri = $source; OutFile = $destination; }
        }
        else
        {
            RetryCommand -Command 'Invoke-WebRequest' -Args @{ Uri = $source; OutFile = $destination; TimeoutSec = $timeoutSec }
        }
    }
}

# Include
$currentDir = $($MyInvocation.MyCommand.Definition) | Split-Path
. "$currentDir/utility/common.ps1"
. "$currentDir/utility/console.utility.ps1"

# Main
$errorActionPreference = 'Stop'

# Add specific step for azure
# Download Azure Transform tool
Add-type -AssemblyName "System.IO.Compression.FileSystem"
$azureTransformContainerUrl = "https://opbuildstoragesandbox2.blob.core.windows.net/azure-transform"

$AzureMarkdownRewriterToolSource = "$azureTransformContainerUrl/.optemp/AzureMarkdownRewriterTool-v8.zip"
$AzureMarkdownRewriterToolDestination = "$repositoryRoot\.optemp\AzureMarkdownRewriterTool.zip"
DownloadFile($AzureMarkdownRewriterToolSource) ($AzureMarkdownRewriterToolDestination) ($true)
$AzureMarkdownRewriterToolUnzipFolder = "$repositoryRoot\.optemp\AzureMarkdownRewriterTool"
if((Test-Path "$AzureMarkdownRewriterToolUnzipFolder"))
{
    Remove-Item $AzureMarkdownRewriterToolUnzipFolder -Force -Recurse
}
[System.IO.Compression.ZipFile]::ExtractToDirectory($AzureMarkdownRewriterToolDestination, $AzureMarkdownRewriterToolUnzipFolder)
$AzureMarkdownRewriterTool = "$AzureMarkdownRewriterToolUnzipFolder\Microsoft.DocAsCode.Tools.AzureMarkdownRewriterTool.exe"

# Create azure args file
$publishConfigFile = Join-Path $repositoryRoot ".openpublishing.publish.config.json"
$publishConfigContent = (Get-Content $publishConfigFile -Raw) | ConvertFrom-Json
$locale = $publishConfigContent.docsets_to_publish[0].locale
if([string]::IsNullOrEmpty($locale))
{
    $locale = "en-us"
}

$azureDocumentUriPrefix = "https://azure.microsoft.com/$locale/documentation/articles"

$transformCommonDirectory = "$repositoryRoot\articles"
$transformDirectoriesToCommonDirectory = @("active-directory", "multi-factor-authentication", "remoteapp")

$azureTransformArgsJsonContent = "["
foreach($transformDirectoriyToCommonDirectory in $transformDirectoriesToCommonDirectory)
{
    if($azureTransformArgsJsonContent -ne "[")
    {
        $azureTransformArgsJsonContent += ','
    }
    $azureTransformArgsJsonContent += "{`"source_dir`": `"$transformCommonDirectory\$transformDirectoriyToCommonDirectory`""
    $azureTransformArgsJsonContent += ", `"dest_dir`": `"$transformCommonDirectory\$transformDirectoriyToCommonDirectory`""
    $azureTransformArgsJsonContent += ", `"docs_host_uri_prefix`": `"/$transformDirectoriyToCommonDirectory`"}"
}
$azureTransformArgsJsonContent += "]"
$tempJsonFilePostFix = (Get-Date -Format "yyyyMMddhhmmss") + "-" + [System.IO.Path]::GetRandomFileName() + ".json"
$auzreTransformArgsJsonPath = Join-Path ($AzureMarkdownRewriterToolUnzipFolder) ("azureTransformArgs" + $tempJsonFilePostFix)
$azureTransformArgsJsonContent = $azureTransformArgsJsonContent.Replace("\", "\\")
Out-File -FilePath $auzreTransformArgsJsonPath -InputObject $azureTransformArgsJsonContent -Force

# Call azure transform for every docset
echo "Start to call azure transform"
&"$AzureMarkdownRewriterTool" "$repositoryRoot" "$auzreTransformArgsJsonPath" "$azureDocumentUriPrefix" "$repositoryRoot\AzureVideoMapping.json"

if ($LASTEXITCODE -ne 0)
{
  exit WriteErrorAndExit("Transform failed and won't do build and publish for azure content") ($LASTEXITCODE)
}

# add build for docs
$buildEntryPointDestination = Join-Path $packageToolsDirectory -ChildPath "opbuild" | Join-Path -ChildPath "mdproj.builder.ps1"
$logLevel = GetValueFromVariableName($logLevel) ($systemDefaultVariables.Item("LogLevel"))
& "$buildEntryPointDestination" "$repositoryRoot" "$packagesDirectory" "$packageToolsDirectory" $dependencies $predefinedEntryPoints $logLevel $systemDefaultVariables

exit $LASTEXITCODE
