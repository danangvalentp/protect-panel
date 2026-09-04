#!/bin/bash
# ============================================
# installprotect13.sh
# Menyembunyikan menu "Application API" dari sidebar
# dan memblokir akses controller Application API
# untuk semua admin KECUALI User ID 1
# ============================================

set -e

BRAND_NAME="${BRAND_NAME:-Jhonaley Store}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)

echo "==========================================="
echo "🔒 INSTALLPROTECT13: Proteksi Application API"
echo "==========================================="
echo "🚀 Sembunyikan menu Application API di sidebar..."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 1: Sembunyikan menu Application API dari sidebar
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 1: Sembunyikan menu Application API di sidebar"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cari file yang mengandung "Application API" di views
SIDEBAR_FILE=$(grep -rl "Application API" "$PANEL_DIR/resources/views/" 2>/dev/null | head -1)

if [ -z "$SIDEBAR_FILE" ]; then
    echo "⚠️ Tidak menemukan menu 'Application API' di views, mencoba layout admin..."
    SIDEBAR_FILE="$PANEL_DIR/resources/views/layouts/admin.blade.php"
fi

if [ ! -f "$SIDEBAR_FILE" ]; then
    echo "❌ File tidak ditemukan: $SIDEBAR_FILE"
    echo "⏭️ Skip bagian 1"
else
    echo "📂 File ditemukan: $SIDEBAR_FILE"
    cp "$SIDEBAR_FILE" "${SIDEBAR_FILE}.bak_${TIMESTAMP}"
    echo "💾 Backup: ${SIDEBAR_FILE}.bak_${TIMESTAMP}"

    if grep -q "PROTEKSI_JHONALEY_APPAPI_MENU" "$SIDEBAR_FILE"; then
        echo "⚠️ Proteksi sudah ada, skip..."
    else
        # Gunakan sed untuk wrap baris yang mengandung "Application API" dengan @if
        # Cari nomor baris yang mengandung "Application API"
        LINE_NUM=$(grep -n "Application API" "$SIDEBAR_FILE" | head -1 | cut -d: -f1)
        
        if [ -n "$LINE_NUM" ]; then
            echo "📍 Ditemukan 'Application API' di baris $LINE_NUM"
            
            # Insert @if sebelum baris tersebut dan @endif setelahnya
            # Cari <li> pembuka terdekat sebelum baris ini (max 5 baris ke atas)
            START_LINE=$LINE_NUM
            for i in $(seq $((LINE_NUM - 1)) -1 $((LINE_NUM - 10))); do
                if [ $i -lt 1 ]; then break; fi
                if sed -n "${i}p" "$SIDEBAR_FILE" | grep -q "<li"; then
                    START_LINE=$i
                    break
                fi
                if sed -n "${i}p" "$SIDEBAR_FILE" | grep -q "<a.*href"; then
                    START_LINE=$i
                    break
                fi
            done

            # Cari </li> penutup terdekat setelah baris ini (max 5 baris ke bawah)
            TOTAL_LINES=$(wc -l < "$SIDEBAR_FILE")
            END_LINE=$LINE_NUM
            for i in $(seq $((LINE_NUM + 1)) $((LINE_NUM + 10))); do
                if [ $i -gt "$TOTAL_LINES" ]; then break; fi
                if sed -n "${i}p" "$SIDEBAR_FILE" | grep -q "</li>"; then
                    END_LINE=$i
                    break
                fi
                if sed -n "${i}p" "$SIDEBAR_FILE" | grep -q "</a>"; then
                    END_LINE=$i
                    break
                fi
            done

            echo "📍 Wrapping baris $START_LINE sampai $END_LINE"

            # Insert @endif setelah END_LINE
            sed -i "${END_LINE}a\\{{-- END PROTEKSI_JHONALEY_APPAPI_MENU --}}" "$SIDEBAR_FILE"
            sed -i "${END_LINE}a\\@endif" "$SIDEBAR_FILE"

            # Insert @if sebelum START_LINE
            sed -i "$((START_LINE))i\\@if(Auth::user()->id === 1)" "$SIDEBAR_FILE"
            sed -i "$((START_LINE))i\\{{-- PROTEKSI_JHONALEY_APPAPI_MENU: Sembunyikan untuk non-ID 1 --}}" "$SIDEBAR_FILE"

            echo "✅ Menu Application API disembunyikan untuk non-ID 1"
        else
            echo "⚠️ Teks 'Application API' tidak ditemukan di file"
        fi
    fi
fi

echo "✅ BAGIAN 1 SELESAI"


echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Sembunyikan menu Application API di sidebar"
