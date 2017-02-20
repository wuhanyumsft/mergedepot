# Include referenced utility scripts
$utilityDir = $($MyInvocation.MyCommand.Definition) | Split-Path
. "$utilityDir/log.utility.ps1"
. "$utilityDir/console.utility.ps1"
. "$utilityDir/common.ps1"

Function LocateGitExe()
{
    try
    {
        $gitPath = Get-Command git.exe | Select-Object -ExpandProperty Definition
        return $gitPath
    }
    catch
    {
        exit ConsoleErrorAndExit("Can't find git.exe in your environment. Please make sure you've already installed git and check if the path is already added into environment variable PATH.") (1)
    }
}

Function ParseSubmodulesFromGit([string]$gitmodulesFile)
{
    $start = "[{"
    $middle = "},{"
    $end = "}]"
    $empty = "[]"

    $gitModuleContents = Get-Content $gitmodulesFile
    $gitModuleJsonContents = $start
    foreach ($line in $gitModuleContents)
    {
        if($line -Match '^\s*\[submodule\s+"\s*(\w+[^"]*|[^"]*\w+)\s*"\s*\]\s*$')
        {
            $submoduleName = $line -Replace '^\s*\[submodule\s+"\s*(\w+[^"]*|[^"]*\w+)\s*"\s*\]\s*$','$1'
            if ($gitModuleJsonContents -ne $start)
            {
                $gitModuleJsonContents += $middle
            }
            $gitModuleJsonContents += "'name' : '$($submoduleName.Trim())'"
        }
        elseif ($line -like "*=*")
        {
            $key = $line.Split("=")[0].Trim()
            $value = $line.Split("=")[1].Trim()
            $gitModuleJsonContents += ",'$key' : '$value'"
        }
    }
    $gitModuleJsonContents += $end
    if ($gitModuleJsonContents -eq $start+$end)
    {
        $gitModuleJsonContents = $empty
    }

    try {
        $submodules = $gitModuleJsonContents | ConvertFrom-Json
    }
    catch {
        $err = $_.Exception
        echo "Invalid JSON file $gitmodulesFile. Exception detail: $err.Message" | timestamp
        exit 1
    }
    
    return $submodules | % { ConvertToHashtableFromPsCustomObject($_) }
}

# TODO: VSO's address is different style, need to care about!
Function GenerateSubmoduleAddressWithToken([string]$gitAddress, [string]$userToken)
{
    if($gitAddress -Match "https:\/\/([\w]+:)?([\w]+)@[\w\W]+")
    {
        return $gitAddress
    }

    $prefix = "https://"
    if($gitAddress.StartsWith($prefix))
    {
        $middle = ""
        if(![System.String]::IsNullOrEmpty($userToken))
        {
            $middle = "username:$userToken@"
        }
        return $prefix + $middle + $gitAddress.Substring($prefix.Length)
    }
    else
    {
        LogUserError -logFilePath $reportFilePath -message "The git address is not started with $prefix. address: $gitAddress." -source $source -line $(GetCurrentLine)
        exit ConsoleErrorAndExit("The git address is not started with $prefix. address: $gitAddress") (1)
    }
}

Function GetWorkingBranch([string]$gitPath, [string]$workingFolder, [string]$reportFilePath, [string]$source, [int]$lineNumber)
{
    $process = RunExeProcess($gitPath) ("rev-parse --abbrev-ref HEAD") ($workingFolder) ($systemDefaultVariables.GitOtherOperationsTimeOutInSeconds)
    if ($process.ExitCode -ne 0)
    {
        $errorMessage = "Can't get working branch info in folder $workingFolder. Error: $($process.StandardError)"
        ConsoleErrorAndExit($errorMessage) ($process.ExitCode)
        LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        return [String]::Empty
    }
    return $process.StandardOutput.Trim()
}

Function GetGitFolderOfCurrentPath([string]$gitPath, [string]$currentPath, [string]$reportFilePath, [string]$source, [int]$lineNumber)
{
    $process = RunExeProcess($gitPath) ("rev-parse --git-dir") ($currentPath) ($systemDefaultVariables.GitOtherOperationsTimeOutInSeconds)
    if ($process.ExitCode -ne 0)
    {
        $errorMessage = "Can't get git folder of $currentPath, make sure the path is inside git repository. Error: $($process.StandardError)."
        ConsoleErrorAndExit($errorMessage) ($process.ExitCode)
        LogUserError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        return [String]::Empty
    }
    return $process.StandardOutput.Trim()
}

