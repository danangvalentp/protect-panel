#!/bin/bash

set -e

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

BRAND_NAME="${BRAND_NAME:-Jhonaley Store}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@JhoanleystoreId}"
BOT_LINK="${BOT_LINK:-@upgradeuser_bot}"
WELCOME_TITLE="${WELCOME_TITLE:-Welcome To Server $BRAND_NAME}"
WELCOME_MESSAGE="${WELCOME_MESSAGE:-Butuh panel legal yang anti mokad? langsung aja ke <a href=\"https://t.me/upgradeuser_bot\">@upgradeuser_bot</a>. Jangan Lupa join Channel <a href=\"https://t.me/jhonaleytesti3\">@jhonaleytesti3</a>.}"

TELEGRAM_USERNAME="${CONTACT_TELEGRAM#@}"
BOT_USERNAME="${BOT_LINK#@}"

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

js_escape() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e "s/'/\\\\'/g"
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

BRAND_NAME_HTML=$(html_escape "$BRAND_NAME")
BRAND_TEXT_HTML=$(html_escape "$BRAND_TEXT")
CONTACT_TELEGRAM_HTML=$(html_escape "$CONTACT_TELEGRAM")
BOT_LINK_HTML=$(html_escape "$BOT_LINK")
BRAND_NAME_JS=$(js_escape "$BRAND_NAME")
CONTACT_TELEGRAM_JS=$(js_escape "$CONTACT_TELEGRAM")
WELCOME_TITLE_JS=$(js_escape "$WELCOME_TITLE")
WELCOME_MESSAGE_JS=$(js_escape "$WELCOME_MESSAGE")
SAFE_TITLE=$(sed_escape "${PANEL_TITLE:-Pterodactyl - $BRAND_NAME}")

can_modify_file() {
  local file="$1"
  if [ -f "$file" ] && [ -w "$file" ]; then
    return 0
  fi

  local dir
  dir=$(dirname "$file")
  [ -w "$dir" ]
}

write_temp_to_target() {
  local temp_file="$1"
  local target_file="$2"
  local label="$3"

  if [ -f "$target_file" ]; then
    chmod u+w "$target_file" 2>/dev/null || true
    chown --reference="$target_file" "$temp_file" 2>/dev/null || true
    chmod --reference="$target_file" "$temp_file" 2>/dev/null || true
  fi

  if cat "$temp_file" > "$target_file" 2>/dev/null; then
    return 0
  fi

  if cp "$temp_file" "$target_file" 2>/dev/null; then
    return 0
  fi

  echo "⚠️ Tidak bisa menulis ke $label, skip. Cek permission file/folder target."
  return 1
}

