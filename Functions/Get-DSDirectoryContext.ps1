function Get-DSDirectoryContext {
    <#
        .ExternalHelp ..\DirectoryServices.Help.xml
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, Position = 0)]
            [DirectoryServices.ActiveDirectory.DirectoryContextType]$Type,
        [Parameter(Mandatory = $True, Position = 1, ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True)]
            [ValidateNotNullOrEmpty()]
            [String]$Name,
        [Parameter(Mandatory = $False, Position = 2)]
            [Management.Automation.PSCredential]$Credential
    )
    if ($Credential) {
        if ($Credential.GetNetworkCredential().Domain.Length -eq 0) {
            $UserName = $Credential.GetNetworkCredential().UserName
        } else {
            $UserName = $Credential.UserName
        }
        return New-Object DirectoryServices.ActiveDirectory.DirectoryContext($Type, $Name, $UserName, 
            $Credential.GetNetworkCredential().Password)
    } else {
        return New-Object DirectoryServices.ActiveDirectory.DirectoryContext($Type, $Name)
    }
}