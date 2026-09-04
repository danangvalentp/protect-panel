#!/bin/bash

BRAND_NAME="${BRAND_NAME:-Jhonaley Store}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@JhoanleystoreId}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Proteksi Application API User..."

# ===================================================================
# BAGIAN 3: PROTEKSI APPLICATION API USER
# Strategi: Inject authorize() di Form Request + Middleware + Controller
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Proteksi Application API User"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === LANGKAH 3a: Proteksi via Form Request authorize() ===
# authorize() jalan SEBELUM rules(), jadi ini paling efektif
echo "🔧 Langkah 3a: Inject proteksi ke Form Request..."

FORM_REQUEST_DIR="/var/www/pterodactyl/app/Http/Requests/Api/Application/Users"

if [ -d "$FORM_REQUEST_DIR" ]; then
  for FR_FILE in "$FORM_REQUEST_DIR"/*.php; do
    if [ -f "$FR_FILE" ]; then
      FR_NAME=$(basename "$FR_FILE")
      
      if grep -q "PROTEKSI_JHONALEY_FORMREQ" "$FR_FILE"; then
        echo "⚠️ $FR_NAME sudah diproteksi"
        continue
      fi
      
      cp "$FR_FILE" "${FR_FILE}.bak_${TIMESTAMP}"
      
      python3 << PYEOF_FR
import re

fr_file = "$FR_FILE"
fr_name = "$FR_NAME"

with open(fr_file, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_FORMREQ" in content:
    print(f"⚠️ {fr_name} sudah diproteksi")
    exit(0)

# Cari method authorize()
auth_pattern = r'(public function authorize\s*\(\s*\)[^{]*\{)'
match = re.search(auth_pattern, content)

if match:
    # Inject check di awal authorize()
    inject = '''
        // PROTEKSI_JHONALEY_FORMREQ: Block modifikasi user ID 1
        if (preg_match('#/api/application/users/1(?:\\\?|$|/)#', request()->getPathInfo())) {
            if (in_array(request()->method(), ['PATCH', 'PUT', 'DELETE'])) {
                abort(403, 'Akses ditolak - protect by Jhonaley Tech');
            }
        }
'''
    content = content.replace(match.group(1), match.group(1) + inject)
    
    with open(fr_file, "w") as f:
        f.write(content)
    print(f"✅ {fr_name} diproteksi via authorize()")
else:
    # Tidak ada authorize(), tambahkan method baru
    # Cari class body
    class_pattern = r'(class \w+[^{]*\{)'
    class_match = re.search(class_pattern, content)
    if class_match:
        inject_method = '''

    // PROTEKSI_JHONALEY_FORMREQ: Block modifikasi user ID 1
    public function authorize(): bool
    {
        if (preg_match('#/api/application/users/1(?:\\\?|$|/)#', request()->getPathInfo())) {
            if (in_array(request()->method(), ['PATCH', 'PUT', 'DELETE'])) {
                abort(403, 'Akses ditolak - protect by Jhonaley Tech');
            }
        }
        return true;
    }
'''
        content = content.replace(class_match.group(1), class_match.group(1) + inject_method)
        
        with open(fr_file, "w") as f:
            f.write(content)
        print(f"✅ {fr_name} diproteksi (authorize() baru ditambahkan)")
    else:
        print(f"❌ Gagal menemukan class di {fr_name}")

PYEOF_FR
    fi
  done
else
  echo "⚠️ Direktori Form Request tidak ditemukan: $FORM_REQUEST_DIR"
  echo "🔍 Mencari Form Request..."
  FORM_REQUEST_DIR=$(find /var/www/pterodactyl/app/Http/Requests -type d -iname "Users" -path "*/Application/*" 2>/dev/null | head -1)
  if [ -n "$FORM_REQUEST_DIR" ]; then
    echo "📂 Ditemukan: $FORM_REQUEST_DIR"
    echo "⚠️ Jalankan ulang script setelah path diperbaiki"
  fi
fi

# === LANGKAH 3b: Buat Middleware (layer tambahan) ===
echo ""
echo "🔧 Langkah 3b: Middleware ProtectAdminUser..."
MIDDLEWARE_DIR="/var/www/pterodactyl/app/Http/Middleware"
MIDDLEWARE_FILE="${MIDDLEWARE_DIR}/ProtectAdminUser.php"

cat > "$MIDDLEWARE_FILE" << 'MWEOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class ProtectAdminUser
{
    /**
     * PROTEKSI_JHONALEY_MIDDLEWARE: Block semua akses API ke User ID 1
     */
    public function handle(Request $request, Closure $next)
    {
        $path = $request->getPathInfo();

        if (preg_match('#/api/application/users/1(?:\?|$|/)#', $path)) {
            if (in_array($request->method(), ['PATCH', 'PUT', 'DELETE', 'POST'])) {
                abort(403, 'Akses ditolak - protect by Jhonaley Tech');
            }
        }

        return $next($request);
    }
}
MWEOF

