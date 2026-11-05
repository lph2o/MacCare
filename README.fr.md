<div align="center">

<img src="Sources/Resources/AppIcon-Preview.png" alt="MacCare Logo" width="160" height="160" />

# MacCare

**Application native macOS open-source de maintenance, d'analyse de stockage APFS, de télémétrie noyau Mach et de sécurité.**  
*Conçue en Swift, SwiftUI, AppKit, Swift Charts, SQLite3 et CryptoKit — Binaire universel (`x86_64` & `arm64`) pour macOS 14+ (Sonoma / Sequoia).*

**🌐 Lire dans votre langue :**  
[**🇬🇧 English**](./README.md) • [**🇫🇷 Français**](./README.fr.md) • [**🇪🇸 Español**](./README.es.md) • [**🇩🇪 Deutsch**](./README.de.md) • [**🇯🇵 日本語**](./README.ja.md) • [**🇨🇳 简体中文**](./README.zh-CN.md)

<br/>

[![Télécharger MacCare.dmg](https://img.shields.io/badge/⬇%20TÉLÉCHARGER%20POUR%20MAC-MacCare--Universal.dmg-00C9A7?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/lph2o/MacCare/releases/latest/download/MacCare-Universal.dmg)
[![Télécharger MacCare.zip](https://img.shields.io/badge/⬇%20TÉLÉCHARGER%20(.ZIP)-MacCare--Universal.zip-845EC2?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/lph2o/MacCare/releases/latest/download/MacCare-Universal.zip)

</div>

---

## Téléchargement & Installation Rapide (Sans aucune compétence technique)

Vous n'avez **pas besoin** d'utiliser le Terminal ni `git clone` pour installer **MacCare** sur votre Mac :

1. **Téléchargez l'installateur** en 1 clic :
   - [**Télécharger `MacCare-Universal.dmg` (Recommandé — Image disque macOS)**](https://github.com/lph2o/MacCare/releases/latest/download/MacCare-Universal.dmg)
   - [**Télécharger `MacCare-Universal.zip` (Archive directe `.app`)**](https://github.com/lph2o/MacCare/releases/latest/download/MacCare-Universal.zip)
2. **Glisser-déposer** : Double-cliquez sur `MacCare-Universal.dmg` et glissez l'icône **MacCare** dans le dossier **Applications**.
3. **Lancez MacCare** depuis votre dossier **Applications**. Vous pouvez changer la langue de l'interface à tout moment (**🇬🇧 EN, 🇫🇷 FR, 🇪🇸 ES, 🇩🇪 DE, 🇯🇵 JA, 🇨🇳 ZH**) depuis le bouton globe en haut à droite !
   > *Astuce premier lancement (macOS Gatekeeper)* : Si macOS affiche un message lors de la première ouverture, faites **Clic droit (ou Ctrl + Clic) sur MacCare → Ouvrir**, puis cliquez sur **Ouvrir**.

---

## Les 9 Modules Fonctionnels

| # | Module | Raccourci | Fonctionnalités Clés |
| :-: | :--- | :-: | :--- |
| **01** | **Smart Care** | `⌘1` | Bilan de santé sur 100, anneau lumineux d'état, grille Bento à 4 piliers (Nettoyage, Protection, Performances, Stockage) et recommandations priorisées. |
| **02** | **System Junk** | `⌘2` | Analyse maître-détail des caches utilisateur, journaux, artefacts Xcode (`DerivedData`), caches de gestionnaires de paquets et restauration SQLite en un clic. |
| **03** | **Storage Analyzer** | `⌘3` | Exploration visuelle **Space Lens** asynchrone (`ScanEngine`), calcul de l'allocation physique APFS et détection des fichiers volumineux et oubliés. |
| **04** | **App Manager** | `⌘4` | Inventaire des applications (`/Applications` & `~/Applications`), corrélation des fichiers associés dans `~/Library` et détection des résidus orphelins (*Leftovers*). |
| **05** | **Duplicate Finder** | `⌘5` | Détection zéro faux-positif en **3 passes** : regroupement par taille → empreinte partielle `SHA-256` (`64 Ko`) → `SHA-256` intégral (`CryptoKit`). |
| **06** | **Performance** | `⌘6` | Télémétrie temps réel du noyau **Mach** (`host_processor_info`, `host_statistics64`, `proc_pid_rusage`) et graphiques `Swift Charts`. |
| **07** | **Startup Manager** | `⌘7` | Audit des `LaunchAgents`, détection des plists corrompus et désactivation/restauration réversible sauvegardée dans SQLite. |
| **08** | **Maintenance** | `⌘8` | Exécution transparente et journalisée des tâches système macOS (cache DNS, QuickLook, vérification SMART/APFS). |
| **09** | **Protection** | `⌘9` | Vérification de la posture de sécurité (SIP, Gatekeeper, FileVault, XProtect), contrôle `SecStaticCode` et attributs POSIX de quarantaine (`getxattr`). |

---

## Licence

Distribué sous licence **MIT**. Consultez [`LICENSE`](./LICENSE).

