Start-Transcript -Path "C:\temp\PhishScraper-debug.txt"

function mail {
    param (
        $fail,
        $body1
    )

    if (!$fail) {
        Stop-Transcript
        $mail = @{
            From = '<email@example.com>'
            To = '<someoneelse@example.com>'
            Subject = 'Phishy Sign-In Scraper'
            Body = "$body1"
            Attachments = 'C:\temp\officeHome.txt'
            SmtpServer = '<stmp server>'
        }
    }
    else {
        $mail = @{
            From = '<email@example.com>'
            To = '<someoneelse@example.com>'
            Subject = 'Phishy Sign-In Scraper Failed'
            Body = "phishScraper.ps1 failed with errors. Please see attached debug log."
            Attachments = 'C:\temp\PhishScraper-debug.txt'
            SmtpServer = '<stmp server>'
        }
    }

    Send-MailMessage @mail
    exit 0
}

function auth {
    
    $GraphProperties = @{
        AppID                 = "<appid>"
        TenantID              = "<tenantid>"
        CertificateThumbprint = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match "<subject>" } | Select-Object -ExpandProperty Thumbprint
    }

    #Authenticate to MS Graph. Requires Cloud App Admin privileges or someone who can approve Graph read permissions.
    try { Connect-MgGraph @GraphProperties -NoWelcome ; logSweep}
    catch { Write-Host "Connection failed." $_.Exception.Message ; Stop-Transcript; mail -fail $true }

}

function logSweep {

    $date = Get-Date
    $backDate = $date.AddDays(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    $oFilter = "AppDisplayName eq 'OfficeHome' and createdDateTime ge $backDate"
    $officeLog = Get-EntraAuditSignInLog -Filter $oFilter

    $stateExp = @{
        'AL' = 'Alabama'; 'AK' = 'Alaska'; 'AZ' = 'Arizona'; 'AR' = 'Arkansas'
        'CA' = 'California'; 'CO' = 'Colorado'; 'CT' = 'Connecticut'; 'DE' = 'Delaware'
        'FL' = 'Florida'; 'GA' = 'Georgia'; 'HI' = 'Hawaii'; 'ID' = 'Idaho'
        'IL' = 'Illinois'; 'IN' = 'Indiana'; 'IA' = 'Iowa'; 'KS' = 'Kansas'
        'KY' = 'Kentucky'; 'LA' = 'Louisiana'; 'ME' = 'Maine'; 'MD' = 'Maryland'
        'MA' = 'Massachusetts'; 'MI' = 'Michigan'; 'MN' = 'Minnesota'; 'MS' = 'Mississippi'
        'MO' = 'Missouri'; 'MT' = 'Montana'; 'NE' = 'Nebraska'; 'NV' = 'Nevada'
        'NH' = 'New Hampshire'; 'NJ' = 'New Jersey'; 'NM' = 'New Mexico'; 'NY' = 'New York'
        'NC' = 'North Carolina'; 'ND' = 'North Dakota'; 'OH' = 'Ohio'; 'OK' = 'Oklahoma'
        'OR' = 'Oregon'; 'PA' = 'Pennsylvania'; 'RI' = 'Rhode Island'; 'SC' = 'South Carolina'
        'SD' = 'South Dakota'; 'TN' = 'Tennessee'; 'TX' = 'Texas'; 'UT' = 'Utah'
        'VT' = 'Vermont'; 'VA' = 'Virginia'; 'WA' = 'Washington'; 'WV' = 'West Virginia'
        'WI' = 'Wisconsin'; 'WY' = 'Wyoming'
    }

   $officehomeReport = @()

    if ($officeLog) {
        $i = 0
        foreach ($log in $officeLog) {
            $loc = Get-EntraUser -UserId $log.UserPrincipalName | Select-Object State
            $loc = $stateExp[$loc]
            $name = $log.UserDisplayName
            $app =  $log.AppDisplayName
            $uA =  $log.userAgent
            $ip =  $log.IPAddress
            $status =  $log.Status.AdditionalDetails
            $region = $log.Location.CountryOrRegion
            $state = $log.Location.State

            if ($log.userAgent -match 'axios') {
                $uA = $uA + " <--- IMPORTANT"
            }
            else {
                $uA = "Standard"
            }
            if ($log.Status.ErrorCode -eq '0') {
                $status = $status + " <--- SUCCESSFUL"
            }
            if ($log.Location.CountryOrRegion -ne "US") {
                $region = $region + " <--- NOT IN UNITED STATES"
            }

            $officehomeReport += [PSCustomObject]@{
                Name = $name
                "User Agent" = $uA
                IP = $ip
                Region = $region
                Status = $status
            }
            $i++
        }
    }
    else {
        $i = 0
    }
    
    $body1 = "There were $i OfficeHome logins recorded."
    $officehomeReport = $officehomeReport | Format-Table -AutoSize -Wrap
    $officehomeReport | Out-File "C:\temp\officeHome.txt"

    mail -fail $false -body1 $body1
}


try { auth } catch {Write-Host "Log Sweep failed:" $_.Exception.Message ; Stop-Transcript; mail -fail $true}
