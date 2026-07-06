#!/bin/bash

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚑 INSTALLPROTECT12 SAFE RECOVERY"
echo "==========================================="
echo "Membersihkan patch Protect12 lama yang bisa bikin 500."
echo "Setelah itu hanya pasang gembok sidebar Nodes + Locations."
echo ""

php_lint_ok() {
  [ -n "$1" ] && [ -f "$1" ] && php -l "$1" >/dev/null 2>&1
}

restore_clean_backup() {
  local target="$1"
  local backup
  [ -n "$target" ] && [ -f "$target" ] || return 0

  for backup in $(ls -t "${target}.bak_"* "${target}.bak_pm_"* 2>/dev/null); do
    if [ -f "$backup" ] && php_lint_ok "$backup" && ! grep -qE 'PROTEKSI_JHONALEY|ProtectAdminUser' "$backup"; then
      cp "$backup" "$target"
      echo "📦 Restore bersih: $target <- $backup"
      return 0
    fi
  done
}

strip_php_guards() {
  local target="$1"
  [ -n "$target" ] && [ -f "$target" ] || return 0
  export STRIP_TARGET="$target"
  python3 << 'PYEOF_STRIP'
import os

path = os.environ["STRIP_TARGET"]
markers = ("PROTEKSI_JHONALEY", "ProtectAdminUser")

with open(path, "r") as f:
    lines = f.read().splitlines()

out = []
i = 0
removed = 0
while i < len(lines):
    line = lines[i]

    if "ProtectAdminUser::class" in line:
        removed += 1
        i += 1
        continue

    if any(marker in line for marker in markers):
        removed += 1
        i += 1
        depth = 0
        while i < len(lines):
            current = lines[i]
            depth += current.count("{") - current.count("}")
            stripped = current.strip()
            i += 1
            if stripped.endswith(";") and depth <= 0:
                break
            if stripped == "}" and depth <= 0:
                break
        continue

    if line.strip() == "," and out and out[-1].rstrip().endswith("["):
        removed += 1
        i += 1
        continue

    out.append(line)
    i += 1

if removed:
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")
    print(f"♻️ Guard lama dibersihkan: {path}")
PYEOF_STRIP
}

safe_php_file() {
  local target="$1"
  [ -n "$target" ] && [ -f "$target" ] || return 0
  if ! php_lint_ok "$target"; then
    echo "❌ PHP masih invalid: $target"
    php -l "$target" || true
    restore_clean_backup "$target"
  fi
}

clean_sidebar_markers() {
  local sidebar="$1"
  [ -n "$sidebar" ] && [ -f "$sidebar" ] || return 0
  export SIDEBAR_TARGET="$sidebar"
  python3 << 'PYEOF_SIDEBAR_CLEAN'
import os

path = os.environ["SIDEBAR_TARGET"]
with open(path, "r") as f:
    content = f.read()

content = content.replace("@if((int) Auth::user()->id === 1)", "@if(auth()->check() && (int) auth()->id() === 1)")
content = content.replace("@if(Auth::user() && (int) Auth::user()->id === 1)", "@if(auth()->check() && (int) auth()->id() === 1)")

def strip_marker_block(text, marker):
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        if marker in lines[i]:
            i += 1
            depth = 0
            while i < len(lines):
                ln = lines[i].strip()
                if ln.startswith("@if"):
                    depth += 1
                elif ln.startswith("@endif"):
                    depth -= 1
                    i += 1
                    if depth <= 0:
                        break
                    continue
                i += 1
            continue
        out.append(lines[i])
        i += 1
    return "\n".join(out)

for marker in ("PROTEKSI_NODES_SIDEBAR", "PROTEKSI_LOCATIONS_SIDEBAR"):
    if marker in content:
        content = strip_marker_block(content, marker)
        print(f"♻️ Sidebar marker lama dibersihkan: {marker}")

with open(path, "w") as f:
    f.write(content)
PYEOF_SIDEBAR_CLEAN
}

