function Get-DSDomainController {
    <#
    .SYNOPSIS
        Gets one or more Active Directory domain controllers based on search parameters or by providing a domain controller identifier.
    .DESCRIPTION
        The Get-ADDomainController cmdlet gets the domain controllers specified by the parameters. 
        You can get domain controllers by setting the Identity or Discover parameters.
        
        The Identity parameter specifies the domain controller to get. You can identify a domain controller by its IPV4Address or DNS host name. 
        
        To get a domain controller by using the discovery mechanism of DCLocator, use the Discover parameter. You can provide search criteria by 
        setting parameters such as Service, SiteName, DomainName, AvoidSelf, and ForceDiscover.
    .PARAMETER Identity
        Fully qualified DNS name, IP-address or NetBIOS name of the domain controller
    .PARAMETER Discover
        Specifies to return a discoverable domain controller that meets the conditions specified by the cmdlet parameters
    .PARAMETER AvoidSelf
        Specifies to not return the current computer as a domain controller. 
        If the currrent computer is not a domain controller, this parameter is ignored.
        If FindAll is specified, this parameter is ignored.
    .PARAMETER DomainName
        Specified the domain to search. Specify the domain by using the NetBIOS name or FQDN of the domain.
    .PARAMETER ForceDiscover
        Forces the cmdlet to clear any cached domain controller information and perform a new discovery.
        If FindAll is specified, this parameter is ignored.
    .PARAMETER Service
        Specifies the types of domain controllers to get. You can specify more than one type by using a comma-separated list.
        Possible values for this parameter are:
        KDC,
        TimeService
        If FindAll is specified, this parameter is ignored.
    .PARAMETER SiteName
        Specifies the name of a site to search in to find the domain controller.
    .PARAMETER Writable
        Only returns writable domain controller(s).
    .PARAMETER FindAll
        Returns all domain controllers that meets the specified criterias.
    .PARAMETER Forest
        In conjuction with FindAll, returns all domain controllers in the specified forest.
    .PARAMETER PdcRole
        Returns the domain controller holding the Primary Domain Controller (PDC) Emulator role for the domain.
    .PARAMETER RidRole
        Returns the domain controller holding the Relative ID (RID) Master role for the domain.
    .PARAMETER InfrastructureRole
        Returns the domain controller holding the Infrastructure Master role for the domain.
    .PARAMETER SchemaRoleOwner
        Returns the domain controller holding the Schema Master role for the forest the domain belongs to.
    .PARAMETER NamingRoleOwner
        Returns the domain controller holding the Domain Naming Master role for the forest the domain belongs to.
    .PARAMETER Credential
        Specifies the user account credentials to use to perform this task. The default credentials are the credentials of the currently logged on user.
    .NOTES
        Version: 1.0
        Author: Andreas Sørlie
    #>
    [CmdletBinding(DefaultParameterSetName = 'Discover')]
    Param(
        [Parameter(ParameterSetName = 'Identity', Mandatory = $True, ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True, Position = 0)]
        [Alias('Name')]
        [String]$Identity,
        [Parameter(ParameterSetName = 'PdcRole', Mandatory = $True, Position = 0)]
        [Switch]$PdcRole,
        [Parameter(ParameterSetName = 'RidRole', Mandatory = $True, Position = 0)]
        [Switch]$RidRole,
        [Parameter(ParameterSetName = 'InfrastructureRole', Mandatory = $True, Position = 0)]
        [Switch]$InfrastructureRole,
        [Parameter(ParameterSetName = 'SchemaRoleOwner', Mandatory = $True, Position = 0)]
        [Switch]$SchemaRoleOwner,
        [Parameter(ParameterSetName = 'NamingRoleOwner', Mandatory = $True, Position = 0)]
        [Switch]$NamingRoleOwner,
        [Parameter(ParameterSetName = 'Discover', Mandatory = $False, Position = 0)]
        [Switch]$Discover,
        [Parameter(ParameterSetName = 'Discover', Mandatory = $False, Position = 1)]
        [Switch]$AvoidSelf,
        [Parameter(ParameterSetName = 'Discover', Mandatory = $False, Position = 2)]
        [Parameter(ParameterSetName = 'PdcRole', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'RidRole', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'InfrastructureRole', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'SchemaRoleOwner', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'NamingRoleOwner', Mandatory = $False, Position = 1)]
        [String]$DomainName,
        [Parameter(ParameterSetName = 'Discover', Mandatory = $False, Position = 3)]
        [Switch]$ForceDiscover,
        [Parameter(ParameterSetName = 'Discover', Mandatory = $False, Position = 4)]
        [String]$Service,
        [Parameter(ParameterSetName = 'Discover', Mandatory = $False, Position = 5)]
        [String]$SiteName,
        [Parameter(ParameterSetName = 'Discover', Mandatory = $False, Position = 6)]
        [Switch]$Writable,
        [Parameter(ParameterSetName = 'Discover', Mandatory = $False, Position = 7)]
        [Switch]$FindAll,
        [Parameter(ParameterSetName = 'Discover', Mandatory = $False, Position = 8)]
        [Switch]$Forest,
        [Parameter(ParameterSetName = 'Identity', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'Discover', Mandatory = $False, Position = 9)]
        [Parameter(ParameterSetName = 'PdcRole', Mandatory = $False, Position = 2)]
        [Parameter(ParameterSetName = 'RidRole', Mandatory = $False, Position = 2)]
        [Parameter(ParameterSetName = 'InfrastructureRole', Mandatory = $False, Position = 2)]
        [Parameter(ParameterSetName = 'SchemaRoleOwner', Mandatory = $False, Position = 2)]
        [Parameter(ParameterSetName = 'NamingRoleOwner', Mandatory = $False, Position = 2)]
        [Management.Automation.PSCredential]$Credential
    )
    if (!$DomainName) {
        try {
            $DomainName = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop).Domain
        } catch {
            Throw $_
        }
    }
    switch ($PsCmdlet.ParameterSetName) {
        'Identity' {
            # Attempt to convert IP to FQDN
            try {
                $Identity = [Net.Dns]::GetHostByAddress($Identity).HostName
            } catch [FormatException] {
                # Identity $Identity was not an IP address - Continues.
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
            try {
                # Get the Host record from DNS (In case of NetBIOS or CNAME records)
                $Identity = [Net.Dns]::GetHostByName($Identity).HostName
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
            try {
                $Context = Get-DSDirectoryContext 'DirectoryServer' $Identity $Credential
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
            try {
                return [DirectoryServices.ActiveDirectory.DomainController]::GetDomainController($Context)
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
        } 'Discover' {
            try {
                $Context = Get-DSDirectoryContext 'Domain' $DomainName $Credential
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
            if ($FindAll) {
                if ($Forest) {
                    try {
                        $DSForest = Get-DSForest $DomainName -Credential $Credential
                    } catch {
                        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                    }
                    foreach ($Domain in $DSForest.Domains) {
                        $DomainControllers += $Domain.DomainControllers
                    }
                    return $DomainControllers
                }
                try {
                    if ($SiteName) {
                        return [DirectoryServices.ActiveDirectory.DomainController]::FindAll($Context, $SiteName)
                    } else {
                        return [DirectoryServices.ActiveDirectory.DomainController]::FindAll($Context)
                    }
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
            }
            [DirectoryServices.ActiveDirectory.LocatorOptions]$LocatorOptions = '0'
            if ($AvoidSelf) {
                $LocatorOptions = $LocatorOptions -bor [DirectoryServices.ActiveDirectory.LocatorOptions]::AvoidSelf
            }
            if ($ForceDiscover) {
                $LocatorOptions = $LocatorOptions -bor [DirectoryServices.ActiveDirectory.LocatorOptions]::ForceRediscovery
            } if ($Service.Contains('KDC')) {
                $LocatorOptions = $LocatorOptions -bor [DirectoryServices.ActiveDirectory.LocatorOptions]::KdcRequired
            }
            if ($Service.Contains('TimeService')) {
                $LocatorOptions = $LocatorOptions -bor [DirectoryServices.ActiveDirectory.LocatorOptions]::TimeServerRequired
            }
            if ($Writable) {
                $LocatorOptions = $LocatorOptions -bor [DirectoryServices.ActiveDirectory.LocatorOptions]::WriteableRequired
            }
            try {
                if ($SiteName) {
                    return [DirectoryServices.ActiveDirectory.DomainController]::FindOne($Context, $SiteName, $LocatorOptions)
                } else {
                    return [DirectoryServices.ActiveDirectory.DomainController]::FindOne($Context, $LocatorOptions)
                }
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
        } 'PdcRole' {
            try {
                return (Get-DSDomain -Name $DomainName -Credential $Credential).PdcRoleOwner
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
        } 'RidRole' {
            try {
                return (Get-DSDomain -Name $DomainName -Credential $Credential).RidRoleOwner
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
        } 'InfrastructureRole' {
            try {
                return (Get-DSDomain -Name $DomainName -Credential $Credential).InfrastructureRoleOwner
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
        } 'SchemaRoleOwner' {
            try {
                return (Get-DSForest -Name $DomainName -Credential $Credential).SchemaRoleOwner
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
        } 'NamingRoleOwner' {
            try {
                return (Get-DSForest -Name $DomainName -Credential $Credential).NamingRoleOwner
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
        }
    }
}