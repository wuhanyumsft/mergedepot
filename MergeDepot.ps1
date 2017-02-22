echo "Hello World."

# Add specific step for azure
# Download Azure Transform tool
Add-type -AssemblyName "System.IO.Compression.FileSystem"
$mergeDepotToolContainerUrl = "https://siwtest.blob.core.windows.net/mergedepot"

if(!(Test-Path ".optemp"))
{
    New-Item ".optemp" -ItemType Directory
}

$currentFolder = Get-Location
$MergeDepotToolSource = "$mergeDepotToolContainerUrl/MergeDepotTool.zip"
$MergeDepotToolDestination = "$currentFolder\.optemp\MergeDepotTool.zip"

Get-ChildItem
echo 'Start Download!'
Invoke-WebRequest -Uri $MergeDepotToolSource -OutFile $MergeDepotToolDestination
echo 'Download Success!'
Get-ChildItem

$MergeDepotToolUnzipFolder = "$currentFolder\.optemp\MergeDepotTool"
if((Test-Path "$MergeDepotToolUnzipFolder"))
{
    Remove-Item $MergeDepotToolUnzipFolder -Force -Recurse
}

[System.IO.Compression.ZipFile]::ExtractToDirectory($MergeDepotToolDestination, $MergeDepotToolUnzipFolder)
echo 'Extract Success!'
Get-ChildItem
$MergeDepotTool = "$MergeDepotToolUnzipFolder\MergeDepot.exe"

# Call azure transform for every docset
echo "Start to call merge depot tool"
&"$MergeDepotTool" "$currentFolder\mergedepot"
echo "Finish calling merge depot tool"

echo "Start to push to git repository"
git add *
git commit -m "update"
git push origin master
echo "Finish pushing to git repository"

if ($LASTEXITCODE -ne 0)
{
  exit WriteErrorAndExit("Merge Depot failed and won't do build and publish for merge depot") ($LASTEXITCODE)
}

exit $LASTEXITCODE
