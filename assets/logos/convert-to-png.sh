#!/usr/bin/env bash
# ============================================================================
# convert-to-png.sh — Conversion SVG → PNG (280×280px, format Azure Marketplace)
# Spécifications Logo Azure Marketplace : 216×216 à 350×350 pixels, PNG
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}"
SIZE=280
ALLOW_IMAGEMAGICK="${ALLOW_IMAGEMAGICK:-0}"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SVG_FILES=(
  "logo-v1-gradient-bleu.svg"
  "logo-v2-nuit-semantique.svg"
  "logo-v3-blanc-epure.svg"
  "logo-v4-hub-connecte.svg"
)

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Conversion SVG → PNG ${SIZE}×${SIZE}px — Azure Marketplace Media  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Détection de l'outil de conversion disponible ────────────────────────────
CONVERTER=""
CONVERT_CMD=""

if command -v rsvg-convert &>/dev/null; then
  CONVERTER="rsvg-convert (librsvg)"
  CONVERT_CMD="rsvg"
elif command -v inkscape &>/dev/null; then
  CONVERTER="Inkscape"
  CONVERT_CMD="inkscape"
elif command -v convert &>/dev/null; then
  if [[ "${ALLOW_IMAGEMAGICK}" == "1" ]]; then
    CONVERTER="ImageMagick (convert)"
    CONVERT_CMD="imagemagick"
  else
    echo -e "${RED}✗ Seul ImageMagick est disponible, rendu SVG potentiellement non fidèle.${NC}"
    echo ""
    echo "  Installez un moteur SVG fiable :"
    echo "    Ubuntu/Debian : sudo apt install librsvg2-bin"
    echo "    Inkscape      : sudo apt install inkscape"
    echo ""
    echo "  Si vous voulez forcer ImageMagick malgré tout :"
    echo "    ALLOW_IMAGEMAGICK=1 bash ./convert-to-png.sh"
    exit 1
  fi
else
  echo -e "${RED}✗ Aucun outil de conversion trouvé.${NC}"
  echo ""
  echo "  Installez l'un des outils suivants :"
  echo "    Ubuntu/Debian : sudo apt install librsvg2-bin"
  echo "    Fedora/RHEL   : sudo dnf install librsvg2-tools"
  echo "    macOS (Brew)  : brew install librsvg"
  echo "    Inkscape      : sudo apt install inkscape"
  echo "    ImageMagick   : sudo apt install imagemagick"
  exit 1
fi

echo -e "  Outil détecté : ${GREEN}${CONVERTER}${NC}"
echo ""

# ── Conversion de chaque logo ─────────────────────────────────────────────────
SUCCESS=0
FAILED=0

for SVG in "${SVG_FILES[@]}"; do
  INPUT="${SCRIPT_DIR}/${SVG}"
  PNG="${OUTPUT_DIR}/${SVG%.svg}.png"

  if [[ ! -f "${INPUT}" ]]; then
    echo -e "  ${YELLOW}⚠ Fichier introuvable : ${SVG}${NC}"
    (( ++FAILED ))
    continue
  fi

  printf "  %-42s → " "${SVG}"

  case "${CONVERT_CMD}" in
    rsvg)
      rsvg-convert -w "${SIZE}" -h "${SIZE}" "${INPUT}" -o "${PNG}"
      ;;
    inkscape)
      inkscape --export-type=png \
               --export-width="${SIZE}" \
               --export-height="${SIZE}" \
               --export-filename="${PNG}" \
               "${INPUT}" 2>/dev/null
      ;;
    imagemagick)
      # -density pour éviter les artefacts SVG avec ImageMagick
      convert -density 300 -resize "${SIZE}x${SIZE}" "${INPUT}" "${PNG}"
      ;;
  esac

  if [[ -f "${PNG}" ]]; then
    SIZE_BYTES=$(stat -c%s "${PNG}" 2>/dev/null || stat -f%z "${PNG}" 2>/dev/null || echo "?")
    echo -e "${GREEN}✓ ${SVG%.svg}.png${NC} (${SIZE_BYTES} bytes)"
    (( ++SUCCESS ))
  else
    echo -e "${RED}✗ Échec de la conversion${NC}"
    (( ++FAILED ))
  fi
done

echo ""
echo -e "  Résultat : ${GREEN}${SUCCESS} succès${NC}, ${RED}${FAILED} échec(s)${NC}"
echo ""

if [[ ${SUCCESS} -gt 0 ]]; then
  echo -e "${BLUE}  ✓ Fichiers PNG prêts pour upload Azure Marketplace Partner Center${NC}"
  echo "    → Offer listing > Marketplace media > Large logo (216–350px, PNG)"
  echo ""
fi
