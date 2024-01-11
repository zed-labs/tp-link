Function tp([string]$Name){
	Get-Command -Module tp | Where {$_.Name -like "*$Name*"}
}
Function tp-KasaConnect($Credential){
	if (! $Credential){
		$Vaulted = vault-get -Type kasa -Username (vault-get -Type kasa).UserName
		if ($Vaulted){$Credential = $Vaulted}else{return "`nSyntax error, requires -Credential (or a vaulted 'kasa' credential)`n"}
	}
	$uri = 'https://wap.tplinkcloud.com'
	$uid = (New-Guid).guid
	$Body = "{'method': 'login','params': {'appType': 'Kasa_Android','cloudUserName': '$($Credential.UserName)','cloudPassword': '$($Credential.GetNetworkCredential().Password)','terminalUUID': $uid }}"

	Write-Host "Getting token..." -NoNewLine
	$Session = Invoke-WebRequest -Uri $uri -Method POST -Body $Body -ContentType 'application/json' | Select -ExpandProperty Content | ConvertFrom-Json
	$Token = $Session | Select -ExpandProperty Result | Select -ExpandProperty Token
	if ($Token){write-host " [ok]" -ForegroundColor DarkGreen}else{write-host " [failed]" -ForegroundColor Cyan; return}
	$Global:KasaToken = $Token
}
Function tp-GetKasaConnection($Credential){
	$Global:KasaToken
}
Function tp-GetKasaDevice(){
	if (! $KasaToken){tp-KasaConnect; if (! $KasaToken){return "Unable to tp-KasaConnect"}}
	$uri = "https://wap.tplinkcloud.com/?token=$KasaToken"
	$Body = "{'method':'getDeviceList'}"
	Write-Host "Getting devices..." -NoNewLine
	$Results = Invoke-WebRequest -Uri $uri -Method POST -Body $Body -ContentType 'application/json' | Select -ExpandProperty Content | ConvertFrom-Json | Select -ExpandProperty result | Select -ExpandProperty deviceList
	if ($Results){write-host " [ok]" -ForegroundColor DarkGreen}else{write-host " [failed]" -ForegroundColor Cyan}
	return $Results
}
Function tp-GetPython(){
	if (! (Test-Path "$((Get-Module tp) | Select -ExpandProperty ModuleBase)`\tp.py")){return}
	return "$((Get-Module tp) | Select -ExpandProperty ModuleBase)`\tp.py"	
}
Function tp-GetAllDevices(){
	$Devices = 'Light1','Light2','AirStone','Water','OfficeLamp','HallLight','Internet','ghjfg' | Sort
	return $Devices
}
Function tp-GetInfo($Device){
	if (! $Device){$Device = tp-GetAllDevices}
	$tp = tp-GetPython
	if (! $tp){return "Unable to locate python script."}
	$Results = @()
	foreach ($d in $Device){
		$Usage = tp-GetUsage $d
		$Response = . $tp -t $d -c info -q | ConvertFrom-Json | Select -ExpandProperty system | Select -ExpandProperty get_sysinfo | Select @{
			l='Device';e={$d}},@{
			l='PowerState';e={if ($_.relay_state -eq 1){'On'}else{'Off'}}},@{
			l='Wattage';e={$Usage.power}},@{
			l='Current';e={$Usage.current}},@{
			l='Voltage';e={$Usage.voltage}},@{
			l='kWhYesterday';e={tp-GetYesterdayUsage $d | Select -ExpandProperty Usage}},@{
			l='kWhLastMonth';e={tp-GetLastMonthUsage $d | Select -ExpandProperty Usage}},@{
			l='LedState';e={if ($_.led_off -eq 0){'On'}else{'Off'}}},@{
			l='Model';e={$_.model.split('(')[0]}},@{
			l='HwVersion';e={$_.hw_ver}},@{
			l='Description';e={$_.dev_name}},@{
			l='Firmware';e={$_.sw_ver}},@{
			l='Type';e={$_.Type}},@{
			l='Alias';e={$_.Alias}},@{
			l='MAC';e={$_.mac}},@{
			l='WifiSignal';e={$_.rssi}},@{
			l='OnDuration';e={if ($_.on_time -ge 1){
				FriendlyTimespan (New-TimeSpan (get-date) (get-date).AddSeconds($_.on_time))
			}else{''}}},@{
			l='OnTime';e={$_.on_time}},@{
			l='Latitude';e={$_.latitude}},@{
			l='Longitude';e={$_.longitude}},@{
			l='OemID';e={$_.oemId}},@{
			l='HwID';e={$_.HwID}},@{
			l='DevID';e={$_.deviceId}},@{
			l='Date';e={"$(Get-Date)"}}
		if ($Response){$Results += $Response}else{write-host "$d in inaccessible"}
	}
	return $Results
}
Function tp-GetPowerState($Device){
	if (! $Device){$Device = tp-GetAllDevices}
	tp-GetInfo $Device | Select Device,PowerState
}
Function tp-SetPowerState($Device,[ArgumentCompleter({'On','Off'})]$State){
	if (! $Device){return "`nSyntax error, requires -Device`n"}
	if (! $State){return "`nSyntax error, requires -State`n"}
	$CurrentState = tp-GetPowerState $Device | Select -ExpandProperty PowerState
	if ($CurrentState -eq 'Down'){return "$Device is inaccessible"}
	if ($State -eq "On"){
		if ($CurrentState -eq 'On'){
			return "Device is already on."
		}else{
			write-host "Turning on $Device`..." -NoNewLine
			$do = . $tp -t $Device -c on -q
			$CurrentState = tp-GetPowerState $Device
			if ($CurrentState -eq 'On'){write-host " [ok]" -ForegroundColor DarkGreen}else{write-host " [failed]" -ForegroundColor Cyan}
		}
	}elseif($State -eq "Off"){
		if ($CurrentState -eq 'Off'){
			return "Device is already off."
		}else{
			write-host "Turning off $Device`..." -NoNewLine
			$do = . $tp -t $Device -c off -q
			$CurrentState = tp-GetPowerState $Device
			if ($CurrentState -eq 'Off'){write-host " [ok]" -ForegroundColor DarkGreen}else{write-host " [failed]" -ForegroundColor Cyan}
		}
	}
}
Function tp-GetLedState($Device){
	if (! $Device){$Device = tp-GetAllDevices}
	tp-GetInfo $Device | Select Device,LedState
}
Function tp-SetLedState($Device,[ArgumentCompleter({'On','Off'})]$State){
	if (! $Device){return "`nSyntax error, requires -Device`n"}
	if (! $State){return "`nSyntax error, requires -State`n"}
	$CurrentState = tp-GetLedState $Device | Select -ExpandProperty LedState
	if ($CurrentState -eq 'Down'){return "$Device is inaccessible"}
	if ($State -eq "On"){
		if ($CurrentState -eq 'On'){
			return "LED is already on."
		}else{
			write-host "Turning LED on for $Device`..." -NoNewLine
			$do = . $tp -t $Device -c ledon -q
			$CurrentState = tp-GetLedState $Device
			if ($CurrentState -eq 'On'){write-host " [ok]" -ForegroundColor DarkGreen}else{write-host " [failed]" -ForegroundColor Cyan}
		}
	}elseif($State -eq "Off"){
		if ($CurrentState -eq 'Off'){
			return "LED is already off."
		}else{
			write-host "Turning LED off for $Device`..." -NoNewLine
			$do = . $tp -t $Device -c ledoff -q
			$CurrentState = tp-GetLedState $Device
			if ($CurrentState -eq 'Off'){write-host " [ok]" -ForegroundColor DarkGreen}else{write-host " [failed]" -ForegroundColor Cyan}
		}
	}
}
Function tp-GetUsage($Device){
	if (! $Device){$Device = tp-GetAllDevices}
	$Results = @()
	$tp = tp-GetPython
	if (! $tp){return "Unable to locate python script."}
	foreach ($d in $Device){
		. $tp -t $d -c energy -q | ConvertFrom-Json | Select -ExpandProperty emeter | Select -ExpandProperty get_realtime | Select @{l='Device';e={$d}},power,current,voltage,@{l='Date';e={"$(Get-Date)"}}
	}
	return $Results
}
Function tp-GetMonthlyHistory($Device){
	if (! $Device){return "`nSyntax error, requires -Device`n"}
	$tp = tp-GetPython
	if (! $tp){return "Unable to locate python script."}
	foreach ($Year in ((-2..0) | %{Get-Date -Format yyyy (Get-Date).AddYears($_)})){
		. $tp -t $Device -j "{\`"emeter\`":{\`"get_monthstat\`":{\`"year\`":$Year}}}" -q | ConvertFrom-Json | Select -ExpandProperty emeter | Select -ExpandProperty get_monthstat | Select -ExpandProperty month_list | Select -Property @{l='Device';e={$Device}},@{l='Date';e={get-date "$($_.month)/$($_.year)" -Format MM/yyyy}},@{l='Usage';e={[math]::round(($_.energy),3)}}
	}
}
Function tp-GetDailyHistory($Device){
	if (! $Device){return "`nSyntax error, requires -Device`n"}
	$tp = tp-GetPython
	if (! $tp){return "Unable to locate python script."}
	foreach ($Year in ((-2..0) | %{Get-Date -Format yyyy (Get-Date).AddYears($_)})){
		foreach ($Month in (1..12)){
			. $tp -t $Device -j "{\`"emeter\`":{\`"get_daystat\`":{\`"month\`":$Month,\`"year\`":$Year}}}" -q | ConvertFrom-Json | Select -ExpandProperty emeter | Select -ExpandProperty get_daystat | Select -ExpandProperty day_list | Select -Property @{l='Device';e={$Device}},@{l='Date';e={get-date "$($_.month)/$($_.day)/$($_.year)" -Format MM/dd/yyyy}},@{l='Usage';e={[math]::round(($_.energy),3)}}
		}
	}
}
Function tp-GetLastMonthUsage($Device){
	if (! $Device){return "`nSyntax error, requires -Device`n"}
	$tp = tp-GetPython
	if (! $tp){return "Unable to locate python script."}
	$Year = Get-Date ((Get-Date).AddMonths(-1)) -Format yyyy
	$Month = [int](Get-Date ((Get-Date).AddMonths(-1)) -Format MM)	
	. $tp -t $Device -j "{\`"emeter\`":{\`"get_monthstat\`":{\`"year\`":$Year}}}" -q | ConvertFrom-Json | Select -ExpandProperty emeter | Select -ExpandProperty get_monthstat | Select -ExpandProperty month_list | Where {$_.month -eq $Month} | Select -Property @{l='Device';e={$Device}},@{l='Date';e={get-date "$($_.month)/$($_.year)" -Format MM/yyyy}},@{l='Usage';e={[math]::round(($_.energy),3)}}
}
Function tp-GetYesterdayUsage($Device){
	if (! $Device){return "`nSyntax error, requires -Device`n"}
	$tp = tp-GetPython
	if (! $tp){return "Unable to locate python script."}
	$Year = Get-Date ((Get-Date).AddDays(-1)) -Format yyyy
	$Month = [int](Get-Date ((Get-Date).AddDays(-1)) -Format MM)
	$Day = [int](Get-Date ((Get-Date).AddDays(-1)) -Format dd)
	. $tp -t $Device -j "{\`"emeter\`":{\`"get_daystat\`":{\`"month\`":$Month,\`"year\`":$Year}}}" -q | ConvertFrom-Json | Select -ExpandProperty emeter | Select -ExpandProperty get_daystat | Select -ExpandProperty day_list | Where {$_.year -eq $Year -And $_.Month -eq $Month -And $_.Day -eq $Day} | Select -Property @{l='Device';e={$Device}},@{l='Date';e={get-date "$($_.month)/$($_.day)/$($_.year)" -Format MM/dd/yyyy}},@{l='Usage';e={[math]::round(($_.energy),3)}}
}
