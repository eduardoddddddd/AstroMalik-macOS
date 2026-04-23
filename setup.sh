#!/usr/bin/env bash
# setup.sh — descarga Swiss Ephemeris C sources y archivos de efemérides
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWIEPH_DIR="$SCRIPT_DIR/Sources/CSwissEph"
EPHE_DIR="$SCRIPT_DIR/Sources/AstroMalik/Resources/ephe"
SWISSEPH_REPO="https://github.com/aloistr/swisseph.git"
SWISSEPH_TMP="/tmp/swisseph_src"

echo "==> AstroMalik macOS — Setup"
echo ""

# ── 1. Swiss Ephemeris C sources ──────────────────────────────────────────────
echo "── Descargando Swiss Ephemeris C sources..."
if [ -d "$SWISSEPH_TMP" ]; then
    rm -rf "$SWISSEPH_TMP"
fi
git clone --depth 1 "$SWISSEPH_REPO" "$SWISSEPH_TMP"

C_FILES=(
    sweph.c swephlib.c swedate.c swejpl.c swemmoon.c
    swecl.c swehel.c swehouse.c swephft.c
)
H_FILES=(
    sweph.h swephexp.h swedate.h sweodef.h swephlib.h
    swejpl.h swemmoon.h swehel.h
)

for f in "${C_FILES[@]}"; do
    if [ -f "$SWISSEPH_TMP/$f" ]; then
        cp "$SWISSEPH_TMP/$f" "$SWIEPH_DIR/"
        echo "  ✔ $f"
    else
        echo "  ✗ $f no encontrado — puede que haya cambiado el nombre en el repo"
    fi
done

for f in "${H_FILES[@]}"; do
    if [ -f "$SWISSEPH_TMP/$f" ]; then
        cp "$SWISSEPH_TMP/$f" "$SWIEPH_DIR/include/"
        echo "  ✔ include/$f"
    fi
done

rm -rf "$SWISSEPH_TMP"
echo ""

# ── 2. Archivos de efemérides (datos astronómicos) ───────────────────────────
echo "── Descargando archivos de efemérides Swiss Ephemeris..."
mkdir -p "$EPHE_DIR"

# Descarga archivos de efemérides mínimos para 1800-2400 (seas_18.se1, sepl_18.se1, semo_18.se1)
EPHE_BASE="https://github.com/aloistr/swisseph/raw/master"
EPHE_FILES=(
    "ephe/seas_18.se1"
    "ephe/sepl_18.se1"
    "ephe/semo_18.se1"
)

for f in "${EPHE_FILES[@]}"; do
    fname=$(basename "$f")
    if curl -fsSL "$EPHE_BASE/$f" -o "$EPHE_DIR/$fname" 2>/dev/null; then
        echo "  ✔ $fname"
    else
        echo "  ✗ $fname — intenta descargar manualmente desde https://www.astro.com/swisseph/swefiles.htm"
    fi
done
echo ""

# ── 3. Corpus DB ─────────────────────────────────────────────────────────────
RESOURCES_DIR="$SCRIPT_DIR/Sources/AstroMalik/Resources"
ORIGINAL_CORPUS="/tmp/astromalik-source/backend/data/corpus.db"
ORIGINAL_CITIES="/tmp/astromalik-source/backend/data/cities_seed.json"

if [ -f "$ORIGINAL_CORPUS" ]; then
    cp "$ORIGINAL_CORPUS" "$RESOURCES_DIR/corpus.db"
    echo "✔ corpus.db copiado desde repo original"
else
    echo "✗ corpus.db no encontrado. Clona primero el repo original:"
    echo "  git clone https://github.com/eduardoddddddd/AstroMalik.git /tmp/astromalik-source"
fi

if [ -f "$ORIGINAL_CITIES" ]; then
    cp "$ORIGINAL_CITIES" "$RESOURCES_DIR/cities_seed.json"
    echo "✔ cities_seed.json copiado"
fi
echo ""

echo "==> Setup completado."
echo "    Abre Package.swift en Xcode para compilar y ejecutar la app."
