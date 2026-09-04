#!/bin/bash
# Fix 500 error pada Protect Manager karena bentrok method authorize()

set -e

PANEL_DIR="/var/www/pterodactyl"
CONTROLLER="$PANEL_DIR/app/Http/Controllers/Admin/ProtectManagerController.php"
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)

echo "🔧 Fix Protect Manager 500..."

if [ ! -f "$CONTROLLER" ]; then
    echo "❌ Controller tidak ditemukan: $CONTROLLER"
    exit 1
fi

cp "$CONTROLLER" "${CONTROLLER}.bak_fixpm_${TIMESTAMP}"
echo "💾 Backup: ${CONTROLLER}.bak_fixpm_${TIMESTAMP}"

python3 << 'PYEOF'
from pathlib import Path

controller = Path('/var/www/pterodactyl/app/Http/Controllers/Admin/ProtectManagerController.php')
content = controller.read_text()

content = content.replace('private function authorize()', 'private function authorizeAccess()')
content = content.replace('$this->authorize();', '$this->authorizeAccess();')
content = content.replace('if (!$user || $user->id !== 1) {', 'if (!$user || (int) $user->id !== 1) {')

controller.write_text(content)
print('✅ Controller berhasil dipatch')
PYEOF

cd "$PANEL_DIR"
php artisan optimize:clear 2>/dev/null || true
php artisan view:clear 2>/dev/null || true
php artisan route:clear 2>/dev/null || true
php artisan config:clear 2>/dev/null || true
php artisan cache:clear 2>/dev/null || true

echo "✅ Cache dibersihkan"
echo "🌐 Silakan klik lagi menu Protect Manager"
