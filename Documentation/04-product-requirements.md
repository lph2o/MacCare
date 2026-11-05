# 04 — Cahier des Charges Fonctionnel de MacCare (*Product Requirements Document*)

> **Projet** : MacCare — Application native de maintenance et de gestion macOS  
> **Mission** : Mission 01 — Phase D (Spécifications fonctionnelles)  
> **Cible système** : macOS 14.0 (Sonoma) et versions ultérieures — Universel Intel (`x86_64`) & Apple Silicon (`arm64`).  
> **Principe directeur** : *MacCare explique toujours ce qu'il va faire, pourquoi un fichier est ciblé et quel est l'impact exact avant toute opération sur le système.*

---

## 1. Classification de Sécurité Obligatoire des Éléments Détectés

Chaque élément identifié par les moteurs d'analyse de MacCare doit obligatoirement recevoir l'un des trois niveaux de classification suivants :

| Niveau | Code interne | Sélectionnable par défaut ? | Définition et comportement dans MacCare |
| :--- | :--- | :---: | :--- |
| **1. Nettoyage sûr** | `.safe` | **Oui** (pré-coché en révision) | Fichiers temporaires, caches d'applications standards ou journaux anciens dont la recréation automatique par macOS ou l'application est documentée et sans perte de données. |
| **2. Nettoyage conditionnel** | `.conditional` | **Non** (décoché par défaut) | Éléments volumineux mais potentiellement utiles (ex. `DerivedData` Xcode, caches de paquets Homebrew/npm, téléchargements anciens, sauvegardes locales, conteneurs Docker). Requiert une coche manuelle explicite et affiche un avertissement contextuel. |
| **3. Élément protégé** | `.protected` | **Verrouillé** (case désactivée) | Fichiers système macOS (SIP), bases de données critiques (`TCC.db`, `Keychain`, bases SQLite de messagerie/photos), documents utilisateur actifs ou fichiers à rôle incertain. Affiché à titre informatif dans l'analyseur de stockage avec un cadenas et une explication. |

---

## 2. Matrice Globale des Fonctionnalités de MacCare (9 Modules)

