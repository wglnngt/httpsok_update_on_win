Param ( $WorkDir )

$oScript = @"
@echo off
cls
>%tmp%\%~n0.ps1 more +0 %~s0
powershell -Command "Set-ExecutionPolicy -Scope Process Bypass; . %tmp%\%~n0.ps1 -WorkDir '%~dp0'"
goto :EOF
"@

$PROJECT_HOME = ".httpsok"
$PROJECT_BACKUP = "${PROJECT_HOME}/_backup"

$HTTPSOK_HOME_URL = "https://httpsok.com/"
$BASE_API_URL = "https://api.httpsok.com/v1/nginx"
$SCRIPT_URL = "https://get.httpsok.com/"

$VER = "1.16.0"
$MODE = "normal"
$HTTPSOK_TOKEN = ""
$TRACE_ID = ""
$HTTPSOK_UUID = ""
$HTTPSOK_UUID_FILE = "${PROJECT_HOME}/uuid"
$HTTPSOK_TOKEN_FILE = "${PROJECT_HOME}/token"
$HTTPSOK_PREPARSE = ""
$UPDATE_DOMAIN = ""

$HTTPSOK_HEADER = $null

function pause() {
	Write-Log "Press any key to contiune..."
	[Console]::ReadKey() | Out-Null
}

function Write-Log() {
	Param( $Msg )

	$strLogFile = "${WorkDir}/history.log"
	$strMsg = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") $Msg"
	Write-Host $strMsg
	$strMsg | Out-File $strLogFile -Append -Enc UTF8
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

		if (!(Test-Path "${Script:PROJECT_HOME}/target.conf")) {
			$strConfig = cat -enc UTF8 "${Script:PROJECT_HOME}/sample.conf"
			$strConfig = $strConfig.Replace("your_valid_domain", ${Script:UPDATE_DOMAIN})
			$strConfig | Out-File "${Script:PROJECT_HOME}/target.conf" -Enc UTF8 -Force
		}
	}
}

function InitHttp() {
	InitPath
	GetToken
	GetUUID
	#pause

	${Script:HTTPSOK_HEADER} = @{
		"Content-Type" = "text/plain"
		"httpsok-token" = ${Script:HTTPSOK_TOKEN}
		"httpsok-version" = ${Script:VER}
		"os-name" = "Ubuntu 18.04.5 LTS"
		"nginx-version" = "nginx/1.24.0"
		"nginx-config-home" = "${Script:PROJECT_HOME}"
		"nginx-config" = "${Script:PROJECT_HOME}/target.conf"
		#"nginx-bin" = "nginx"
		"trace-id" = ${Script:TRACE_ID}
		"mode" = ${Script:MODE}
		"httpsok-uuid" = ${Script:HTTPSOK_UUID}
	}
}

function GetAPI() {
	Param( $Action, $SaveFile )

	InitHttp

	$oRet = $null
	$strUrl = "${Script:BASE_API_URL}$Action"
	Write-Log "Current api:`n`t$strUrl"
	foreach ($key in ${Script:HTTPSOK_HEADER}.keys) {
		$strHeader += "-H `"${key}: $(${Script:HTTPSOK_HEADER}[$key])`" "
	}
	if ($SaveFile -ne $null) {
		#$oRet = Invoke-RestMethod -Method GET -Uri $strUrl -Header ${Script:HTTPSOK_HEADER} -OutFile $SaveFile
		$strCMD = "curl.exe -sk -X GET $strHeader `"$strUrl`" -o $SaveFile"
		Write-Log "Execution: $strCMD"
		$oRet = Invoke-Expression $strCMD
	} else {
		#$oRet = Invoke-RestMethod -Method GET -Uri $strUrl -Header ${Script:HTTPSOK_HEADER}
		$strCMD = "curl.exe -sk -X GET $strHeader `"$strUrl`" "
		Write-Log "Execution: $strCMD"
		$oRet = Invoke-Expression $strCMD
	}
	#Write-Log $oRet

	return $oRet
}

function PostAPI() {
	Param( $Action, $BodyContent )

	InitHttp
	#${Script:HTTPSOK_HEADER}

	$strUrl = "${Script:BASE_API_URL}$Action"
	Write-Log "Current api:`n`t$strUrl"
	foreach ($key in ${Script:HTTPSOK_HEADER}.keys) {
		$strHeader += "-H `"${key}: $(${Script:HTTPSOK_HEADER}[$key])`" "
	}
	$strCMD = "curl.exe -sk -X POST --data-binary `"$BodyContent`" $strHeader `"$strUrl`""
	#Write-Log "Execution: $strCMD"
	$oRet = Invoke-Expression $strCMD
	#Write-Log $oRet

	return $oRet
}

