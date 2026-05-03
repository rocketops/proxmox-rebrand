#!/usr/bin/env bash
# Wrapper de un solo comando. Crea el branding dir, baja install.sh + assets, y ejecuta.
#
# Uso desde Web UI Shell del Proxmox (Datacenter -> nodo -> Shell):
#   curl -fsSL https://raw.githubusercontent.com/rocketops/proxmox-rebrand/main/bootstrap.sh | bash

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Correr como root."
  exit 1
fi

BRAND_DIR="/root/branding"
BASE="https://github.com/rocketops/proxmox-rebrand/raw/main"

mkdir -p "$BRAND_DIR/assets"

echo "==> Bajando install.sh"
curl -fsSL "$BASE/install.sh" -o "$BRAND_DIR/install.sh"
chmod +x "$BRAND_DIR/install.sh"

echo "==> Bajando logo"
curl -fsSL "$BASE/assets/logo.svg" -o "$BRAND_DIR/logo.svg"

echo "==> Ejecutando install.sh"
bash "$BRAND_DIR/install.sh"
