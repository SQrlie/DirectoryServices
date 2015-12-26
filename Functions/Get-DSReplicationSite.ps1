function Get-DSReplicationSite {
    <#
    .SYNOPSIS
        Returns a specific Active Directory site or a set of site objects based on parameters specified.
    .DESCRIPTION
        The Get-DSReplicationSite cmdlet returns a specific Active Directory site or set of site objects based on parameters specified.
    .PARAMETER Identity
        Specifies the Active Directory site name. If not specified, the computer site will be returned.
    .PARAMETER DomainName
        Gets all sites in the specified domain.
    .PARAMETER ForestName
        Gets all sites in the specified forest.
    .PARAMETER Domain
        Gets all sites in the domain that belongs to the domain object.
    .PARAMETER Forest
        Gets all sites in the forest that belongs to the forest object.
    .PARAMETER Server
        Specifies the Active Directory Domain Services instance to connect to.
    .PARAMETER Credential
        Specifies the user account credentials to use to perform this task. The default credentials are the credentials of the currently logged on user.
    .EXAMPLE
        $Credential = Get-Credential
        Get-DSReplicationSite -Credential $Credential
        Gets the current computer site using specified credentials.
    .EXAMPLE 
        Get-DSReplicationSite -DomainName Contoso.com
        Returns all sites in the Contoso domain.
    .EXAMPLE
        Get-DSForest | Get-DSReplicationSite
        Gets all slites in the current forest.
    .NOTES
        Version: 1.0
        Author: Andreas Sørlie
    #>
    [CmdletBinding(DefaultParameterSetName = 'Identity')]
    Param (
        [Parameter(ParameterSetName = 'Identity', Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True, Position = 0)] 
        [Alias('Name', 'SiteName')]
        [String] $Identity,
        [Parameter(ParameterSetName = 'DomainName', Mandatory=$True, Position = 0)] 
        [String] $DomainName,
        [Parameter(ParameterSetName = 'ForestName', Mandatory=$True, Position = 0)] 
        [String] $ForestName,
        [Parameter(ParameterSetName = 'Domain', Mandatory=$True, ValueFromPipeline=$True, Position = 0)] 
        [DirectoryServices.ActiveDirectory.Domain] $Domain,
        [Parameter(ParameterSetName = 'Forest', Mandatory=$True, ValueFromPipeline=$True, Position = 0)] 
        [DirectoryServices.ActiveDirectory.Forest] $Forest,
        [Parameter(ParameterSetName = 'Identity', Mandatory=$False, Position = 1)] 
        [String] $Server,
        [Parameter(ParameterSetName = 'Identity', Mandatory=$False, Position = 2)] 
        [Parameter(ParameterSetName = 'DomainName', Mandatory=$False, Position = 1)] 
        [Parameter(ParameterSetName = 'ForestName', Mandatory=$False, Position = 1)] 
        [Management.Automation.PSCredential]$Credential
    )
    switch ($PsCmdlet.ParameterSetName) {
        'Identity' {
            if (!$Server) {
                try {
                    [DirectoryServices.ActiveDirectory.DomainController]$Server = Get-DSDomainController -Credential $Credential
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
            } else {
                try {
                    [DirectoryServices.ActiveDirectory.DomainController]$Server = Get-DSDomainController -Identity $Server -Credential $Credential
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
            }
            $Sites = $Server.Forest.Sites
            if (!$Identity) {
                try {
                    $Identity = [DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite().Name
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
            }
            $Site = $Sites | Where {
                $_.Name -eq $Identity
            }
            if (!$Site) {
                Throw "Site `"$Identity`" was not found."
            }
            return $Site
        } 'DomainName' {
            try {
                $Domain = Get-DSDomain -Name $DomainName -Credential $Credential
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
            return $Domain.Forest.Sites | Where {
                $_.Domains.Contains($Domain)
            }
        } 'ForestName' {
            try {
                $Forest = Get-DSForest -Name $ForestName -Credential $Credential
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
            return $Forest.Sites
        } 'Domain' {
            return $Domain.Forest.Sites | Where {
                $_.Domains.Contains($Domain)
            }
        } 'Forest' {
            return $Forest.Sites
        }
        
    }
}