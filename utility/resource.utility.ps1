Function FindResource(
    [object[]]$resources,
    [parameter(mandatory=$true)]
    [string]$resourceName,
    [string]$resourceVersion = $null
)
{
    foreach ($resource in $resources)
    {
        if ([string]::Compare($resource.Name, $resourceName, $true) -eq 0)
        {
            if ([string]::IsNullOrEmpty($resourceVersion) -or ([string]::Compare($resource.Version, $resourceVersion, $true) -eq 0))
            {
                return $resource
            }
        }
    }

    return $null
}
