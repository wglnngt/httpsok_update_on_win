Param ($EntryDir)

$oScriptBlock = @"
    @echo off
    cls
    >%tmp%\%~n0.ps1 more +0 %~0
    Powershell -ExecutionPolicy Bypass -File "%tmp%\%~n0.ps1" "%~dp0"
    goto :EOF
"@

function pause() {
    Write-Host "Press any key to contiune..."
    [Console]::ReadKey() | Out-Null
}

$PROJECT_HOME = ".httpsok"
$PROJECT_BACKUP = "${PROJECT_HOME}/_backup"
$HTTPSOK_TOKEN_FILE = "${PROJECT_HOME}/token_openapi"
$BASE_OPENAPI_URL = "https://openapi.httpsok.com/v1"

$HTTPSOK_TOKEN = ""
$TRACE_ID = ""
$UPDATE_DOMAIN = ""
$API_KEY = ""
$WorkDir = ""

if ($EntryDir -ne $null) {
    $WorkDir = $EntryDir.Trim("[`" ]")
}

function InitPath() {
    if (!(Test-Path ${Script:PROJECT_HOME})) {
        mkdir ${Script:PROJECT_HOME}
    }
    if (!(Test-Path ${Script:PROJECT_BACKUP})) {
        mkdir ${Script:PROJECT_BACKUP}
    }

    if (!(Test-Path "${Script:PROJECT_HOME}/domain.conf")) {
        ${Script:UPDATE_DOMAIN} = Read-Host "Please input the domain name you want to bind"
        ${Script:UPDATE_DOMAIN} | Out-File "${Script:PROJECT_HOME}/domain.conf" -Enc UTF8 -Force
    } else {
        ${Script:UPDATE_DOMAIN} = $(cat "${Script:PROJECT_HOME}/domain.conf" -Enc UTF8)
    }
}

function GetToken() {
    while ($true) {
        if (${Script:HTTPSOK_TOKEN} -eq "") {
            if (Test-Path ${Script:HTTPSOK_TOKEN_FILE}) {
                ${Script:HTTPSOK_TOKEN} = $(cat ${Script:HTTPSOK_TOKEN_FILE} -Enc UTF8)
            } else {
                ${Script:HTTPSOK_TOKEN} = Read-Host "Please input the token"
            }

            if (${Script:HTTPSOK_TOKEN} -ne "") {
                ${Script:HTTPSOK_TOKEN} | Out-File ${Script:HTTPSOK_TOKEN_FILE} -Enc UTF8 -Force
                break
            } else {
                Write-Host "Unvaliable token, please retry later..."
                pause
            }
        } else {
            break
        }
    }
}

function Write-Log() {
    Param( $Msg )

    $strLogFile = "${Script:WorkDir}/history.log"
    $strMsg = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") $Msg"
    Write-Host $strMsg
    $strMsg | Out-File $strLogFile -Append -Enc UTF8
}

