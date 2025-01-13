$win32_computersystem = get-ciminstance win32_computersystem
$Manufacturer = $win32_computersystem.Manufacturer
$Model = $win32_computersystem.Model
If($Manufacturer -like "*lenovo*")
	{
		$Model_FriendlyName = $win32_computersystem.SystemFamily
	}Else
	{
		$Model_FriendlyName = $Model
	}	

$DCR = "" # id available in DCR > JSON view > immutableId
$Table = "DriversSecureLA_CL" # custom log to create
$AZ_Function_URL = ""

$PNPSigned_Drivers = get-ciminstance win32_PnpSignedDriver | where {($_.manufacturer -ne "microsoft") -and ($_.driverprovidername -ne "microsoft") -and`
($_.DeviceName -ne $null)} | select-object @{label="TimeGenerated";Expression={get-date -Format "dddd MM/dd/yyyy HH:mm K"}},`
@{Label="DCR";Expression={$DCR}},`
@{Label="Table";Expression={$Table}},`
@{Label="DeviceName";Expression={$env:computername}},`
@{Label="ModelFriendlyName";Expression={$Model_FriendlyName}},`
@{Label="DeviceManufacturer";Expression={$Manufacturer}},`
@{Label="Model";Expression={$Model}},`
@{Label="DriverName";Expression={$_.DeviceName}},DriverVersion,`
@{Label="DriverDate";Expression={$_.ConvertToDateTime($_.DriverDate)}},`
DeviceClass, DeviceID, manufacturer,InfName,Location

$PS_Version = ($psversiontable).PSVersion.Major
If($PS_Version -eq 7)
	{
		$Body_JSON = $PNPSigned_Drivers | ConvertTo-Json -AsArray;
	}Else{
		$Body_JSON = $PNPSigned_Drivers | ConvertTo-Json
	}

$Secure_header = @{message='Iam_a_bi_more_secure'}
$response = Invoke-WebRequest -Uri $AZ_Function_URL -Method POST -Body $body_json -Headers $Secure_header
