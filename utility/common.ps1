# Checking for null in PowerShell, more details refer to: https://www.codykonior.com/2013/10/17/checking-for-null-in-powershell/
Function IsNull([object]$object) 
{
    if (-Not $object) 
    {
        return $true
    }
    elseif ($object -is [String] -and $object -eq [String]::Empty) 
    {
        return $true
    }
    elseif ($object -is [DBNull] -or $object -is [System.Management.Automation.Language.NullString]) 
    {
        return $true
    }
    else
    {
        return $false
    }
}

Function ArgumentNotNull([object]$argumentValue, [string]$argumentName)
{
    if ($argumentValue -eq $null)
    {
        Write-Callstack
        Throw [System.ArgumentException] "Argument $argumentName should not be null"
    }
}

Function ArgumentNotNullOrEmpty([string]$argumentValue, [string]$argumentName)
{
    if ([System.String]::IsNullOrEmpty($argumentValue))
    {
        Write-Callstack
        Throw [System.ArgumentException] "Argument $argumentName should not be null or empty"
    }
}

# Parameter $ErrorRecord: Powershell 3.0 specifies a ScriptStackTrace property to the ErrorRecord object. Refer to: https://blogs.msdn.microsoft.com/powershell/2006/12/07/resolve-error/ for more details.
# Parameter $SkipNumber: The Skip parameter leave Write-Callstack or any number of error-handling stack frames out of the Get-PSCallstack listing.
# Parameter $SkipLastNumber: The SkipLast parameter is similar with Skip which skip items from last.
function Write-Callstack([System.Management.Automation.ErrorRecord]$ErrorRecord = $null, [int]$SkipNumber = 1, [int]$SkipLastNumber = 1)
{
    if ($ErrorRecord)
    {
        Write-Host -ForegroundColor Red "$ErrorRecord $($ErrorRecord.InvocationInfo.PositionMessage)"

        if ($ErrorRecord.Exception)
        {
            Write-Host -ForegroundColor Red $ErrorRecord.Exception
        }

        if ((Get-Member -InputObject $ErrorRecord -Name ScriptStackTrace) -ne $null)
        {
            # PS 3.0 has a stack trace on the ErrorRecord; if we have it, use it & skip the manual stack trace below
            Write-Host -ForegroundColor Red $ErrorRecord.ScriptStackTrace
            return
        }
    }

    $PSCallStack = Get-PSCallStack | Select -Skip $SkipNumber
    $PSCallStackAfterSkipLast = SkipLastElementsFromArray($PSCallStack) ($SkipLastNumber)
    $PSCallStackAfterSkipLast | % {
        Write-Host -ForegroundColor Yellow -NoNewLine "! "
        Write-Host -ForegroundColor Red $_.Command $_.Location $(if ($_.Arguments.Length -le 80) { $_.Arguments })
    }
}

function Write-HostWithTimestamp([string]$output)
{
    ArgumentNotNullOrEmpty($output) ('$output')

    Write-Host -NoNewline -ForegroundColor Magenta "[$(((get-date).ToUniversalTime()).ToString("HH:mm:ss.ffffffZ"))]: "
    Write-Host $output
}

Function IsPathExists([string]$path)
{
    if ([System.String]::IsNullOrEmpty($path))
    {
        return $false
    }

    return Test-Path -Path $path
}

Function CheckPathAndWriteError([string]$path)
{
    if(!(IsPathExists($path)))
    {
        Write-Error "$path doesn't exist"
    }
}

Function ConvertToJsonSafely {
    param ([string]$content, [switch]$compress)
    process
    {
        # For Powershell version 5.1, the maximum depth is 100
        if ($compress)
        {
            return $_ | ConvertTo-Json -Depth 99 -Compress
        }
        else
        {
            return $_ | ConvertTo-Json -Depth 99
        }
    }
}

