<#
 
.SYNOPSIS
PowerShell Module for Active Directory Domain Services (AD DS) based on .NET Namespace System.DirectoryServices.
 
.NOTES
Name:            DirectoryServices.psm1
Title:           Active Directory Directory Services PowerShell Module
Authors:         Andreas Sørlie
                 Marius Koch
Date:            09.06.2015
Version:         1.1.3

Changelog:
27.11.2014: 1.0 Andreas Sørlie
- Intial version with the following functions:
    Get-DSDirectoryContext
    Get-DSDirectoryEntry
    Get-DSForest
    Get-DSDomain
- For now, error handling is done through the function Initialize-ErrorRecord. This may change.
11.03.2015: 1.1 
- Added functions:
    Get-DSDomainController
    Get-DSRootDSE
    Get-DSObject
    Add-DSAccessRule
12.03.2015: 1.1.1
- Added Get-DSTrust
17.05.2015: 1.1.2
- Added New-DSObject. Requires additional work, but supports organizationalUnit and nTDSConnection. No extensive testing has been made.
09.06.2015: 1.1.3
- Added ParameterSet Server to Get-DSForest and Get-DSDomain
- Added switch Forest in Get-DSDomainController in order to be able to get all domain controllers in the forest.
- Added default path to New-DSObject.
- Auto-completion of DC (Domain Component) in Get-DSObject.
- Added examples to Get-DSTrust

#>

# Enumerations Start

Add-Type -TypeDefinition @"
    public enum DSCurrentUserContext {
        LocalMachine = 0,
        LocalComputer = LocalMachine,
        CurrentUser = 1,
        LoggedOnUser = CurrentUser
    }
"@

# Enumerations End

function Initialize-ErrorRecord {
    [CmdletBinding(DefaultParameterSetName = 'Message')]
    Param(
        [Parameter(ParameterSetName = 'ErrorRecord', Mandatory = $True, Position = 0)]
        [Management.Automation.ErrorRecord]$ErrorRecord,
        [Parameter(ParameterSetName = 'ErrorRecord', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'Message', Mandatory = $False, Position = 1)]
        [Object]$Object,
        [Parameter(ParameterSetName = 'ErrorRecord', Mandatory = $False, Position = 2)]
        [Parameter(ParameterSetName = 'Message', Mandatory = $False, Position = 2)]
        [String]$Title,
        [Parameter(ParameterSetName = 'ErrorRecord', Mandatory = $False, Position = 3)]
        [Parameter(ParameterSetName = 'Message', Mandatory = $False, Position = 3)]
        [Management.Automation.ErrorCategory]$ErrorCategory = 'NotSpecified',
        [Parameter(ParameterSetName = 'Message', Mandatory = $True, Position = 0)]
        [Parameter(ParameterSetName = 'ErrorRecord', Mandatory = $False, Position = 4)]
        [String]$ErrorMessage
    )
    switch ($PsCmdlet.ParameterSetName) {
        'Message' {
            $Exception = New-Object Exception $ErrorMessage
            $ErrorRecord = New-Object Management.Automation.ErrorRecord (
                $Exception,
                $ErrorMessage,
                $ErrorCategory,
                [System.Object]
            )
        }
    }
    if (!$Object) {
        $Object = $ErrorRecord.TargetObject
    }
    if (!$ErrorMessage) {
        $ErrorMessage = $ErrorRecord.Exception.GetBaseException().Message
    }
    if ($Title) {
        $ErrorMessage = "$Title : $ErrorMessage"
    }
    return New-Object Management.Automation.ErrorRecord (
        $ErrorRecord.Exception.GetBaseException(),
        $ErrorMessage,
        $ErrorCategory,
        $Object
    )
}

