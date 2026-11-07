#!/usr/bin/env python3
"""Rebranding de NotFox sobre un omni.ja de Firefox DESCOMPRIMIDO.

Uso: patch_brand.py <dir-omni-descomprimido> <dir-de-assets> <modo>
  modo "browser": brand.ftl + brand.properties + recursos gráficos
  modo "toolkit": brandings.ftl (Firefox -> NotFox en nombres de producto)
"""
import os
import re
import sys

BRAND_FTL_ES = """\
-brand-shorter-name = NotFox
-brand-short-name = NotFox
-brand-shortcut-name = NotFox
-brand-full-name = NotFox
-brand-product-name = NotFox
-vendor-short-name = NotFox
trademarkInfo = NotFox es una parodia comunitaria sobre Mozilla Firefox. Firefox y los logotipos de Firefox son marcas registradas de Mozilla Foundation.
"""

BRAND_FTL_EN = """\
-brand-shorter-name = NotFox
-brand-short-name = NotFox
-brand-shortcut-name = NotFox
-brand-full-name = NotFox
-brand-product-name = NotFox
-vendor-short-name = NotFox
trademarkInfo = NotFox is a community parody of Mozilla Firefox. Firefox and the Firefox logos are trademarks of the Mozilla Foundation.
"""

BRAND_PROPS = """\
brandShorterName = NotFox
brandShortName = NotFox
brandFullName = NotFox
"""

TEXT_REPLACEMENTS = {
    "localization/es-ES/branding/brand.ftl": BRAND_FTL_ES,
    "localization/en-US/branding/brand.ftl": BRAND_FTL_EN,
    "chrome/es-ES/locale/branding/brand.properties": BRAND_PROPS,
    "chrome/en-US/locale/branding/brand.properties": BRAND_PROPS,
}

FILE_MAP = {
    "chrome/browser/content/branding/icon16.png": "icon16.png",
    "chrome/browser/content/branding/icon32.png": "icon32.png",
    "chrome/browser/content/branding/icon48.png": "icon48.png",
    "chrome/browser/content/branding/icon64.png": "icon64.png",
    "chrome/browser/content/branding/icon128.png": "icon128.png",
    "chrome/browser/content/branding/about-logo.png": "about-logo.png",
    "chrome/browser/content/branding/about-logo@2x.png": "about-logo@2x.png",
    "chrome/browser/content/branding/about-logo-private.png": "about-logo.png",
    "chrome/browser/content/branding/about-logo-private@2x.png": "about-logo@2x.png",
    "chrome/browser/content/branding/about-logo.svg": "about-logo.svg",
    "chrome/browser/content/branding/about.png": "about.png",
    "chrome/browser/content/branding/about-wordmark.svg": "wordmark.svg",
    "chrome/browser/content/branding/firefox-wordmark.svg": "wordmark.svg",
}

BRANDINGS = [
    "localization/es-ES/toolkit/branding/brandings.ftl",
    "localization/en-US/toolkit/branding/brandings.ftl",
]

# En brandings.ftl solo renombramos el producto Firefox; otras marcas
# (Mozilla Thunderbird, MDN, Pocket...) se quedan como están.
FIREFOX_RE = re.compile(r"\bFirefox\b")


def patch_browser(root: str, assets: str) -> None:
    done = []
    for rel, content in TEXT_REPLACEMENTS.items():
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            print(f"AVISO: no existe {rel} (se omite)", file=sys.stderr)
            continue
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(content)
        done.append(rel)
    missing = []
    for rel, asset in FILE_MAP.items():
        src = os.path.join(assets, asset)
        dst = os.path.join(root, rel)
        if not (os.path.exists(src) and os.path.exists(dst)):
            missing.append(rel)
            continue
        with open(src, "rb") as fh:
            data = fh.read()
        with open(dst, "wb") as fh:
            fh.write(data)
        done.append(rel)
    print(f"browser: {len(done)} entradas parcheadas")
    if missing:
        print("FALTAN:", missing, file=sys.stderr)
        sys.exit(1)


def patch_toolkit(root: str) -> None:
    for rel in BRANDINGS:
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            print(f"AVISO: no existe {rel}", file=sys.stderr)
            continue
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        text = FIREFOX_RE.sub("NotFox", text)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        print(f"toolkit: {rel} parcheado")


if __name__ == "__main__":
    root, mode = sys.argv[1], sys.argv[3]
    if mode == "browser":
        patch_browser(root, sys.argv[2])
    elif mode == "toolkit":
        patch_toolkit(root)
    else:
        sys.exit(f"modo desconocido: {mode}")