Function GetJsonContent([string]$jsonFilePath)
{
    ArgumentNotNullOrEmpty($jsonFilePath) ('$jsonFilePath')

    try {
        $jsonContent = Get-Content $jsonFilePath -Raw -Encoding UTF8
        return $jsonContent | ConvertFrom-Json
    }
    catch {
        Write-Callstack
        Write-Error "Invalid JSON file $jsonFilePath. JSON content detail: $jsonContent" -ErrorAction Continue
        throw
    }
}

Function GetLargeJsonContent([string]$jsonFilePath)
{
    try {
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
        $jsonSerializer= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
        $jsonSerializer.MaxJsonLength  = [System.Int32]::MaxValue

        $jsonContent = Get-Content $jsonFilePath -Raw -Encoding UTF8
        return $jsonSerializer.DeserializeObject($jsonContent)
    }
    catch {
        Write-Callstack
        Write-Error "Invalid JSON file $jsonFilePath. JSON content detail: $jsonContent" -ErrorAction Continue
        throw
    }
}

# Parameter $variableValue: can be null or empty
Function GetValueFromVariableName([string]$variableValue, [string]$defaultStringValue)
{
    if([string]::IsNullOrEmpty($variableValue))
    {
        $variableValue = $defaultStringValue
    }
    return $variableValue
}

# Parameter $psCustomObject: can be null or empty
Function ConvertToHashtableFromPsCustomObject([object]$psCustomObject)
{
    $hashtable = @{ }
    if ($psCustomObject)
    {
        $psCustomObject | Get-Member -MemberType *Property | % {
            $hashtable.($_.name) = $psCustomObject.($_.name)
        }
    }
    return $hashtable
}

# Parameter $globalMetadataFile: can be null or empty
Function GetUserAccessTokenFromGlobalMetadata([string]$globalMetadataFile, [string]$accessToken)
{
    return GetPropertyStringValueFromGlobalMetadata($globalMetadataFile) ($accessToken) ("_op_accessToken")
}

# Parameter $globalMetadataFile: can be null or empty
Function GetGitHubTemplateCloneTokenFromGlobalMetadata([string]$globalMetadataFile, [string]$accessToken)
{
    return GetPropertyStringValueFromGlobalMetadata($globalMetadataFile) ($accessToken) ("_op_gitHubTemplateCloneToken")
}

# Parameter $globalMetadataFile: can be null or empty
Function GetPropertyStringValueFromGlobalMetadata([string]$globalMetadataFile, [string]$overrideValue, [string]$property)
{
    if (![string]::IsNullOrEmpty($overrideValue))
    {
        return $overrideValue
    }

    if (![string]::IsNullOrEmpty($globalMetadataFile) -and (IsPathExists($globalMetadataFile)))
    {
        $docsetMetadata = ConvertToHashtableFromPsCustomObject(Get-Content $globalMetadataFile | ConvertFrom-Json)
        if ($docsetMetadata.($property) -and ![string]::IsNullOrEmpty($docsetMetadata.($property)))
        {
            $overrideValue = $docsetMetadata.($property)
        }
    }

    return $overrideValue
}

Function ValidatePublishConfig([object] $publishConfigContent)
{
    ArgumentNotNull($publishConfigContent) ('$publishConfigContent')

    $duplicateDocsetOutputSubFolders = $publishConfigContent.docsets_to_publish | group build_output_subfolder | where {$_.count -gt 1} | select name, count | Out-String
    if ($duplicateDocsetOutputSubFolders.Length -gt 0)
    {
        Write-Host "Following docset output subfolders occur more than once: $duplicateDocsetOutputSubFolders"
        exit 1
    }
}

Function ParseBuildEntryPoint([object]$predefinedEntryPoints, [string]$buildEntryPoint)
{
    ArgumentNotNull($predefinedEntryPoints) ('$predefinedEntryPoints')
    ArgumentNotNullOrEmpty($buildEntryPoint) ('$buildEntryPoint')

    foreach ($predefinedEntryPoint in $predefinedEntryPoints.Keys)
    {
        if ($buildEntryPoint -eq "$predefinedEntryPoint.ps1" -or $buildEntryPoint -eq $predefinedEntryPoint)
        {
            return $predefinedEntryPoint
        }
    }
    return $buildEntryPoint
}

