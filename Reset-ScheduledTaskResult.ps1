#Requires -Version 5.1
<#
.SYNOPSIS
    Resets the last run result (LastTaskResult / LastRunTime) of one or more scheduled tasks.

.DESCRIPTION
    LastTaskResult is read-only and managed by the Task Scheduler service. The only supported way
    to reset it is to export the task, delete it and register it again.

    For each task, the script:
      1. Exports the task definition (XML) and its DACL (SDDL) to a backup folder.
      2. Detects whether the task runs under an account with a stored password.
         If so, prompts once per account (Get-Credential) and validates the registration
         under a temporary name before touching the original task.
      3. Unregisters and re-registers the task from the exported XML.
      4. Restores the DACL.
      5. Attempts an automatic rollback from the backup if the re-registration fails.

    gMSA, SYSTEM, LOCAL SERVICE, NETWORK SERVICE, S4U and group principals need no password.

.PARAMETER TaskName
    One or more task names (exact names, without path).

.PARAMETER TaskPath
    Task folder path. Default: '\'

.PARAMETER ComputerName
    Target computer. Default: local computer. Remote access uses CIM (WinRM) and the
    Schedule.Service COM object (DCOM/RPC).

.PARAMETER BackupFolder
    Folder where XML and SDDL backups are written. Default: %TEMP%\TaskBackup

.EXAMPLE
    .\Reset-ScheduledTaskResult.ps1 -TaskName 'MyTask' -WhatIf

.EXAMPLE
    .\Reset-ScheduledTaskResult.ps1 -TaskName 'Task1','Task2' -ComputerName SRV01

.NOTES
    Run from an elevated PowerShell session.
    The reset is not durable for tasks deployed by Group Policy Preferences.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory, Position = 0)]
    [string[]]$TaskName,

    [string]$TaskPath = '\',

    [string]$ComputerName = $env:COMPUTERNAME,

    [string]$BackupFolder = (Join-Path $env:TEMP 'TaskBackup')
)

$ErrorActionPreference = 'Stop'

$isRemote   = $ComputerName -ne $env:COMPUTERNAME
$folderPath = if ($TaskPath -eq '\') { '\' } else { $TaskPath.TrimEnd('\') }
$credCache  = @{}   # one credential prompt per account
$null       = New-Item -ItemType Directory -Path $BackupFolder -Force

$cim = if ($isRemote) { New-CimSession -ComputerName $ComputerName } else { $null }
$svc = New-Object -ComObject Schedule.Service
$svc.Connect($ComputerName)

function Get-TaskSddl {
    param([string]$Name)
    # 4 = DACL_SECURITY_INFORMATION (SACL requires SeSecurityPrivilege)
    $svc.GetFolder($folderPath).GetTask($Name).GetSecurityDescriptor(4)
}

try {
    foreach ($name in $TaskName) {
        $common = @{ TaskName = $name; TaskPath = $TaskPath }
        if ($cim) { $common.CimSession = $cim }

        $unregistered = $false
        $xml          = $null
        $regArgs      = @{}

        try {
            $task      = Get-ScheduledTask @common
            $principal = $task.Principal
            $before    = Get-ScheduledTaskInfo @common
            $xml       = Export-ScheduledTask @common
            $sddl      = Get-TaskSddl -Name $name

            # Backup before any change
            $stamp = '{0}_{1:yyyyMMdd_HHmmss}' -f $name, (Get-Date)
            $xml  | Set-Content -Path (Join-Path $BackupFolder "$stamp.xml")  -Encoding Unicode
            $sddl | Set-Content -Path (Join-Path $BackupFolder "$stamp.sddl") -Encoding UTF8

            # Is a stored password required?
            $needsPwd = ($principal.LogonType -in 'Password', 'InteractiveOrPassword') -and
                        ($principal.UserId -notmatch '\$$')

            if ($needsPwd) {
                $user = $principal.UserId
                if (-not $credCache.ContainsKey($user)) {
                    $credCache[$user] = Get-Credential -UserName $user -Message "Password for task '$name'"
                }
                $cred = $credCache[$user]
                if ($cred.UserName -ne $user) {
                    throw "Entered account '$($cred.UserName)' differs from the task account '$user'."
                }
                $regArgs = @{ User = $cred.UserName; Password = $cred.GetNetworkCredential().Password }
            }

            $action = "Unregister and re-register (current result: $($before.LastTaskResult))"
            if (-not $PSCmdlet.ShouldProcess("$ComputerName $TaskPath$name", $action)) { continue }

            # Dry registration under a temporary name (tasks with a stored password)
            if ($needsPwd) {
                $tmp = @{ TaskName = "${name}_tmpcheck"; TaskPath = $TaskPath }
                if ($cim) { $tmp.CimSession = $cim }
                Register-ScheduledTask @tmp -Xml $xml @regArgs | Out-Null
                Unregister-ScheduledTask @tmp -Confirm:$false
            }

            Unregister-ScheduledTask @common -Confirm:$false
            $unregistered = $true
            Register-ScheduledTask @common -Xml $xml @regArgs | Out-Null
            $unregistered = $false

            # Restore the DACL
            $svc.GetFolder($folderPath).GetTask($name).SetSecurityDescriptor($sddl, 0)

            $after = Get-ScheduledTaskInfo @common
            [pscustomobject]@{
                Computer     = $ComputerName
                TaskName     = $name
                ResultBefore = $before.LastTaskResult
                ResultAfter  = $after.LastTaskResult
                AclRestored  = ((Get-TaskSddl -Name $name) -eq $sddl)
                PasswordUsed = $needsPwd
                Backup       = Join-Path $BackupFolder $stamp
            }
        }
        catch {
            $msg = $_.Exception.Message

            # Automatic rollback if the task was deleted but not re-registered
            if ($unregistered -and $xml) {
                try {
                    Register-ScheduledTask @common -Xml $xml @regArgs | Out-Null
                    $svc.GetFolder($folderPath).GetTask($name).SetSecurityDescriptor($sddl, 0)
                    $msg += ' | Rollback OK: original task restored.'
                }
                catch {
                    $msg += " | Rollback FAILED: restore manually from $BackupFolder."
                }
            }
            Write-Error "[$name] $msg"
        }
    }
}
finally {
    if ($cim) { $cim | Remove-CimSession }
}
