#!/usr/bin/env bash
# proxmox-rebrand · Rocket Operations
#
# White-label de Proxmox VE: logo, colores, footer, sin banner de subscripcion,
# version oculta. Idempotente. Sobrevive a `apt upgrade pve-manager` via APT hook.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/rocketops/proxmox-rebrand/main/install.sh -o /tmp/rebrand.sh
#   bash /tmp/rebrand.sh
#
# Reversion:
#   bash /root/branding/uninstall.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Correr como root."
  exit 1
fi

if [[ ! -f /etc/pve/.version ]]; then
  echo "Esto no parece ser un nodo Proxmox VE. Abortando."
  exit 1
fi

BRAND_DIR="/root/branding"
BACKUP_DIR="$BRAND_DIR/backup"
PVEMANAGER_JS="/usr/share/pve-manager/js/pvemanagerlib.js"
PVEMANAGER_HTML="/usr/share/pve-manager/index.html.tpl"
PVEMANAGER_LOGO="/usr/share/pve-manager/images/logo-128.png"
PROXMOX_LIB_JS="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
PVE_CSS="/usr/share/pve-manager/css/ext6-pve.css"

mkdir -p "$BACKUP_DIR"

backup_once() {
  local src="$1"
  local name="$(basename "$src").orig"
  if [[ -f "$src" && ! -f "$BACKUP_DIR/$name" ]]; then
    cp -p "$src" "$BACKUP_DIR/$name"
    echo "  backup → $BACKUP_DIR/$name"
  fi
}

echo "==> Backup de archivos originales"
backup_once "$PVEMANAGER_JS"
backup_once "$PVEMANAGER_HTML"
backup_once "$PVEMANAGER_LOGO"
backup_once "$PROXMOX_LIB_JS"
backup_once "$PVE_CSS"

echo "==> Logo"
# Convertir SVG a PNG 128x128 si tenemos rsvg-convert; si no, dejar SVG y enlazar.
if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -w 256 -h 70 "$BRAND_DIR/logo.svg" -o "$PVEMANAGER_LOGO"
else
  # Fallback: copiar SVG como .png (Proxmox sirve binario directo, navegadores modernos aceptan)
  cp "$BRAND_DIR/logo.svg" "$PVEMANAGER_LOGO"
fi

echo "==> Title de la pestaña"
sed -i 's|<title>[^<]*</title>|<title>Rocket Operations · Console</title>|g' "$PVEMANAGER_HTML"

echo "==> Strings 'Proxmox VE' → 'Rocket Operations · Console'"
# El header dice "Proxmox Virtual Environment X.Y.Z" — sustituir por nuestra cadena sin versión.
sed -i "s|Proxmox Virtual Environment|Rocket Operations · Console|g" "$PVEMANAGER_JS"
# Algunos paneles usan "Proxmox VE" suelto.
sed -i "s|Proxmox VE|Rocket Operations|g" "$PVEMANAGER_JS"

echo "==> Ocultar versión en el header"
# El widget que muestra version: PVE.Workspace o similar.
# Estrategia: reemplazar "version: " seguido de la cadena PVE_VERSION por cadena vacia.
sed -i "s|nodename: nodename, version: pveversion|nodename: nodename, version: ''|g" "$PVEMANAGER_JS" || true
# Footer "Powered by …"
sed -i "s|html: 'Powered by [^']*'|html: 'Powered by <a href=\"#\" style=\"color:#06B6D4;text-decoration:none\">Rocket Operations</a>'|g" "$PVEMANAGER_JS" || true

echo "==> Quitar banner 'No valid subscription'"
# Patch clásico: convertir el Ext.Msg.show del nag en un void({...}).
sed -Ezi "s/(\s+Ext\.Msg\.show\(\{\s+title: gettext\('No valid sub)/                void\({ \/\/\1/g" "$PROXMOX_LIB_JS"

echo "==> CSS — paleta Aurora"
cat > "$BRAND_DIR/aurora.css" <<'CSS'
/* Rocket Operations · Aurora theme */
/* Header bar */
.x-toolbar-default { background-color: #0F172A !important; border-bottom-color: #06B6D4 !important; }
.x-toolbar-default .x-toolbar-text-default,
.x-toolbar-default .x-btn-button-default-toolbar-small,
.x-toolbar-default .x-btn-inner-default-toolbar-small {
  color: #F8FAFC !important;
}
/* Buttons hover/focus */
.x-btn-default-toolbar-small-over,
.x-btn-default-toolbar-small-focus {
  background-color: #0891B2 !important;
  border-color: #06B6D4 !important;
}
/* Tree selected node */
.x-tree-view .x-grid-item-selected {
  background-color: rgba(6, 182, 212, 0.15) !important;
  border-color: #06B6D4 !important;
}
/* Tabs active */
.x-tab-active {
  border-bottom-color: #06B6D4 !important;
}
.x-tab-active .x-tab-inner-default {
  color: #06B6D4 !important;
}
/* Login window */
.x-window-default .x-window-header-default {
  background-color: #0F172A !important;
}
.x-window-default .x-window-header-text-default {
  color: #F8FAFC !important;
}
/* Logo container — un poco mas claro */
#logobar { background: #0F172A !important; padding: 6px 12px !important; }
CSS

# Append a la CSS principal si no esta ya
if ! grep -q "Rocket Operations · Aurora theme" "$PVE_CSS"; then
  cat "$BRAND_DIR/aurora.css" >> "$PVE_CSS"
  echo "  CSS agregada a $PVE_CSS"
fi

echo "==> APT hook (sobrevive a apt upgrade)"
cat > /etc/apt/apt.conf.d/99-rocket-rebrand <<EOF
DPkg::Post-Invoke { "if [ -x $BRAND_DIR/install.sh ]; then $BRAND_DIR/install.sh --reapply >/dev/null 2>&1 || true; fi"; };
EOF

echo "==> Uninstall script"
cat > "$BRAND_DIR/uninstall.sh" <<'UNINST'
#!/usr/bin/env bash
set -e
BRAND_DIR="/root/branding"
BACKUP_DIR="$BRAND_DIR/backup"

restore() {
  local target="$1"
  local name="$(basename "$target").orig"
  if [[ -f "$BACKUP_DIR/$name" ]]; then
    cp -p "$BACKUP_DIR/$name" "$target"
    echo "  restaurado → $target"
  fi
}

restore "/usr/share/pve-manager/js/pvemanagerlib.js"
restore "/usr/share/pve-manager/index.html.tpl"
restore "/usr/share/pve-manager/images/logo-128.png"
restore "/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
restore "/usr/share/pve-manager/css/ext6-pve.css"

rm -f /etc/apt/apt.conf.d/99-rocket-rebrand

systemctl restart pveproxy
echo "Original Proxmox restaurado. Ctrl-F5 en el navegador."
UNINST
chmod +x "$BRAND_DIR/uninstall.sh"

echo "==> Reiniciando pveproxy"
systemctl restart pveproxy

echo
echo "✓ White-label aplicado."
echo "  Refresca con Ctrl-F5 en el navegador."
echo "  Para revertir: bash $BRAND_DIR/uninstall.sh"