Function GetCurrentScriptFile
{
    return $MyInvocation.MyCommand.Definition
}

Function GetCurrentLine
{
    return $Myinvocation.ScriptlineNumber
}

Function JoinPath([string]$rootPath, [string[]]$childPaths)
{
    ArgumentNotNullOrEmpty($rootPath) ('$rootPath')
    ArgumentNotNull($childPaths) ('$childPaths')

    $destination = $rootPath

    $childPaths | % {
        $destination = Join-Path $destination -ChildPath $_
    }

    return $destination
}

Function GetNormalizedPath([string]$path)
{
    ArgumentNotNullOrEmpty($path) ('$path')

    return $path -Replace "\\+|\/{2,}", "/"
}

Function RunExeProcess([string]$exeFilePath, [string]$arguments, [string]$workingDirectory = [String]::Empty, [int]$timeoutSec = -1)
{
    ArgumentNotNullOrEmpty($exeFilePath) ('$exeFilePath')
    ArgumentNotNullOrEmpty($arguments) ('$arguments')

    $redirectedStdOutFile = JoinPath($env:TEMP) (@([System.IO.Path]::GetRandomFileName()))
    $redirectedStdErrFile = JoinPath($env:TEMP) (@([System.IO.Path]::GetRandomFileName()))

    Try
    {
        if ($timeoutSec -le 0)
        {
            if ([string]::IsNullOrEmpty($workingDirectory))
            {
                $process = Start-Process -FilePath $exeFilePath -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardError $redirectedStdErrFile -RedirectStandardOutput $redirectedStdOutFile -Wait
            }
            else
            {
                $process = Start-Process -FilePath $exeFilePath -ArgumentList $arguments -WorkingDirectory $workingDirectory -NoNewWindow -PassThru -RedirectStandardError $redirectedStdErrFile -RedirectStandardOutput $redirectedStdOutFile -Wait
            }
        }
        else
        {
            if ([string]::IsNullOrEmpty($workingDirectory))
            {
                $process = Start-Process -FilePath $exeFilePath -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardError $redirectedStdErrFile -RedirectStandardOutput $redirectedStdOutFile
            }
            else
            {
                $process = Start-Process -FilePath $exeFilePath -ArgumentList $arguments -WorkingDirectory $workingDirectory -NoNewWindow -PassThru -RedirectStandardError $redirectedStdErrFile -RedirectStandardOutput $redirectedStdOutFile
            }

            if (!$process.HasExited)
            {
                Try
                {
                    Wait-Process -InputObject $process -Timeout $timeoutSec
                }
                Catch [System.InvalidOperationException]
                {
                    # $process may exit before Wait-Process, regard as no error
                }

                if (!$process.HasExited)
                {
                    Stop-Process -InputObject $process -Force
                    if (IsPathExists($redirectedStdOutFile))
                    {
                        $standardOutput = Get-Content $redirectedStdOutFile
                    }
                    if (IsPathExists($redirectedStdErrFile))
                    {
                        $standardError = Get-Content $redirectedStdErrFile
                    }
                    $errorMessage = "Run process $exeFilePath timeout in $timeoutSec seconds. Output: $standardOutput. Error: $standardError"
                    Write-HostWithTimestamp $errorMessage
                    Throw [System.Exception] $errorMessage
                }
            }
        }

        # need to wait process to exit so that we can get correct exit code below,
        # see https://msdn.microsoft.com/en-us/library/windows/desktop/ms683189(v=vs.85).aspx
        if (!$process.HasExited)
        {
            Try
            {
                Wait-Process -InputObject $process
            }
            Catch [System.InvalidOperationException]
            {
                # $process may exit before Wait-Process, regard as no error
            }
        }

        $executionResult = @{}
        $executionResult.ExitCode = $process.GetType().GetField("exitCode", "NonPublic,Instance").GetValue($process)
        if (IsPathExists($redirectedStdOutFile))
        {
            $executionResult.StandardOutput = Get-Content $redirectedStdOutFile
        }
        if (IsPathExists($redirectedStdErrFile))
        {
            $executionResult.StandardError = Get-Content $redirectedStdErrFile
        }
    }
    Catch
    {
        if (($process -ne $null) -and (!$process.HasExited))
        {
            $process.Kill()
        }
        Write-Callstack
        Throw
    }
    Finally
    {
        if (($process -ne $null) -and (!$process.HasExited))
        {
            $process.Kill()
        }
        if (IsPathExists($redirectedStdOutFile))
        {
            Remove-Item $redirectedStdOutFile -Force
        }
        if (IsPathExists($redirectedStdErrFile))
        {
            Remove-Item $redirectedStdErrFile -Force
        }
    }

    return $executionResult
}

