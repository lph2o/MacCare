#!/bin/zsh
set -euo pipefail

# Script pour créer un DMG professionnellement stylisé avec Finder AppleScript :
# - Fenêtre aux dimensions précises (720 x 460)
# - Fond Retina haute résolution avec flèche néon et cartes cibles
# - Icônes MacCare.app et Applications positionnées exactement sur les socles
# - Masquage de la barre d'outils et de la barre d'état
# - Éjection propre et conversion en image UDZO finale compressée

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${DIST_DIR:-${PROJECT_ROOT}/dist}"
APP_BUNDLE="${DIST_DIR}/MacCare.app"
DMG_PATH="${DIST_DIR}/MacCare-Universal.dmg"
TEMP_DMG="/tmp/maccare-temp.dmg"
VOLUME_NAME="MacCare"
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
BG_DIR="/tmp/maccare-dmg-bg"

echo "==> [1/6] Préparation du fond stylisé..."
mkdir -p "${BG_DIR}"
if [ ! -f "${BG_DIR}/background.tiff" ]; then
    SWIFTPM_MODULECACHE_OVERRIDE=/tmp/clang-cache swift -module-cache-path /tmp/clang-cache "${PROJECT_ROOT}/scripts/generate-dmg-background.swift" "${BG_DIR}"
    tiffutil -cathidpicheck "${BG_DIR}/background@1x.png" "${BG_DIR}/background@2x.png" -out "${BG_DIR}/background.tiff"
fi

echo "==> [2/6] Démontage préalable si déjà monté..."
if [ -d "${MOUNT_DIR}" ]; then
    hdiutil detach "${MOUNT_DIR}" -force || true
    sleep 1
fi

echo "==> [3/6] Création de l'image disque RW temporaire..."
rm -f "${TEMP_DMG}" "${DMG_PATH}"
# Calcul de la taille requise (taille app + 80 Mo de marge)
APP_SIZE_MB=$(du -sm "${APP_BUNDLE}" | cut -f1)
TOTAL_SIZE_MB=$((APP_SIZE_MB + 90))

hdiutil create -size "${TOTAL_SIZE_MB}m" -volname "${VOLUME_NAME}" -fs HFS+ -ov "${TEMP_DMG}"

echo "==> [4/6] Montage de l'image disque..."
ATTACH_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG}")
DEVICE=$(echo "${ATTACH_OUTPUT}" | head -n1 | awk '{print $1}')
echo "Monté sur ${DEVICE} -> ${MOUNT_DIR}"
sleep 1

echo "==> [5/6] Copie de MacCare.app, lien Applications et fond visuel..."
mkdir -p "${MOUNT_DIR}/.background"
cp "${BG_DIR}/background.tiff" "${MOUNT_DIR}/.background/background.tiff"
cp "${BG_DIR}/background@2x.png" "${MOUNT_DIR}/.background/background.png"

cp -R "${APP_BUNDLE}" "${MOUNT_DIR}/MacCare.app"
ln -s /Applications "${MOUNT_DIR}/Applications"

# Masquer le dossier .background
if command -v SetFile &>/dev/null; then
    SetFile -a V "${MOUNT_DIR}/.background" || true
fi

echo "==> [6/6] Configuration de la vue Finder (positions, taille d'icône, arrière-plan)..."
osascript <<EOF || true
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- Largeur 720, Hauteur 460
        set bounds of container window to {160, 120, 880, 580}
        
        set opts to the icon view options of container window
        set icon size of opts to 128
        set text size of opts to 13
        set arrangement of opts to not arranged
        
        -- Définition du fond d'écran
        try
            set background picture of opts to file ".background:background.tiff"
        on error
            try
                set background picture of opts to file ".background:background.png"
            end try
        end try
        
        -- Positionnement précis au centre des socles dessinés
        -- Socle MacCare (gauche) : x=195, y=220
        -- Socle Applications (droite) : x=525, y=220
        set position of item "MacCare.app" of container window to {195, 220}
        set position of item "Applications" of container window to {525, 220}
        
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

sleep 2
sync
hdiutil detach "${DEVICE}" -force || hdiutil detach "${MOUNT_DIR}" -force

echo "==> Compression en DMG final UDZO..."
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}"
rm -f "${TEMP_DMG}"

echo "==> DMG stylisé généré avec succès :"
ls -lh "${DMG_PATH}"

