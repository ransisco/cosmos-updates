#!/bin/bash
# ============================================================================
# build-notfox.sh - pipeline reproducible de NotFox
#
# Uso:  ./build-notfox.sh [VERSION_FIREFOX] [LOCALE]
#       ./build-notfox.sh 159.0.1 es-ES
#
# Descarga el tarball oficial de Firefox, aplica el rebranding NotFox,
# instala la configuración blindada (notfox.cfg + policies.json), el
# actualizador propio y empaqueta el .deb completo.
# Mantenimiento: ejecutar con cada versión nueva de Firefox.
# ============================================================================
set -euo pipefail

FFVER="${1:-159.0.1}"
LOCALE="${2:-es-ES}"
DEBVER="$FFVER-1notfox1"

BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$BUILD_DIR/../src"
ICON_DIR="$BUILD_DIR/icons"
ASSET_DIR="$BUILD_DIR/assets"
DIST_DIR="$BUILD_DIR/../dist"
TARBALL="$BUILD_DIR/firefox-$FFVER.tar.bz2"
[ -f "$TARBALL" ] || TARBALL="$BUILD_DIR/firefox-$FFVER.tar.xz"
FF_DIR="$BUILD_DIR/firefox"
PKG="$BUILD_DIR/pkgroot"

echo "== NotFox build: Firefox $FFVER ($LOCALE) -> $DEBVER =="

# --- 1. descarga -------------------------------------------------------------
if [ ! -f "$TARBALL" ]; then
  echo "-- descargando Firefox $FFVER $LOCALE"
  curl -fSL --retry 2 -o "$BUILD_DIR/firefox-$FFVER.tar.xz" \
    "https://download-installer.cdn.mozilla.net/pub/firefox/releases/$FFVER/linux-x86_64/$LOCALE/firefox-$FFVER.tar.xz"
  TARBALL="$BUILD_DIR/firefox-$FFVER.tar.xz"
fi

# --- 2. extracción limpia ----------------------------------------------------
echo "-- extrayendo"
rm -rf "$FF_DIR"
tar -xf "$TARBALL" -C "$BUILD_DIR"
cd "$FF_DIR"

# --- 3. quitar actualizador de Mozilla, informes de fallo y pings -----------
echo "-- limpiando updater/telemetría de Mozilla"
rm -f updater updater.ini update-settings.ini precomplete removed-files \
      pingsender crashreporter crashreporter.ini crashhelper minidump-analyzer \
      firefox.sig firefox-bin.sig libxul.so.sig

# --- 4. identidad de la app --------------------------------------------------
echo "-- application.ini -> NotFox"
sed -i 's/^Vendor=Mozilla/Vendor=NotFox/; s/^Name=Firefox/Name=NotFox/; s/^RemotingName=firefox/RemotingName=notfox/' application.ini
cp application.ini browser/application.ini

# --- 5. configuración blindada ----------------------------------------------
echo "-- notfox.cfg + local-settings.js + policies.json"
cp "$SRC_DIR/notfox.cfg" notfox.cfg
mkdir -p defaults/pref
cp "$SRC_DIR/local-settings.js" defaults/pref/local-settings.js
cp "$SRC_DIR/policies.json" distribution/policies.json
cp "$SRC_DIR/distribution.ini" distribution/distribution.ini
echo "$DEBVER" > notfox-version
cp "$SRC_DIR/notfox-updater.sh" notfox-updater
chmod 755 notfox-updater

# --- 6. iconos ---------------------------------------------------------------
echo "-- renderizando iconos"
mkdir -p "$ICON_DIR" "$ASSET_DIR"
TMHOME=$(mktemp -d)
render_icon() { # render_icon <size> — cairosvg: alfa real, sin recorte de bordes
  python3 -c "import cairosvg; cairosvg.svg2png(url='$SRC_DIR/notfox.svg', write_to='$ICON_DIR/icon_$1_t.png', output_width=$1, output_height=$1)"
}
for s in 16 32 48 64 128 192 256 384; do render_icon "$s"; done
rm -rf "$TMHOME"

