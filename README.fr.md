# Reset-ScheduledTaskResult

> Script PowerShell qui réinitialise le dernier résultat d'exécution de tâches planifiées Windows en conservant leur définition et leurs ACL.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-informational.svg)](CHANGELOG.md)

[English version](README.md)

---

## Présentation

`LastTaskResult` et `LastRunTime` sont des propriétés en lecture seule gérées par le service Planificateur de tâches. Aucune cmdlet ne permet de les modifier. Ce script applique le seul contournement supporté : exporter la tâche, la supprimer puis la recréer, ce qui la remet à l'état « jamais exécutée » (`LastTaskResult` = `267011` / `0x41303`).

Il sauvegarde la définition XML et la DACL avant toute modification, restaure les ACL ensuite, gère les tâches exécutées sous un compte avec mot de passe stocké et revient automatiquement en arrière si la recréation échoue.

---

## Fonctionnalités

- Traitement d'une ou plusieurs tâches en une seule exécution, en local ou sur un ordinateur distant
- Sauvegarde du XML et du SDDL de la tâche avant toute modification
- Restauration de la DACL après recréation, avec vérification
- Détection des tâches avec mot de passe stocké, une seule saisie par compte
- Validation de l'enregistrement sous un nom temporaire avant la suppression de la tâche d'origine
- Retour arrière automatique en cas d'échec de la recréation
- Prise en charge de `-WhatIf` et `-Confirm`
- Un objet résultat par tâche (résultat avant/après, état des ACL, chemin de sauvegarde)

---

## Prérequis

| Dépendance | Version |
|------------|---------|
| Windows PowerShell | >= 5.1 |
| Module ScheduledTasks | Inclus dans Windows |
| Privilèges | Administrateur local (session élevée) sur la cible |

Pour une cible distante : WinRM (CIM) et les règles pare-feu « Gestion à distance des tâches planifiées » (DCOM/RPC) doivent être accessibles.

---

## Installation

```powershell
git clone https://github.com/9LivesITSolutions/Reset-ScheduledTaskResult.git
cd Reset-ScheduledTaskResult
```

Aucune dépendance à installer. Si besoin, débloquer le script :

```powershell
Unblock-File .\Reset-ScheduledTaskResult.ps1
```

---

## Utilisation

```powershell
# Simulation (rien n'est modifié)
.\Reset-ScheduledTaskResult.ps1 -TaskName 'MaTache' -WhatIf

# Exécution réelle (confirmation demandée)
.\Reset-ScheduledTaskResult.ps1 -TaskName 'MaTache'

# Plusieurs tâches sur un serveur distant
.\Reset-ScheduledTaskResult.ps1 -TaskName 'Tache1','Tache2' -ComputerName SRV01

# Tâche dans un sous-dossier
.\Reset-ScheduledTaskResult.ps1 -TaskName 'MaTache' -TaskPath '\MonDossier\'
```

Exemple de sortie :

```
Computer     : SRV01
TaskName     : MaTache
ResultBefore : 2147942402
ResultAfter  : 267011
AclRestored  : True
PasswordUsed : False
Backup       : C:\Users\admin\AppData\Local\Temp\TaskBackup\MaTache_20261006_101500
```

Une invite `Get-Credential` apparaît uniquement pour les tâches qui nécessitent un mot de passe stocké, une fois par compte. Rien n'est écrit sur le disque.

Après la réinitialisation d'une tâche avec mot de passe stocké, lancez-la une fois et vérifiez le résultat pour confirmer que le mot de passe est valide :

```powershell
Start-ScheduledTask -TaskName 'MaTache'
(Get-ScheduledTaskInfo -TaskName 'MaTache').LastTaskResult
```

---

## Paramètres

| Paramètre | Défaut | Description |
|-----------|--------|-------------|
| `-TaskName` | (obligatoire) | Un ou plusieurs noms de tâche, sans chemin |
| `-TaskPath` | `\` | Chemin du dossier de la tâche |
| `-ComputerName` | Ordinateur local | Ordinateur cible |
| `-BackupFolder` | `%TEMP%\TaskBackup` | Destination des sauvegardes `.xml` et `.sddl` |

---

## Ce qui est conservé ou perdu

| Conservé | Perdu ou modifié |
|----------|------------------|
| Déclencheurs, actions, conditions, paramètres | `LastRunTime`, `LastTaskResult`, `NumberOfMissedRuns` (effet recherché) |
| Compte d'exécution et niveau d'exécution | GUID interne de la tâche |
| État activé/désactivé, description | Dates de création du fichier de tâche et de la clé de registre |
| DACL (restaurée depuis le SDDL) | Propriétaire du descripteur de sécurité (devient le compte qui lance le script) |
| | Les SACL (règles d'audit) ne sont pas gérées |
| | Une instance en cours est arrêtée à la suppression de la tâche |

### Limites

- Le mot de passe stocké n'est jamais exporté dans le XML : il doit être fourni pour les tâches qui en ont un.
- La validation de l'enregistrement ne prouve pas que le mot de passe est correct ; l'erreur peut n'apparaître qu'à la première exécution.
- Les tâches déployées par les préférences de stratégie de groupe peuvent être réécrites au prochain rafraîchissement, la réinitialisation n'est alors pas durable.
- Le journal `Microsoft-Windows-TaskScheduler/Operational` est désactivé par défaut ; sans lui, le dernier résultat est la seule trace d'exécution.

---

## Structure du projet

```
Reset-ScheduledTaskResult/
├── Reset-ScheduledTaskResult.ps1   # Script principal
├── README.md                       # Documentation (EN)
├── README.fr.md                    # Documentation (FR)
└── CHANGELOG.md                    # Historique des versions
```

---

## Contribuer

1. Forker le dépôt
2. Créer une branche (`git checkout -b feature/ma-fonctionnalite`)
3. Valider les modifications (`git commit -m 'feat: add ma-fonctionnalite'`)
4. Pousser la branche (`git push origin feature/ma-fonctionnalite`)
5. Ouvrir une Pull Request

Merci de suivre les [Conventional Commits](https://www.conventionalcommits.org/) pour les messages de commit.

---

## Licence

Ce projet est distribué sous licence MIT. Voir le fichier [LICENSE](LICENSE).

---

Maintenu par **9 Lives IT Solutions** — Informatique de santé & automatisation d'infrastructure.
