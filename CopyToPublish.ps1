echo "Bypass Build."
$copySourceFolder = Join-Path $repositoryRoot "mergedepot"
$copyTargetFolder = Join-Path $OutputFolder "mergedepot"
echo "Start copying files and folders from $copySourceFolder to $copyTargetFolder."
Copy-Item $copySourceFolder $copyTargetFolder -recurse
echo "Finish copying files and folders from $copySourceFolder to $copyTargetFolder."
