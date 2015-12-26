function Get-DSRootDSE {
     <#
    .SYNOPSIS
        Gets the root of a Directory Server information tree.
    .DESCRIPTION
        The Get-DsRootDSE cmdlet gets the conceptual object representing the root of the directory information tree of a directory server. 
        This tree provides information about the configuration and capabilities of the directory server, such as the distinguished name for the 
        configuration container, the current time on the directory server, and the functional levels of the directory server and the domain.
    .PARAMETER Credential
        Specifies the user account credentials to use to perform this task. The default credentials are the credentials of the currently logged on user.
    .PARAMETER Server
        Specifies the Active Directory Domain Services instance to connect to, by providing one of the following values for a corresponding domain name or directory server. 
        The service may be any of the following:
        Active Directory Lightweight Domain Services, 
        Active Directory Domain Services or Active Directory Snapshot instance.
    .NOTES
        Version: 1.0
        Author: Andreas Sørlie
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False, Position = 0)]
        [Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory = $False, ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True, Position = 1)]
        [Alias('Domain','DomainName', 'Name')]
        [String]$Server
    )
    if (!$Server) {
        try {
            $Server = (Get-DSDomainController -Credential $Credential).Name
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    }
    try {
        $DE = Get-DSDirectoryEntry "LDAP://$Server/RootDSE" $Credential
    } catch {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
    try {
        $currentTime = $($DE.currentTime).Split('.')[0]
        $currentTime = [DateTime]::ParseExact($currentTime, 'yyyyMMddHHmmss' , [Globalization.CultureInfo]::InvariantCulture)
        $currentTime = $currentTime.ToLocalTime()
    } catch  {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
    $domainFunctionality = [DirectoryServices.ActiveDirectory.DomainMode]$($DE.domainFunctionality)
    $forestFunctionality = [DirectoryServices.ActiveDirectory.ForestMode]$($DE.forestFunctionality)
    return New-Object -TypeName PSObject -ArgumentList @{
        'configurationNamingContext' = $($DE.configurationNamingContext)
        'currentTime' = $currentTime
        'defaultNamingContext' = $($DE.defaultNamingContext)
        'dnsHostName' = $($DE.dnsHostName)
        'domainControllerFunctionality' = $($DE.domainControllerFunctionality)
        'domainFunctionality' = $domainFunctionality
        'dsServiceName' = $($DE.dsServiceName)
        'forestFunctionality' = $forestFunctionality
        'highestCommittedUSN' = $($DE.highestCommittedUSN)
        'isGlobalCatalogReady' = $($DE.isGlobalCatalogReady)
        'isSynchronized' = $($DE.isSynchronized)
        'ldapServiceName' = $($DE.ldapServiceName)
        'namingContexts' = $($DE.namingContexts)
        'rootDomainNamingContext' = $($DE.rootDomainNamingContext)
        'schemaNamingContext' = $($DE.schemaNamingContext)
        'serverName' = $($DE.serverName)
        'subschemaSubentry' = $($DE.subschemaSubentry)
        'supportedCapabilities' = $($DE.supportedCapabilities)
        'supportedControl' = $($DE.supportedControl)
        'supportedLDAPPolicies' = $($DE.supportedLDAPPolicies)
        'supportedLDAPVersion' = $($DE.supportedLDAPVersion)
        'supportedSASLMechanisms' = $($DE.supportedSASLMechanisms)
        'Synchronized' = $($DE.isSynchronized)
        'GlobalCatalogReady' = $($DE.isGlobalCatalogReady)
        'DirectoryEntry' = $DE
    }
}