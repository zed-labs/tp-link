# tp-link
Powershell module to manage tp-link smart plugs.

Python required.
Python code credit to:  https://github.com/softScheck/tplink-smartplug/blob/master/tplink_smartplug.py

Edit tp-GetAllDevices to reflect the IP or DNS names of your devices on the network.

## Get device info ##
tp-GetInfo -Device Light1

## Get info, all devices ##
tp-GetInfo

## Get current power state of all devices ##
tp-GetPowerState

## Turn on a device ##
tp-SetPowerState -Device Light1 -State On

## Turn off a device ##
tp-SetPowerState -Device Light1 -State Off

## Get monthly power usage ##
tp-GetMonthlyHistory -Device Light1

## Get daily power usage ##
tp-GetDailyHistory -Device Light1

## Kasa examples ##
Connect to Kasa...

tp-KasaConnect -Credential (Get-Credential)

Get Kasa registered devices

tp-GetKasaDevice