remove_block_by_markers() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip cleanup branding di $file karena tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)
  awk -v start="$start_marker" -v end="$end_marker" '
    index($0, start) { skip=1; next }
    skip && index($0, end) { skip=0; next }
    !skip { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

cleanup_old_branding() {
  local file="$1"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip branding cleanup di $file karena tidak writable"
    return 0
  fi

  remove_block_by_markers "$file" "<!-- BRANDING_JHONALEY_START -->" "<!-- BRANDING_JHONALEY_END -->"
  remove_block_by_markers "$file" "<!-- BRANDING_JHONALEY: Custom Branding -->" "</style>"

  tmp_file=$(mktemp)
  awk '
    BEGIN { skip=0; depth=0; seen_div=0 }
    /<!-- BRANDING_JHONALEY: Footer -->/ { skip=1; depth=0; seen_div=0; next }
    skip {
      line=$0
      opens=gsub(/<div[^>]*>/, "&", line)
      closes=gsub(/<\/div>/, "&", line)
      if (opens > 0) {
        depth += opens
        seen_div = 1
      }
      if (closes > 0) {
        depth -= closes
      }
      if (seen_div && depth <= 0) {
        skip=0
      }
      next
    }
    { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

inject_before_closing() {
  local file="$1"
  local snippet_file="$2"
  local label="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip inject ke $label karena file tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)

  if grep -q "</body>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/body>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </body> di $label"
  elif grep -q "</html>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/html>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </html> di $label"
  else
    cat "$snippet_file" > "$tmp_file"
    cat "$file" >> "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten ditambahkan di akhir $label"
  fi

  rm -f "$tmp_file"
}

echo "==========================================="
echo "🔒 PROTECT 5A: Sembunyikan & Block Menu Nests"
echo "==========================================="
echo ""
echo "🚀 Memasang proteksi Nests (Sembunyikan + Block Akses)..."
echo ""

# === LANGKAH 1: Restore NestController dari backup asli ===
CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
LATEST_BACKUP=$(ls -t "${CONTROLLER}.bak_"* 2>/dev/null | tail -1)

if [ -n "$LATEST_BACKUP" ]; then
  cp "$LATEST_BACKUP" "$CONTROLLER"
  echo "📦 Controller di-restore dari backup paling awal: $LATEST_BACKUP"
else
  echo "⚠️ Tidak ada backup, menggunakan file saat ini"
fi

cp "$CONTROLLER" "${CONTROLLER}.bak_${TIMESTAMP}"

# === LANGKAH 2: Inject proteksi ke NestController ===
python3 << 'PYEOF'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Proteksi sudah ada di NestController")
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

print("✅ Proteksi berhasil diinjeksi ke NestController")
PYEOF

echo ""
echo "📋 Verifikasi NestController (cari PROTEKSI):"
grep -n "PROTEKSI_JHONALEY" "$CONTROLLER"
echo ""

# === LANGKAH 3: Proteksi juga EggController (halaman egg di dalam nest) ===
EGG_CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/EggController.php"
if [ -f "$EGG_CONTROLLER" ]; then
  if ! grep -q "PROTEKSI_JHONALEY" "$EGG_CONTROLLER"; then
    cp "$EGG_CONTROLLER" "${EGG_CONTROLLER}.bak_${TIMESTAMP}"

    python3 << 'PYEOF2'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/EggController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Sudah ada proteksi di EggController")
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

print("✅ EggController juga diproteksi")
PYEOF2
  else
    echo "⚠️ EggController sudah diproteksi"
  fi
fi

# === LANGKAH 4: Sembunyikan menu Nests di sidebar ===
echo "🔧 Menyembunyikan menu Nests dari sidebar..."

SIDEBAR_FILES=(
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"
)

SIDEBAR_FOUND=""
for SF in "${SIDEBAR_FILES[@]}"; do
  if [ -f "$SF" ] && grep -q "admin.nests" "$SF" 2>/dev/null; then
    SIDEBAR_FOUND="$SF"
    break
  fi
done

if [ -z "$SIDEBAR_FOUND" ]; then
  SIDEBAR_FOUND=$(grep -rl "admin.nests" /var/www/pterodactyl/resources/views/partials/ 2>/dev/null | head -1)
  if [ -z "$SIDEBAR_FOUND" ]; then
    SIDEBAR_FOUND=$(grep -rl "admin.nests" /var/www/pterodactyl/resources/views/layouts/ 2>/dev/null | head -1)
  fi
fi

if [ -n "$SIDEBAR_FOUND" ]; then
  echo "📂 Sidebar ditemukan: $SIDEBAR_FOUND"

  echo "📋 Baris terkait Nests di sidebar:"
  grep -n -i "nest" "$SIDEBAR_FOUND" | head -10
  echo ""

  if ! can_modify_file "$SIDEBAR_FOUND"; then
    echo "⚠️ Sidebar tidak writable, skip sembunyikan menu Nests."
  else
    cp "$SIDEBAR_FOUND" "${SIDEBAR_FOUND}.bak_${TIMESTAMP}" 2>/dev/null || true

    SIDEBAR_TEMP=$(mktemp)
    export SIDEBAR_FOUND SIDEBAR_TEMP
    python3 << 'PYEOF3'
import os

sidebar = os.environ["SIDEBAR_FOUND"]
sidebar_temp = os.environ["SIDEBAR_TEMP"]

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_NESTS_SIDEBAR" in content:
    print("⚠️ Sidebar Nests sudah diproteksi")
    raise SystemExit(0)

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]

    if ('admin.nests' in line or "route('admin.nests')" in line) and 'admin.nests.view' not in line and 'admin.nests.egg' not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1

        if li_start >= 0:
            new_lines.insert(li_start, "{{-- PROTEKSI_NESTS_SIDEBAR --}}")
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

with open(sidebar_temp, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Temp sidebar berhasil dibuat")
PYEOF3

    if write_temp_to_target "$SIDEBAR_TEMP" "$SIDEBAR_FOUND" "$SIDEBAR_FOUND"; then
      echo "✅ Menu Nests disembunyikan dari sidebar"
    else
      echo "⚠️ Gagal menulis perubahan sidebar, skip langkah sembunyikan menu."
    fi

    rm -f "$SIDEBAR_TEMP"
  fi
else
  echo "⚠️ File sidebar tidak ditemukan."
fi

# === LANGKAH 5: Cache clear di-handle oleh controller ===
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller setelah install selesai"

echo ""
echo "==========================================="
echo "✅ Proteksi Nests LENGKAP selesai!"
echo "==========================================="
echo "🔒 Menu Nests disembunyikan dari sidebar (selain ID 1)"
echo "🔒 Akses /admin/nests diblock (selain ID 1)"
echo "🔒 Akses /admin/nests/view/* diblock (selain ID 1)"
echo "🔒 EggController juga diproteksi"
echo "🚀 Panel tetap normal, server tetap jalan"
echo "==========================================="
echo ""
echo "⚠️ Jika ada masalah, restore:"
echo "   cp ${CONTROLLER}.bak_${TIMESTAMP} $CONTROLLER"
if [ -n "$SIDEBAR_FOUND" ]; then
  echo "   cp ${SIDEBAR_FOUND}.bak_${TIMESTAMP} $SIDEBAR_FOUND"
fi
echo "   cd /var/www/pterodactyl && php artisan view:clear && php artisan route:clear"

# ===================================================================
# RE-INJECT SIDEBAR PROTECT MANAGER (jika hilang setelah modifikasi admin.blade.php)
# ===================================================================
ADMIN_LAYOUT=""
for CANDIDATE in \
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"; do
  if [ -f "$CANDIDATE" ]; then
    ADMIN_LAYOUT="$CANDIDATE"
    break
  fi
done

if [ -f "$ADMIN_LAYOUT" ] && ! grep -q "PROTEKSI_JHONALEY_MASTER_SIDEBAR" "$ADMIN_LAYOUT" 2>/dev/null; then
  echo "🔧 Re-inject sidebar Protect Manager..."

  SIDEBAR_SNIPPET=$(mktemp)
  cat > "$SIDEBAR_SNIPPET" << 'SIDEBAR_PM_EOF'
                {{-- PROTEKSI_JHONALEY_MASTER_SIDEBAR: Protect Manager Menu --}}
                @if(Auth::user() && Auth::user()->id === 1)
                <li class="{{ Route::currentRouteName() === 'admin.protect-manager' ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>
                @endif
                {{-- END PROTEKSI_JHONALEY_MASTER_SIDEBAR --}}
SIDEBAR_PM_EOF

  INSERT_LINE=""
  SETTINGS_LINE=$(grep -n "admin.settings\|Configuration\|Settings\|settings" "$ADMIN_LAYOUT" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$SETTINGS_LINE" ]; then
    INSERT_LINE=$((SETTINGS_LINE - 1))
    while [ "$INSERT_LINE" -gt 0 ]; do
      if sed -n "${INSERT_LINE}p" "$ADMIN_LAYOUT" | grep -q "<li"; then
        break
      fi
      INSERT_LINE=$((INSERT_LINE - 1))
    done
  fi

  if [ -z "$INSERT_LINE" ] || [ "$INSERT_LINE" -le 0 ]; then
    INSERT_LINE=$(grep -n "</ul>" "$ADMIN_LAYOUT" | tail -1 | cut -d: -f1)
    if [ -n "$INSERT_LINE" ]; then
      INSERT_LINE=$((INSERT_LINE - 1))
    fi
  fi

  if [ -n "$INSERT_LINE" ] && [ "$INSERT_LINE" -gt 0 ]; then
    TEMP_LAYOUT=$(mktemp)
    head -n "$INSERT_LINE" "$ADMIN_LAYOUT" > "$TEMP_LAYOUT"
    cat "$SIDEBAR_SNIPPET" >> "$TEMP_LAYOUT"
    tail -n +"$((INSERT_LINE + 1))" "$ADMIN_LAYOUT" >> "$TEMP_LAYOUT"
    if cat "$TEMP_LAYOUT" > "$ADMIN_LAYOUT" 2>/dev/null; then
      echo "✅ Sidebar Protect Manager berhasil di-re-inject"
    else
      echo "⚠️ Gagal re-inject sidebar, skip"
    fi
    rm -f "$TEMP_LAYOUT"
  else
    echo "⚠️ Tidak bisa menemukan posisi sidebar untuk re-inject"
  fi
  rm -f "$SIDEBAR_SNIPPET"
fi

# ===================================================================
# CLEAR CACHE - paksa clear di sini agar welcome banner langsung tampil
# ===================================================================
if [ -d /var/www/pterodactyl ]; then
  cd /var/www/pterodactyl
  php artisan view:clear 2>/dev/null || true
  php artisan cache:clear 2>/dev/null || true
  rm -rf /var/www/pterodactyl/storage/framework/views/*.php 2>/dev/null || true
  echo "✅ View & compiled blade cache dibersihkan"
fi


echo ""
echo "✅ PROTECT 5A SELESAI: Menu Nests disembunyikan & diblokir (selain ID 1)"

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_ADMIN" ]; then
  for F in "$CONTROLLER" "$EGG_CONTROLLER"; do
    [ -f "$F" ] || continue
    python3 - "$F" "$DENY_MSG_ADMIN" << 'PYABORT'
import sys, re
path, msg = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(
    r"abort\(\s*403\s*,\s*(['\"])(?:\\\1|(?!\1).)*\1\s*\)",
    "abort(403, " + repr(msg) + ")",
    content
)
if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✏️  Pesan akses ditolak dikustomisasi di " + path)
PYABORT
  done
fi
