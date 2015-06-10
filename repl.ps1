function New-ReplicationLink {
    param(
        [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName)]
        [string]$SourceDC,
        [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName)]
        [string]$DestinationDC,
        [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName)]
        [string]$Server,
        [Parameter(Mandatory=$False)]
        [Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$False)]
        [switch]$WhatIf
    )
$DestinationDCShortName = $DestinationDC.Split(".")[0].ToUpper()
$ObjectPath = (Get-DSDomainController $SourceDC).GetDirectoryEntry().Children.DistinguishedName
$OtherAttributes = @{
    FromServer = (Get-DSDomainController $DestinationDC).GetDirectoryEntry().Children.DistinguishedName
    Options = "0x0"
    EnabledConnection = "True"
}

if ($WhatIf) {
    New-DSObject -Name "IP-FROM-$($DestinationDCShortName)" -Path $ObjectPath -Credential $Credential -OtherAttributes $OtherAttributes -Type "nTDSConnection" -WhatIf
} else {
    try {
        New-DSObject -Name "IP-FROM-$($DestinationDCShortName)" -Path $ObjectPath -Credential $Credential -OtherAttributes $OtherAttributes -Type "nTDSConnection" -Verbose
    } catch {
    }
}
}