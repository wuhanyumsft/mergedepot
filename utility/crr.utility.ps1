# Include referenced utility scripts
$utilityDir = $($MyInvocation.MyCommand.Definition) | Split-Path
. "$utilityDir/log.utility.ps1"
. "$utilityDir/common.ps1"
. "$utilityDir/git.utility.ps1"
. "$utilityDir/console.utility.ps1"
. "$utilityDir/nuget.utility.ps1"
. "$utilityDir/resource.utility.ps1"

Function ValidateCRR([object]$publishConfigContent, [string]$reportFilePath, [string]$source, [int]$lineNumber)
{
    $hasDuplicateCRRs = $false
    $crrPaths = @()
    foreach($crr in $publishConfigContent.dependent_repositories)
    {
        $normalizedPathToRoot = NormalizePath($crr.path_to_root)
        if($crrPaths.Contains($normalizedPathToRoot))
        {
            $errorMessage = "Dependent repositories are invalid in publish config: Don't set more than one dependent repositories with same path_to_root. Same path_to_root value: $normalizedPathToRoot"
            LogUserError -logFilePath $reportFilePath -message $errorMessage -source $source -line $(GetCurrentLine)
            $hasDuplicateCRRs = $true
        }
        else
        {
            $crrPaths += $normalizedPathToRoot
        }
    }

    return !$hasDuplicateCRRs
}

