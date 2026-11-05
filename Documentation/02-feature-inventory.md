# 02 — Inventaire Fonctionnel des 9 Modules de MacCare

> **Projet** : **MacCare** — Suite native open-source de maintenance et d'analyse pour macOS

---

## 1. Vue d'Ensemble des Modules

MacCare structure ses fonctionnalités autour de **9 modules spécialisés** accessibles depuis la barre latérale principale et via les raccourcis clavier `⌘1` à `⌘9`, complétés par un moniteur de barre des menus :

| # | Module | Raccourci | Rôle Principal |
| :-: | :--- | :-: | :--- |
| **01** | **Smart Care** | `⌘1` | Diagnostic global en un clic, calcul de l'indice de santé (0–100), grille Bento à 4 piliers et recommandations priorisées. |
| **02** | **System Junk** | `⌘2` | Analyse maître-détail des caches utilisateur (`.safe`), journaux, artefacts Xcode (`DerivedData`), caches de paquets (`.conditional`) et restauration SQLite. |
| **03** | **Storage Analyzer** | `⌘3` | Exploration visuelle **Space Lens** de l'arborescence APFS, tri par taille physique allouée et détection des fichiers volumineux. |
| **04** | **App Manager** | `⌘4` | Inventaire des applications installées, corrélation des fichiers associés dans `~/Library` et détection des résidus orphelins (*Leftovers*). |
| **05** | **Duplicate Finder** | `⌘5` | Détection déterministe des fichiers en double en 3 passes (Taille → `SHA-256` partiel `64 Ko` → `SHA-256` complet) avec préservation garantie d'un original. |
| **06** | **Performance** | `⌘6` | Surveillance temps réel CPU et mémoire virtuelle Mach (`Active`, `Wired`, `Compressed`, pression mémoire) et liste des processus actifs. |
| **07** | **Startup Manager** | `⌘7` | Audit des `LaunchAgents` utilisateur, détection des plists brisés et désactivation/restauration réversible sauvegardée dans SQLite. |
| **08** | **Maintenance** | `⌘8` | Exécution transparente et journalisée des scripts d'entretien macOS (cache DNS, QuickLook, LaunchServices, vérification APFS/SMART). |
| **09** | **Protection** | `⌘9` | Contrôle de la posture de sécurité macOS (SIP, Gatekeeper, FileVault, XProtect), vérification `SecStaticCode` et inspection de la quarantaine POSIX. |
