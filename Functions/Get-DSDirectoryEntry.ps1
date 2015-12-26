function Get-DSDirectoryEntry {
    <#
        .ExternalHelp ..\DirectoryServices.Help.xml
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False, Position = 0,ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True)]
            [String]$Path,
        [Parameter(Mandatory = $False, Position = 1, ValueFromPipelineByPropertyName=$True)]
            [Management.Automation.PSCredential]$Credential
    )
    if ($Credential) {
        if ($Credential.GetNetworkCredential().Domain.Length -eq 0) {
            $UserName = $Credential.GetNetworkCredential().UserName
        } else {
            $UserName = $Credential.UserName
        }
        $DirectoryEntry = New-Object DirectoryServices.DirectoryEntry($Path, $UserName, $Credential.GetNetworkCredential().Password)
    } else {
        $DirectoryEntry = New-Object DirectoryServices.DirectoryEntry($Path)
    }
    if ($DirectoryEntry.NativeObject -eq $Null) {
        Throw [DirectoryServices.DirectoryServicesCOMException] "Unable to retrieve DirectoryEntry: $Path"
    }
    return $DirectoryEntry
}