| ID | Module & Sous-fonctionnalité | Valeur Utilisateur | Complexité | Dépendances Techniques | Permissions Requises | Risques Identifiés | Priorité |
| :-: | :--- | :--- | :---: | :--- | :--- | :--- | :-: |
| **M01** | **01 — Smart Care** (Diagnostic global, synthèse stockage, lancement groupé) | Vue à 360° de l'état du Mac en moins de 15 secondes | Moyenne | `ScanEngine`, `AnalysisEngine`, `SafetyEngine`, `Swift Charts` | Droits utilisateur standard (FDA optionnel pour scan étendu) | Temps de scan trop long si mal parallélisé | **P0 (MVP)** |
| **M02** | **02 — System Junk** (Caches utilisateur, logs, fichiers temp, Xcode/Dev, Corbeille) | Récupération rapide de plusieurs Go sans risque pour les données personnelles | Moyenne | `FileManager`, `SafetyEngine` (règles blanches/noires), `NSWorkspace.recycle` | Droits utilisateur + FDA optionnel (pour conteneurs protégés) | Suppression d'un cache d'app en cours d'exécution -> vérifier `NSRunningApplication` | **P0 (MVP)** |
| **M03** | **03 — Storage Analyzer** (Cartographie visuelle des dossiers, fichiers volumineux & anciens) | Comprendre visuellement où part l'espace disque et cibler les gros fichiers | Élevée | `FileManager.enumerator` asynchrone, `URLResourceValues` (`totalFileAllocatedSizeKey`), `Swift Charts` | Accès dossier sélectionné (`NSOpenPanel`) ou FDA pour disque entier | Boucles infinies sur liens symboliques ou points de montage `/System/Volumes/Data` (firmlinks APFS) | **P0 (MVP)** |
| **M04** | **04 — App Manager** (Inventaire apps, désinstallation propre, détection des restes orphelins) | Désinstaller une app avec tous ses fichiers `~/Library` ou nettoyer les restes d'anciennes apps | Élevée | `Bundle`, `MDItem` / Spotlight, moteur de corrélation `CFBundleIdentifier`, `NSWorkspace` | Droits utilisateur (pour `~/Library`) ; authentification macOS si app protégée dans `/Applications` | Faux positifs sur un préfixe de bundle partagé (ex. suite Microsoft/Adobe) -> règles d'exclusion strictes | **P1** |
| **M05** | **05 — Duplicate Finder** (Doublons exacts par taille + empreinte SHA-256 progressive) | Éliminer les copies redondantes de fichiers volumineux en gardant toujours au moins un original | Élevée | Pipeline 3 passes (Taille -> Hash partiel 64 Ko -> `CryptoKit.SHA256` complet), `QLPreviewPanel` | Accès aux dossiers choisis par l'utilisateur (`~` ou sous-dossiers) | Suppression accidentelle de toutes les copies -> garde-fou interdisant de cocher 100 % d'un groupe | **P1** |
| **M06** | **06 — Performance** (Moniteur CPU, pression mémoire, disque, réseau et processus actifs) | Identifier objectivement quel processus ralentit le Mac (sans fausse promesse de « magie RAM ») | Moyenne | `host_processor_info`, `host_statistics64`, `proc_pidinfo`, `NSRunningApplication`, `IOKit` | Droits utilisateur standard (aucun privilège root requis) | Surconsommation CPU du moniteur lui-même -> rafraîchissement adaptatif (2s à 5s) | **P1** |
| **M07** | **07 — Startup Manager** (Éléments d'ouverture de session et `LaunchAgents` utilisateur/système) | Accélérer l'ouverture de session et désactiver les agents d'arrière-plan indésirables | Moyenne | Inspection `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons`, `plutil`/`PropertyListDecoder`, `launchctl` | Droits utilisateur pour `~/Library/LaunchAgents` ; lecture seule sur `/Library/LaunchDaemons` sans élévation | Désactivation d'un agent critique -> sauvegarder l'état initial et distinguer désactivation vs suppression | **P2** |
| **M08** | **08 — Maintenance** (Opérations documentées : cache DNS, vérification APFS/SMART, Spotlight, QuickLook) | Exécuter des actions de maintenance macOS réelles, transparentes et expliquées | Faible à Moyenne | `Process` (ex. `qlmanage -r cache`, `dscacheutil`, `diskutil info`), journal d'opérations SQLite | Droits utilisateur (ou invite `osascript`/auth explicite uniquement pour une commande système ponctuelle) | Blocage de l'interface si une commande CLI tarde -> timeout strict et annulation | **P2** |
| **M09** | **09 — Protection** (Contrôle `codesign`, attributs de quarantaine `com.apple.quarantine`, audit LaunchAgents suspects et statut sécurité macOS) | Vérifier l'intégrité des binaires et repérer les persistances non signées (sans se prétendre antivirus complet) | Moyenne | `Security.framework` (`SecStaticCodeCheckValidity`), `getxattr` (`com.apple.quarantine`), `csrutil status`, `spctl --status`, `fdesetup status` | Droits utilisateur standard + FDA optionnel | Générer de l'anxiété par de fausses alertes -> qualifier clairement « Non signé / À vérifier » vs « Menace » | **P2** |

---

## 3. Spécifications Détaillées et Critères d'Acceptation par Module

### 3.1. Module 01 — Smart Care (Tableau de bord & Diagnostic global)
- **Description** : Écran d'accueil de MacCare présentant l'état synthétique du Mac (jauge d'occupation du volume principal APFS, pression mémoire actuelle, nombre de jours depuis le dernier redémarrage, statut du dernier nettoyage) et permettant de lancer un **Diagnostic Global** non destructif.
- **Sous-fonctionnalités** :
  - `SC-01` : Résumé temps réel du disque principal (Utilisé, Disponible, Purgeable macOS).
  - `SC-02` : Lancement coordonné de l'analyse rapide (Caches sûrs, Corbeille, Restes d'applications, Éléments de démarrage, Indicateurs de sécurité).
  - `SC-03` : Cartes de recommandations interactives permettant d'ouvrir la prévisualisation détaillée de chaque catégorie avant toute action.
- **Critères d'acceptation** :
  - [ ] Le tableau de bord s'affiche en moins de `300 ms` au lancement de l'application.
  - [ ] Le diagnostic global s'exécute de manière asynchrone avec possibilité d'annulation immédiate (`Stop`) en moins de `200 ms`.
  - [ ] Aucun fichier n'est supprimé automatiquement à la fin du diagnostic : l'utilisateur doit obligatoirement passer par le panneau de prévisualisation et confirmer.

---

### 3.2. Module 02 — System Junk (Nettoyage des fichiers temporaires et caches)
- **Description** : Analyse et nettoyage ciblé des répertoires temporaires et caches documentés de l'espace utilisateur.
- **Catégories prises en charge** :
  1. **Caches d'applications utilisateur (`.safe`)** : Sous-dossiers de `~/Library/Caches/` correspondant à des applications identifiées et **fermées**, à l'exclusion des listes protégées (ex. `CloudKit`, `com.apple.Safari/TabSnapshots`, `PassKit`, `GeoServices`).
  2. **Journaux et rapports de plantage utilisateur (`.safe`)** : `~/Library/Logs/` et `~/Library/Logs/DiagnosticReports/` (fichiers `.ips` / `.crash` de plus de 7 jours).
  3. **Fichiers temporaires utilisateur (`.safe`)** : Fichiers obsolètes dans `NSTemporaryDirectory()` appartenant à l'utilisateur courant et non verrouillés.
  4. **Caches de développement (`.conditional` — décochés par défaut)** :
     - Xcode `DerivedData` (`~/Library/Developer/Xcode/DerivedData`), `iOS Device Logs`, archives anciennes.
     - Caches de gestionnaires de paquets (Homebrew `~/Library/Caches/Homebrew`, npm `~/.npm/_cacache`, CocoaPods, SwiftPM) avec indication claire que leur suppression entraînera un re-téléchargement lors du prochain build.
  5. **Corbeille utilisateur (`.conditional`)** : Contenu de `~/.Trash` avec affichage détaillé des fichiers présents avant vidage.
- **Critères d'acceptation** :
  - [ ] Si une application est en cours d'exécution (`NSWorkspace.shared.runningApplications`), son cache est signalé comme « Application active — ignoré par sécurité » ou propose de fermer l'application proprement avant nettoyage.
  - [ ] Chaque élément affiche son chemin complet, sa taille exacte sur disque (`totalFileAllocatedSizeKey`), sa date de dernière modification et son badge de sécurité (`.safe` ou `.conditional`).
  - [ ] Par défaut, la suppression déplace les éléments vers la Corbeille (`FileManager.trashItem`) ou, lorsqu'il s'agit du vidage explicite de la Corbeille ou d'une option confirmée, les supprime en journalisant chaque opération dans SQLite.

---

### 3.3. Module 03 — Storage Analyzer (Cartographie et fichiers volumineux)
- **Description** : Exploration visuelle et tabulaire de l'occupation du disque (dossier Utilisateur `~` par défaut, ou tout volume/dossier choisi par l'utilisateur).
- **Sous-fonctionnalités** :
  - `SA-01` : **Cartographie hiérarchique interactive** (vue arborescente + graphique proportionnel par dossier avec navigation ascendante/descendante par fil d'Ariane *Breadcrumb*).
  - `SA-02` : **Vue Fichiers Volumineux & Anciens (*Large & Old Files*)** : Liste filtrable par taille (`> 50 Mo`, `> 250 Mo`, `> 1 Go`), par ancienneté de dernier accès (`> 1 mois`, `> 6 mois`, `> 1 an`) et par type (`UniformTypeIdentifiers` : Vidéos, Archives, Images disque `.dmg`/`.iso`, Documents, Audio).
  - `SA-03` : Détection des firmlinks APFS et des fichiers *cloud-only* (fichiers iCloud Drive non téléchargés localement via `ubiquitousItemDownloadingStatusKey`) pour ne compter que l'espace **réellement alloué sur le disque local**.
- **Critères d'acceptation** :
  - [ ] Le scanner ne traverse jamais deux fois le même inode/volume (vérification de `volumeIdentifierKey` et exclusion de `/System/Volumes/Data` si `/` est scanné).
  - [ ] Les tailles affichées correspondent à l'allocation physique réelle sur APFS (`totalFileAllocatedSizeKey`) et non à la taille logique apparente des fichiers *sparse* ou *cloud-evicted*.
  - [ ] Aperçu Quick Look (`Espace`) et révélation dans le Finder (`⌘⇧R`) disponibles sur chaque fichier.

---

### 3.4. Module 04 — App Manager (Applications et résidus)
- **Description** : Inventaire des applications installées dans `/Applications` et `~/Applications`, analyse de leur empreinte totale et détection des fichiers associés ou orphelins.
- **Sous-fonctionnalités** :
  - `AM-01` : **Inventaire enrichi** : Icône, nom, version, identifiant de bundle (`CFBundleIdentifier`), architecture (`Universel`, `Apple Silicon`, `Intel`), origine (`App Store`, `Developer ID`, `Non signé`), date de dernière ouverture (`kMDItemLastUsedDate`), taille du `.app` + taille des fichiers associés.
  - `AM-02` : **Inspection des fichiers associés** : Découverte déterministe des ressources liées dans `~/Library/Application Support/`, `~/Library/Caches/`, `~/Library/Preferences/`, `~/Library/Containers/`, `~/Library/Group Containers/`, `~/Library/Saved Application State/`, `~/Library/WebKit/`, `~/Library/Logs/`.
  - `AM-03` : **Désinstallation avec mise à la corbeille** : Déplacement atomique de l'application et des fichiers associés sélectionnés vers la Corbeille (permettant une restauration immédiate via « Remettre » dans le Finder).
  - `AM-04` : **Détecteur de restes orphelins (*Leftovers*)** : Identification des dossiers `~/Library` dont l'identifiant de bundle ne correspond plus à aucune application installée sur le système (avec liste blanche des composants système d'Apple `com.apple.*`).
