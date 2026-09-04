#!/bin/bash

BRAND_NAME="${BRAND_NAME:-Jhonaley Store}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@JhoanleystoreId}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Proteksi Locations (sidebar + akses)..."

# ===================================================================
# BAGIAN 5: PROTEKSI LOCATIONS (Sembunyikan + Block Akses)
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 5: Proteksi Locations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === Sembunyikan menu Locations di sidebar ===
echo "🔧 Menyembunyikan menu Locations dari sidebar..."

# Re-use sidebar file dari BAGIAN 1
LOC_SIDEBAR=""
for SF in "/var/www/pterodactyl/resources/views/layouts/admin.blade.php" "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"; do
  if [ -f "$SF" ]; then
    LOC_SIDEBAR="$SF"
    break
  fi
done

if [ -z "$LOC_SIDEBAR" ]; then
  LOC_SIDEBAR=$(grep -rl "admin.locations" /var/www/pterodactyl/resources/views/ 2>/dev/null | head -1)
fi

if [ -n "$LOC_SIDEBAR" ] && [ -f "$LOC_SIDEBAR" ]; then
  if grep -q "PROTEKSI_LOCATIONS_SIDEBAR" "$LOC_SIDEBAR"; then
    echo "⚠️ Sidebar Locations sudah diproteksi"
  else
    if [ ! -f "${LOC_SIDEBAR}.bak_${TIMESTAMP}" ]; then
      cp "$LOC_SIDEBAR" "${LOC_SIDEBAR}.bak_${TIMESTAMP}"
    fi

    python3 << PYEOF_LOC_SIDEBAR
sidebar = "$LOC_SIDEBAR"

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_LOCATIONS_SIDEBAR" in content:
    print("⚠️ Sidebar Locations sudah diproteksi")
    exit(0)

import re

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]

    if ('admin.locations' in line or "route('admin.locations')" in line) and 'admin.locations.view' not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1

        if li_start >= 0:
            new_lines.insert(li_start, "{{-- PROTEKSI_LOCATIONS_SIDEBAR --}}")
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

print("✅ Menu Locations disembunyikan dari sidebar")
PYEOF_LOC_SIDEBAR
  fi
else
  echo "⚠️ File sidebar tidak ditemukan untuk Locations"
fi

# === Proteksi LocationController ===
echo ""
echo "🔧 Memproteksi LocationController..."

LOC_CTRL="/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"

if [ ! -f "$LOC_CTRL" ]; then
  LOC_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Admin -maxdepth 1 -iname "LocationController.php" 2>/dev/null | head -1)
fi

if [ -n "$LOC_CTRL" ] && [ -f "$LOC_CTRL" ]; then
  echo "📂 LocationController ditemukan: $LOC_CTRL"

  if grep -q "PROTEKSI_JHONALEY_LOCATION" "$LOC_CTRL"; then
    echo "⚠️ LocationController sudah diproteksi"
  else
    LOC_BACKUP=$(ls -t "${LOC_CTRL}.bak_"* 2>/dev/null | tail -1)
    if [ -n "$LOC_BACKUP" ]; then
      cp "$LOC_BACKUP" "$LOC_CTRL"
      echo "📦 Restore dari backup: $LOC_BACKUP"
    fi

    cp "$LOC_CTRL" "${LOC_CTRL}.bak_${TIMESTAMP}"

    python3 << 'PYEOF_LOC_CTRL'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"

# Coba path default, kalau tidak ada cari
import os
if not os.path.exists(controller):
    import subprocess
    result = subprocess.run(
        ["find", "/var/www/pterodactyl/app/Http/Controllers/Admin", "-maxdepth", "1", "-iname", "LocationController.php"],
        capture_output=True, text=True
    )
    if result.stdout.strip():
        controller = result.stdout.strip().split("\n")[0]
    else:
        print("❌ LocationController tidak ditemukan")
        exit(1)

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_LOCATION" in content:
    print("⚠️ Sudah ada proteksi")
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
        
        new_lines.append("        // PROTEKSI_JHONALEY_LOCATION: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke LocationController")
PYEOF_LOC_CTRL
  fi
else
  echo "⚠️ LocationController tidak ditemukan, skip."
fi

echo ""
echo "✅ BAGIAN 5 SELESAI: Proteksi Locations terpasang"
echo ""


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$LOC_CTRL"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by Jhonaley Tech|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by Jhonaley Tech|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|Jhonaley Tech|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi Locations (sidebar + akses)"
