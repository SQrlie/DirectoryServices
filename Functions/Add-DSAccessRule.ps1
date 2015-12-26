function Add-DSAccessRule {
    <#
        .ExternalHelp ..\DirectoryServices.Help.xml
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True, Position = 0)] 
            [Alias('DN')]
            [ValidateNotNullOrEmpty()]
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