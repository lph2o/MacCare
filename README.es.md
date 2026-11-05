<div align="center">

<img src="Sources/Resources/AppIcon-Preview.png" alt="MacCare Logo" width="160" height="160" />

# MacCare

**Suite nativa y de código abierto para macOS de mantenimiento, análisis de almacenamiento APFS, telemetría del kernel Mach y seguridad.**  
*Desarrollada en Swift, SwiftUI, AppKit, Swift Charts, SQLite3 y CryptoKit — Binario universal (`x86_64` Intel y `arm64` Apple Silicon) para macOS 14+ (Sonoma / Sequoia).*

**🌐 Leer en tu idioma:**  
[**🇬🇧 English**](./README.md) • [**🇫🇷 Français**](./README.fr.md) • [**🇪🇸 Español**](./README.es.md) • [**🇩🇪 Deutsch**](./README.de.md) • [**🇯🇵 日本語**](./README.ja.md) • [**🇨🇳 简体中文**](./README.zh-CN.md)

<br/>

[![Descargar MacCare.dmg](https://img.shields.io/badge/⬇%20DESCARGAR%20PARA%20MAC-MacCare--Universal.dmg-00C9A7?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/lph2o/MacCare/releases/latest/download/MacCare-Universal.dmg)
[![Descargar MacCare.zip](https://img.shields.io/badge/⬇%20DESCARGAR%20(.ZIP)-MacCare--Universal.zip-845EC2?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/lph2o/MacCare/releases/latest/download/MacCare-Universal.zip)

</div>

---

## Descarga Directa e Instalación en 1 Clic (Sin conocimientos técnicos)

No necesitas usar la Terminal ni `git clone` para instalar **MacCare**:

1. **Descarga el instalador directamente**:
   - [**Descargar `MacCare-Universal.dmg` (Recomendado — Imagen de disco macOS)**](https://github.com/lph2o/MacCare/releases/latest/download/MacCare-Universal.dmg)
   - [**Descargar `MacCare-Universal.zip` (Aplicación lista para usar)**](https://github.com/lph2o/MacCare/releases/latest/download/MacCare-Universal.zip)
2. **Arrastrar y soltar**: Abre `MacCare-Universal.dmg` y arrastra **MacCare** a tu carpeta **Aplicaciones**.
3. **Abre MacCare**: Puedes cambiar el idioma de la interfaz en cualquier momento (**🇬🇧 EN, 🇫🇷 FR, 🇪🇸 ES, 🇩🇪 DE, 🇯🇵 JA, 🇨🇳 ZH**) desde el icono del globo en la barra superior.
   > *Nota para el primer inicio (macOS Gatekeeper)*: Haz **Clic derecho (o Control + Clic) en MacCare → Abrir** y confirma en **Abrir**.

---

## Los 9 Módulos Principales

- **01 — Smart Care (`⌘1`)**: Puntuación de salud (0–100), panel Bento de 4 pilares y recomendaciones inteligentes.
- **02 — System Junk (`⌘2`)**: Limpieza segura de cachés, registros y artefactos de compilación con restauración SQLite en 1 clic.
- **03 — Storage Analyzer (`⌘3`)**: Exploración visual **Space Lens** del espacio físico asignado en APFS.
- **04 — App Manager (`⌘4`)**: Desinstalación limpia de aplicaciones y detección de residuos huérfanos en `~/Library`.
- **05 — Duplicate Finder (`⌘5`)**: Detección de duplicados en 3 pasadas (`SHA-256`) sin falsos positivos.
- **06 — Performance (`⌘6`)**: Monitor en tiempo real de memoria virtual Mach y carga de CPU.
- **07 — Startup Manager (`⌘7`)**: Gestión reversible de `LaunchAgents` y detección de archivos `.plist` rotos.
- **08 — Maintenance (`⌘8`)**: Tareas de mantenimiento de macOS (caché DNS, QuickLook, verificación APFS/SMART).
- **09 — Protection (`⌘9`)**: Auditoría de SIP, Gatekeeper, FileVault, XProtect, firmas `SecStaticCode` y cuarentena POSIX.

---

## Licencia

Distribuido bajo la licencia **MIT**. Consulta [`LICENSE`](./LICENSE).
