<#
.SYNOPSIS
This is a Powershell script to retrieve your Checkmarx ScanData for Insight Analysis
.DESCRIPTION
This script will collect Scan Information that includes data about: Projects, Presets, Teams, Engines, and Result Metrics 
.PARAMETER cx_sast_server
    URL of the Checkmarx Server (i.e. https://companyname.checkmarx.net or http://localhost).
.PARAMETER day_span
    The amount of days you from current day you would like to retrieve data for.
.PARAMETER start_date
    The start date of the date range you would like to collect data (Format: yyyy-mm-DD)
.PARAMETER end_date
    The end date of the date range you would like to collect data (Format: yyyy-mm-DD)
.EXAMPLE
    C:\PS> .\cxInsight_9_0.ps1 -cx_sast_server https://customerurl.checkmarx.net
.EXAMPLE
    C:\PS> .\cxInsight_9_0.ps1 -start_date 2019-04-01
.EXAMPLE
    C:\PS> .\cxInsight_9_0.ps1 -cx_sast_server http://localhost -day_span 180
.NOTES
    Author: Checkmarx
    Date:   April 13, 2020
    Updated: March 9, 2021
#>

param(
    [Parameter(Mandatory=$true)]
    [String]$cx_sast_server,
    [int]$day_span = 90,
    [String]$start_date = ((Get-Date).AddDays(-$day_span).ToString("yyyy-MM-dd")),
    [String]$end_date = (Get-Date -format "yyyy-MM-dd"),
    [Parameter(Mandatory=$False)]
    [switch]
    $bypassProxy
    )

###### Do Not Change The Following Configs ######
$grantType = "password"
$scope = "access_control_api sast_api"
$clientId = "resource_owner_sast_client"
$clientSecret = "014DF517-39D1-4453-B7B3-9930C563627C"

$cred = Get-Credential -Credential $null
$cxUsername = $cred.UserName
$cxPassword = $cred.GetNetworkCredential().password

$serverRestEndpoint = $cx_sast_server + "/cxrestapi/"
function getOAuth2Token() {
    $body = @{
        username      = $cxUsername
        password      = $cxPassword
        grant_type    = $grantType
        scope         = $scope
        client_id     = $clientId
        client_secret = $clientSecret
    }
    
    try {
        if ($bypassProxy) {
            $response = Invoke-RestMethod -noProxy -uri "${serverRestEndpoint}auth/identity/connect/token" -method post -body $body -contenttype 'application/x-www-form-urlencoded'
        }
        else {
            $response = Invoke-RestMethod -uri "${serverRestEndpoint}auth/identity/connect/token" -method post -body $body -contenttype 'application/x-www-form-urlencoded'
        }
    }
    catch {
        Write-Host "Exception:" $_
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
		Write-Host "Unable to retrieve Checkmarx AC Token"
        exit(-1)
    }
    
    return $response.token_type + " " + $response.access_token
}

Write-Host "Running Script on Version " (get-host).Version 
$token = getOAuth2Token

# Allow for use of the SOAP Proxy with HTTPS - solution sourced from thezim's 10/13/17 suggestion
# https://github.com/MicrosoftDocs/PowerShell-Docs/issues/1753
Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
             ServicePoint srvPoint, X509Certificate certificate,
             WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

function getOdata() {
    $Url = "${cx_sast_server}/cxwebinterface/odata/v1/Scans?`$select=Id,ProjectName,OwningTeamId,TeamName,ProductVersion,EngineServerId,Origin,PresetName,ScanRequestedOn,QueuedOn,EngineStartedOn,EngineFinishedOn,ScanCompletedOn,ScanDuration,FileCount,LOC,FailedLOC,TotalVulnerabilities,High,Medium,Low,Info,IsIncremental,IsLocked,IsPublic&`$expand=ScannedLanguages(`$select=LanguageName)&`$filter=ScanRequestedOn%20gt%20${start_date}Z%20and%20ScanRequestedOn%20lt%20${end_date}z"
    $headers = @{
        Authorization = $token
    }
    try {
        if ($bypassProxy) {
            $response = Invoke-RestMethod -noProxy -uri "$Url" -method get -headers $headers -OutFile "data.txt"
        }
        else {
            $response = Invoke-RestMethod -uri "$Url" -method get -headers $headers -OutFile "data.txt"
        }
        return $response
    }
    catch {
        Write-Host "Exception:" $_
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
		Write-Host $Url
		Write-Host "An Error has prevented this script from collecting Odata."
        exit(-1)
    }
}

try
{
    $data = getOdata('')
    Read-Host -Prompt "The script was successful. Please send the 'data.txt' file in this directory to your Checkmarx Engineer. Press Enter to exit"
}
catch
{
    Write-Host "Exception:" $_
    Write-Error $_.Exception.ToString()
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    Read-Host -Prompt "The above error occurred. Press Enter to exit."
}
