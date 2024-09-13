Param ( $WorkDir )

$oScript = @"
@echo off
cls
>%tmp%\HttpsOK_Update_Cert.ps1 more +0 %~s0
powershell -Command "Set-ExecutionPolicy -Scope Process Bypass; . %tmp%\HttpsOK_Update_Cert.ps1 -WorkDir '%~dp0'"
goto :EOF
"@

$PROJECT_HOME = ".httpsok"
$PROJECT_BACKUP = "${PROJECT_HOME}\_backup"

$HTTPSOK_HOME_URL = "https://httpsok.com/"
$BASE_API_URL = "https://api.httpsok.com/v1/nginx"
$SCRIPT_URL = "https://get.httpsok.com/"

$VER = "1.16.0"
$MODE = "normal"
$HTTPSOK_TOKEN = ""
$TRACE_ID = ""
$HTTPSOK_UUID = ""
$HTTPSOK_UUID_FILE = "${PROJECT_HOME}\uuid"
$HTTPSOK_TOKEN_FILE = "${PROJECT_HOME}\token"
$HTTPSOK_PREPARSE = ""

$HTTPSOK_HEADER = $null

function pause() {
	Write-Host "Press any key to contiune..."
	[Console]::ReadKey() | Out-Null
}

function InitPath() {
	if (!(Test-Path ${Script:PROJECT_HOME})) {
		mkdir ${Script:PROJECT_HOME}
	}
	if (!(Test-Path ${Script:PROJECT_BACKUP})) {
		mkdir ${Script:PROJECT_BACKUP}
	}
}

