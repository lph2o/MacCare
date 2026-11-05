# 01 — Fondations Système macOS & Spécification d'Architecture

> **Projet** : **MacCare** — Application native open-source de maintenance, d'analyse de stockage APFS et de sécurité pour macOS  
> **Cible** : macOS 14.0+ (Sonoma / Sequoia) • Binaire universel (`x86_64` & `arm64`)

---

## 1. Principes d'Ingénierie Système macOS

MacCare s'appuie exclusivement sur les interfaces publiques et documentées du système d'exploitation d'Apple :

1. **Système de fichiers APFS (`statfs` & `URLResourceKey`)** :
   - Lecture instantanée de la capacité totale, libre et purgeable via l'appel noyau `statfs("/")`.
   - Calcul de la taille physique réellement allouée sur disque (`totalFileAllocatedSizeKey`) pour éviter de surestimer les fichiers creux (*sparse files*) ou non téléchargés depuis iCloud (`ubiquitousItemDownloadingStatusKey`).
2. **Télémétrie Noyau Mach (`MachMetricsService`)** :
   - Collecte directe des compteurs processeur (`host_processor_info` avec `PROCESSOR_CPU_LOAD_INFO`) et de la mémoire virtuelle (`host_statistics64` avec `HOST_VM_INFO64`), suivie de la désallocation systématique des tampons Mach (`vm_deallocate`).
   - Inspection de l'empreinte mémoire et processeur des processus actifs via `proc_pid_rusage`.
3. **Sécurité & Vérification Cryptographique (`Security.framework`)** :
   - Contrôle de l'état de **System Integrity Protection (SIP)**, **Gatekeeper**, **FileVault** et **XProtect**.
   - Vérification native des signatures de code des exécutables et agents de lancement via `SecStaticCodeCreateWithPath` et `SecStaticCodeCheckValidity`.
   - Lecture des attributs étendus POSIX de quarantaine (`com.apple.quarantine`) via `getxattr`.
4. **Exécution Sans Démon Root Permanent** :
   - Fonctionnement intégral dans l'espace utilisateur avec respect strict des autorisations **TCC** (*Full Disk Access* et `NSOpenPanel`).
   - Traçabilité complète et restauration en un clic grâce à une base locale **SQLite3** en mode **WAL**.
