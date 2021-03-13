function  Get-WarrantyHudu {
    [CmdletBinding()]
    Param(
        [string]$HuduAPIKey,
        [String]$HuduBaseURL,
        [String]$HuduDeviceAssetLayout,
        [string]$HuduWarrantyField,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty
    )


    write-host "Source is Hudu. Grabbing all devices." -ForegroundColor Green
    #Get the Hudu API Module if not installed
    if (Get-Module -ListAvailable -Name HuduAPI) {
        Import-Module HuduAPI 
    } else {
        Install-Module HuduAPI -Force
        Import-Module HuduAPI
    }

    New-HuduAPIKey $HuduAPIKey
    New-HuduBaseUrl $HuduBaseURL

    #Get the Asset Layout from Hudu
    $layout = Get-HuduAssetLayouts -name $HuduDeviceAssetLayout
    if (!$layout) {
        Write-Error "Hudu Layout Not Found"
        exit
    }
    
    #Process field name into API format
    $HuduProcessedFieldName = ($HuduWarrantyField.ToLower()) -replace " ", "_"

    #Get Devices
    $Devices = Get-HuduAssets -assetlayoutid $layout.id

    $warrantyObject = foreach ($device in $Devices) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.primary_serial). Device $i of $($devices.Count)" -percentComplete ($i / $Devices.Count * 100)
        $WarState = Get-Warrantyinfo -DeviceSerial $device.primary_serial -client $device.company_name

        if ($SyncWithSource -eq $true) {
            $field = $device.fields | where-object {$_.label -eq $HuduWarrantyField}
            if ($field){
                #Handle existing expiry date
                $device.fields | where-object {$_.label -eq $HuduWarrantyField} | ForEach-Object {$_.value = "$($WarState.enddate)"}
            } else {
                if($device.fields){
                    #Handle existing fields but no expiry date
                    $device.fields | Add-Member -NotePropertyName $HuduProcessedFieldName  -NotePropertyValue "$($WarState.enddate)"
                } else {
                    #Handle no existing fields
                    $device.fields = @{
                        "$HuduProcessedFieldName" = "$($WarState.enddate)"
                    }
                }    
            }
            switch ($OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        $null = set-huduasset -name $device.name -company_id $device.company_id -asset_layout_id $layout.id -fields $device.fields -asset_id $device.id
                    }
                     
                }
                $false { 
                    if ($null -eq $field.value -and $null -ne $warstate.EndDate) { 
                        $null = set-huduasset -name $device.name -company_id $device.company_id -asset_layout_id $layout.id -fields $device.fields -asset_id $device.id
                    } 
                }
            }
        }
        $WarState
    }
    return $warrantyObject
}