echo "✅ Middleware ProtectAdminUser dibuat"

# === LANGKAH 3c: Register middleware di Kernel.php ===
KERNEL="/var/www/pterodactyl/app/Http/Kernel.php"

if [ -f "$KERNEL" ]; then
  if ! grep -q "ProtectAdminUser" "$KERNEL"; then
    cp "$KERNEL" "${KERNEL}.bak_${TIMESTAMP}"

    python3 << 'PYEOF5'
import re

kernel = "/var/www/pterodactyl/app/Http/Kernel.php"

with open(kernel, "r") as f:
    content = f.read()

if "ProtectAdminUser" in content:
    print("⚠️ Middleware sudah terdaftar di Kernel")
    exit(0)

# Cari protected $middleware array
pattern = r'(protected \$middleware\s*=\s*\[)(.*?)(\];)'
match = re.search(pattern, content, re.DOTALL)

if match:
    existing = match.group(2).rstrip()
    if not existing.rstrip().endswith(','):
        existing = existing.rstrip() + ','
    new_content = match.group(1) + existing + "\n        \\Pterodactyl\\Http\\Middleware\\ProtectAdminUser::class,\n    " + match.group(3)
    content = content[:match.start()] + new_content + content[match.end():]
else:
    # Fallback: cari $middlewareGroups api
    api_pattern = r"('api'\s*=>\s*\[)(.*?)(\],)"
    api_match = re.search(api_pattern, content, re.DOTALL)
    if api_match:
        existing = api_match.group(2).rstrip()
        if not existing.rstrip().endswith(','):
            existing = existing.rstrip() + ','
        new_content = api_match.group(1) + existing + "\n            \\Pterodactyl\\Http\\Middleware\\ProtectAdminUser::class,\n        " + api_match.group(3)
        content = content[:api_match.start()] + new_content + content[api_match.end():]
    else:
        print("❌ Tidak bisa menemukan array middleware di Kernel.php")
        exit(1)

with open(kernel, "w") as f:
    f.write(content)

print("✅ Middleware ProtectAdminUser didaftarkan di Kernel.php")
PYEOF5

  else
    echo "⚠️ Middleware ProtectAdminUser sudah terdaftar di Kernel"
  fi
else
  echo "❌ Kernel.php tidak ditemukan!"
fi

# === LANGKAH 3d: Juga proteksi controller (backup plan) ===
APP_USER_CTRL="/var/www/pterodactyl/app/Http/Controllers/Api/Application/Users/UserController.php"

if [ ! -f "$APP_USER_CTRL" ]; then
  APP_USER_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Api/Application -iname "UserController.php" 2>/dev/null | head -1)
fi

if [ -n "$APP_USER_CTRL" ] && [ -f "$APP_USER_CTRL" ]; then
  APP_BACKUP=$(ls -t "${APP_USER_CTRL}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$APP_BACKUP" ]; then
    cp "$APP_BACKUP" "$APP_USER_CTRL"
  fi
  cp "$APP_USER_CTRL" "${APP_USER_CTRL}.bak_${TIMESTAMP}"

  if ! grep -q "PROTEKSI_JHONALEY_APPUSER" "$APP_USER_CTRL"; then
    python3 << PYEOF6
import re

controller = "$APP_USER_CTRL"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_APPUSER" in content:
    exit(0)

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
        
        new_lines.append("        // PROTEKSI_JHONALEY_APPUSER: Block akses API untuk admin ID 1")
        if 'User \$user' in line or (j > i and any('User \$user' in lines[k] for k in range(i, min(j+1, len(lines))))):
            new_lines.append("        if (isset(\$user) && (int) \$user->id === 1) {")
            new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
            new_lines.append("        }")
        else:
            new_lines.append("        if (preg_match('#/users/1(\\\\?|\$|/|\\\\b)#', \$request->getPathInfo())) {")
            new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
            new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Controller UserController juga diproteksi (backup plan)")
PYEOF6
  fi
fi

echo ""
echo "✅ BAGIAN 3 SELESAI: Proteksi Application API User terpasang (Middleware + Controller)"
echo ""


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$APP_USER_CTRL" "$MIDDLEWARE_FILE"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by Jhonaley Tech|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by Jhonaley Tech|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|Jhonaley Tech|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi Application API User"
