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
echo "🚀 Block akses Application API Controller..."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 2: Block akses ke Application API Controller
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 2: Block akses Application API Controller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

API_CONTROLLER="$PANEL_DIR/app/Http/Controllers/Admin/ApiController.php"

if [ ! -f "$API_CONTROLLER" ]; then
    echo "❌ ApiController tidak ditemukan: $API_CONTROLLER"
else
    cp "$API_CONTROLLER" "${API_CONTROLLER}.bak_${TIMESTAMP}"
    echo "💾 Backup: ${API_CONTROLLER}.bak_${TIMESTAMP}"

    if grep -q "PROTEKSI_JHONALEY_APPAPI_BLOCK" "$API_CONTROLLER"; then
        echo "⚠️ Proteksi sudah ada, skip..."
    else
        # Cari baris "public function index" dan inject proteksi setelahnya
        INDEX_LINE=$(grep -n "public function index" "$API_CONTROLLER" | head -1 | cut -d: -f1)
        
        if [ -n "$INDEX_LINE" ]; then
            # Cari baris { setelah function declaration
            BRACE_LINE=$INDEX_LINE
            for i in $(seq "$INDEX_LINE" $((INDEX_LINE + 3))); do
                if sed -n "${i}p" "$API_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done

            # Inject setelah opening brace
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_JHONALEY_APPAPI_BLOCK: Block akses untuk non-ID 1" "$API_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if (\\\\Auth::user()->id !== 1) { abort(403, 'Akses Application API tidak diizinkan.'); }" "$API_CONTROLLER"

            echo "✅ Proteksi index() diinjeksi"
        fi

        # Juga proteksi method store (buat key)
        STORE_LINE=$(grep -n "public function store" "$API_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$STORE_LINE" ]; then
            BRACE_LINE=$STORE_LINE
            for i in $(seq "$STORE_LINE" $((STORE_LINE + 3))); do
                if sed -n "${i}p" "$API_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_JHONALEY_APPAPI_BLOCK" "$API_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if (\\\\Auth::user()->id !== 1) { abort(403, 'Akses Application API tidak diizinkan.'); }" "$API_CONTROLLER"
            echo "✅ Proteksi store() diinjeksi"
        fi

        # Proteksi method delete
        DELETE_LINE=$(grep -n "public function delete\|public function destroy" "$API_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$DELETE_LINE" ]; then
            BRACE_LINE=$DELETE_LINE
            for i in $(seq "$DELETE_LINE" $((DELETE_LINE + 3))); do
                if sed -n "${i}p" "$API_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_JHONALEY_APPAPI_BLOCK" "$API_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if (\\\\Auth::user()->id !== 1) { abort(403, 'Akses Application API tidak diizinkan.'); }" "$API_CONTROLLER"
            echo "✅ Proteksi delete() diinjeksi"
        fi
    fi
fi

echo "✅ BAGIAN 2 SELESAI"


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$API_CONTROLLER"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by Jhonaley Tech|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by Jhonaley Tech|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|Jhonaley Tech|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Block akses Application API Controller"
