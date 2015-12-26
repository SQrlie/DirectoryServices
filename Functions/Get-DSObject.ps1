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