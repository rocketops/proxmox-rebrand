# proxmox-rebrand · Rocket Operations

White-label de Proxmox VE para Rocket Operations. Reemplaza marca, paleta de colores, footer, oculta versión y elimina el banner "No valid subscription". Idempotente y sobrevive a `apt upgrade pve-manager`.

**Owner legal:** Rocket Operations / Los Infinitos. Este repo se distribuye sólo para uso interno; Proxmox VE es marca registrada de Proxmox Server Solutions GmbH.

## Instalación

Desde el **Web UI Shell** del Proxmox (`Datacenter → nodo → Shell`):

```bash
curl -fsSL https://raw.githubusercontent.com/rocketops/proxmox-rebrand/main/bootstrap.sh | bash
```

Refresca el navegador con `Ctrl-F5`.

## Lo que cambia

- **Logo:** SVG "RO Rocket Operations" en cyan sobre dark navy.
- **Header / título:** "Rocket Operations · Console" (sin "Proxmox VE").
- **Versión:** oculta del header.
- **Footer:** `Powered by Rocket Operations` con link cyan.
- **Colores (paleta Aurora):**
  - Header: `#0F172A` (slate-900)
  - Texto: `#F8FAFC` (slate-50)
  - Accent: `#06B6D4` (cyan-500)
  - Hover: `#0891B2` (cyan-600)
- **Subscription nag:** eliminado.

## Reversión

```bash
bash /root/branding/uninstall.sh
```

Restaura los originales desde `/root/branding/backup/` y elimina el APT hook.

## Cómo sobrevive a `apt upgrade`

`install.sh` instala un hook en `/etc/apt/apt.conf.d/99-rocket-rebrand` que se ejecuta tras cada `apt` invoke. Si Proxmox restaura un archivo durante un upgrade, el hook re-aplica el rebrand.

## Compatibilidad

Probado en Proxmox VE 8.x. Para versiones anteriores los selectores CSS pueden cambiar — revisar `aurora.css` generado en `/root/branding/`.

## Archivos modificados

- `/usr/share/pve-manager/js/pvemanagerlib.js`
- `/usr/share/pve-manager/index.html.tpl`
- `/usr/share/pve-manager/images/logo-128.png`
- `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js`
- `/usr/share/pve-manager/css/ext6-pve.css`

Backups en `/root/branding/backup/` (sólo se crean en el primer run, no se sobreescriben).
