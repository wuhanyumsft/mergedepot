Function ConsoleWarning([string]$message)
{
    Write-Host -ForegroundColor Yellow $message
}

Function ConsoleErrorAndExit([string]$message, [int]$exitCode)
{
    Write-Host -ForegroundColor Red $message
    return $exitCode
}

Function ConsoleWarningAndExit([string]$message, [int]$exitCode)
{
    Write-Host -ForegroundColor Yellow $message
    return $exitCode
}

Function ConsoleInfoAndExit([string]$message, [int]$exitCode)
{
    Write-Host $message
    return $exitCode
}