Function SetRemoteUrl([string]$gitPath, [string]$remote, [string]$url, [string]$workingFolder, [string]$reportFilePath, [string]$source, [int]$lineNumber)
{
    $process = RunExeProcess($gitPath) ("remote set-url $remote ""$url""") ($workingFolder) ($systemDefaultVariables.GitOtherOperationsTimeOutInSeconds)
    if ($process.ExitCode -ne 0)
    {
        $errorMessage = "Set remote url: $url in folder:$workingFolder failed. Error: $($process.StandardError)"
        ConsoleErrorAndExit($errorMessage) ($process.ExitCode)
        LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        return $false
    }
    return $true
}

Function GetRemoteUrl([string]$gitPath, [string]$remote, [string]$workingFolder, [string]$reportFilePath, [string]$source, [int]$lineNumber)
{
    $process = RunExeProcess ($gitPath) ("remote get-url $remote") ($workingFolder) ($systemDefaultVariables.GitOtherOperationsTimeOutInSeconds)
    if ($process.ExitCode -ne 0)
    {
        $errorMessage = "Get remote $remote url in folder:$workingFolder failed. Error: $($process.StandardError)"
        ConsoleErrorAndExit($errorMessage) ($process.ExitCode)
        LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        return [String]::Empty
    }
    return $process.StandardOutput.Trim()
}

Function NormalizeGitUrlWithoutToken([string]$gitUrl)
{
    if($gitUrl -Match "(?<prefix>https:\/\/)((?<username>[\w]+):)?(?<accesstoken>[\w]+)@(?<postfix>[\w\W]+)")
    {
        return $Matches["prefix"] + $Matches["postfix"]
    }
    return $gitUrl
}

Function CloneWithRetry([string]$gitPath, [string]$gitUrl, [string]$clonedPath, [string]$reportFilePath, [string]$source, [int]$lineNumber, [int]$maxRetryCount = $systemDefaultVariables.DefaultMaxRetryCount, [ValidateScript({$_ -ge 0})][int]$retryIncrementalIntervalInSeconds = 10)
{
    $currentRetryIteration = 1
    $retryIncrementalIntervalInSeconds = 0
    $errorMessage = [string]::Empty

    Write-HostWithTimestamp "Start to clone repository with retry."
    do{
        try
        {
            return Clone($gitPath) ($gitUrl) ($clonedPath) ($reportFilePath) ($source) ($lineNumber)
        }
        Catch
        {
            $gitUrlWithoutToken = NormalizeGitUrlWithoutToken($gitUrl)
            $errorMessage = "Clone $gitUrlWithoutToken to folder $clonedPath failed. exception: '$($_.Exception.Message)'."
            Write-HostWithTimestamp "Calling iteration $currentRetryIteration failed: $errorMessage"
        }

        if ($currentRetryIteration -ne $maxRetryCount)
        {
            LogInfo -logFilePath $reportFilePath -message "ScriptTraceError: Clone repository content timeout. Working directory: $clonedPath" -source $source -line $lineNumber
            if (IsPathExists($clonedPath))
            {
                Write-HostWithTimestamp "Clean up the cloned destination folder: $clonedPath."
                Remove-Item $clonedPath -Recurse -Force
            }
            $retryIntervalInSeconds += $retryIncrementalIntervalInSeconds
            Start-Sleep -Seconds $retryIntervalInSeconds
        }
    } while (++$currentRetryIteration -le $maxRetryCount)

    ConsoleErrorAndExit($errorMessage) (1)
    LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
    return $false
}

Function Clone([string]$gitPath, [string]$gitUrl, [string]$clonedPath, [string]$reportFilePath, [string]$source, [int]$lineNumber)
{
    $gitUrlWithoutToken = NormalizeGitUrlWithoutToken($gitUrl)
    Write-HostWithTimestamp "Start to clone $gitUrlWithoutToken repository to folder $clonedPath."
    $process = RunExeProcess($gitPath) ("clone ""$gitUrl"" ""$clonedPath""") ([string]::Empty) ($systemDefaultVariables.GitCloneRepositoryTimeOutInSeconds)
    if ($process.ExitCode -ne 0)
    {
        $processErrorMessage = $process.StandardError
        $errorMessage = "Clone $gitUrlWithoutToken to folder $clonedPath failed. Error: $processErrorMessage"
        ConsoleErrorAndExit($errorMessage) ($process.ExitCode)
        if (([string]$processErrorMessage).Contains("Authentication failed") -or ([string]$processErrorMessage).Contains("Repository not found"))
        {
            LogUserError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        }
        else
        {
            LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        }
        return $false
    }
    Write-HostWithTimestamp "Clone repository to folder $clonedPath succeeded."
    return $true
}

