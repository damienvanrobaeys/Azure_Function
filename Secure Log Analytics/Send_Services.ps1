$DCR = "" # id available in DCR > JSON view > immutableId
$Table = "ServicesSecureLA_CL" # custom log to create
$AZ_Function_URL = ""

$Get_Services = get-service | select-object @{label="TimeGenerated";Expression={get-date -Format "dddd MM/dd/yyyy HH:mm K"}},`
@{Label="DCR";Expression={$DCR}},`
@{Label="Table";Expression={$Table}},`
@{Label="DeviceName";Expression={$env:computername}},`
DisplayName, Name, Status, StartType

$PS_Version = ($psversiontable).PSVersion.Major
If($PS_Version -eq 7)
	{
		$Body_JSON = $Get_Services | ConvertTo-Json -AsArray;
	}Else{
		$Body_JSON = $Get_Services | ConvertTo-Json
	}

$Secure_header = @{message='Iam_a_bit_more_secure'}
$response = Invoke-WebRequest -Uri $AZ_Function_URL -Method POST -Body $body_json -Headers $Secure_header
