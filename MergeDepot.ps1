echo "Hello World."

# Main
$errorActionPreference = 'Stop'

# Add specific step for azure
# Download Azure Transform tool
Add-type -AssemblyName "System.IO.Compression.FileSystem"
$azureTransformContainerUrl = "https://opbuildstoragesandbox2.blob.core.windows.net/azure-transform"

New-Item ".optemp" -ItemType Directory
$AzureMarkdownRewriterToolSource = "$azureTransformContainerUrl/.optemp/AzureMarkdownRewriterTool-v8.zip"
$AzureMarkdownRewriterToolDestination = "$repositoryRoot\.optemp\AzureMarkdownRewriterTool.zip"
echo 'Start Download!'
Invoke-WebRequest -Uri $AzureMarkdownRewriterToolSource -OutFile $AzureMarkdownRewriterToolDestination
echo 'Download Success!'

$AzureMarkdownRewriterToolUnzipFolder = "$repositoryRoot\.optemp\AzureMarkdownRewriterTool"
if((Test-Path "$AzureMarkdownRewriterToolUnzipFolder"))
{
    Remove-Item $AzureMarkdownRewriterToolUnzipFolder -Force -Recurse
}

[System.IO.Compression.ZipFile]::ExtractToDirectory($AzureMarkdownRewriterToolDestination, $AzureMarkdownRewriterToolUnzipFolder)
echo 'Extract Success!'
$AzureMarkdownRewriterTool = "$AzureMarkdownRewriterToolUnzipFolder\Microsoft.DocAsCode.Tools.AzureMarkdownRewriterTool.exe"

# Call azure transform for every docset
echo "Start to call azure transform"
&"$AzureMarkdownRewriterTool"

if ($LASTEXITCODE -ne 0)
{
  exit WriteErrorAndExit("Transform failed and won't do build and publish for azure content") ($LASTEXITCODE)
}

# add build for docs
$buildEntryPointDestination = Join-Path $packageToolsDirectory -ChildPath "opbuild" | Join-Path -ChildPath "mdproj.builder.ps1"
$logLevel = GetValueFromVariableName($logLevel) ($systemDefaultVariables.Item("LogLevel"))
& "$buildEntryPointDestination" "$repositoryRoot" "$packagesDirectory" "$packageToolsDirectory" $dependencies $predefinedEntryPoints $logLevel $systemDefaultVariables

exit $LASTEXITCODE