# assets para omni.ja
for s in 16 32 48 64 128; do cp "$ICON_DIR/icon_${s}_t.png" "$ASSET_DIR/icon${s}.png"; done
cp "$ICON_DIR/icon_192_t.png" "$ASSET_DIR/about-logo.png"
cp "$ICON_DIR/icon_384_t.png" "$ASSET_DIR/about-logo@2x.png"
convert "$ICON_DIR/icon_256_t.png" -resize 236x236 -gravity center -background none -extent 300x236 "$ASSET_DIR/about.png"
sed 's/width="100%" height="100%"/width="192" height="192"/' "$SRC_DIR/notfox.svg" > "$ASSET_DIR/about-logo.svg"
cp "$SRC_DIR/wordmark.svg" "$ASSET_DIR/wordmark.svg"

# --- 7. rebranding de omni.ja -------------------------------------------------
# Los omni.ja oficiales llevan offsets no estándar: se descomprimen con unzip
# (que los compensa), se parchean en disco y se reempaquetan con zip -0.
patch_omni() { # patch_omni <jar-relativo> <modo>
  local jar="$1" mode="$2" tmp
  tmp=$(mktemp -d)
  (cd "$tmp" && unzip -qq "$FF_DIR/$jar" >/dev/null 2>&1) || true
  python3 "$SRC_DIR/patch_brand.py" "$tmp" "$ASSET_DIR" "$mode"
  rm -f "$FF_DIR/$jar.new"
  (cd "$tmp" && zip -X -q -0 -r "$FF_DIR/$jar.new" .)
  mv "$FF_DIR/$jar.new" "$FF_DIR/$jar"
  rm -rf "$tmp"
}
echo "-- parcheando browser/omni.ja (marca + recursos)"
patch_omni browser/omni.ja browser
echo "-- parcheando omni.ja (brandings.ftl)"
patch_omni omni.ja toolkit

# iconos de ventana (X11)
for s in 16 32 48 64 128; do
  cp "$ICON_DIR/icon_${s}_t.png" "browser/chrome/icons/default/default${s}.png"
done

# --- 8. empaquetado .deb ------------------------------------------------------
echo "-- montando pkgroot"
rm -rf "$PKG"
mkdir -p "$PKG/opt" "$PKG/usr/bin" "$PKG/usr/share/applications" "$PKG/DEBIAN"
cp -r "$FF_DIR" "$PKG/opt/notfox"
cp "$SRC_DIR/notfox-wrapper.sh" "$PKG/usr/bin/notfox"
chmod 755 "$PKG/usr/bin/notfox" "$PKG/opt/notfox/notfox-updater"
cp "$SRC_DIR/notfox.desktop" "$PKG/usr/share/applications/notfox.desktop"

for s in 16 32 48 64 128 256; do
  mkdir -p "$PKG/usr/share/icons/hicolor/${s}x${s}/apps"
  cp "$ICON_DIR/icon_${s}_t.png" "$PKG/usr/share/icons/hicolor/${s}x${s}/apps/notfox.png"
done
mkdir -p "$PKG/usr/share/icons/hicolor/scalable/apps"
cp "$SRC_DIR/notfox.svg" "$PKG/usr/share/icons/hicolor/scalable/apps/notfox.svg"

sed "s/@VERSION@/$DEBVER/" "$SRC_DIR/control" > "$PKG/DEBIAN/control"
cp "$SRC_DIR/postinst" "$PKG/DEBIAN/postinst"
chmod 755 "$PKG/DEBIAN/postinst"

mkdir -p "$DIST_DIR"
dpkg-deb --root-owner-group --build "$PKG" "$DIST_DIR/notfox_${DEBVER}_amd64.deb"
echo "== OK: $DIST_DIR/notfox_${DEBVER}_amd64.deb =="
ls -la "$DIST_DIR"
