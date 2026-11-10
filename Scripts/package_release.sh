#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# WispTile v1.0.0 Production Release Packaging Script
# Direct Distribution · Hardened Runtime · Developer ID Signing · DMG & ZIP
# ==============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${PROJECT_ROOT}/dist"
APP_NAME="WispTile"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
ZIP_NAME="${APP_NAME}-1.0.0.zip"
DMG_NAME="${APP_NAME}-1.0.0.dmg"

echo "========================================================================"
echo " Packaging WispTile 1.0.0 for Production Release"
echo "========================================================================"
echo "Project Root: ${PROJECT_ROOT}"
echo "Output Directory: ${DIST_DIR}"

# 1. Clean and prepare dist directory
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"
touch "${DIST_DIR}/.metadata_never_index"

# 2. Build Release configuration with Swift Compiler
echo -e "\n[1/5] Building Release binaries..."
cd "${PROJECT_ROOT}"
swift build -c release --product WispTileApp
swift build -c release --product wisptile

RELEASE_BIN="${PROJECT_ROOT}/.build/release/WispTileApp"
if [[ ! -f "${RELEASE_BIN}" ]]; then
    echo "❌ Error: Release binary not found at ${RELEASE_BIN}"
    exit 1
fi

# 3. Assemble macOS .app Bundle Structure
echo -e "\n[2/5] Assembling ${APP_NAME}.app bundle structure..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${RELEASE_BIN}" "${APP_BUNDLE}/Contents/MacOS/WispTileApp"
chmod +x "${APP_BUNDLE}/Contents/MacOS/WispTileApp"

# Copy Info.plist
cp "${PROJECT_ROOT}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Copy branding assets & application icon
if [[ -f "${PROJECT_ROOT}/Resources/AppIcon.icns" ]]; then
    cp "${PROJECT_ROOT}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi
if [[ -f "${PROJECT_ROOT}/WispTile logo.png" ]]; then
    cp "${PROJECT_ROOT}/WispTile logo.png" "${APP_BUNDLE}/Contents/Resources/WispTileLogo.png"
fi
if [[ -f "${PROJECT_ROOT}/Resources/WispTileMenuBarIcon.png" ]]; then
    cp "${PROJECT_ROOT}/Resources/WispTileMenuBarIcon.png" "${APP_BUNDLE}/Contents/Resources/WispTileMenuBarIcon.png"
fi

# 4. Code Signing with Hardened Runtime & Entitlements
echo -e "\n[3/5] Applying Hardened Runtime & Code Signing..."
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
ENTITLEMENTS="${PROJECT_ROOT}/Resources/WispTile.entitlements"

if [[ -n "${SIGNING_IDENTITY}" ]]; then
    echo "Using Developer ID Application: ${SIGNING_IDENTITY}"
    codesign --force --options runtime --entitlements "${ENTITLEMENTS}" --sign "${SIGNING_IDENTITY}" --timestamp "${APP_BUNDLE}"
else
    echo "No Developer ID certificate supplied. Applying local Hardened Runtime ad-hoc signature..."
    codesign --force --options runtime --entitlements "${ENTITLEMENTS}" --sign - "${APP_BUNDLE}"
fi

# Verify signature
echo "Verifying signature validity..."
codesign --verify --deep --strict --verbose=1 "${APP_BUNDLE}"
echo "✅ Code signature verified successfully."

# 5. Create Distribution ZIP & DMG
echo -e "\n[4/5] Creating Distribution Artifacts (ZIP & DMG)..."

# Create ZIP archive (preserves symlinks and permissions)
cd "${DIST_DIR}"
ditto -c -k --keepParent "${APP_NAME}.app" "${ZIP_NAME}"
ZIP_SIZE=$(stat -f%z "${ZIP_NAME}" 2>/dev/null || stat -c%s "${ZIP_NAME}")
ZIP_SHA=$(shasum -a 256 "${ZIP_NAME}" | cut -d ' ' -f 1)
echo "  • ZIP Archive: ${ZIP_NAME} (${ZIP_SIZE} bytes, SHA256: ${ZIP_SHA:0:16}...)"

# Create DMG with Applications shortcut
DMG_STAGING="${DIST_DIR}/dmg_staging"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create -volname "${APP_NAME} 1.0.0" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${DIST_DIR}/${DMG_NAME}"
rm -rf "${DMG_STAGING}"

DMG_SIZE=$(stat -f%z "${DIST_DIR}/${DMG_NAME}" 2>/dev/null || stat -c%s "${DIST_DIR}/${DMG_NAME}")
DMG_SHA=$(shasum -a 256 "${DIST_DIR}/${DMG_NAME}" | cut -d ' ' -f 1)
echo "  • DMG Disk Image: ${DMG_NAME} (${DMG_SIZE} bytes, SHA256: ${DMG_SHA:0:16}...)"

# 6. Notarization hook explanation (CI / Production)
echo -e "\n[5/5] Notarization Pipeline Status:"
if [[ -n "${APPLE_ID:-}" && -n "${TEAM_ID:-}" && -n "${APP_PASSWORD:-}" ]]; then
    echo "Submitting to Apple Notary Service via xcrun notarytool..."
    xcrun notarytool submit "${DIST_DIR}/${DMG_NAME}" --apple-id "${APPLE_ID}" --team-id "${TEAM_ID}" --password "${APP_PASSWORD}" --wait
    xcrun stapler staple "${DIST_DIR}/${DMG_NAME}"
    xcrun stapler staple "${APP_BUNDLE}"
    echo "✅ Notarized & Stapled successfully."
else
    echo "ℹ️  Apple ID credentials not provided in environment; notarization submission skipped for local build."
    echo "   Ready for: xcrun notarytool submit ${DMG_NAME} --keychain-profile \"AC_PASSWORD\" --wait"
fi

# Clean up loose bundle in dist/ to prevent macOS Spotlight duplicate registration
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "${APP_BUNDLE}" 2>/dev/null || true
rm -rf "${APP_BUNDLE}"

echo -e "\n========================================================================"
echo "🎉 WispTile 1.0.0 Release Packaging Completed Successfully!"
echo "   Artifacts available in: ${DIST_DIR}"
echo "   • ${APP_NAME}.app (Hardened Runtime)"
echo "   • ${DMG_NAME} (${DMG_SIZE} bytes)"
echo "   • ${ZIP_NAME} (${ZIP_SIZE} bytes)"
echo "========================================================================"
