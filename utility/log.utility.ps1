# define enum LogLevel
Add-Type -TypeDefinition @"
   public enum LogLevel
   {
      Error,
      Warning,
      Info,
      Verbose,
      Diagnostic
   }
"@

Add-Type -TypeDefinition @"
   public enum LogItemType
   {
      System,
      User
   }
"@

Function FormatLogItem([object]$logItem, [int]$index)
{
    $messageSeverity = [LogLevel] $logItem.message_severity
    Write-Output $messageSeverity
    Write-Output $index
    if ($logItem.file)
    {
        Write-Output "[ $($logItem.file)"
        if ($logItem.line)
        {
            Write-Output "(line $($logItem.line))"
        }
        Write-Output "]"
    }
    Write-Output ": $($logItem.message)"
}

Function GenerateLogItem
{
    param( 
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$source,
        [Parameter(Mandatory=$true)][LogLevel]$logLevel,
        [Parameter(Mandatory=$true)][LogItemType]$logItemType,
        [Parameter(Mandatory=$false)][string]$file = '',
        [Parameter(Mandatory=$false)][int]$line = $null
    )
    $logItem = @{}
    $logItem.message = $message
    $logItem.source = $source
    $logItem.file = $file
    $logItem.line = $line
    $logItem.message_severity = $logLevel.ToString()
    $logItem.log_item_type = $logItemType.ToString()
    $logItem.date_time = ((Get-Date).ToUniversalTime()).ToString("yyyy/MM/dd HH:mm:ss")

    return $logItem | ConvertToJsonSafely -compress
}

# Sample：Log -logFilePath 'log/log.txt' -message 'message' -source 'source' -logLevel ([LogLevel]"Error") -logItemType ([LogItemType]"System")
Function Log
{
    param(
        [Parameter(Mandatory=$true)][string]$logFilePath,
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$source,
        [Parameter(Mandatory=$true)][LogLevel]$logLevel,
        [Parameter(Mandatory=$true)][LogItemType]$logItemType,
        [Parameter(Mandatory=$false)][string]$file = '',
        [Parameter(Mandatory=$false)][int]$line = $null
    )
    $logMessage = GenerateLogItem -message $message -source $source -logLevel $logLevel -logItemType $logItemType -file $file -line $line
    Add-Content "$logFilePath" "$logMessage"
}

# Sample：LogSystemError -logFilePath 'log/log.txt' -message 'message' -source 'source'
Function LogSystemError
{
    param(
        [Parameter(Mandatory=$true)][string]$logFilePath,
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$source,
        [Parameter(Mandatory=$false)][string]$file = '',
        [Parameter(Mandatory=$false)][int]$line = $null
    )
    Log -logFilePath $logFilePath -message $message -source $source -logLevel ([LogLevel]"Error") -logItemType ([LogItemType]"System") -file $file -line $line
}

# Sample：LogUserError -logFilePath 'log/log.txt' -message 'message' -source 'source'
Function LogUserError
{
    param(
        [Parameter(Mandatory=$true)][string]$logFilePath,
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$source,
        [Parameter(Mandatory=$false)][string]$file = '',
        [Parameter(Mandatory=$false)][int]$line = $null
    )
    Log -logFilePath $logFilePath -message $message -source $source -logLevel ([LogLevel]"Error") -logItemType ([LogItemType]"User") -file $file -line $line
}

# Sample：LogSystemWarning -logFilePath 'log/log.txt' -message 'message' -source 'source'
Function LogSystemWarning
{
    param(
        [Parameter(Mandatory=$true)][string]$logFilePath,
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$source,
        [Parameter(Mandatory=$false)][string]$file = '',
        [Parameter(Mandatory=$false)][int]$line = $null
    )
    Log -logFilePath $logFilePath -message $message -source $source -logLevel ([LogLevel]"Warning") -logItemType ([LogItemType]"System") -file $file -line $line
}

# Sample：LogUserWarning -logFilePath 'log/log.txt' -message 'message' -source 'source'
Function LogUserWarning
{
    param(
        [Parameter(Mandatory=$true)][string]$logFilePath,
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$source,
        [Parameter(Mandatory=$false)][string]$file = '',
        [Parameter(Mandatory=$false)][int]$line = $null
    )
    Log -logFilePath $logFilePath -message $message -source $source -logLevel ([LogLevel]"Warning") -logItemType ([LogItemType]"User") -file $file -line $line
}

# Sample：LogInfo -logFilePath 'log/log.txt' -message 'message' -source 'source'
Function LogInfo
{
    param(
        [Parameter(Mandatory=$true)][string]$logFilePath,
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$source,
        [Parameter(Mandatory=$false)][string]$file = '',
        [Parameter(Mandatory=$false)][int]$line = $null
    )
    Log -logFilePath $logFilePath -message $message -source $source -logLevel ([LogLevel]"Info") -logItemType ([LogItemType]"System") -file $file -line $line
}

# Sample：LogVerbose -logFilePath 'log/log.txt' -message 'message' -source 'source'
Function LogVerbose
{
    param(
        [Parameter(Mandatory=$true)][string]$logFilePath,
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$source,
        [Parameter(Mandatory=$false)][string]$file = '',
        [Parameter(Mandatory=$false)][int]$line = $null
    )
    Log -logFilePath $logFilePath -message $message -source $source -logLevel ([LogLevel]"Verbose") -logItemType ([LogItemType]"System") -file $file -line $line
}

# Logging in customized script plugin, supporting user to log by this function
# The varibale $logFilePath is provide by $ParameterDictionary by default
# Sample：Log -message 'message' -source 'source'
Function Logging
{
    param(
        [Parameter(Mandatory=$false)][string]$logFilePath = $ParameterDictionary.environment.logFile,
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$source,
        [Parameter(Mandatory=$false)][string]$file = '',
        [Parameter(Mandatory=$false)][int]$line = $null
    )

    Log -logFilePath $logFilePath -message $message -source $source -logLevel ([LogLevel]"Warning") -logItemType ([LogItemType]"User") -file $file -line $line
}
