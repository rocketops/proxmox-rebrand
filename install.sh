#!/usr/bin/env bash
# proxmox-rebrand v2 · Rocket Operations
#
# CAMBIOS vs v1:
#  - Cada patch parte SIEMPRE de baseline (los .orig en /root/branding/backup/)
#    para que sea verdaderamente idempotente y reversible.
#  - Strings rebrand únicamente; visual via CSS append (CSS roto no rompe JS).
#  - Subscription nag patch usa perl multilinea con verificación de match.
#  - Smoke test post-restart: HTTP 200 + <title> esperado. Si falla → rollback automático.
#  - Sin APT hook hasta que probemos estable manualmente.
#
# Uso:
#   curl -fsSL https://github.com/rocketops/proxmox-rebrand/raw/main/install.sh -o /tmp/r.sh && bash /tmp/r.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "Correr como root."; exit 1; fi
[[ -f /etc/pve/.version ]] || { echo "No es Proxmox VE."; exit 1; }

BRAND_DIR="/root/branding"
BACKUP_DIR="$BRAND_DIR/backup"
PVEMANAGER_JS="/usr/share/pve-manager/js/pvemanagerlib.js"
PVEMANAGER_HTML="/usr/share/pve-manager/index.html.tpl"
PVEMANAGER_LOGO="/usr/share/pve-manager/images/logo-128.png"
PVEMANAGER_HEADER_LOGO="/usr/share/pve-manager/images/proxmox_logo.png"
PROXMOX_LIB_JS="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
PVE_CSS="/usr/share/pve-manager/css/ext6-pve.css"

mkdir -p "$BACKUP_DIR"

backup_once() {
  local src="$1" name="$(basename "$1").orig"
  if [[ -f "$src" && ! -f "$BACKUP_DIR/$name" ]]; then
    cp -p "$src" "$BACKUP_DIR/$name"
  fi
}

restore_baseline() {
  local target="$1" name="$(basename "$1").orig"
  if [[ -f "$BACKUP_DIR/$name" ]]; then
    cp -p "$BACKUP_DIR/$name" "$target"
  fi
}

rollback_all() {
  echo "⚠ ROLLBACK — restaurando originales"
  for f in "$PVEMANAGER_JS" "$PVEMANAGER_HTML" "$PVEMANAGER_LOGO" "$PROXMOX_LIB_JS" "$PVE_CSS"; do
    restore_baseline "$f"
  done
  systemctl restart pveproxy
  echo "Originales restaurados. Refresca el navegador."
}

trap '[[ $? -ne 0 ]] && rollback_all' EXIT

echo "==> Backup (idempotente — sólo crea si no existen)"
for f in "$PVEMANAGER_JS" "$PVEMANAGER_HTML" "$PVEMANAGER_LOGO" "$PVEMANAGER_HEADER_LOGO" "$PROXMOX_LIB_JS" "$PVE_CSS"; do
  backup_once "$f"
done

echo "==> Restore baseline antes de patchear (clean slate)"
for f in "$PVEMANAGER_JS" "$PVEMANAGER_HTML" "$PVEMANAGER_LOGO" "$PVEMANAGER_HEADER_LOGO" "$PROXMOX_LIB_JS" "$PVE_CSS"; do
  restore_baseline "$f"
done

echo "==> Logos (favicon + header)"
# favicon (logo-128.png) puede ser SVG, los navegadores aceptan
cp "$BRAND_DIR/logo.svg" "$PVEMANAGER_LOGO"
# header logo (proxmox_logo.png) DEBE ser PNG real 172x30
if [[ -f "$BRAND_DIR/header-logo.png" ]]; then
  cp "$BRAND_DIR/header-logo.png" "$PVEMANAGER_HEADER_LOGO"
else
  echo "  ⚠ header-logo.png no encontrado en $BRAND_DIR — el logo del header no cambiará"
fi

echo "==> Title de la pestaña"
sed -i 's|<title>[^<]*</title>|<title>Rocket Operations · Console</title>|g' "$PVEMANAGER_HTML"
grep -q "Rocket Operations · Console" "$PVEMANAGER_HTML" || { echo "FAIL title patch"; exit 1; }

echo "==> Header 'Proxmox Virtual Environment' → 'Rocket Operations · Console'"
sed -i "s|'Proxmox Virtual Environment'|'Rocket Operations · Console'|g" "$PVEMANAGER_JS"
grep -q "Rocket Operations · Console" "$PVEMANAGER_JS" || { echo "FAIL header patch"; exit 1; }

