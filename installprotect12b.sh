#!/bin/bash

BRAND_NAME="${BRAND_NAME:-Jhonaley Store}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@JhoanleystoreId}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Proteksi Client Account API..."

# ===================================================================
# BAGIAN 2: PROTEKSI CLIENT ACCOUNT API (Block ubah password/email admin ID 1)
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 2: Proteksi Client Account API"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ACCT_CTRL="/var/www/pterodactyl/app/Http/Controllers/Api/Client/AccountController.php"

if [ ! -f "$ACCT_CTRL" ]; then
  ACCT_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Api/Client -maxdepth 1 -iname "AccountController.php" 2>/dev/null | head -1)
fi

if [ -n "$ACCT_CTRL" ] && [ -f "$ACCT_CTRL" ]; then
  echo "📂 Client AccountController ditemukan: $ACCT_CTRL"

  ACCT_BACKUP=$(ls -t "${ACCT_CTRL}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$ACCT_BACKUP" ]; then
    cp "$ACCT_BACKUP" "$ACCT_CTRL"
    echo "📦 Restore dari backup: $ACCT_BACKUP"
  fi

  cp "$ACCT_CTRL" "${ACCT_CTRL}.bak_${TIMESTAMP}"

  python3 << PYEOF4
import re

controller = "$ACCT_CTRL"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_ACCOUNT" in content:
    print("⚠️ Proteksi sudah ada di AccountController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    use_pattern = r'(use Pterodactyl\\[^;]+;)'
    match = re.search(use_pattern, content)
    if match:
        content = content.replace(match.group(0), match.group(0) + "\nuse Illuminate\\Support\\Facades\\Auth;", 1)

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (updatePassword|updateEmail|update)\b', line) and '__construct' not in line:
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY_ACCOUNT: Block ubah data admin ID 1")
        new_lines.append("        \$targetUser = \$request->user();")
        new_lines.append("        if ((int) \$targetUser->id === 1 && (!Auth::user() || (int) Auth::user()->id !== 1)) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke Client AccountController")
PYEOF4

  echo ""
  grep -n "PROTEKSI_JHONALEY_ACCOUNT" "$ACCT_CTRL"
else
  echo "⚠️ Client AccountController tidak ditemukan, skip."
fi

echo ""
echo "✅ BAGIAN 2 SELESAI: Proteksi Client Account API terpasang"
echo ""


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$ACCT_CTRL"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by Jhonaley Tech|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by Jhonaley Tech|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|Jhonaley Tech|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi Client Account API"
