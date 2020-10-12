<#
    .SYNOPSIS
    This script will detect the zabbixid of each Windows host and defines it as a grain named "zabbixid" for SaltStack.

    .DESCRIPTION
    Author: Amir Saleh Alavi (sms_alavinekoo@yahoo.com)
    Version: 1.0 (Date: 12/10/2020)

    This script will detect the zabbixid of each Windows host (by searching for it in the zabbix config file), and defines it as a grain named "zabbixid" for SaltStack.

    .NOTES
    This script only works for Windows systems, which have Zabbix agent and salt-minion agent installed on them, and the purpose of this script is to integrate them together.
    This script requires Administrative rights
    
#>

#Requires -Version 4.0
#Requires -PSEdition Desktop
#Requires -RunAsAdministrator

# Set Error Action Prefrence
$ErrorActionPreference="Stop"

# Define Zabbix and Salt-Minion config files and ZabbixID
# In order to detect the location of Zabbix config file, we detect it by looking into the zabbix agent service and the path defined for it.
$zabbixPath=Get-WmiObject win32_service | Where-Object {$_.Name -eq "zabbix agent"} | Select-Object PathName
if ($NULL -eq $zabbixPath)
{
    Write-Host $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S") - "Zabbix is not installed or there is a problem with finding the parmeters related to it."
    Write-Host $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S") - "Exiting Script."
    Exit 1
}
$zabbixConf=$zabbixPath.pathname.split('"')[3]
$zabbixID=(Select-String -Path $zabbixConf -Pattern '^Hostname=').Line -replace ('Hostname=','')
$saltPath=(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\App Paths\salt-minion.exe').Path
$grainsConf=$saltPath -replace 'bin\\','conf\grains'

# Test to see if grains file exist
if (!(Test-Path -Path $grainsConf))
{
    New-Item $grainsConf -Force | Out-Null
}

# Find the important lines in the salt grains config files which is the lines which start with "zabbixid:"
$zabbixIDLine=(Select-String -Path $grainsConf -Pattern '^zabbixid:').Line

# see if there is more than one line for minion grains defining zabbixid
$i=0; foreach ($zabbixLine in $zabbixIDLine) {$i++}
if ($i -gt 1)
{
    Write-Host $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S") - "There are more than one line for zabbixid grain in the salt grains config file."
    Write-Host $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S") - "Exiting script."
    Exit 2
}

# Apply required changes to the salt-minion config file
if ($zabbixIDLine -eq "zabbixid: $zabbixID")
{
    Write-Host $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S") - "There is no need to change anything in the salt-minion config file."
}
elseif ($null -eq $zabbixIDLine)
{
    Add-Content -Path $grainsconf -Value "zabbixid: $zabbixID" -Verbose
    Write-Host $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S") - "Grain configs added."
}
elseif ($zabbixIDLine -ne "zabbixid: $zabbixID") {
    (Get-Content $grainsConf).Replace($zabbixIDLine,"zabbixid: $zabbixID") | Set-Content $grainsConf -Verbose
    Write-Host $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S") - "salt-grains config file updated."
}