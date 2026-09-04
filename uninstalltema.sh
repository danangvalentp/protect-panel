#!/bin/bash
# ============================================
# 🗑️  UNINSTALL TEMA / BRANDING JHONALEY
# ============================================
# Strip semua blok BRANDING_JHONALEY dari layout
# tanpa bergantung pada file backup.
# ============================================

set -e

PTERO_DIR="/var/www/pterodactyl"
LAYOUT_DIR="${PTERO_DIR}/resources/views/layouts"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🗑️  Memulai uninstall tema Jhonaley..."
echo ""

if [ ! -d "$LAYOUT_DIR" ]; then
  echo "❌ Folder layout tidak ditemukan: $LAYOUT_DIR"
  exit 1
fi

LAYOUT_FILES=(
  "${LAYOUT_DIR}/admin.blade.php"
  "${LAYOUT_DIR}/master.blade.php"
  "${LAYOUT_DIR}/auth.blade.php"
)

CLEANED=0
SKIPPED=0

for FILE in "${LAYOUT_FILES[@]}"; do
  [ ! -f "$FILE" ] && continue
  LABEL=$(basename "$FILE")
  echo "🔍 Memproses: $LABEL"

  if ! grep -q "BRANDING_JHONALEY\|jhonaley-footer\|Pterodactyl - Jhonaley" "$FILE" 2>/dev/null; then
    echo "   ℹ️  Tidak ada branding terdeteksi, skip"
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  python3 - "$FILE" << 'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Hapus blok <style> yang diawali komentar BRANDING_JHONALEY
content = re.sub(
    r"<!--\s*BRANDING_JHONALEY[^>]*-->\s*<style>.*?</style>",
    "",
    content,
    flags=re.DOTALL,
)

# 2. Hapus blok footer <div class="jhonaley-footer">...</div> (toleran terhadap variasi quote)
content = re.sub(
    r"<!--\s*BRANDING_JHONALEY[^>]*-->\s*<div class=[\"']jhonaley-footer[\"']>.*?</div>\s*</div>",
    "",
    content,
    flags=re.DOTALL,
)

# 3. Fallback: hapus div jhonaley-footer apapun walau marker hilang
content = re.sub(
    r"<div class=[\"']jhonaley-footer[\"']>.*?</div>\s*</div>",
    "",
    content,
    flags=re.DOTALL,
)

# 4. Sapu sisa marker komentar BRANDING_JHONALEY apa pun
content = re.sub(r"<!--\s*BRANDING_JHONALEY[^>]*-->", "", content)

# 5. Kembalikan title default
content = content.replace(
    "<title>Pterodactyl - Jhonaley Tech</title>",
    "<title>Pterodactyl</title>",
)

# 6. Rapikan baris kosong berlebih
content = re.sub(r"\n{3,}", "\n\n", content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("   ✅ Branding dihapus")
PYEOF
  chmod 644 "$FILE"
  CLEANED=$((CLEANED+1))
done

echo ""
echo "🧹 Membersihkan cache Laravel..."
cd "$PTERO_DIR"
php artisan view:clear 2>/dev/null || true
php artisan cache:clear 2>/dev/null || true
php artisan config:clear 2>/dev/null || true

chown -R www-data:www-data "$LAYOUT_DIR" 2>/dev/null || true

echo ""
echo "==========================================="
echo "✅ UNINSTALL TEMA SELESAI"
echo "==========================================="
echo "🧽 Dibersihkan : $CLEANED file"
echo "⏭️  Dilewati    : $SKIPPED file (sudah bersih)"
echo "==========================================="
echo ""
echo "💡 Hard refresh browser (Ctrl+Shift+R) untuk lihat hasil"
echo "💡 Sekarang aman install branding versi terbaru"
