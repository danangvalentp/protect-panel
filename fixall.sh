#!/bin/bash
# Fix All-in-One: Perbaiki 500 error Protect Manager + Sidebar
set -e

PANEL_DIR="/var/www/pterodactyl"
CONTROLLER="$PANEL_DIR/app/Http/Controllers/Admin/ProtectManagerController.php"
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)

echo "==========================================="
echo "🔧 FIX ALL-IN-ONE: Protect Manager"
echo "==========================================="
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FIX 1: Perbaiki Controller (authorize → authorizeAccess)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 FIX 1: Patch ProtectManagerController"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "$CONTROLLER" ]; then
    echo "❌ Controller tidak ditemukan: $CONTROLLER"
    echo "⏭️ Skip fix controller"
else
    cp "$CONTROLLER" "${CONTROLLER}.bak_fixall_${TIMESTAMP}"
    echo "💾 Backup: ${CONTROLLER}.bak_fixall_${TIMESTAMP}"

    python3 << 'PYEOF'
from pathlib import Path

controller = Path('/var/www/pterodactyl/app/Http/Controllers/Admin/ProtectManagerController.php')
content = controller.read_text()

changed = False

if 'private function authorize()' in content:
    content = content.replace('private function authorize()', 'private function authorizeAccess()')
    changed = True

if '$this->authorize();' in content:
    content = content.replace('$this->authorize();', '$this->authorizeAccess();')
    changed = True

if 'if (!$user || $user->id !== 1) {' in content:
    content = content.replace('if (!$user || $user->id !== 1) {', 'if (!$user || (int) $user->id !== 1) {')
    changed = True

if changed:
    controller.write_text(content)
    print('✅ Controller dipatch: authorize() → authorizeAccess()')
else:
    print('⚠️ Controller sudah benar, skip...')
PYEOF
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FIX 2: Perbaiki Sidebar (restore + inject ulang)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 FIX 2: Fix Sidebar Protect Manager"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LAYOUT_FILE=""
for f in "$PANEL_DIR/resources/views/layouts/admin.blade.php" "$PANEL_DIR/resources/views/layouts/app.blade.php"; do
    if [ -f "$f" ]; then
        LAYOUT_FILE="$f"
        break
    fi
done

if [ -z "$LAYOUT_FILE" ]; then
    echo "❌ Layout file tidak ditemukan!"
    echo "⏭️ Skip fix sidebar"
else
    echo "📂 Layout: $LAYOUT_FILE"

    # Restore dari backup jika sidebar injection sebelumnya gagal/korup
    LATEST_BACKUP=$(ls -t "${LAYOUT_FILE}.bak_pm_"* 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        echo "🔄 Restore dari backup: $LATEST_BACKUP"
        cp "$LATEST_BACKUP" "$LAYOUT_FILE"
    fi

    # Backup baru
    cp "$LAYOUT_FILE" "${LAYOUT_FILE}.bak_pm_${TIMESTAMP}"

    if grep -q "PROTEKSI_JHONALEY_MASTER_SIDEBAR" "$LAYOUT_FILE"; then
        echo "⚠️ Sidebar sudah ada, skip..."
    else
        ANCHOR_LINE=$(grep -n "Settings\|settings\|Configuration" "$LAYOUT_FILE" | grep -i "href\|route\|url" | tail -1 | cut -d: -f1)
        
        if [ -z "$ANCHOR_LINE" ]; then
            ANCHOR_LINE=$(grep -n "</ul>" "$LAYOUT_FILE" | tail -1 | cut -d: -f1)
        fi

        if [ -z "$ANCHOR_LINE" ]; then
            echo "❌ Tidak bisa menemukan posisi sidebar"
        else
            TOTAL_LINES=$(wc -l < "$LAYOUT_FILE")
            INSERT_LINE=$ANCHOR_LINE
            for i in $(seq "$ANCHOR_LINE" $((ANCHOR_LINE + 15))); do
                if [ "$i" -gt "$TOTAL_LINES" ]; then break; fi
                if awk "NR==$i" "$LAYOUT_FILE" | grep -q "</li>"; then
                    INSERT_LINE=$i
                    break
                fi
            done

            TEMP_FILE=$(mktemp)
            head -n "$INSERT_LINE" "$LAYOUT_FILE" > "$TEMP_FILE"
            cat >> "$TEMP_FILE" << 'SIDEBAREOF'
                {{-- PROTEKSI_JHONALEY_MASTER_SIDEBAR: Protect Manager Menu --}}
                @if(Auth::user() && Auth::user()->id === 1)
                <li class="{{ Route::currentRouteName() === 'admin.protect-manager' ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>
                @endif
                {{-- END PROTEKSI_JHONALEY_MASTER_SIDEBAR --}}
SIDEBAREOF
            tail -n +"$((INSERT_LINE + 1))" "$LAYOUT_FILE" >> "$TEMP_FILE"
            mv "$TEMP_FILE" "$LAYOUT_FILE"
            chmod 644 "$LAYOUT_FILE"
            echo "✅ Sidebar berhasil ditambahkan!"
        fi
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Clear semua cache
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "🧹 Membersihkan cache..."
cd "$PANEL_DIR"
php artisan optimize:clear 2>/dev/null || true
php artisan view:clear 2>/dev/null || true
php artisan route:clear 2>/dev/null || true
php artisan config:clear 2>/dev/null || true
php artisan cache:clear 2>/dev/null || true
echo "✅ Semua cache dibersihkan"

echo ""
echo "==========================================="
echo "✅ FIX ALL-IN-ONE SELESAI!"
echo "==========================================="
echo "🌐 Buka Admin Panel → Sidebar → Protect Manager"
