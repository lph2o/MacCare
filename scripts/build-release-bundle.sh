#!/bin/zsh
# Script d'assemblage Release universel (x86_64 + arm64), signature codesign et préparation à l'installation macOS.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_SCRATCH="${BUILD_SCRATCH:-/tmp/maccare-release-build}"
DIST_DIR="${DIST_DIR:-${PROJECT_ROOT}/dist}"
APP_BUNDLE="${DIST_DIR}/MacCare.app"

export SWIFTPM_MODULECACHE_OVERRIDE="${BUILD_SCRATCH}/swiftpm-module-cache"
CLANG_CACHE="${BUILD_SCRATCH}/clang-module-cache"
SWIFTPM_CACHE="${BUILD_SCRATCH}/swiftpm-cache"

echo "==> [1/5] Compilation Release pour Intel (x86_64)..."
swift build --disable-sandbox \
    -c release \
    --arch x86_64 \
    --package-path "${PROJECT_ROOT}" \
    --scratch-path "${BUILD_SCRATCH}" \
    --cache-path "${SWIFTPM_CACHE}" \
    -Xswiftc -module-cache-path -Xswiftc "${CLANG_CACHE}"

echo "==> [2/5] Compilation Release pour Apple Silicon (arm64)..."
swift build --disable-sandbox \
    -c release \
    --arch arm64 \
    --package-path "${PROJECT_ROOT}" \
    --scratch-path "${BUILD_SCRATCH}" \
    --cache-path "${SWIFTPM_CACHE}" \
    -Xswiftc -module-cache-path -Xswiftc "${CLANG_CACHE}"

BIN_X86="${BUILD_SCRATCH}/x86_64-apple-macosx/release/MacCare"
BIN_ARM="${BUILD_SCRATCH}/arm64-apple-macosx/release/MacCare"

echo "==> [3/5] Assemblage du bundle universel MacCare.app..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

lipo -create "${BIN_X86}" "${BIN_ARM}" -output "${APP_BUNDLE}/Contents/MacOS/MacCare"
chmod +x "${APP_BUNDLE}/Contents/MacOS/MacCare"
cp "${PROJECT_ROOT}/Sources/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
if [ -f "${PROJECT_ROOT}/Sources/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_ROOT}/Sources/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi
printf "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "==> [4/5] Vérification de l'architecture universelle (lipo -info)..."
lipo -info "${APP_BUNDLE}/Contents/MacOS/MacCare"

echo "==> [5/7] Signature cryptographique du bundle MacCare.app..."
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:--}"
codesign --force --deep --sign "${SIGN_IDENTITY}" \
    --entitlements "${PROJECT_ROOT}/Sources/Resources/MacCare.entitlements" \
    "${APP_BUNDLE}"
codesign --verify --verbose=2 "${APP_BUNDLE}"

echo "==> [6/7] Création de l'archive directe MacCare-Universal.zip..."
ZIP_ARCHIVE="${DIST_DIR}/MacCare-Universal.zip"
rm -f "${ZIP_ARCHIVE}"
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_ARCHIVE}"

echo "==> [7/7] Création de l'image disque MacCare-Universal.dmg (Stylée avec fond HD et glisser-déposer)..."
"${PROJECT_ROOT}/scripts/build-styled-dmg.sh"

echo "==> Bundle Release universel prêt : ${APP_BUNDLE}"
ls -lh "${DIST_DIR}"
