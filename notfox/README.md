# NotFox

Fork ligero de Firefox (tarball oficial es-ES) con perfil blindado estilo
LibreWolf, 5 extensiones nativas forzadas por policies.json (uBlock Origin,
Consent-O-Matic, Skip Redirect, Multi-Account Containers, enhanced-h264ify),
Total Cookie Protection y actualizador propio (notfox-updater.sh, lee
notfox/manifest.json de este repo).

## Reconstruir

    ./build-notfox.sh <version-firefox> <locale>   # p.ej. ./build-notfox.sh 159.0.1 es-ES

Genera dist/notfox_<version>-1notfox1_amd64.deb sin dependencias extra
(probado en Linux Mint 22.3). Requisitos de build: curl, tar, zip, unzip,
ImageMagick, python3-cairosvg, dpkg-deb.

Las extensiones se instalan forzadas desde AMO (URLs en src/policies.json).