function Get-DSDirectoryContext {
    <#
    .SYNOPSIS
        Gets a DirectoryContext
    .DESCRIPTION
        Returns a DirectoryContext. Note that this function does not check if the context is valid.
    .PARAMETER Type
        The type of context. Possible values for this parameter are:
        ApplicationPartition
        ConfigurationSet
        DirectoryServer
        Domain
        Forest
    .PARAMETER Name
        Name of the context
    .PARAMETER Credential
        The credentials to use for connecting to the specified context. If not specifed, current user's credential will be used. 
        Note that this function does not validate the credentials.
    .EXAMPLE
        Get-DSDirectoryContext -Type Forest -Name 'contoso.com'
        Gets the forest directory context of forest name contoso.com.
    .INPUTS
        [System.DirectoryServices.ActiveDirectory.DirectoryContextType]$Type
        [System.String]$Name
        [System.Management.Automation.PSCredential]$Credential
    .OUTPUTS
        [System.DirectoryServices.ActiveDirectory.DirectoryContext]
    .NOTES
        Version: 1.1
        Author: Andreas Sørlie
        Changelog:
        1.1: 25.12.2015 Andreas Sørlie
        - Added examples and inputs/outputs
        - Formatting
        - Validation of $Name
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, Position = 0)]
            [DirectoryServices.ActiveDirectory.DirectoryContextType]$Type,
        [Parameter(Mandatory = $True, Position = 1)]
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

function Get-DSDirectoryEntry {
    <#
    .SYNOPSIS
        Gets a DirectoryEntry
    .DESCRIPTION
        Returns a DirectoryEntry.
    .PARAMETER Path
        The path of the DirectoryEntry
    .PARAMETER Credential
        The credentials to use for connecting to the specified DirectoryEntry. 
        If not specifed, current user's credential will be used. 
    .EXAMPLE
        Get-DSDirectoryEntry
        Returns the DirectoryEntry for the default naming context.
    .EXAMPLE
        $Credential = Get-Credential
        Get-DSDirectoryEntry -Path "LDAP://contoso.com/OU=Corp,DC=contoso,DC=com" -Credential $Credential
        Returns the DirectoryEntry for the organizational unit "Corp".
    .INPUTS
        [System.String]$Path
        [System.Management.Automation.PSCredential]$Credential
    .OUTPUTS
        [System.DirectoryServices.DirectoryEntry]$DirectoryEntry
        [DirectoryServices.DirectoryServicesCOMException]$Exception
            If the Directory Service is unable to retrieve the entry.
    .NOTES
        Version: 1.1
        Author: Andreas Sørlie
        Changelog:
        1.1: 25.12.2015 Andreas Sørlie
        - Simplified error handling
        - Added examples and inputs/outputs
        - Formatting
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False, Position = 0,ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='The path of the DirectoryEntry')]
            [String]$Path,
        [Parameter(Mandatory = $False, Position = 1, ValueFromPipelineByPropertyName=$True,
            HelpMessage='The credentials to use for connecting to the specified DirectoryEntry.')]
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

