#!/bin/bash

BRAND_NAME="${BRAND_NAME:-Jhonaley Store}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@JhoanleystoreId}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Proteksi Nodes (sidebar + akses)..."

# ===================================================================
# BAGIAN 1: PROTEKSI NODES (Sembunyikan + Block Akses)
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 1: Proteksi Nodes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === Restore & proteksi NodeViewController ===
CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeViewController.php"
LATEST_BACKUP=$(ls -t "${CONTROLLER}.bak_"* 2>/dev/null | tail -1)

if [ -n "$LATEST_BACKUP" ]; then
  cp "$LATEST_BACKUP" "$CONTROLLER"
  echo "📦 NodeViewController di-restore dari backup: $LATEST_BACKUP"
else
  echo "⚠️ Tidak ada backup NodeViewController, menggunakan file saat ini"
fi

cp "$CONTROLLER" "${CONTROLLER}.bak_${TIMESTAMP}"

python3 << 'PYEOF'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeViewController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Proteksi sudah ada di NodeViewController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke NodeViewController")
PYEOF

echo ""
grep -n "PROTEKSI_JHONALEY" "$CONTROLLER"

# === Sembunyikan menu Nodes di sidebar ===
echo ""
echo "🔧 Menyembunyikan menu Nodes dari sidebar..."

SIDEBAR_FILES=(
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"
)

SIDEBAR_FOUND=""
for SF in "${SIDEBAR_FILES[@]}"; do
  if [ -f "$SF" ]; then
    SIDEBAR_FOUND="$SF"
    break
  fi
done

if [ -z "$SIDEBAR_FOUND" ]; then
  SIDEBAR_FOUND=$(grep -rl "admin.nodes" /var/www/pterodactyl/resources/views/layouts/ 2>/dev/null | head -1)
  if [ -z "$SIDEBAR_FOUND" ]; then
    SIDEBAR_FOUND=$(grep -rl "admin.nodes" /var/www/pterodactyl/resources/views/partials/ 2>/dev/null | head -1)
  fi
fi

if [ -n "$SIDEBAR_FOUND" ]; then
  if [ ! -f "${SIDEBAR_FOUND}.bak_${TIMESTAMP}" ]; then
    cp "$SIDEBAR_FOUND" "${SIDEBAR_FOUND}.bak_${TIMESTAMP}"
  fi
  echo "📂 Sidebar ditemukan: $SIDEBAR_FOUND"

  python3 << PYEOF2
sidebar = "$SIDEBAR_FOUND"

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_NODES_SIDEBAR" in content:
    print("⚠️ Sidebar Nodes sudah diproteksi")
    exit(0)

import re

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]

    if ('admin.nodes' in line or "route('admin.nodes')" in line) and 'admin.nodes.view' not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1

        if li_start >= 0:
            new_lines.insert(li_start, "{{-- PROTEKSI_NODES_SIDEBAR --}}")
            new_lines.insert(li_start, "@if((int) Auth::user()->id === 1)")

            new_lines.append(line)
            i += 1

            li_depth = 1
            while i < len(lines) and li_depth > 0:
                curr = lines[i]
                li_depth += curr.count('<li') - curr.count('</li')
                new_lines.append(curr)
                i += 1

            new_lines.append("@endif")
            continue

    new_lines.append(line)
    i += 1

with open(sidebar, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Menu Nodes disembunyikan dari sidebar")
PYEOF2

else
  echo "⚠️ File sidebar tidak ditemukan."
fi

# === Proteksi NodeController (halaman list nodes) ===
NODE_LIST="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
if [ -f "$NODE_LIST" ]; then
  if ! grep -q "PROTEKSI_JHONALEY" "$NODE_LIST"; then
    cp "$NODE_LIST" "${NODE_LIST}.bak_${TIMESTAMP}"
    
    python3 << 'PYEOF3'
controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Sudah ada proteksi")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

import re
lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ NodeController juga diproteksi")
PYEOF3
  else
    echo "⚠️ NodeController sudah diproteksi"
  fi
fi

echo ""
echo "✅ BAGIAN 1 SELESAI: Proteksi Nodes terpasang"
echo ""


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$CONTROLLER" "$NODE_LIST"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by Jhonaley Tech|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by Jhonaley Tech|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|Jhonaley Tech|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi Nodes (sidebar + akses)"
