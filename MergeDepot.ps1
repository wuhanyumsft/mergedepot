echo "Hello World."
# Include
#$currentDir = $($MyInvocation.MyCommand.Definition) | Split-Path
#. "$currentDir/../utility/common.ps1"
#. "$currentDir/../utility/console.utility.ps1"

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