function main() {
    if (${Script:WorkDir} -eq $null) {
        ${Script:WorkDir} = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
    pushd ${Script:WorkDir}
    Write-Log "Current work dir: ${Script:WorkDir}"
    Write-Log "`n`n"
    #pause

    InitPath
    GetToken

    $oHeader = @{
        "OpenApiKey" = "${Script:HTTPSOK_TOKEN}"
        "Content-Type" = "application/json"
    }

    # Step 1: Authenticate
    Write-Log "Step 1: query domain state"
    $strAPICheckUrl = "${Script:BASE_OPENAPI_URL}/cert/dv"
    Write-Log "Current api: $strAPICheckUrl"
    $oBody = @{
        "domainList" = @(, "${Script:UPDATE_DOMAIN}")
    }
    $strBody = "$($oBody | ConvertTo-Json -Compress)"

    Write-Log "Headers: $($oHeader | ConvertTo-Json -Compress)"
    Write-Log "Body: $strBody"

    $strCMD = "IWR -Method POST -Headers `$oHeader -Uri `"$strAPICheckUrl`" -Body `$strBody"
    Write-Log "Execution command: $strCMD"
    $oRetAuth = $(Invoke-Expression $strCMD) | ConvertFrom-Json
    $strRetAuth = $oRetAuth | ConvertTo-Json -Depth 5 -Compress

    Write-Log $oRetAuth
    Write-Log $strRetAuth
    Write-Log "`n`n"
    #pause

    $strCode = ""
    $strCertCode = ""

    # Step 2: Apply
    Write-Log "Step 2: issue domain certificate"
    $strCode = [string]$oRetAuth.code
    Write-Log "Return auth code: $strCode"
    if ($strCode -ne "0" -or $oRetAuth.data.valid -ne $true) {
        Write-Log "Error autherization..."
        pause
        exit
    } else {
        if (Test-Path "${Script:PROJECT_HOME}/mission") {
            $strCertCode = $(Cat "${Script:PROJECT_HOME}/mission")
        } else {
            $strAPIApplyUrl = "${Script:BASE_OPENAPI_URL}/cert/apply"
            Write-Log "Current api: $strAPIApplyUrl"
            $strCMD = "IWR -Method POST -Uri `"$strAPIApplyUrl`" -Headers `$oHeader -Body `$strBody"
            Write-Log "Execution command: $strCMD"
            $oRetApply = $(Invoke-Expression $strCMD) | ConvertFrom-Json
            $strRetApply = $oRetApply | ConvertTo-Json -Depth 5 -Compress

            Write-Log $oRetApply
            Write-Log $strRetApply

            if ($oRetApply.data -ne "") {
                $strCertCode = [string]$oRetApply.data
                $strCertCode | Out-File "${Script:PROJECT_HOME}/mission" -Enc UTF8 -Force
            }
        }
    }
    Write-Log "Return cert mission: $strCertCode"
    Write-Log "`n`n"
    #pause

    # Step 3: Cert content load
    Write-Log "Step 3: query cert content"
    Write-Log "Return cert code: $strCertCode"
    $oRetCert = $null
    $strRetCert = ""
    if ($strCertCode -eq "") {
        Write-Log "Error cert query"
        pause
        exit
    } else {
        $strAPICertUrl = "${Script:BASE_OPENAPI_URL}/cert/apply/${strCertCode}"
        Write-Log "Current api: $strAPICertUrl"
        while ($true) {
            $strCMD = "IWR -Method Get -Uri `"$strAPICertUrl`" -Headers `$oHeader"
            Write-Log "Execution command: $strCMD"
            $oRetCert = $(Invoke-Expression $strCMD) | ConvertFrom-Json
            $strRetCert = $oRetCert | ConvertTo-Json -Depth 5 -Compress

            Write-Log $oRetCert
            Write-Log $strRetCert

            if ($oRetCert -ne $null -and $oRetCert.data -ne $null -and $oRetCert.data.certificate -ne $null) {
                if ($oRetCert.data.status -eq 3) {
                    # Status: Error
                    Write-Log "Cert apply error, please retry later..."
                    pause
                    exit
                } elseif ($oRetCert.data.status -ne 1) {
                    # Status: In Processing
                    Write-Log "Cert apply in processing, will retry later..."
                    Sleep -Milliseconds $(4*60*1000)
                } else {
                    # Status: Successed
                    break
                }
            } else {
                Write-Log "No valid data return, retry later..."
                Sleep -Milliseconds $(4*60*1000)
            }
        }
    }
    if ($oRetCert -ne $null -and $oRetCert.data -ne $null) {
        #Write-Log "Return data as PSObject:`n"
        #Write-Log $oRetCert.data
        #Write-Log "Return data as Json:`n$($oRetCert.data | ConvertTo-Json -Compress)"

		# Backup old cert files first
		$strDateTime = Get-Date -Format "yyyyMMddHHmmss"
		if (Test-Path "${Script:PROJECT_HOME}/cert.pem") {
			mv -Force "${Script:PROJECT_HOME}/cert.pem" "${Script:PROJECT_BACKUP}/cert.pem_bak_${strDateTime}"
		}
		if (Test-Path "${Script:PROJECT_HOME}/cert.key") {
			mv -Force "${Script:PROJECT_HOME}/cert.key" "${Script:PROJECT_BACKUP}/cert.key_bak_${strDateTime}"
		}

		# Write newest cert files to local
        $oUTF8 = [Text.Encoding]::UTF8
        [IO.File]::WriteAllBytes("$PWD/${Script:PROJECT_HOME}/cert.pem", $oUTF8.GetBytes($oRetCert.data.certificate))
        [IO.File]::WriteAllBytes("$PWD/${Script:PROJECT_HOME}/cert.key", $oUTF8.GetBytes($oRetCert.data.privatekey))

        # Backup misson tag when updated cert files
        if (Test-Path "${Script:PROJECT_HOME}/mission") {
            mv -Force "${Script:PROJECT_HOME}/mission" "${Script:PROJECT_BACKUP}/mission_${strCertCode}_${strDateTime}"
        }
    }
    Write-Log "`n`n"

    # Step 4: Update ssl certification to IIS Website
    Write-Log "Step 4: Update ssl certification to IIS WebSite configration"
	Start CreateAndImportSSLCertification.bat
}


main
pause