lock_sidebar_item() {
  local sidebar="$1"
  local marker="$2"
  local route_key="$3"
  [ -n "$sidebar" ] && [ -f "$sidebar" ] || return 0
  export SIDEBAR_TARGET="$sidebar"
  export LOCK_MARKER="$marker"
  export LOCK_ROUTE_KEY="$route_key"
  python3 << 'PYEOF_LOCK'
import os, re

path = os.environ["SIDEBAR_TARGET"]
marker = os.environ["LOCK_MARKER"]
route_key = os.environ["LOCK_ROUTE_KEY"]

with open(path, "r") as f:
    content = f.read()

if marker in content:
    print(f"⚠️ Sidebar sudah ada marker: {marker}")
    raise SystemExit(0)

def lock_transform(block_text):
    def repl(m):
        attrs = m.group(1)
        attrs = re.sub(r'href\s*=\s*"[^"]*"', 'href="#" onclick="return false;"', attrs, count=1)
        if re.search(r'style\s*=\s*"', attrs):
            attrs = re.sub(r'style\s*=\s*"([^"]*)"', r'style="\1;opacity:0.55;pointer-events:none;cursor:not-allowed;filter:grayscale(1);"', attrs, count=1)
        else:
            attrs = attrs.rstrip() + ' style="opacity:0.55;pointer-events:none;cursor:not-allowed;filter:grayscale(1);"'
        return '<a ' + attrs + '><i class="fa fa-lock" style="margin-right:6px;"></i>'
    return re.sub(r'<a\s+([^>]*)>', repl, block_text, count=1)

lines = content.split("\n")
new_lines = []
i = 0
changed = False

while i < len(lines):
    line = lines[i]
    if (f"admin.{route_key}" in line or f"route('admin.{route_key}')" in line or f'route("admin.{route_key}")' in line) and f"admin.{route_key}.view" not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1
        if li_start >= 0:
            block = new_lines[li_start:] + [line]
            new_lines = new_lines[:li_start]
            i += 1
            li_depth = sum(x.count('<li') - x.count('</li') for x in block)
            while i < len(lines) and li_depth > 0:
                curr = lines[i]
                li_depth += curr.count('<li') - curr.count('</li')
                block.append(curr)
                i += 1
            new_lines.append(f"{{-- {marker} --}}")
            new_lines.append("@if(auth()->check() && (int) auth()->id() === 1)")
            new_lines.extend(block)
            new_lines.append("@else")
            new_lines.append(lock_transform("\n".join(block)))
            new_lines.append("@endif")
            changed = True
            continue
    new_lines.append(line)
    i += 1

if changed:
    with open(path, "w") as f:
        f.write("\n".join(new_lines))
    print(f"✅ Sidebar dikunci: admin.{route_key}")
else:
    print(f"⚠️ Menu admin.{route_key} tidak ditemukan di sidebar asli")
PYEOF_LOCK
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 1: Recovery file PHP lama Protect12"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PHP_TARGETS=(
  "$PANEL_DIR/app/Http/Controllers/Admin/Nodes/NodeViewController.php"
  "$PANEL_DIR/app/Http/Controllers/Admin/Nodes/NodeController.php"
  "$PANEL_DIR/app/Http/Controllers/Api/Client/AccountController.php"
  "$PANEL_DIR/app/Http/Controllers/Api/Application/Users/UserController.php"
  "$PANEL_DIR/app/Http/Controllers/Admin/ApiController.php"
  "$PANEL_DIR/app/Http/Controllers/Admin/LocationController.php"
  "$PANEL_DIR/app/Http/Kernel.php"
)

if [ -d "$PANEL_DIR/app/Http/Requests/Api/Application/Users" ]; then
  for FR in "$PANEL_DIR/app/Http/Requests/Api/Application/Users"/*.php; do
    [ -f "$FR" ] && PHP_TARGETS+=("$FR")
  done
fi

for FILE in "${PHP_TARGETS[@]}"; do
  if [ -f "$FILE" ]; then
    cp "$FILE" "${FILE}.bak_${TIMESTAMP}" 2>/dev/null || true
    restore_clean_backup "$FILE"
    strip_php_guards "$FILE"
    safe_php_file "$FILE"
  fi
done

if [ -f "$PANEL_DIR/app/Http/Middleware/ProtectAdminUser.php" ]; then
  mv "$PANEL_DIR/app/Http/Middleware/ProtectAdminUser.php" "$PANEL_DIR/app/Http/Middleware/ProtectAdminUser.php.disabled_${TIMESTAMP}" 2>/dev/null || true
  echo "♻️ Middleware ProtectAdminUser lama dinonaktifkan"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 2: Pasang gembok sidebar aman"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SIDEBAR_FILE=""
for SF in "$PANEL_DIR/resources/views/layouts/admin.blade.php" "$PANEL_DIR/resources/views/partials/admin/sidebar.blade.php"; do
  if [ -f "$SF" ]; then
    SIDEBAR_FILE="$SF"
    break
  fi
done

if [ -z "$SIDEBAR_FILE" ]; then
  SIDEBAR_FILE=$(grep -RIlE --include='*.blade.php' 'admin\.nodes|admin\.locations' "$PANEL_DIR/resources/views" 2>/dev/null | grep -vE '\.bak|bak_pm|storage/framework' | head -1)
fi

if [ -n "$SIDEBAR_FILE" ] && [ -f "$SIDEBAR_FILE" ]; then
  cp "$SIDEBAR_FILE" "${SIDEBAR_FILE}.bak_${TIMESTAMP}" 2>/dev/null || true
  echo "📂 Sidebar: $SIDEBAR_FILE"
  clean_sidebar_markers "$SIDEBAR_FILE"
  lock_sidebar_item "$SIDEBAR_FILE" "PROTEKSI_NODES_SIDEBAR" "nodes"
  lock_sidebar_item "$SIDEBAR_FILE" "PROTEKSI_LOCATIONS_SIDEBAR" "locations"
else
  echo "⚠️ Sidebar asli tidak ditemukan, skip gembok sidebar"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Cache"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ℹ️ Cache clear dilakukan Protect Manager controller"

echo ""
echo "==========================================="
echo "✅ INSTALLPROTECT12 SAFE SELESAI"
echo "==========================================="
echo "♻️ Guard PHP lama Protect12 dibersihkan agar panel tidak 500"
echo "🔒 Nodes + Locations tetap tampil sebagai gembok untuk non-ID 1"
echo "⚠️ Proteksi controller/API rawan 500 tidak dipasang oleh Protect12 safe"
echo "==========================================="