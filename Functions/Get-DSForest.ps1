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