Function RunExeProcessWithShellExecute([string]$exeFilePath, [string]$arguments, [string]$workingDirectory = [String]::Empty)
{
    ArgumentNotNullOrEmpty($exeFilePath) ('$exeFilePath')
    ArgumentNotNullOrEmpty($arguments) ('$arguments')

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exeFilePath
    $psi.Arguments = $arguments
    $psi.WorkingDirectory = $workingDirectory
    $psi.UseShellExecute = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start() | Out-Null
    
    $process.WaitForExit()

    return $process
}

Function CloneParameterDictionaryWithContext([hashtable]$currentDictionary, [hashtable]$context)
{
    ArgumentNotNull($currentDictionary) ('$currentDictionary')
    ArgumentNotNull($context) ('$context')

    $ParameterDictionary = $currentDictionary.Clone()
    $ParameterDictionary.context = $context

    return $ParameterDictionary
}

Function NormalizePath([string]$originalPath)
{
    ArgumentNotNullOrEmpty($originalPath) ('$originalPath')

    $originalPaths = $originalPath.Split("\/", [System.StringSplitOptions]::RemoveEmptyEntries)
    return [string]::Join("/", $originalPaths)
}

Function SkipLastElementsFromArray([object[]]$array, [int]$skipLastNumber = 1)
{
    ArgumentNotNull($array) ('$array')

    $skipCount = $array.Count - $skipLastNumber
    if ($skipCount -le 0)
    {
        # An empty array is mangled into $null in the process
        # Preserve an array on return by prepending it with the array construction operator (,)
        # Refer to http://stackoverflow.com/questions/18476634/powershell-doesnt-return-an-empty-array-as-an-array for more details.
        return ,@()
    }

    $ArrayAfterSkipLast = @()
    for ($i = 0; $i -lt $skipCount; $i++)
    {
        $ArrayAfterSkipLast += $array[$i]
    }

    return $ArrayAfterSkipLast
}

Function IsStringInArray([string[]]$array, [string]$value, [bool]$ignoreCase = $false)
{
    ArgumentNotNullOrEmpty($value) ('$value')

    if($array -eq $null)
    {
        return $false
    }

    if($ignoreCase)
    {
        return $array.ToLower().Contains($value.ToLower())
    }
    else
    {
        return $array.Contains($value)
    }
}

Function ParseBoolValue([string]$variableName, [string]$stringValue, [bool]$defaultBoolValue)
{
    if([string]::IsNullOrEmpty($stringValue))
    {
        return $defaultBoolValue
    }

    try
    {
        $parsedBoolValue = [System.Convert]::ToBoolean($stringValue)
    }
    catch
    {
        Write-Error "variable $variableName does not have a valid bool value: $stringValue. Exception: $($_.Exception.Message)"
    }

    return $parsedBoolValue
}

Function GetAssemblyFileVersion([string]$assemblyFilePath)
{
    ArgumentNotNullOrEmpty($assemblyFilePath) ('$assemblyFilePath')

    return Get-ChildItem $assemblyFilePath | Select-Object -ExpandProperty VersionInfo | Select-Object -ExpandProperty FileVersion
}