function PostAPI2() {
	Param( $Action, $BodyContent )

	InitHttp
	#${Script:HTTPSOK_HEADER}

	$strUrl = "${Script:BASE_API_URL}$Action"
	Write-Log "Current api:`n`t$strUrl"
	foreach ($key in ${Script:HTTPSOK_HEADER}.keys) {
		$strHeader += "-H `"${key}: $(${Script:HTTPSOK_HEADER}[$key])`" "
	}
	$strCMD = "curl.exe -sk -X POST --data-binary `"@$BodyContent`" $strHeader `"$strUrl`""
	Write-Log "Execution: $strCMD"
	$oRet = Invoke-Expression $strCMD
	#Write-Log $oRet

	return $oRet
}

function PutAPI() {
	Param( $Action, $BodyContent )

	InitHttp
	#${Script:HTTPSOK_HEADER}

	$strUrl = "${Script:BASE_API_URL}$Action"
	Write-Log "Current api:`n`t$strUrl"
	foreach ($key in ${Script:HTTPSOK_HEADER}.keys) {
		$strHeader += "-H `"${key}: $(${Script:HTTPSOK_HEADER}[$key])`" "
	}
	$strCMD = "curl.exe -sk -X PUT --data-binary `"$BodyContent`" $strHeader `"$strUrl`""
	#Write-Log "Execution: $strCMD"
	$oRet = Invoke-Expression $strCMD
	#Write-Log $oRet

	return $oRet
}

function UploadAPI() {
	Param( $Code, $File1, $File2 )

	InitHttp
	#${Script:HTTPSOK_HEADER}

	$strUrl = "${Script:BASE_API_URL}/upload?code=$Code"
	Write-Log "Current api:`n`t$strUrl"
	foreach ($key in ${Script:HTTPSOK_HEADER}.keys) {
		$strHeader += "-H `"${key}: $(${Script:HTTPSOK_HEADER}[$key])`" "
	}
	$strCMD = "curl.exe -sk -X POST -H `"Content-Type: multipart/form-data`" -F `"cert=@$File1`" -F `"certKey=@$File2`" $strHeader `"$strUrl`""
	#Write-Log "Execution:`n`t$strCMD"
	$oRet = Invoke-Expression $strCMD
	#Write-Log $oRet

	return $oRet
}

function GetToken() {
	while ($true) {
		if (${Script:HTTPSOK_TOKEN} -eq "") {
			if (Test-Path ${Script:HTTPSOK_TOKEN_FILE}) {
				${Script:HTTPSOK_TOKEN} = $(cat ${Script:HTTPSOK_TOKEN_FILE})
			} else {
				${Script:HTTPSOK_TOKEN} = Read-Host "Please input the token"
			}
			if (${Script:HTTPSOK_TOKEN} -ne "") {
				${Script:HTTPSOK_TOKEN} | Out-File ${Script:HTTPSOK_TOKEN_FILE} -Enc UTF8 -Force
				break
			} else {
				Write-Log "Unvaliable token, please retry later..."
				pause
			}
		} else {
			break
		}
	}

	if (${Script:TRACE_ID} -eq "") {
		${Script:TRACE_ID} = $([GUID]::NewGuid() -Replace "-", "")
	}
}

function GetUUID() {
	if (${Script:HTTPSOK_UUID} -ne "") {
		return
	}

	if (Test-Path ${Script:HTTPSOK_UUID_FILE}) {
		${Script:HTTPSOK_UUID} = $(cat ${Script:HTTPSOK_UUID_FILE})
		if (${Script:HTTPSOK_UUID} -ne "") {
			return
		}
	}

	${Script:HTTPSOK_UUID} = $([GUID]::NewGuid().Guid)
	${Script:HTTPSOK_UUID} | Out-File ${Script:HTTPSOK_UUID_FILE} -Enc UTF8 -Force
}

function CheckToken() {
	$oRet = GetAPI "/status"
	if ($oRet -eq "ok") {
		return 0
	} else {
		return -1
	}
}

function PreParse() {
	$oRet = $(PostAPI2 -Action "/preparse" -BodyContent "${Script:PROJECT_HOME}/target.conf")

	return $oRet
}

function UploadCert() {
	Param( $PreParse )

	$arrParam = $PreParse.Split(",")
	$strCode = $arrParam[0]
	$strCert = $arrParam[1]
	$strCertKey = $arrParam[2]

	$oRet = UploadAPI -Code $strCode -File1 $strCert -File2 $strCertKey

	return $oRet
}

function CheckDns() {
	$oRet = GetAPI "/checkDns"
	$strRet = $($oRet.split("`n")[0]).Trim()

	switch ([int]$strRet) {
		3 {
			$oRet = "DNS check pass"
		}
		13 {
			$oRet = "DNS check failed"
		}
	}

	return $oRet
}

function CheckCert() {
	Param ( $PreParse )
	$arrParam = $PreParse.Split(",")
	$strCode = $arrParam[0]
	$strCert = $arrParam[1]
	$strCertKey = $arrParam[2]
	Write-Host "Check -Depth 60 -Code `"$strCode`" -Cert `"$strCert`" -CertKey `"$strCertKey`""
	pause

	$oRet = Check -Depth 60 -Code "$strCode" -Cert "$strCert" -CertKey "$strCertKey"
	$strRet = ""
	try {
		$strRet = $($oRet.Split("`n") | ?{ $_ -like "*latest_code*" }).Split(" ")[1]
	} catch {
		#Write-Log "CheckCert failed: $($_.Exception.Message)"
	}

	return $strRet
}

function Check() {
	Param( $Depth, $Code, $Cert, $CertKey )

	if ($Depth -le 0) {
		Write-Log "The maxinum number of attempts exceeded"
		return
	}

	$oRet = GetAPI "/check?code=$Code"
	$arrLines = $oRet.Split("`n")

	$strStatus = $arrLines[0].Trim()
	switch ($strStatus) {
		"1" {
			$strMd5Line = $arrLines[1].Trim()
			$arrSubParams = $strMd5Line.Split(",")
			$strCertFileMd5 = $arrSubParams[0]
			$strCertKeyMd5 = $arrSubParams[1]

			$strTmpCertFile = "${Script:PROJECT_HOME}/tmp_$Code.crt"
			$strTmpCertKey  = "${Script:PROJECT_HOME}/tmp_$Code.key"

			GetAPI "/cert/$Code.cer" "$strTmpCertFile"
			GetAPI "/cert/$Code.key" "$strTmpCertKey"

			$strTmpCertFileMd5 = $(Get-FileHash "$strTmpCertFile" -Algorithm MD5).Hash
			$strTmpCertKeyMd5 = $(Get-FileHash "$strTmpCertKey" -Algorithm MD5).Hash
			if ($strCertFileMd5.ToUpper() -eq $strTmpCertFileMd5 -and
				$strCertKeyMd5.ToUpper() -eq $strTmpCertKeyMd5
			) {
				# Cert file create and move old to backup folder
				CreateCertFile "$Code" "$Cert"
				CreateCertFile "$Code" "$CertKey"

				mv "$strTmpCertFile" "$Cert"
				mv "$strTmpCertKey" "$CertKey"

				Write-Log "$Code $Cert : New cert updated"
				RemoteLog -Type "cert-updated-success" -Code "$Code" -Message "New cert updated"
			} else {
				Write-Log "$Code $Cert : New cert update failed(md5 not match)"
				RemoteLog -Type "cert-updated-failed" -Code "$Code" -Message "New cert update failed(md5 not match):cert_file_md5=$strCertFileMd5,tmp_cert_md5=$strTmpCertFileMd5,cert_key_file_md5=$strCertKeyMd5,tmp_cert_key_md5=$strTmpCertKeyMd5"
			}
		}
		"2" {
			Write-Log "$Code $Cert : New cert update processing, please jus wait..."
			Sleep -Milliseconds 10000
			Check $($Depth - 1) "$Code" "$Cert" "$CertKey"
		}
		"3" {
			Write-Log "$Code $Cert : Cert valid, no need to update"
		}
		"12" {
			Write-Error "$Code $Cert : Code invalid"
		}
		Default {
			Write-Error "$Code $Cert : $oRet"
		}
	}

	
	return $oRet
}

function RemoteLog() {
	Param ( $Type, $Code, $Message )
	$oRet = PutAPI "/log/${Type}?code=${Code}" "${Message}"

	return $oRet
}

function CreateCertFile() {
	Param( $Code, $File )

	$strDir = Split-Path -Parent $File
	if (!(Test-Path $strDir)) {
		mkdir $strDir
	}
	if (Test-Path $File) {
		$strTime = (Get-Date).ToLocalTime() -Replace "[^0-9]", ""
		mv $File "${File}_bak_${strTime}"
		mv "${File}_bak_${strTime}" "${Script:PROJECT_BACKUP}"
	}
}

function main() {
	Param ( $WorkRoot )
	pushd "$WorkRoot"

	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11

	$nRet = CheckToken
	if ($nRet -eq 0) {
		Write-Log "Avalible token checked, you can continue now"
	} else {
		Write-Log "Error when token check, please retry later..."
		pause
		exit
	}
	Write-Log "`n`n"
	#pause

	${Script:HTTPSOK_PREPARSE} = PreParse
	Write-Log "Preparse result:`n`t${Script:HTTPSOK_PREPARSE}"
	Write-Log "`n`n"
	pause

	$oRet = UploadCert ${Script:HTTPSOK_PREPARSE}
	Write-Log "Upload result:`n`t$oRet"
	Write-Log "`n`n"
	#pause

	$oRet = CheckDns
	Write-Log "CheckDns result:`n`t$oRet"
	Write-Log "`n`n"
	#pause

	$oRet = CheckCert ${Script:HTTPSOK_PREPARSE}
	Write-Log "CheckCert result:`n`t$oRet"
	Write-Log "`n`n"
	#pause
	
	Write-Log "Update ssl certification to IIS component..."
	Start CreateAndImportSSLCertification.bat
}

main -WorkRoot "$WorkDir"
pause