Function InitializeCRR([string]$repositoryRoot, [object]$publishConfigContent, [object[]]$cachedRepositories, [object[]]$lastDependencyStatus, [string]$reportFilePath, [string]$source, [int]$lineNumber)
{
    #Clone dependent repositories and switch to specified branch
    $gitPath = LocateGitExe
    $cloneExitCode = 0
    $defaultRemoteName = "origin"

    $gitmodulesFile = JoinPath($repositoryRoot) (@(".gitmodules"))
    if (IsPathExists($gitmodulesFile))
    {
        Write-HostWithTimestamp "Clean the submodule folder before clone dependent repository"
        $submodules = ParseSubmodulesFromGit($gitmodulesFile)
        foreach ($submodule in $submodules)
        {
            $submoduleGitPath = JoinPath($repositoryRoot) (@("$($submodule.path)", ".git"))
            if (IsPathExists($submoduleGitPath))
            {
                Remove-Item "$submoduleGitPath" -Recurse -Force
            }
        }
        & "$gitPath" "-C" "$repositoryRoot" "submodule" "--quiet" "deinit" "-f" "."
    }

    $dpRepoClonedPathsToRoot = @()
    if ($publishConfigContent.dependent_repositories -ne $null)
    {
        # Locate current parent repository working branch
        $workingBranchName = GetWorkingBranch($gitPath) ($repositoryRoot) ($reportFilePath) ($source) ($(GetCurrentLine))
        if ([String]::IsNullOrEmpty($workingBranchName))
        {
            Write-HostWithTimestamp "Can't get working branch in folder $repositoryRoot."
            exit 1
        }
        Write-HostWithTimestamp "Parent working branch is $workingBranchName"

        # Clone dependent repository and switch to spcified branch
        foreach($dpRepo in $publishConfigContent.dependent_repositories)
        {
            if ($dpRepo.path_to_root.StartsWith(".."))
            {
                $errorMessage = "Dependent repository cloned path can't be above the root path. If it's not, please make sure you don't write the path start with "".."". Invalid value: $($dpRepo.path_to_root)"
                LogUserError -logFilePath $reportFilePath -message $errorMessage -source $source -line $(GetCurrentLine)
                exit ConsoleErrorAndExit($errorMessage) (1)
            }

            $cloneAccessToken = $_op_accessToken
            if ((IsStringInArray($systemDefaultVariables.PreservedTemplateFolders) ("$($dpRepo.path_to_root)") ($true)))
            {
                $cloneAccessToken = $_op_gitHubTemplateCloneToken
            }

            $dpRepoPath = JoinPath($repositoryRoot) (@($dpRepo.path_to_root))

            if (!(IsPathExists($dpRepoPath)) -or ((Get-ChildItem -Force $dpRepoPath) -eq $Null))
            {
                # check environment resource, if the repo is cached, copy it to path_to_root
                if ($cachedRepositories)
                {
                    $cachedRepo = FindResource($cachedRepositories) ($($dpRepo.url))
                    if ($cachedRepo)
                    {
                        Write-HostWithTimestamp "Using cached data in $($cachedRepo.Location) for repository '$($dpRepo.url)', path_to_root '$($dpRepo.path_to_root)'"
                        if (IsPathExists($dpRepoPath))
                        {
                            Remove-Item "$dpRepoPath" -Recurse -Force
                        }
                        Copy-Item "$($cachedRepo.Location)" -Destination "$dpRepoPath" -Recurse -Force
                    }
                }
            }

            if ((IsPathExists($dpRepoPath)) -and ((Get-ChildItem -Force $dpRepoPath) -ne $Null))
            {
                $gitFolderPathOfDpRepoFolder = GetGitFolderOfCurrentPath($gitPath) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))
                if (([String]::IsNullOrEmpty($gitFolderPathOfDpRepoFolder)) -or ($gitFolderPathOfDpRepoFolder -ne ".git"))
                {
                    $errorMessage = "Folder $($dpRepo.path_to_root) under repository is not a valid git folder of dependent repository $($dpRepo.url). Error: $($process.StandardError). Got git path: $gitFolderPathOfDpRepoFolder"
                    LogUserError -logFilePath $reportFilePath -message $errorMessage -source $source -line $(GetCurrentLine)
                    exit ConsoleErrorAndExit($errorMessage) (1)
                }

                $remoteOriginUrl = GetRemoteUrl($gitPath) ($defaultRemoteName) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))
                if (([String]::IsNullOrEmpty($remoteOriginUrl)) -or ($remoteOriginUrl.ToLower().Trim(".git") -ne $dpRepo.url.ToLower().Trim(".git")))
                {
                    $errorMessage = "Folder $($dpRepo.path_to_root) under repository $defaultRemoteName is from $remoteOriginUrl but not from $($dpRepo.url). Please clean up the folder."
                    LogUserError -logFilePath $reportFilePath -message $errorMessage -source $source -line $(GetCurrentLine)
                    exit ConsoleErrorAndExit($errorMessage) (1)
                }

                Try
                {
                    $remoteOriginUrlWithToken = GenerateSubmoduleAddressWithToken ($remoteOriginUrl) ($cloneAccessToken)
                    if (!(SetRemoteUrl($gitPath) ($defaultRemoteName) ($remoteOriginUrlWithToken) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))) -or !(PullWithRetry($gitPath) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))))
                    {
                        exit 1
                    }
                }
                Finally
                {
                    if (!(SetRemoteUrl($gitPath) ($defaultRemoteName) ($remoteOriginUrl) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))))
                    {
                        exit 1
                    }
                }
            }
            else
            {
                $dpRepoUrlWithToken = GenerateSubmoduleAddressWithToken ($dpRepo.url) ($cloneAccessToken)
                if(!(CloneWithRetry($gitPath) ($dpRepoUrlWithToken) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))) -or !(SetRemoteUrl($gitPath) ($defaultRemoteName) ($dpRepo.url) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))))
                {
                    exit 1
                }
            }

            if ($cloneExitCode -ne 0)
            {
                continue;
            }

            $pathToRoot = GetNormalizedPath($dpRepo.path_to_root)
            Write-HostWithTimestamp "Add '$pathToRoot' to cloned path"
            $dpRepoClonedPathsToRoot += $pathToRoot

            # Based on branch mapping information and parent working branch, switch to the speicified branch name of dependent repository
            $branch = $dpRepo.branch
            $mappingBranch = $($($dpRepo.branch_mapping).$workingBranchName)
            if (![String]::IsNullOrEmpty($mappingBranch))
            {
                $branch = $mappingBranch
            }
            Write-HostWithTimestamp "Dependent repository $($dpRepo.url) is using branch: $branch"

            Try
            {
                $dpRepoUrlWithToken = GenerateSubmoduleAddressWithToken ($dpRepo.url) ($cloneAccessToken)

                # checkout to cached template commit id if necessary
                if ((IsStringInArray($systemDefaultVariables.PreservedTemplateFolders) ("$($dpRepo.path_to_root)") ($true)) -and $lastDependencyStatus)
                {
                    foreach ($lastTemplateCrrStatus in $lastDependencyStatus)
                    {
                        if ($lastTemplateCrrStatus -and ($lastTemplateCrrStatus.path -eq $dpRepo.path_to_root) -and ($lastTemplateCrrStatus.url -eq $dpRepo.url) -and ($lastTemplateCrrStatus.branch -eq $branch) -and $lastTemplateCrrStatus.commit_id)
                        {
                            $lastTemplateCrrCommitId = $lastTemplateCrrStatus.commit_id
                        }
                    }

                    if (![string]::IsNullOrEmpty($lastTemplateCrrCommitId))
                    {
                        if ((Checkout($gitPath) ($branch) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))) -and (Reset($gitPath) ($lastTemplateCrrCommitId) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))))
                        {
                            Write-HostWithTimestamp "Checkout template in '$($dpRepo.path_to_root)' to branch $branch with cached commit id '$lastTemplateCrrCommitId'"
                            continue;
                        }
                        else
                        {
                            Write-HostWithTimestamp "Failed to checkout template in '$($dpRepo.path_to_root)' to branch $branch with cached commit id '$lastTemplateCrrCommitId', try checking out to latest"
                        }
                    }
                }

                if (!(Checkout($gitPath) ($branch) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))) -or !(SetRemoteUrl($gitPath) ($defaultRemoteName) ($dpRepoUrlWithToken) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))) -or !(PullWithRetry($gitPath) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))))
                {
                    exit 1
                }
            }
            Finally
            {
                if (!(SetRemoteUrl($gitPath) ($defaultRemoteName) ($dpRepo.url) ($dpRepoPath) ($reportFilePath) ($source) ($(GetCurrentLine))))
                {
                    exit 1
                }
            }
        }

        if ($cloneExitCode -ne 0)
        {
            $errorMessage = "Clone dependent repositories and checkout to specifiec branch failed"
            LogSystemError -logFilePath $reportFilePath -message $errorMessage -source $source -line $(GetCurrentLine)
            exit ConsoleErrorAndExit($errorMessage) ($cloneExitCode)
        }
    }

    if ($dpRepoClonedPathsToRoot.Length -eq 0)
    {
        return ,@()
    }

    return $dpRepoClonedPathsToRoot
}