function Get-DSForest {
    <#
    .SYNOPSIS
        Gets an Active Directory forest.
    .DESCRIPTION
        The Get-DSForest cmdlet gets the Active Directory forest specified by the parameters. You can specify the forest by setting the Name or Current parameters.
        
        If no parameters are specified, AD Forest of LocalMachine will be returned.
    .PARAMETER Current
        Specifies whether to return the domain of the local computer or the current logged on user. Possible values for this parameter are:
        LocalMachine/LocalComputer/0
        CurrentUser/LoggedOnUser/1
    .PARAMETER Name
        Specifies an Active Directory forest object by providing the Fully qualified domain name (FQDN).
        This parameter can also get this object through the pipeline.
    .PARAMETER Server
        Gets the forest of the specifed Active Directory Domain Controller.
    .PARAMETER Credential
        Specifies the user account credentials to use to perform this task. The default credentials are the credentials of the currently logged on user.
    .NOTES
        Version: 1.0
        Author: Andreas Sørlie
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param(
        [Parameter(ParameterSetName = 'Current', Mandatory = $True, Position = 0)]
        [DSCurrentUserContext]$Current,
        [Parameter(ParameterSetName = 'Name', Mandatory = $False, ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True, Position = 0)]
        [Alias('Forest','ForestName')]
        [String]$Name,
        [Parameter(ParameterSetName = 'Server', Mandatory = $True, Position = 0)]
        [String]$Server,
        [Parameter(ParameterSetName = 'Current', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'Name', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'Server', Mandatory = $False, Position = 1)]
        [Management.Automation.PSCredential]$Credential
    )
    switch ($PsCmdlet.ParameterSetName) {
        'Name' {
            if (!$Name) {
                try {
                    $DomainName = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop).Domain
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
            } else {
                try {
                    $Context = Get-DSDirectoryContext 'Forest' $Name $Credential
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
                try {
                    return [DirectoryServices.ActiveDirectory.Forest]::GetForest($Context)
                } catch [DirectoryServices.ActiveDirectory.ActiveDirectoryObjectNotFoundException] {
                    $DomainName = $Name
                } catch {
                    Throw Initialize-ErrorRecord $_ 'DirectoryServices.ActiveDirectory.Forest' $MyInvocation.MyCommand
                }
            }
        } 'Current' {
            if ($Current -eq [DSCurrentUserContext]::CurrentUser) {
                $DomainName = $Env:UserDNSDomain
            } elseif ($Current -eq [DSCurrentUserContext]::LocalMachine) {
                try {
                    $DomainName = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop).Domain
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
            }
        } 'Server' {
            try {
                $DomainController = Get-DSDomainController -Identity $Server -Credential $Credential
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
            return $DomainController.Forest
        }
    }
    try {
        $Domain = Get-DSDomain $Name $Credential
    } catch {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
    try {
        return $Domain.Forest
    } catch {
        Throw Initialize-ErrorRecord $_ 'DirectoryServices.ActiveDirectory.Forest' $MyInvocation.MyCommand
    }
}

function Get-DSDomain {
    <#
    .SYNOPSIS
        Gets an Active Directory domain.
    .DESCRIPTION
        The Get-DSDomain cmdlet gets the Active Directory domain specified by the parameters. You can specify the domain by setting the Name or Current parameters.
        
        If no parameters are specified, AD Domain of LocalMachine will be returned.
    .PARAMETER Current
        Specifies whether to return the domain of the local computer or the current logged on user. Possible values for this parameter are:
        LocalMachine/LocalComputer/0
        CurrentUser/LoggedOnUser/1
    .PARAMETER Name
        Specifies an Active Directory domain object by providing the Fully qualified domain name (FQDN).
        This parameter can also get this object through the pipeline.
    .PARAMETER Server
        Gets the domain of the specifed Active Directory Domain Controller.
    .PARAMETER Credential
        Specifies the user account credentials to use to perform this task. The default credentials are the credentials of the currently logged on user.
    .NOTES
        Version: 1.0
        Author: Andreas Sørlie
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param(
        [Parameter(ParameterSetName = 'Current', Mandatory = $True, Position = 0)]
        [DSCurrentUserContext]$Current,
        [Parameter(ParameterSetName = 'Name', Mandatory = $False, ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True, Position = 0)]
        [Alias('Domain','DomainName')]
        [String]$Name,
        [Parameter(ParameterSetName = 'Server', Mandatory = $True, Position = 0)]
        [String]$Server,
        [Parameter(ParameterSetName = 'Current', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'Name', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'Server', Mandatory = $False, Position = 1)]
        [Management.Automation.PSCredential]$Credential
    )
    switch ($PsCmdlet.ParameterSetName) {
        'Name' {
            if (!$Name) {
                try {
                    $Name = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop).Domain
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
            }
        } 'Current' {
            if ($Current -eq [DSCurrentUserContext]::CurrentUser) {
                $Name = $Env:UserDNSDomain
            } elseif ($Current -eq [DSCurrentUserContext]::LocalMachine) {
                try {
                    $Name = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop).Domain
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
            }
        } 'Server' {
            try {
                $DomainController = Get-DSDomainController -Identity $Server -Credential $Credential
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
            return $DomainController.Domain
        }
    }
    try {
        $Context = Get-DSDirectoryContext 'Domain' $Name $Credential
    } catch {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
    try {
        [DirectoryServices.ActiveDirectory.Domain]::GetDomain($Context)
    } catch [DirectoryServices.ActiveDirectory.ActiveDirectoryObjectNotFoundException] {
        Throw Initialize-ErrorRecord $_ 'DirectoryServices.ActiveDirectory.Domain' $MyInvocation.MyCommand 'ObjectNotFound' "Could not find a domain identified by: '$Name'"
    } catch {
        Throw Initialize-ErrorRecord $_ 'DirectoryServices.ActiveDirectory.Domain' $MyInvocation.MyCommand
    }
}

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

function New-DSObject {
    <#
    .SYNOPSIS
        Gets one or more Active Directory objects.
    .DESCRIPTION
        The Get-DSObject cmdlet gets an Active Directory object or performs a search to retrieve multiple objects.
    .PARAMETER Name
        The Name parameter specifies the objects Name. Ex "Users" for an OU, IP-FROM-DOMAINCONTROLLER1 for replication-link.
    .PARAMETER Description
        Used to describe the object.
    .PARAMETER DisplayName
        The displayname of the object
    .PARAMETER Instance
        Not yet supported. This is supposed to be used as a clone-function.
    .PARAMETER ProtectedFromAccidentalDeletion
        Accepts $True and $False, default $False. Avoids the messy accidental deletions of entire OU-structures and the likes.
    .PARAMETER OtherAttributes
        Add values not natively supported by this Cmdlet to a hashtable, and pass it through to OtherAttributes. Examples are fromServer, enabledConnection for the objectclass nTDSConnection (replication links).
    .PARAMETER Type
        The type of the object to be created. Some examples are organizationalUnit, nTDSConnection, user.
    .PARAMETER Credential
        Specifies the user account credentials to use to perform this task. The default credentials are the credentials of the currently logged on user.
    .PARAMETER Server
        Specifies the Active Directory Domain Services instance to connect to. To use the Global Catalog specify <ServerName>:<PortNumber>
    .EXAMPLE
        New-DSObject -Name "Banking" -Path "dc=contoso,dc=com" -Type organizationalUnit -Description "Contains bankers!" -ProtectedFromAccidentalDeletion $True -Server dc1
    .EXAMPLE
        New-DSObject -Name "IP-FROM-CONTOSODC1" -Path "CN=NTDS Settings,CN=CONTOSODC2,CN=Servers,CN=Contoso-Site,CN=Sites,CN=Configuration,DC=contoso,DC=com" -Type "nTDSConnection -OtherAttributes $attr -Server Contosodc2
    .NOTES
        Version: 0.9 WIP
        Author: Marius Koch
        Todo: Test and possibly add more functionality (?) for users. Though the users should probably be post-processed using the function Set-ADObject, which has not yet been written.
        Also: Add support for Instance, so one can clone from a template-user etc.
    #>
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName = $True, Position = 1)]
        [string]$Name,
        [Parameter(Mandatory = $False)]
        [Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory = $False)]
        [string]$Description,
        [Parameter(Mandatory = $False)]
        [string]$DisplayName,
        [Parameter(Mandatory = $False)]
        [System.DirectoryServices.DirectoryEntry]$Instance, # Get this through Get-DSObject and input here. <-- move this to synopspis/help
        [Parameter(Mandatory = $False)]
        [System.Collections.Hashtable]$OtherAttributes,
        [Parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True)]
        [string]$Path,
        [Parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True)]
        [System.Boolean]$ProtectedFromAccidentalDeletion = $False,
        [Parameter(Mandatory = $False)]
        [string]$Server,
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 2)]
        [string]$Type,
        [Parameter(Mandatory = $False)]
        [switch]$WhatIf
    )

    # Validate and process types for creation
    switch ($Type.ToLower()) {
        'organizationalunit' { $CreateVar2 = "OU=$($Name)" }
        default { $CreateVar2 = "CN=$($Name)" }
    }
    if (!$Server) {
        try {
            $Server = (Get-DSDomainController -Credential $Credential).Name
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    }
    if (!$Path) {
        try {
            $Path = (Get-DSDomain -Server $Server -Credential $Credential).GetDirectoryEntry().distinguishedName
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    }
# Her kreeres det! GOTCHA!
    $DestinationPath = Get-DSObject -Identity $Path -Credential $Credential -Server $server
    try {
        $do = $DestinationPath.Create($Type,$CreateVar2)
    } catch {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
    
    if ($Description) {
        try {
            Write-Verbose "Adding description to the object"
            $do.Put("Description",$Description)
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    }

    if ($DisplayName) {
        try {
            Write-Verbose "Adding DisplayName to the object"
            $do.Put("DisplayName",$DisplayName)
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    }

    if ($OtherAttributes) {
        foreach ($attribute in $OtherAttributes.GetEnumerator()) {
            Write-Verbose "Adding $($attribute.Name) with the value $($attribute.Value) to the object"
            $do.Put($attribute.Name,$attribute.Value)
        }
    }

    if ($WhatIf) {
        Write-Output "Would create the object $($do.Path) - rerun without WhatIf to create." # Lists out what would be created - ghetto-whatif?
    } else {
        try {
            Write-Verbose "Attempting to create the $($Type) $($Name)"
            $do.SetInfo()
        } catch [System.Management.Automation.MethodInvocationException] {
            Throw Initialize-ErrorRecord "This object cannot be created with additional, mandatory attributes. Use -OtherAttributes to correct this." $Null $MyInvocation.MyCommand
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    }
    
    if ($ProtectedFromAccidentalDeletion) {
        try {
            Write-Verbose "Adding protection from accidental deletion to the object"
            $ModifiedDN = "$($CreateVar2),$($Path)"
            Add-DSAccessRule -DistinguishedName $ModifiedDN -Rights "Delete,DeleteTree" -Type "Deny" -InheritanceType "None" -Identity "Everyone"
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    }
}

function Get-DSObject {
    <#
    .SYNOPSIS
        Gets one or more Active Directory objects.
    .DESCRIPTION
        The Get-DSObject cmdlet gets an Active Directory object or performs a search to retrieve multiple objects.
    .PARAMETER Identity
        The Identity parameter specifies the Active Directory object to get, identified by its distinguished name (DN).
    .PARAMETER LDAPFilter
        Specifies an LDAP query string that is used to filter Active Directory objects.
    .PARAMETER ResultPageSize
        Specifies the number of objects to include in one page for an Active Directory Domain Services query.
    .PARAMETER ResultSetSize
        Specifies the maximum number of objects to return for an Active Directory Domain Services query.
    .PARAMETER SearchBase
        Specifies an Active Directory path to search under.
    .PARAMETER SearchScope
        Specifies the scope of an Active Directory search. Possible values for this parameter are:
        Base or 0
        OneLevel or 1
        Subtree or 2
    .PARAMETER FindOne
        Returns all objects that matches the criterias
    .PARAMETER Credential
        Specifies the user account credentials to use to perform this task. The default credentials are the credentials of the currently logged on user.
    .PARAMETER Server
        Specifies the Active Directory Domain Services instance to connect to. To use the Global Catalog specify <ServerName>:<PortNumber>
    .NOTES
        Version: 1.0
        Author: Andreas Sørlie
    #>
    [CmdletBinding(DefaultParameterSetName = 'Search')]
    Param(
        [Parameter(ParameterSetName = 'Identity', Mandatory = $False, ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True, Position = 0)]
        [Alias('DistinguishedName','DN')]
        [String]$Identity,
        [Parameter(ParameterSetName = 'Search', Mandatory = $False, Position = 0)]
        [String]$LDAPFilter = '(objectClass=*)',
        [Parameter(ParameterSetName = 'Search', Mandatory = $False, Position = 1)]
        [Alias('ResultPageSize')]
        [Int]$PageSize = 0,
        [Parameter(ParameterSetName = 'Search', Mandatory = $False, Position = 2)]
        [Alias('ResultSetSize', 'SetSize')]
        [Int]$SizeLimit = 0,
        [Parameter(ParameterSetName = 'Search', Mandatory = $False, Position = 3)]
        [Alias('SearchBase')]
        [String]$SearchRoot,
        [Parameter(ParameterSetName = 'Search', Mandatory = $False, Position = 4)]
        [DirectoryServices.SearchScope]$SearchScope = 'Subtree',
        [Parameter(ParameterSetName = 'Search', Mandatory = $False, Position = 5)]
        [Switch]$FindOne,
        [Parameter(ParameterSetName = 'Identity', Mandatory = $False, Position = 1)]
        [Parameter(ParameterSetName = 'Search', Mandatory = $False, Position = 6)]
        [Management.Automation.PSCredential]$Credential,
        [Parameter(ParameterSetName = 'Identity', Mandatory = $False, Position = 2)]
        [Parameter(ParameterSetName = 'Search', Mandatory = $False, Position = 7)]
        [String]$Server
    )
    if (!$Server) {
        try {
            $Server = (Get-DSDomainController -Credential $Credential).Name
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    }
    switch ($PsCmdlet.ParameterSetName) {
        'Identity' {
            if (!$Identity.Contains('DC=')) {
                try {
                    $RootPath = (Get-DSDomain -Server $Server -Credential $Credential).GetDirectoryEntry().distinguishedName
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
                $Identity = "$Identity,$RootPath"
            }
            try {
                return Get-DSDirectoryEntry -Path "LDAP://$Server/$Identity" -Credential $Credential
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
        }
        'Search' {
            if (!$SearchRoot) {
                try {
                    $defaultNamingContext = (Get-DSRootDSE -Server $Server -Credential $Credential).defaultNamingContext
                    $Root = Get-DSDirectoryEntry -Path "LDAP://$Server/$defaultNamingContext" -Credential $Credential
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
            } else {
                try {
                    $Root = Get-DSDirectoryEntry -Path "LDAP://$Server/$SearchRoot" -Credential $Credential
                } catch {
                    Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
                }
            }
            $Searcher = New-Object DirectoryServices.DirectorySearcher $Root
            $Searcher.Filter = $LDAPFilter
            $Searcher.PageSize = $PageSize
            $Searcher.SizeLimit = $SizeLimit
            $Searcher.SearchScope = $SearchScope
            try {
                if ($FindOne) {
                    $Result = $Searcher.FindOne()
                } else {
                    $Result = $Searcher.FindAll()
                    $Result | Out-Null # Neccesary to throw exception
                }
            } catch {
                Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
            }
            if ($Result -eq $Null) {
                return $Null
            }
            $Entries = @()
            foreach ($Entry in $Result) {
                $Entries += $Entry.GetDirectoryEntry()
            }
            return $Entries
        }
    }
}

function Add-DSAccessRule {
    <#
    .SYNOPSIS
        This cmdlet adds an access rule to a specified directory object.
    .DESCRIPTION
        Adds the specified access rule to the Discretionary Access Control List (DACL) associated with the specified object.
    .PARAMETER DistinguishedName
        The distinguished name (DN) of the directory object in which to add an access rule.
    .PARAMETER Identity
        The account/identity which will be added to the access rule.
    .PARAMETER Rights
        The rights the identity will be given. Possible values are (or a combination of the following):
        CreateChild
        DeleteChild
        ListChildren
        Self
        ReadProperty
        WriteProperty
        DeleteTree
        ListObject
        ExtendedRight
        Delete
        ReadControl
        GenericExecute
        GenericWrite
        GenericRead
        WriteDacl
        WriteOwner
        GenericAll
        Synchronize
        AccessSystemSecurity
        
        Default is ReadProperty, GenericExecute (equals Read).
    .PARAMETER Type
        The access control type. Possible values are:
        Allow
        Deny
        
        Default is Allow.
    .PARAMETER InheritanceType
        Type of inheritance. Possible values are:
        None
        All
        Descendents
        SelfAndChildren
        Children
        
        Default is None (this object only).
    .PARAMETER ObjectType
        Common name (CN) of the object type the identity will be granted permissions on.
        Must be a valid object type present in the Schema partition.
        
        Default is All.
    .PARAMETER InheritedObjectType
        Common name (CN) of the object this access rule will be propagated to.
        Must be a valid object type present in the Schema partition.
        
        Default is All. 
    .PARAMETER Credential
        Specifies the user account credentials to use to perform this task. The default credentials are the credentials of the currently logged on user.
    .EXAMPLE
        Add-DSAccessRule -DistinguishedName 'OU=Domain Controllers,DC=contoso,DC=com' -Identity Administrator -Rights GenericAll -InheritanceType All
        Grants the account Administrator full rights on the Domain Controller Organizational Unit (OU) as well as all descendant objects.
    .EXAMPLE
        Add-DSAccessRule -DistinguishedName 'CN=Users,DC=contoso,DC=com' -Identity Guests
        Gives the default Guests group read permission on the Users container. The permission will not propagate to descendant objects.
    .EXAMPLE
        Add-DSAccessRule -DistinguishedName 'DC=contoso,DC=com' -Identity SELF -Rights WriteProperty -InheritanceType Descendents -ObjectType ms-TPM-OwnerInformation -InheritedObjectType Computer
        Gives all computers objects the Write permission on their own ms-TPM-OwnerInformation property.
    .NOTES
        Version: 1.0
        Author: Andreas Sørlie
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True, Position = 0)] 
        [Alias('DN')]
        [String] $DistinguishedName,
        [Parameter(Mandatory=$True, Position = 1)]
        [Security.Principal.NTAccount] $Identity,
        [Parameter(Mandatory=$False, Position = 2)]
        [DirectoryServices.ActiveDirectoryRights] $Rights = 'ReadProperty, GenericExecute',
        [Parameter(Mandatory=$False, Position = 3)]
        [Security.AccessControl.AccessControlType] $Type = 'Allow',
        [Parameter(Mandatory=$False, Position = 4)]
        [DirectoryServices.ActiveDirectorySecurityInheritance] $InheritanceType = 'None',
        [Parameter(Mandatory=$False, Position = 5)]
        [String] $ObjectType,
        [Parameter(Mandatory=$False, Position = 6)]
        [String] $InheritedObjectType,
        [Parameter(Mandatory=$False, Position = 7)]
        [String] $Server,
        [Parameter(Mandatory=$False, Position = 8)]
        [Management.Automation.PSCredential]$Credential
    )
    if (!$Server) {
        try {
            $Server = (Get-DSDomainController -Credential $Credential).Name
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    }
    try {
        $SchemaDN = (Get-DSRootDSE -Server $Server -Credential $Credential).SchemaNamingContext
    } catch {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
    if ($ObjectType.Length -ne 0 -and $ObjectType -ne 'All') {
        try {
            $Object = Get-DSObject -LDAPFilter "(CN=$ObjectType)" -SearchRoot $SchemaDN -FindOne -Server $Server -Credential $Credential
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
        if (!$Object) {
            Throw Initialize-ErrorRecord "Invalid ObjectType specified" $Null $MyInvocation.MyCommand
        }
        $ObjectType = [Guid]$($Object.schemaIDGUID)
    } else {
        $ObjectType = [Guid]::Empty
    }
    if ($InheritedObjectType.Length -ne 0 -and $InheritedObjectType -ne 'All') {
        try {
            $InheritedObject = Get-DSObject -LDAPFilter "(CN=$InheritedObjectType)" -SearchRoot $SchemaDN -FindOne -Server $Server -Credential $Credential
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
        if (!$InheritedObject) {
            Throw Initialize-ErrorRecord "Invalid InheritedObjectType specified" $Null $MyInvocation.MyCommand
        }
        $InheritedObjectType = [Guid]$($InheritedObject.schemaIDGUID)
    } else {
        $InheritedObjectType = [Guid]::Empty
    }
    try {
        ([Security.Principal.NTAccount]$Identity).Translate([Security.Principal.SecurityIdentifier]) | Out-Null
    } catch {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
    try {
        $AccessRule = New-Object DirectoryServices.ActiveDirectoryAccessRule(
            $Identity,
            $Rights,
            $Type,
            $ObjectType,
            $InheritanceType,
            $InheritedObjectType
        )
    } catch {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
    try {
        $DirectoryEntry = Get-DSDirectoryEntry -Path "LDAP://$Server/$DistinguishedName" -Credential $Credential
    } catch {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
    try {
        $DirectoryEntry.PSBase.ObjectSecurity.AddAccessRule($AccessRule) | Out-Null
    } catch {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
    try {
        $DirectoryEntry.PSBase.CommitChanges() | Out-Null
    } catch {
        Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
    }
}

function Get-DSTrust {
    <#
    .SYNOPSIS
        Returns domain trusts for the given context.
    .DESCRIPTION
        The Get-DSTrust cmdlet returns all trusted domain objects in the directory that matches the given criterias.
    .PARAMETER SourceName
        Name of the domain to return domain/forest trusts for.
    .PARAMETER Context
        The context to return trusts for. Possible values are:
        Domain
        Forest
        If not specified, trusts for Domain context will be returned.
    .PARAMETER TargetName
        The target to return the trust information for. If not specified, all trusts for SourceName will be returned.
    .PARAMETER TrustType
        The type of the trust relationship. Possible values are:
        CrossLink
        External
        Forest
        Kerberos
        ParentChild
        TreeRoot
        Unknown
        If not specified, all trust types will be returned.
    .PARAMETER TrustDirection
        The trust direction of the trust, relative to the Source. Possible values are:
        Inbound or 1
        Outbound or 2
        Bidirectional or 3
        If not specified, all trust types will be returned.
    .PARAMETER Credential
        Specifies the user account credentials to use to perform this task. The default credentials are the credentials of the currently logged on user.
    .EXAMPLE
        Get-DSTrust
        Gets all trust for current domain.
    .EXAMPLE
        Get-DSTrust -Context Forest -Direction Bidirectional -SourceName Contoso.com -Credential (Get-Credential)
        Gets all bidirectional trust from the Contoso.com domain using the specified credentials.
    .NOTES
        Version: 1.0
        Author: Andreas Sørlie
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param (
        [Parameter(ParameterSetName = 'Name', Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True, Position = 0)] 
        [Alias('Name', 'Source', 'DomainName', 'Domain')]
        [String] $SourceName,
        [Parameter(ParameterSetName = 'Name', Mandatory=$False, Position = 1)] 
        [DirectoryServices.ActiveDirectory.DirectoryContextType] $Context = 'Domain',
        [Parameter(ParameterSetName = 'Name', Mandatory=$False, Position = 2)] 
        [Alias('Target')]
        [String] $TargetName,
        [Parameter(ParameterSetName = 'Name', Mandatory=$False, Position = 3)] 
        [Alias('Type')]
        [DirectoryServices.ActiveDirectory.TrustType] $TrustType,
        [Parameter(ParameterSetName = 'Name', Mandatory=$False, Position = 4)] 
        [Alias('Direction')]
        [DirectoryServices.ActiveDirectory.TrustDirection] $TrustDirection,
        [Parameter(ParameterSetName = 'Name',  Mandatory=$False, Position = 5)]
        [Management.Automation.PSCredential]$Credential
    )
    if (!$SourceName) {
        try {
            $SourceDomain = Get-DSDomain -Credential $Credential
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    } else {
        try {
            $SourceDomain = Get-DSDomain -Name $SourceName -Credential $Credential
        } catch {
            Throw Initialize-ErrorRecord $_ $Null $MyInvocation.MyCommand
        }
    }
    if ($Context -eq 'Domain') {
        $Source = $SourceDomain
    } elseif ($Context -eq 'Forest') {
        $Source = $SourceDomain.Forest
    } else {
        Throw "Invalid Context specified. Must be either Domain or Forest."
    }
    if ($TargetName) {
        $Trusts = $Source.GetTrustRelationship($TargetName)
    } else {
        $Trusts = $Source.GetAllTrustRelationships()
    }
    [Collections.ArrayList]$Result = @($Trusts)
    foreach ($Trust in $Trusts) {
        if ($TrustType) {
            if ($Trust.TrustType -NotContains $TrustType) {
                $Result.Remove($Trust)
            }
        }
        if ($TrustDirection) {
            if ($Trust.TrustDirection -NotContains $TrustDirection) {
                $Result.Remove($Trust)
            }
        }
    }
    return $Result
}

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