using namespace System.Net

param($Request, $TriggerMetadata)

function Get-AzToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ResourceUri,
        [Switch]$AsHeader
    ) 
    $Context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
    $Token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $ResourceUri).AccessToken
    if ($AsHeader) {
        return @{Headers = @{Authorization = "Bearer $Token" } }
    }
    return $Token   
}

If($Request.Headers.message -ne 'Iam_a_bit_more_secure')
    {
        "Password not valid"
        EXIT
    }    

$Inputs = $Request.Body | ConvertFrom-Json
$DeviceName = $($Inputs[0].DeviceName)
$DCR = $($Inputs[0].DCR)
$Table = $($Inputs[0].Table)
$Inputs = ConvertFrom-Json $Request.Body 
$Inputs_JSON = $Request.Body 

$Data_Log_Size = $Inputs_JSON.Length
If ($Data_Log_Size -eq 0)
    {
        "Log is empty: no data to send"
        EXIT
    }

If($DCR -eq $null -or $Table -eq $null)
	{
		If(($DCR -eq $null) -and ($Table -eq $null))
			{
				"DCR and Table are missing"
			}
		ElseIf(($DCR -eq $null) -and ($Table -ne $null))
			{
				"DCR is missing"
			}
		ElseIf(($DCR -ne $null) -and ($Table -eq $null))
			{
				"Table is missing"
			}
		EXIT
	}

# Get token to check device in Intune
$Token = Get-AzToken -ResourceUri 'https://graph.microsoft.com/'
$headers = @{'Authorization'="Bearer " + $Token}

$Get_Device_URL = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter' + "=contains(deviceName,'$DeviceName')"   
$Get_Device_Info = Invoke-WebRequest -Uri $Get_Device_URL -Method GET -Headers $Headers -UseBasicParsing  
$Get_Device_Info_JsonResponse = ($Get_Device_Info.Content | ConvertFrom-Json).value
If($Get_Device_Info_JsonResponse -ne $null) # "The device is allowed"
    {
        $Device_Compliance = $Get_Device_Info_JsonResponse.complianceState
        $Device_OwnerType = $Get_Device_Info_JsonResponse.managedDeviceOwnerType

        If(($Device_Compliance -ne "compliant") -or ($Device_OwnerType -ne "company"))
            {
                If(($Device_Compliance -ne "compliant") -and ($Device_OwnerType -ne "company"))
                    {
                        "Device is not compliant and owner is not company"
                    }
                ElseIf(($Device_Compliance -eq "compliant") -and ($Device_OwnerType -ne "company"))
                    {
                        "Device owner is not company"
                    }   
                ElseIf(($Device_Compliance -ne "compliant") -and ($Device_OwnerType -eq "company"))
                    {
                        "Device is not compliant"
                    }   
                EXIT                                      
            }

        $bearerToken = Get-AzToken -ResourceUri 'https://monitor.azure.com//.default'
        
        $DceURI = "https://dce-grt-dwpprd-we-telemetry-rmuq.westeurope-1.ingest.monitor.azure.com" # available in DCE > Logs Ingestion value
        $DcrImmutableId = "dcr-$DCR" # id available in DCR > JSON view > immutableId
				
        Add-Type -AssemblyName System.Web

        $headers = @{"Authorization" = "Bearer $bearerToken"; "Content-Type" = "application/json" };
        $uri = "$DceURI/dataCollectionRules/$DcrImmutableId/streams/Custom-$Table"+"?api-version=2023-01-01";

        Try{
            $uploadResponse = Invoke-RestMethod -Uri $uri -Method "Post" -Body $Inputs_JSON -Headers $headers;
            $body = "Upload to Log Analytics OK"
        }
        Catch{
            $body = "Upload to Log Analytics KO"
        }
    }
Else
{
    "The device is not allowed (not managed)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