- **Critères d'acceptation** :
  - [ ] Les applications système d'Apple (`/System/Applications`) sont marquées `.protected` et ne peuvent jamais être sélectionnées pour la désinstallation.
  - [ ] Avant toute désinstallation, l'utilisateur visualise l'arbre exact des fichiers associés et peut décocher ceux qu'il souhaite conserver (ex. conserver ses préférences ou données utilisateur pour une réinstallation future).

---

### 3.5. Module 05 — Duplicate Finder (Détection de doublons)
- **Description** : Identification déterministe des fichiers strictement identiques dans un ou plusieurs dossiers sélectionnés.
- **Algorithme en 3 passes ( Zéro faux positif & haute performance )** :
  1. **Passe 1 (Taille & Inode)** : Regroupement rapide des fichiers réguliers (hors liens symboliques et même `fileResourceIdentifierKey`/hardlinks) ayant exactement la même taille en octets (`fileSize > 0`). Les tailles uniques sont éliminées immédiatement sans lecture disque.
  2. **Passe 2 (Pré-empreinte rapide — *Partial Hash*)** : Pour les fichiers de même taille (`> 128 Ko`), calcul de l'empreinte sur les premiers `32 Ko` et les derniers `32 Ko` du fichier.
  3. **Passe 3 (Empreinte cryptographique complète `SHA-256`)** : Calcul de l'empreinte `CryptoKit.SHA256` par flux de `1 Mo` uniquement sur les candidats ayant survécu aux passes 1 et 2.
