# Include referenced utility scripts
$utilityDir = $($MyInvocation.MyCommand.Definition) | Split-Path
. "$utilityDir/log.utility.ps1"

# Sample：GetJsonContentWithLog -$jsonFilePath 'sample.json' -$reportFilePath 'message' -source 'source' -lineNumber '10' -logType 'User'
Function GetJsonContentWithLog
{
    param (
        [parameter(mandatory=$true)]
        [string]$jsonFilePath, 

        [parameter(mandatory=$true)]
        [string]$reportFilePath,

        [parameter(mandatory=$true)]
        [string]$source,

        [parameter(mandatory=$true)]
        [int]$lineNumber,

        [parameter(mandatory=$false)]
        [string]$logType = "User"
    )

    try
    {
        return GetJsonContent($jsonFilePath)
    }
    catch 
    {
        $errorMessage = "Invalid syntax in $jsonFilePath. Please validate your syntax with a JSON validator like http://jsonlint.com/ and update the json file in the repo with a correct syntax."

        if ([LogItemType]"$logType" -eq [LogItemType]"User")
        {
            LogUserError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        }
        else
        {
            LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        }

        throw
    }
}

# Sample：GetLargeJsonContentWithLog -$jsonFilePath 'sample.json' -$reportFilePath 'message' -source 'source' -lineNumber '10' -logType 'User'
Function GetLargeJsonContentWithLog
{
    param (
        [parameter(mandatory=$true)]
        [string]$jsonFilePath, 

        [parameter(mandatory=$true)]
        [string]$reportFilePath,

        [parameter(mandatory=$true)]
        [string]$source,

        [parameter(mandatory=$true)]
        [int]$lineNumber,

        [parameter(mandatory=$false)]
        [string]$logType = "User"
    )

    try
    {
        return GetLargeJsonContent($jsonFilePath)
    }
    catch 
    {
        $errorMessage = "Invalid syntax in $jsonFilePath. Please validate your syntax with a JSON validator like http://jsonlint.com/ and update the json file in the repo with a correct syntax."

        if ([LogItemType]"$logType" -eq [LogItemType]"User")
        {
            LogUserError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        }
        else
        {
            LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        }

        throw
    }
}