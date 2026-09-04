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
echo "🚀 Proteksi API /api/application/users (root_admin)..."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 3: Proteksi Application API endpoint /api/application/users
# Mencegah non-ID 1 mengubah root_admin via REST API
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Proteksi API /api/application/users (root_admin)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cari Application API UserController
API_USER_CONTROLLER="$PANEL_DIR/app/Http/Controllers/Api/Application/Users/UserController.php"

if [ ! -f "$API_USER_CONTROLLER" ]; then
    echo "⚠️ API UserController tidak ditemukan: $API_USER_CONTROLLER"
    echo "   Mencoba path alternatif..."
    API_USER_CONTROLLER=$(find "$PANEL_DIR/app/Http/Controllers/Api" -name "UserController.php" -path "*/Application/*" 2>/dev/null | head -1)
fi

if [ -z "$API_USER_CONTROLLER" ] || [ ! -f "$API_USER_CONTROLLER" ]; then
    echo "❌ API UserController tidak ditemukan, skip bagian 3"
else
    echo "📂 File ditemukan: $API_USER_CONTROLLER"
    cp "$API_USER_CONTROLLER" "${API_USER_CONTROLLER}.bak_${TIMESTAMP}"
    echo "💾 Backup: ${API_USER_CONTROLLER}.bak_${TIMESTAMP}"

    if grep -q "PROTEKSI_JHONALEY_API_ROOTADMIN" "$API_USER_CONTROLLER"; then
        TMP=$(mktemp)
        awk '
            BEGIN { skip_next=0 }
            /PROTEKSI_JHONALEY_API_ROOTADMIN/ { skip_next=1; next }
            skip_next == 1 { skip_next=0; next }
            { print }
        ' "$API_USER_CONTROLLER" > "$TMP" && mv "$TMP" "$API_USER_CONTROLLER"
        chmod 644 "$API_USER_CONTROLLER"
        echo "♻️ Guard API users lama dari protect13 dibersihkan; proteksi API users ditangani protect14 V5"
    fi

    if true; then
        echo "ℹ️ Skip injeksi API /api/application/users di protect13; create/delete user API ditangani protect14 V5 agar API key Admin ID 1 tetap bisa."
    elif grep -q "PROTEKSI_JHONALEY_API_ROOTADMIN" "$API_USER_CONTROLLER"; then
        echo "⚠️ Proteksi sudah ada, skip..."
    else
        # Proteksi method store (create user via API)
        STORE_LINE=$(grep -n "public function store" "$API_USER_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$STORE_LINE" ]; then
            BRACE_LINE=$STORE_LINE
            for i in $(seq "$STORE_LINE" $((STORE_LINE + 5))); do
                if sed -n "${i}p" "$API_USER_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_JHONALEY_API_ROOTADMIN: Block non-ID 1 dari set root_admin via API" "$API_USER_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if ((int) \\\$request->user()->id !== 1 && \\\$request->has('root_admin') && \\\$request->input('root_admin')) { return response()->json(['error' => '${BRAND_TEXT} - Tidak diizinkan mengubah status admin via API'], 403); }" "$API_USER_CONTROLLER"
            echo "✅ Proteksi store() API diinjeksi"
        fi

        # Proteksi method update (update user via API)
        UPDATE_LINE=$(grep -n "public function update" "$API_USER_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$UPDATE_LINE" ]; then
            BRACE_LINE=$UPDATE_LINE
            for i in $(seq "$UPDATE_LINE" $((UPDATE_LINE + 5))); do
                if sed -n "${i}p" "$API_USER_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_JHONALEY_API_ROOTADMIN: Block non-ID 1 dari ubah root_admin via API" "$API_USER_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if ((int) \\\$request->user()->id !== 1 && \\\$request->has('root_admin')) { \\\$user = \\\$this->repository->find(\\\$request->route('user')); if ((bool) \\\$request->input('root_admin') !== (bool) \\\$user->root_admin) { return response()->json(['error' => '${BRAND_TEXT} - Tidak diizinkan mengubah status admin via API'], 403); } }" "$API_USER_CONTROLLER"
            echo "✅ Proteksi update() API diinjeksi"
        fi

        # Proteksi method delete (hapus user via API)
        DELETE_LINE=$(grep -n "public function delete\|public function destroy" "$API_USER_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$DELETE_LINE" ]; then
            BRACE_LINE=$DELETE_LINE
            for i in $(seq "$DELETE_LINE" $((DELETE_LINE + 5))); do
                if sed -n "${i}p" "$API_USER_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_JHONALEY_API_ROOTADMIN: Block non-ID 1 dari hapus user via API" "$API_USER_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if ((int) \\\$request->user()->id !== 1) { return response()->json(['error' => '${BRAND_TEXT} - Tidak diizinkan menghapus user via API'], 403); }" "$API_USER_CONTROLLER"
            echo "✅ Proteksi delete() API diinjeksi"
        fi
    fi
fi

echo "✅ BAGIAN 3 SELESAI"


echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi API /api/application/users (root_admin)"
