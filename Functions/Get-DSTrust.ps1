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