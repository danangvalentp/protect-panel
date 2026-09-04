#!/bin/bash

BRAND_NAME="${BRAND_NAME:-Jhonaley Store}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@JhoanleystoreId}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Proteksi API Key (Admin)..."

# ===================================================================
# BAGIAN 4: PROTEKSI API KEY - Block buat key atas nama User ID 1
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 4: Block buat API key atas nama User ID 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

API_CTRL="/var/www/pterodactyl/app/Http/Controllers/Admin/ApiController.php"

if [ ! -f "$API_CTRL" ]; then
  API_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Admin -maxdepth 1 -iname "*api*" -name "*.php" 2>/dev/null | head -1)
fi

if [ -n "$API_CTRL" ] && [ -f "$API_CTRL" ]; then
  echo "📂 ApiController ditemukan: $API_CTRL"

  API_BACKUP=$(ls -t "${API_CTRL}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$API_BACKUP" ]; then
    cp "$API_BACKUP" "$API_CTRL"
    echo "📦 Restore dari backup: $API_BACKUP"
  fi

  cp "$API_CTRL" "${API_CTRL}.bak_${TIMESTAMP}"

  export API_CTRL_PATH="$API_CTRL"
  python3 << 'PYEOF7'
import re
import os

controller = os.environ["API_CTRL_PATH"]

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_APIKEY" in content:
    print("⚠️ Proteksi sudah ada di ApiController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    use_pattern = r'(use Pterodactyl\\\\Http\\\\Controllers\\\\Controller;)'
    if re.search(use_pattern, content):
        content = re.sub(use_pattern, r'\1\nuse Illuminate\\Support\\Facades\\Auth;', content)
    else:
        content = re.sub(r'(use [^;]+;)(\s*class )', r'\1\nuse Illuminate\\Support\\Facades\\Auth;\2', content)

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    # Inject di method index
    if re.search(r'public function index', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY_APIKEY: Setiap admin hanya lihat key milik sendiri")
        new_lines.append("        if (Auth::user() && (int) Auth::user()->id !== 1) {")
        new_lines.append("            $keys = \\Pterodactyl\\Models\\ApiKey::where('user_id', (int) Auth::user()->id)")
        new_lines.append("                ->where('key_type', \\Pterodactyl\\Models\\ApiKey::TYPE_APPLICATION)")
        new_lines.append("                ->get();")
        new_lines.append("            return view('admin.api.index', ['keys' => $keys]);")
        new_lines.append("        }")
        
        if j > i:
            i = j
    
    # Inject di method store
    if re.search(r'public function store', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY_APIKEY: Block buat key atas nama User ID 1")
        new_lines.append("        $targetUserId = (int) ($request->input('user_id') ?? $request->input('user') ?? 0);")
        new_lines.append("        if ($targetUserId === 1 && (!Auth::user() || (int) Auth::user()->id !== 1)) {")
        new_lines.append("            abort(403, 'Tidak bisa membuat API key atas nama User ID 1 - protect by Jhonaley Tech');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    
    # Inject di method delete/destroy
    if re.search(r'public function (delete|destroy)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY_APIKEY: Block hapus key milik User ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            $key = $request->route('id') ?? $request->route('key');")
        new_lines.append("            if ($key) {")
        new_lines.append("                $apiKey = \\Pterodactyl\\Models\\ApiKey::find($key);")
        new_lines.append("                if ($apiKey && (int) $apiKey->user_id === 1) {")
        new_lines.append("                    abort(403, 'Tidak bisa menghapus API key milik User ID 1 - protect by Jhonaley Tech');")
        new_lines.append("                }")
        new_lines.append("            }")
        new_lines.append("        }")
        
        if j > i:
            i = j
    
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi API key berhasil diinjeksi ke ApiController")
PYEOF7

  echo ""
  grep -n "PROTEKSI_JHONALEY_APIKEY" "$API_CTRL"
else
  echo "⚠️ ApiController tidak ditemukan, skip."
fi

echo ""
echo "✅ BAGIAN 4 SELESAI: Proteksi API key terpasang"
echo ""

# ===================================================================
# ===================================================================
# PROTEKSI BLADE VIEW: API INDEX - filter key per admin
# ===================================================================
API_BLADE="/var/www/pterodactyl/resources/views/admin/api/index.blade.php"

if [ ! -f "$API_BLADE" ]; then
  API_BLADE=$(find /var/www/pterodactyl/resources/views/admin -path "*/api/index*" -name "*.blade.php" 2>/dev/null | head -1)
fi

if [ -n "$API_BLADE" ] && [ -f "$API_BLADE" ]; then
  echo "📂 API Blade view ditemukan: $API_BLADE"

  API_BLADE_BACKUP=$(ls -t "${API_BLADE}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$API_BLADE_BACKUP" ]; then
    cp "$API_BLADE_BACKUP" "$API_BLADE"
    echo "📦 Restore dari backup: $API_BLADE_BACKUP"
  fi

  cp "$API_BLADE" "${API_BLADE}.bak_${TIMESTAMP}"

  export API_BLADE_PATH="$API_BLADE"
  python3 << 'PYEOF_BLADE'
import re
import os

blade_file = os.environ["API_BLADE_PATH"]

with open(blade_file, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_APIKEY_BLADE" in content:
    print("⚠️ Proteksi Blade sudah ada")
    exit(0)

# Cari loop @foreach yang menampilkan keys
foreach_pattern = r'(@foreach\s*\(\s*\$\w+\s+as\s+\$(\w+)\s*\))'
match = re.search(foreach_pattern, content)

if match:
    original_foreach = match.group(0)
    
    filter_code = """
{{-- PROTEKSI_JHONALEY_APIKEY_BLADE: Setiap admin hanya lihat key sendiri --}}
@php
    $__currentUserId = (int) Auth::user()->id;
    if ($__currentUserId !== 1) {
        $keys = $keys->filter(function($item) use ($__currentUserId) {
            return (int) $item->user_id === $__currentUserId;
        });
    }
@endphp
""" + original_foreach
    
    content = content.replace(original_foreach, filter_code, 1)
    
    with open(blade_file, "w") as f:
        f.write(content)
    print("✅ Proteksi Blade view API berhasil diterapkan")
else:
    foreach_generic = re.search(r'(@foreach\s*\([^)]+\))', content)
    if foreach_generic:
        original = foreach_generic.group(0)
        filter_code = """
{{-- PROTEKSI_JHONALEY_APIKEY_BLADE: Setiap admin hanya lihat key sendiri --}}
@php
    $__currentUserId = (int) Auth::user()->id;
    if ($__currentUserId !== 1) {
        $keys = isset($keys) ? $keys->filter(function($item) use ($__currentUserId) {
            return (int) ($item->user_id ?? 0) === $__currentUserId;
        }) : collect([]);
    }
@endphp
""" + original
        content = content.replace(original, filter_code, 1)
        
        with open(blade_file, "w") as f:
            f.write(content)
        print("✅ Proteksi Blade view API (fallback) berhasil diterapkan")
    else:
        print("⚠️ Tidak menemukan @foreach di Blade view")

PYEOF_BLADE
else
  echo "⚠️ Blade view API tidak ditemukan"
fi


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$API_CTRL"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by Jhonaley Tech|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by Jhonaley Tech|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|Jhonaley Tech|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi API Key (Admin)"
