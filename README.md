# reset-scheduledtask-result

> PowerShell script that resets the last run result of Windows scheduled tasks while preserving their definition and ACLs.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-informational.svg)](CHANGELOG.md)

🇫🇷 [Version française](README.fr.md)

---

## Overview

`LastTaskResult` and `LastRunTime` are read-only properties managed by the Task Scheduler service. No cmdlet can reset them. This script performs the only supported workaround: export the task, delete it, and register it again, so the task returns to its "never run" state (`LastTaskResult` = `267011` / `0x41303`).

It backs up the XML definition and the DACL before any change, restores the ACLs afterwards, handles tasks that run under an account with a stored password, and rolls back automatically if the re-registration fails.

---

## Features

- Processes one or several tasks in a single run, locally or on a remote computer
- Backs up the task XML and its SDDL before any modification
- Restores the task DACL after re-registration and verifies it
- Detects tasks with a stored password and prompts once per account
- Validates the registration under a temporary name before deleting the original task
- Automatic rollback if the re-registration fails
- Supports `-WhatIf` and `-Confirm`
- Returns one result object per task (before/after result, ACL status, backup path)

---

## Requirements

| Dependency | Version |
|------------|---------|
| Windows PowerShell | >= 5.1 |
| ScheduledTasks module | Included with Windows |
| Privileges | Local administrator (elevated session) on the target |

For remote targets: WinRM (CIM) and the "Remote Scheduled Tasks Management" firewall rules (DCOM/RPC) must be reachable.

---

## Installation

```powershell
git clone https://github.com/9lives/reset-scheduledtask-result.git
cd reset-scheduledtask-result
```

No dependency to install. If needed, unblock the script:

```powershell
Unblock-File .\Reset-ScheduledTaskResult.ps1
```

---

## Usage

```powershell
# Simulation (nothing is changed)
.\Reset-ScheduledTaskResult.ps1 -TaskName 'MyTask' -WhatIf

# Real run (confirmation requested)
.\Reset-ScheduledTaskResult.ps1 -TaskName 'MyTask'

# Several tasks on a remote server
.\Reset-ScheduledTaskResult.ps1 -TaskName 'Task1','Task2' -ComputerName SRV01

# Task in a sub-folder
.\Reset-ScheduledTaskResult.ps1 -TaskName 'MyTask' -TaskPath '\MyFolder\'
```

Example output:

```
Computer     : SRV01
TaskName     : MyTask
ResultBefore : 2147942402
ResultAfter  : 267011
AclRestored  : True
PasswordUsed : False
Backup       : C:\Users\admin\AppData\Local\Temp\TaskBackup\MyTask_20261006_101500
```

A `Get-Credential` prompt appears only for tasks that need a stored password, once per account. Nothing is written to disk.

After resetting a task that uses a stored password, run it once and check the result to confirm the password is valid:

```powershell
Start-ScheduledTask -TaskName 'MyTask'
(Get-ScheduledTaskInfo -TaskName 'MyTask').LastTaskResult
```

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-TaskName` | (required) | One or more task names, without path |
| `-TaskPath` | `\` | Task folder path |
| `-ComputerName` | Local computer | Target computer |
| `-BackupFolder` | `%TEMP%\TaskBackup` | Destination of the `.xml` and `.sddl` backups |

---

## What is preserved or lost

| Preserved | Lost or changed |
|-----------|-----------------|
| Triggers, actions, conditions, settings | `LastRunTime`, `LastTaskResult`, `NumberOfMissedRuns` (intended) |
| Run-as account and run level | Internal task GUID |
| Enabled/disabled state, description | Creation dates of the task file and registry key |
| DACL (restored from SDDL) | Owner of the security descriptor (becomes the account running the script) |
| | SACL (audit rules) are not handled |
| | A running instance is stopped when the task is deleted |

### Limitations

- The stored password is never exported in the XML. It must be supplied for tasks with a stored password.
- Registration validation does not prove the password is correct; the error may only appear at the first run.
- Tasks deployed by Group Policy Preferences may be rewritten at the next policy refresh, so the reset is not durable.
- The `Microsoft-Windows-TaskScheduler/Operational` event log is disabled by default; without it, the last result is the only execution trace.

---

## Project Structure

```
reset-scheduledtask-result/
├── Reset-ScheduledTaskResult.ps1   # Main script
├── README.md                       # Documentation (EN)
├── README.fr.md                    # Documentation (FR)
└── CHANGELOG.md                    # Version history
```

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'feat: add my-feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

Please follow [Conventional Commits](https://www.conventionalcommits.org/) for commit messages.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
