#!/bin/bash
# Fix: Inject sidebar Protect Manager ke layout admin
# Menggunakan head/tail bukan sed untuk menghindari masalah karakter @

set -e

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)

echo "🔧 Fix Sidebar Protect Manager..."

# Cari layout file
LAYOUT_FILE=""
for f in "$PANEL_DIR/resources/views/layouts/admin.blade.php" "$PANEL_DIR/resources/views/layouts/app.blade.php"; do
    if [ -f "$f" ]; then
        LAYOUT_FILE="$f"
        break
    fi
done

if [ -z "$LAYOUT_FILE" ]; then
    echo "❌ Layout file tidak ditemukan!"
    exit 1
fi

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
    # Cari posisi insert - cari Settings/Configuration link
    ANCHOR_LINE=$(grep -n "Settings\|settings\|Configuration" "$LAYOUT_FILE" | grep -i "href\|route\|url" | tail -1 | cut -d: -f1)
    
    if [ -z "$ANCHOR_LINE" ]; then
        ANCHOR_LINE=$(grep -n "</ul>" "$LAYOUT_FILE" | tail -1 | cut -d: -f1)
    fi

    if [ -z "$ANCHOR_LINE" ]; then
        echo "❌ Tidak bisa menemukan posisi sidebar"
        exit 1
    fi

    # Cari </li> terdekat setelah anchor
    TOTAL_LINES=$(wc -l < "$LAYOUT_FILE")
    INSERT_LINE=$ANCHOR_LINE
    for i in $(seq "$ANCHOR_LINE" $((ANCHOR_LINE + 15))); do
        if [ "$i" -gt "$TOTAL_LINES" ]; then break; fi
        if awk "NR==$i" "$LAYOUT_FILE" | grep -q "</li>"; then
            INSERT_LINE=$i
            break
        fi
    done

    echo "📍 Insert setelah baris $INSERT_LINE"

    # Gunakan head/tail + heredoc (BUKAN sed)
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

# Clear cache
cd "$PANEL_DIR"
php artisan view:clear 2>/dev/null || true
php artisan route:clear 2>/dev/null || true
php artisan cache:clear 2>/dev/null || true
echo "✅ Cache dibersihkan"
echo ""
echo "🌐 Buka Admin Panel → Sidebar → Protect Manager"