function InitHttp() {
	InitPath
	GetToken
	GetUUID

	${Script:HTTPSOK_HEADER} = @{
		"Content-Type" = "text/plain"
		"httpsok-token" = ${Script:HTTPSOK_TOKEN}
		"httpsok-version" = ${Script:VER}
		"os-name" = "ubuntu"
		"nginx-version" = "1.7.11.3"
		"nginx-config-home" = "."
		"nginx-config" = "${Script:PROJECT_HOME}/sample.conf"
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
	Write-Host "Current api:`n`t$strUrl"
	if ($SaveFile -ne $null) {
		$oRet = Invoke-RestMethod -Method GET -Uri $strUrl -Header ${Script:HTTPSOK_HEADER} -OutFile $SaveFile
	} else {
		$oRet = Invoke-RestMethod -Method GET -Uri $strUrl -Header ${Script:HTTPSOK_HEADER}
	}
	#Write-Host $oRet

	return $oRet
}

function PostAPI() {
	Param( $Action, $BodyContent )

	InitHttp
	#${Script:HTTPSOK_HEADER}

	$strUrl = "${Script:BASE_API_URL}$Action"
	Write-Host "Current api:`n`t$strUrl"
	foreach ($key in ${Script:HTTPSOK_HEADER}.keys) {
		$strHeader += "-H `"${key}:$(${Script:HTTPSOK_HEADER}[$key])`" "
	}
	$strCMD = "curl.exe -s -X POST --data-binary `"$BodyContent`" $strHeader `"$strUrl`""
	#Write-Host "Execution: $strCMD"
	$oRet = Invoke-Expression $strCMD
	#Write-Host $oRet

	return $oRet
}

function PostAPI2() {
	Param( $Action, $BodyContent )

	InitHttp
	#${Script:HTTPSOK_HEADER}

	$strUrl = "${Script:BASE_API_URL}$Action"
	Write-Host "Current api:`n`t$strUrl"
	foreach ($key in ${Script:HTTPSOK_HEADER}.keys) {
		$strHeader += "-H `"${key}:$(${Script:HTTPSOK_HEADER}[$key])`" "
	}
	$strCMD = "curl.exe -s -X POST --data-binary `"@$BodyContent`" $strHeader `"$strUrl`""
	#Write-Host "Execution: $strCMD"
	$oRet = Invoke-Expression $strCMD
	#Write-Host $oRet

	return $oRet
}

function PutAPI() {
	Param( $Action, $BodyContent )

	InitHttp
	#${Script:HTTPSOK_HEADER}

	$strUrl = "${Script:BASE_API_URL}$Action"
	Write-Host "Current api:`n`t$strUrl"
	foreach ($key in ${Script:HTTPSOK_HEADER}.keys) {
		$strHeader += "-H `"${key}:$(${Script:HTTPSOK_HEADER}[$key])`" "
	}
	$strCMD = "curl.exe -s -X PUT --data-binary `"$BodyContent`" $strHeader `"$strUrl`""
	#Write-Host "Execution: $strCMD"
	$oRet = Invoke-Expression $strCMD
	#Write-Host $oRet

	return $oRet
}

function UploadAPI() {
	Param( $Code, $File1, $File2 )

	InitHttp
	#${Script:HTTPSOK_HEADER}

	$strUrl = "${Script:BASE_API_URL}/upload?code=$Code"
	Write-Host "Current api:`n`t$strUrl"
	foreach ($key in ${Script:HTTPSOK_HEADER}.keys) {
		$strHeader += "-H `"${key}:$(${Script:HTTPSOK_HEADER}[$key])`" "
	}
	$strCMD = "curl.exe -s -X POST -H `"Content-Type: multipart/form-data`" -F `"cert=@$File1`" -F `"certKey=@$File2`" $strHeader `"$strUrl`""
	#Write-Host "Execution:`n`t$strCMD"
	$oRet = Invoke-Expression $strCMD
	#Write-Host $oRet

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
				Write-Host "Unvaliable token, please retry later..."
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

	${Script:HTTPSOK_UUID} = $([GUID]::NewGuid() -Replace "-", "")
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
	$oRet = $(PostAPI2 -Action "/preparse" -BodyContent "${Script:PROJECT_HOME}/sample.conf")

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

	$oRet = Check 60 "$strCode" "$strCert" "$strCertKey"
	$strRet = $($oRet | sed -n "/latest_code/p" | awk "{print `$2}")

	return $strRet
}

function Check() {
	Param( $Depth, $Code, $Cert, $CertKey )

	if ($Depth -le 0) {
		Write-Host "The maxinum number of attempts exceeded"
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

				Write-Host "$Code $Cert : New cert updated"
				RemoteLog "cert-updated-success" "$Code" "New cert updated"
			} else {
				Write-Host "$Code $Cert : New cert update failed(md5 not match)"
				RemoteLog "cert-updated-failed" "$Code" "New cert update failed(md5 not match):cert_file_md5=$strCertFileMd5,tmp_cert_md5=$strTmpCertFileMd5,cert_key_file_md5=$strCertKeyMd5,tmp_cert_key_md5=$strTmpCertKeyMd5"
			}
		}
		"2" {
			Write-Host "$Code $Cert : New cert update processing, please jus wait..."
			Sleep -Milliseconds 10000
			Check $($Depth - 1) "$Code" "$Cert" "$CertKey"
		}
		"3" {
			Write-Host "$Code $Cert : Cert valid, no need to update"
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
	$oRet = PutAPI "/log/$Type?code=$Code" "$Message"

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

	$nRet = CheckToken
	if ($nRet -eq 0) {
		Write-Host "Avalible token checked, you can continue now"
	} else {
		Write-Host "Error when token check, please retry later..."
		pause
		exit
	}
	#pause

	${Script:HTTPSOK_PREPARSE} = PreParse
	Write-Host "Preparse result:`n`t${Script:HTTPSOK_PREPARSE}"
	#pause

	$oRet = UploadCert ${Script:HTTPSOK_PREPARSE}
	Write-Host "Upload result:`n`t$oRet"
	#pause

	$oRet = CheckDns
	Write-Host "CheckDns result:`n`t$oRet"
	#pause

	$oRet = CheckCert ${Script:HTTPSOK_PREPARSE}
	Write-Host "CheckCert result:`n`t$oRet"
	#pause
	
}

main -WorkRoot "$WorkDir"
pause
