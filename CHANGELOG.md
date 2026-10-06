# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.0.0] - 2026-10-06

### Added
- Reset of `LastTaskResult` / `LastRunTime` by exporting, unregistering and re-registering scheduled tasks
- Batch processing of several tasks, local or remote (`-ComputerName`)
- Backup of the task XML and DACL (SDDL) to a configurable folder before any change
- DACL restoration after re-registration, with verification (`AclRestored`)
- Detection of tasks with a stored password and one `Get-Credential` prompt per account
- Dry registration under a temporary name before deleting the original task
- Automatic rollback from the exported XML if the re-registration fails
- `-WhatIf` / `-Confirm` support
- English and French documentation

---

<!-- Links -->
[Unreleased]: https://github.com/9lives/reset-scheduledtask-result/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/9lives/reset-scheduledtask-result/releases/tag/v1.0.0