Function Checkout([string]$gitPath, [string]$branch, [string]$workingFolder, [string]$reportFilePath, [string]$source, [int]$lineNumber)
{
    Write-HostWithTimestamp "Start to switch branch to $branch in folder $workingFolder."
    $process = RunExeProcess($gitPath) ("checkout $branch") ($workingFolder) ($systemDefaultVariables.GitOtherOperationsTimeOutInSeconds)
    if ($process.ExitCode -ne 0)
    {
        $errorMessage = "Checkout to branch $branch in folder: $workingFolder failed. Error: $($process.StandardError)"
        LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        ConsoleErrorAndExit($errorMessage) ($process.ExitCode)
        return $false
    }
    Write-HostWithTimestamp "Switch branch to $branch in folder $workingFolder succeeded."
    return $true
}

Function Reset([string]$gitPath, [string]$commitId, [string]$workingFolder, [string]$reportFilePath, [string]$source, [int]$lineNumber)
{
    Write-HostWithTimestamp "Start to reset to $commitId in folder $workingFolder."
    $process = RunExeProcess($gitPath) ("reset $commitId --hard") ($workingFolder) ($systemDefaultVariables.GitOtherOperationsTimeOutInSeconds)
    if ($process.ExitCode -ne 0)
    {
        $errorMessage = "Reset to commit id $commitId in folder: $workingFolder failed. Error: $($process.StandardError)"
        LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        ConsoleErrorAndExit($errorMessage) ($process.ExitCode)
        return $false
    }
    Write-HostWithTimestamp "Reset to $commitId in folder $workingFolder succeeded."
    return $true
}

Function PullWithRetry([string]$gitPath, [string]$workingFolder, [string]$reportFilePath, [string]$source, [int]$lineNumber, [int]$maxRetryCount = $systemDefaultVariables.DefaultMaxRetryCount, [ValidateScript({$_ -ge 0})][int]$retryIncrementalIntervalInSeconds = 10)
{
    $currentRetryIteration = 1
    $retryIncrementalIntervalInSeconds = 0
    $errorMessage = [string]::Empty

    Write-HostWithTimestamp "Start to pull repository with retry."
    do{
        try
        {
            return Pull($gitPath) ($workingFolder) ($reportFilePath) ($source) ($lineNumber)
        }
        Catch
        {
            $errorMessage = "Pull content to folder $workingFolder failed. exception: '$($_.Exception.Message)'."
            Write-HostWithTimestamp "Calling iteration $currentRetryIteration failed: $errorMessage"
        }

        if ($currentRetryIteration -ne $maxRetryCount)
        {
            LogInfo -logFilePath $reportFilePath -message "ScriptTraceError: Pull repository content timeout. Working directory: $workingFolder" -source $source -line $lineNumber
            $retryIntervalInSeconds += $retryIncrementalIntervalInSeconds
            Start-Sleep -Seconds $retryIntervalInSeconds
        }
    } while (++$currentRetryIteration -le $maxRetryCount)

    ConsoleErrorAndExit($errorMessage) (1)
    LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
    return $false
}

Function Pull([string]$gitPath, [string]$workingFolder, [string]$reportFilePath, [string]$source, [int]$lineNumber)
{
    Write-HostWithTimestamp "Start to pull content in folder $workingFolder."
    $process = RunExeProcess($gitPath) ("pull") ($workingFolder) ($systemDefaultVariables.GitPullRepositoryTimeOutInSeconds)
    if ($process.ExitCode -ne 0)
    {
        $processErrorMessage = $process.StandardError
        $errorMessage = "Pull content in folder $workingFolder failed. Error: $processErrorMessage "
        ConsoleErrorAndExit($errorMessage) ($process.ExitCode)
        if (([string]$processErrorMessage).Contains("Authentication failed") -or ([string]$processErrorMessage).Contains("Repository not found"))
        {
            LogUserError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        }
        else
        {
            LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $lineNumber
        }
        return $false
    }
    Write-HostWithTimestamp "Pull content in folder $workingFolder succeeded."
    return $true
}