- **Critères d'acceptation** :
  - [ ] Deux fichiers ne sont déclarés doublons que si leur taille **et** leur condensat `SHA-256` complet sont strictement identiques.
  - [ ] **Règle d'or de sécurité** : L'interface interdit de cocher simultanément toutes les copies d'un groupe de doublons sans afficher une alerte modale bloquante ; le bouton « Sélection intelligente » conserve toujours au moins l'exemplaire le plus ancien ou situé dans le dossier principal.
  - [ ] Les bundles macOS considérés comme des paquets (`.app`, `.photoslibrary`, `.xcodeproj`, `. logicx`) ne sont pas démembrés fichier par fichier par défaut afin de ne pas corrompre des paquets applicatifs.

---

### 3.6. Module 06 — Performance (Surveillance des ressources et processus)
- **Description** : Tableau de bord télémétrique honnête et précis de l'utilisation des ressources du Mac.
- **Sous-fonctionnalités** :
  - `PF-01` : **Processeur (CPU)** : Charge globale (% Utilisateur, % Système, % Inactif), historique glissant sur 60 secondes (`Swift Charts`), uptime du système.
  - `PF-02` : **Mémoire (RAM)** : Répartition exacte issue du noyau Mach (`host_statistics64` : *Mémoire de l'app / Active*, *Mémoire résidente / Wired*, *Mémoire compressée*, *Cache de fichiers*, *Swap utilisé*) et indicateur de **Pression mémoire** (`Normale`, `Modérée`, `Critique`). *Aucune fausse promesse d'optimisation magique de la RAM.*
  - `PF-03` : **Explorateur de processus actifs** : Liste des applications et processus utilisateur triable par % CPU ou mémoire réelle (`phys_footprint`), avec possibilité de quitter proprement (`terminate()`) ou forcer à quitter (`forceTerminate()`) une application utilisateur bloquée après confirmation.
- **Critères d'acceptation** :
  - [ ] La consommation CPU propre de MacCare sur l'écran Performance reste inférieure à `3 %` d'un cœur sur Mac Intel `x86_64`.
  - [ ] Les processus système critiques (`kernel_task`, `launchd`, `WindowServer`, `loginwindow`) sont marqués `.protected` et ne proposent aucun bouton d'arrêt.

---

### 3.7. Module 07 — Startup Manager (Gestion des éléments de démarrage)
- **Description** : Inventaire transparent et gestion contrôlée des éléments lancés à l'ouverture de session ou en arrière-plan.
- **Sources inspectées** :
  1. `~/Library/LaunchAgents/*.plist` (Agents utilisateur — modifiables sans droits root).
  2. `/Library/LaunchAgents/*.plist` et `/Library/LaunchDaemons/*.plist` (Agents et démons globaux — inspectés en lecture seule avec affichage complet du binaire cible, des arguments `ProgramArguments`, de l'état `RunAtLoad`/`KeepAlive` et de la signature du binaire).
  3. Éléments d'ouverture de session macOS (`SMAppService` / `Réglages Système > Général > Ouverture`).
- **Critères d'acceptation** :
  - [ ] Détection automatique des **agents orphelins / endommagés** (dont l'exécutable `Program` ou `ProgramArguments[0]` n'existe plus sur le disque).
  - [ ] Avant toute désactivation ou mise à la corbeille d'un `.plist` de `~/Library/LaunchAgents`, MacCare crée une sauvegarde de l'état dans son historique local permettant de restaurer l'agent en un clic.

---

### 3.8. Module 08 — Maintenance (Opérations de maintenance documentées)
- **Description** : Catalogue d'opérations de maintenance natives macOS, chacune accompagnée d'une fiche technique expliquant : *Ce que fait la commande*, *Quand l'utiliser*, *Commande exacte exécutée* et *Impact attendu*.
- **Opérations retenues** :
  1. **Réinitialiser le cache des vignettes Quick Look** (`qlmanage -r` & `qlmanage -r cache`) — 100 % espace utilisateur, résout les icônes ou aperçus corrompus dans le Finder.
  2. **Reconstruire la base LaunchServices utilisateur** (`lsregister`) — corrige les doublons dans le menu « Ouvrir avec » du Finder.
  3. **Vider le cache DNS local** (`dscacheutil -flushcache` + `killall -HUP mDNSResponder`).
  4. **Vérifier l'état SMART et la structure du conteneur APFS** (`diskutil info` / `diskutil verifyVolume` en lecture seule).
  5. **Inspecter les instantanés locaux Time Machine** (`tmutil listlocalsnapshots /`) pour afficher l'espace récupérable.
- **Critères d'acceptation** :
  - [ ] La commande shell exacte et ses arguments sont visibles par l'utilisateur avant exécution.
  - [ ] La sortie standard (`stdout`/`stderr`), le code de retour et la durée d'exécution sont affichés en direct et enregistrés dans le journal SQLite.

---

### 3.9. Module 09 — Protection (Contrôles de sécurité et d'intégrité)
- **Description** : Audit de posture de sécurité macOS et inspection d'intégrité des éléments exécutables courants. **MacCare indique explicitement qu'il complète les protections natives d'Apple (XProtect, Gatekeeper, SIP) et ne remplace pas un moteur antivirus temps réel.**
- **Contrôles effectués** :
  1. **Posture de sécurité du Mac** : Vérification en lecture seule de l'état de **SIP** (`csrutil status`), **Gatekeeper** (`spctl --status`), **FileVault** (`fdesetup status`) et présence des mises à jour de sécurité **XProtect** (`/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist`).
  2. **Audit de signature des LaunchAgents & Applications** : Vérification via `Security.framework` (`SecStaticCodeCreateWithPath` / `SecStaticCodeCheckValidity`) des exécutables référencés par les `LaunchAgents`/`LaunchDaemons` et les applications de `/Applications` (détection des binaires non signés, à signature invalide ou altérée).
  3. **Inspecteur de Quarantaine (`com.apple.quarantine`)** : Analyse des fichiers téléchargés dans `~/Downloads` portant encore l'attribut étendu de quarantaine ou des scripts/binaires exécutables récemment déposés.
- **Critères d'acceptation** :
  - [ ] Aucun faux sentiment de sécurité : l'écran affiche clairement le périmètre des contrôles effectués.
  - [ ] Tout élément signalé peut être inspecté (chemin du binaire, autorité de signature `codesign`, hash `SHA-256`, plist parent) sans jamais être supprimé sans validation explicite de l'utilisateur.