Function RestoreOpCommonPackages([string]$tempRestoredFolder, [string]$packageConfigPath, [string]$detinationRestoredFolder, [string]$nugetExe, [string]$nugetConfig, [string]$reportFilePath, [int]$maxRetryCount, [object]$lastRepoStatus = $null, [object[]]$environmentResources = $null)
{
    if (!(IsPathExists($tempRestoredFolder)))
    {
        New-Item $tempRestoredFolder -ItemType Directory
    }
    $actualPackageConfigPath = $packageConfigPath

    $opCommonPackageId = "opbuild.templates.common"
    [xml]$packageConfigXml = Get-Content -Path $packageConfigPath
    $opCommonPackageNode = $packageConfigXml.SelectSingleNode("packages/package[@id='$opCommonPackageId']")
    $opCommonPackageVersion = $requestedVersion = $opCommonPackageNode.Attributes["version"].Value

    $opCommonPackage = @{}
    $opCommonPackage["id"] = $opCommonPackageId
    $opCommonPackage["version"] = $opCommonPackageVersion
    if (([string]::Compare($opCommonPackageVersion, "latest", $true) -eq 0) -or ([string]::Compare($opCommonPackageVersion, "latest-prerelease", $true) -eq 0))
    {
        # Get actual version of op common package
        if ($lastRepoStatus -and $($lastRepoStatus.$opCommonPackageId))
        {
            $opCommonPackageVersion = $($lastRepoStatus.$opCommonPackageId);
            Write-HostWithTimestamp "Using cached version $opCommonPackageVersion for package $opCommonPackageId"
        }
        else
        {
            $usePrereleasePackage = [string]::Compare($opCommonPackageVersion, "latest-prerelease", $true) -eq 0
            $opCommonPackageVersion = GetPackageLatestVersion($nugetExe) ($opCommonPackageId) ($nugetConfig) ($maxRetryCount) ($usePrereleasePackage) ($environmentResources)
        }

        $opCommonPackageNode.SetAttribute("version", $opCommonPackageVersion)
        $actualPackageConfigPath = JoinPath($tempRestoredFolder) (@("packages.config"))
        $packageConfigXml.Save($actualPackageConfigPath)
    }
    Write-HostWithTimestamp "Using version $opCommonPackageVersion for package $opCommonPackageId. (requested: $requestedVersion)"
    $opCommonPackage["actualVersion"] = $opCommonPackageVersion

    RestorePackageWithLog($nugetExe) ($actualPackageConfigPath) ($tempRestoredFolder) ($nugetConfig) ($reportFilePath)
    if (!(IsPathExists($detinationRestoredFolder)))
    {
        New-Item $detinationRestoredFolder -ItemType Directory
    }

    $sourceContent = "$tempRestoredFolder\$opCommonPackageId.$opCommonPackageVersion\templates\*"
    Copy-Item $sourceContent $detinationRestoredFolder -Recurse -Force

    return $opCommonPackage
}

Function IsPreservedFallbackFolder([string]$dpRepoClonedPathToRoot, [string]$PreservedFallbackFolderRegex)
{
    return $dpRepoClonedPathToRoot -Match $PreservedFallbackFolderRegex
}