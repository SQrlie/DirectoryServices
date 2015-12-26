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