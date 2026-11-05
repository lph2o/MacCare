# 03 — Architecture d'Interface & Design System Aurora

> **Projet** : **MacCare** — Ergonomie native macOS (HIG Sonoma / Sequoia)

---

## 1. Cycle d'Expérience Utilisateur en 4 États

Chaque module de MacCare suit un flux prévisible et non destructif :

1. **État d'Introduction (`ModuleIntroHeroView`)** :
   - Présente le titre du module, ses 3 piliers fonctionnels avec icônes explicatives et un orbe 3D lumineux aux couleurs de la palette Aurora du module.
2. **État d'Analyse Asynchrone (`Task.detached` / `ScanEngine`)** :
   - Exécution hors du `@MainActor` avec prise en charge de l'annulation coopérative immédiate (`Task.checkCancellation()`).
3. **État de Synthèse & Exploration Maître-Détail** :
   - Cartes Bento vitrées, graphiques `Swift Charts` et listes filtrables qualifiées par un badge de sécurité (`Sûr`, `À vérifier`, `Protégé`).
4. **État de Confirmation & Restauration (`StagingConfirmationModalView`)** :
   - Fenêtre modale interactive récapitulant séparément les éléments sûrs et conditionnels, permettant de décocher les éléments conditionnels en un clic, d'inspecter chaque fichier dans le Finder et d'exécuter le déplacement vers la Corbeille macOS avec journalisation SQLite.

---

## 2. Système de Design (`MacCareTheme`)

- **Fond Sombre Immersif** : `#0D0E17` avec halos radiaux dynamiques (`AuroraCanvasBackground`) propres à chaque module.
- **Surfaces Vitrées** : `.ultraThinMaterial` combiné à une teinte translucide (`white.opacity(0.065)`) et une bordure spéculaire (`white.opacity(0.16)`).
- **Sémantique de Sécurité** :
  - **Sûr (`.safe`)** : Vert émeraude `#48E3B0`
  - **Conditionnel (`.conditional`)** : Ambre `#FFC73D`
  - **Protégé (`.protected`)** : Corail `#FF596B`
