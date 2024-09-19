Param ( $WorkDir )

$oScript = @"
@echo off
cls
>%tmp%\%~n0.ps1 more +0 %~s0
powershell -Command "Set-ExecutionPolicy -Scope Process Bypass; . %tmp%\%~n0.ps1 -WorkDir '%~dp0'"
goto :EOF
"@

$PROJECT_HOME = ".httpsok"
$PROJECT_BACKUP = "${PROJECT_HOME}\_backup"
$UPDATE_DOMAIN = ""
function pause() {
	Write-Log "Press any key to contiune..."
	[Console]::ReadKey() | Out-Null
}

function DomainCheck() {
	if (!(Test-Path "${Script:PROJECT_HOME}/domain.conf")) {
		${Script:UPDATE_DOMAIN} = Read-Host "Please input the domain name you want to bind"
		${Script:UPDATE_DOMAIN} | Out-File "${Script:PROJECT_HOME}/domain.conf" -Enc UTF8 -Force
	} else {
		${Script:UPDATE_DOMAIN} = $(cat "${Script:PROJECT_HOME}/domain.conf" -Enc UTF8)
	}
}
function Write-Log() {
	Param( $Msg )

	$strLogFile = "${WorkDir}\history.log"
	$strMsg = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") $Msg"
	Write-Host $strMsg
	$strMsg | Out-File $strLogFile -Append -Enc UTF8
}

function main() {
	Param ( $WorkRoot )
	pushd $WorkRoot

	DomainCheck

	# Backup old cert file
	Write-Log "Step 1: Backup the old pfx file."
	if (Test-Path "${Script:UPDATE_DOMAIN}.pfx") {
		$strDT = $(Get-Date -Format "yyyyMMddHHmmss").ToString()
		mv ${Script:UPDATE_DOMAIN}.pfx "backup_${strDT}_${Script:UPDATE_DOMAIN}.pfx"
	}

	# Export cert as pkcs12 file
	Write-Log "Step 2: Export the new cert to pfx file."
	$env:mypass = "123654"
	#$strSrcFolder = Read-Host "Input the source cert file folder"
	$strSrcFolder = "$PWD\.httpsok"
	openssl pkcs12 -export -out ${Script:UPDATE_DOMAIN}.pfx -inkey ${strSrcFolder}\cert.key -in ${strSrcFolder}\cert.pem -passout env:mypass

	$strWildCharDomain = ${Script:UPDATE_DOMAIN} -replace "^[^.]*\.", "."
	# Delete old pfx in local machine
	Write-Log "Step 3: Delete the certification from cert store."
	ls Cert:\LocalMachine\My | ?{ $_.Subject -like "*${strWildCharDomain}"} | rm

	# Import pfx to cert store
	Write-Log "Step 4: Import the new certification to cert store."
	certutil -f -p $env:mypass -importPFX $PWD\${Script:UPDATE_DOMAIN}.pfx

	# ReBind certification of web site
	Write-Log "Step 5: Rebind the certification to default web site as https protocol."
	$oCert = $( ls Cert:\LocalMachine\My | ?{ $_.Subject -like "*${strWildCharDomain}" } )
	$oCert
	$oBind = Get-WebBinding -Name "Default Web Site" -Protocol "https"
	$oBind
	Write-Log "  Step 5.1: Remove certification from Default Web Site."
	$oBind.RemoveSslCertificate()
	#pause
	Write-Log "  Step 5.2: Add new certification from Default Web Site."
	$oBind.AddSslCertificate($oCert.Thumbprint, "My")
	#pause

	# Restart web site
	Write-Log "Step 6: Restart the Default Web Site."
	$oWebSite = Get-WebSite -Name "Default Web Site"
	$oWebSite.Stop()
	$oWebSite.Start()

}

main -WorkRoot $WorkDir
pause