echo "==> Subscription nag (perl multilinea + verificación)"
perl -0777 -i -pe "s/(Ext\.Msg\.show\(\{\s*\n\s*title: gettext\('No valid subscription'\),)/orig_cmd(); return; \1/" "$PROXMOX_LIB_JS"
if ! grep -q "orig_cmd(); return; Ext.Msg.show" "$PROXMOX_LIB_JS"; then
  echo "  ⚠ patch de subscription no matcheó — restaurando ese archivo solo"
  restore_baseline "$PROXMOX_LIB_JS"
else
  echo "  ✓ subscription nag bypass aplicado"
fi

echo "==> CSS — paleta Aurora + footer + hide del banner residual"
cat >> "$PVE_CSS" <<'CSS'

/* === Rocket Operations · Aurora theme === */
.x-toolbar-default { background-color: #0F172A !important; border-bottom: 2px solid #06B6D4 !important; }
.x-toolbar-default .x-toolbar-text-default,
.x-toolbar-default .x-btn-button-default-toolbar-small,
.x-toolbar-default .x-btn-inner-default-toolbar-small {
  color: #F8FAFC !important;
}
.x-btn-default-toolbar-small-over,
.x-btn-default-toolbar-small-focus {
  background-color: #0891B2 !important;
  border-color: #06B6D4 !important;
}
.x-tree-view .x-grid-item-selected {
  background-color: rgba(6, 182, 212, 0.15) !important;
  border-color: #06B6D4 !important;
}
.x-tab-active { border-bottom-color: #06B6D4 !important; }
.x-tab-active .x-tab-inner-default { color: #06B6D4 !important; }
.x-window-default .x-window-header-default { background-color: #0F172A !important; }
.x-window-default .x-window-header-text-default { color: #F8FAFC !important; }
#logobar { background: #0F172A !important; padding: 6px 12px !important; }

/* "Powered by Rocket Operations" en esquina inferior derecha */
body::after {
  content: "Powered by Rocket Operations";
  position: fixed;
  bottom: 8px;
  right: 14px;
  font-size: 10px;
  font-family: Helvetica, Arial, sans-serif;
  color: #06B6D4;
  z-index: 9999;
  pointer-events: none;
  opacity: 0.75;
  letter-spacing: 0.5px;
}
CSS

echo "==> Restart pveproxy + smoke test"
systemctl restart pveproxy
sleep 3

CODE=$(curl -sk -o /dev/null -w '%{http_code}' https://localhost:8006/)
TITLE=$(curl -sk https://localhost:8006/ | grep -oE '<title>[^<]+' | head -1)

if [[ "$CODE" != "200" ]]; then
  echo "FAIL: pveproxy responde $CODE"
  exit 1
fi
if [[ "$TITLE" != *"Rocket Operations"* ]]; then
  echo "FAIL: title no rebrandeado ($TITLE)"
  exit 1
fi

# Verificar que el JS principal todavía se sirve sin error 500
JSCODE=$(curl -sk -o /dev/null -w '%{http_code}' "https://localhost:8006/pve2/js/pvemanagerlib.js")
if [[ "$JSCODE" != "200" && "$JSCODE" != "304" ]]; then
  echo "FAIL: pvemanagerlib.js responde $JSCODE"
  exit 1
fi

# desactivar trap — todo OK
trap - EXIT

echo
echo "✓ White-label v2 aplicado y smoke-test pasado."
echo "  HTTP: $CODE · $TITLE"
echo "  Refresca con Ctrl-Shift-R en el navegador."
echo "  Para revertir manualmente: bash /root/branding/uninstall.sh"

# Generar uninstall.sh
cat > "$BRAND_DIR/uninstall.sh" <<UNINST
#!/usr/bin/env bash
set -e
BACKUP_DIR="$BACKUP_DIR"
for tgt in "$PVEMANAGER_JS" "$PVEMANAGER_HTML" "$PVEMANAGER_LOGO" "$PVEMANAGER_HEADER_LOGO" "$PROXMOX_LIB_JS" "$PVE_CSS"; do
  name=\$(basename "\$tgt").orig
  [[ -f "\$BACKUP_DIR/\$name" ]] && cp -p "\$BACKUP_DIR/\$name" "\$tgt" && echo "  restaurado → \$tgt"
done
rm -f /etc/apt/apt.conf.d/99-rocket-rebrand
systemctl restart pveproxy
echo "Original Proxmox restaurado."
UNINST
chmod +x "$BRAND_DIR/uninstall.sh"
