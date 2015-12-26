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