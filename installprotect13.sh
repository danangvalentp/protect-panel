#!/bin/bash
# ============================================
# installprotect13.sh
# Menyembunyikan menu "Application API" dari sidebar
# dan memblokir akses controller Application API
# untuk semua admin KECUALI User ID 1
# ============================================

set -e

BRAND_NAME="${BRAND_NAME:-Jhonaley Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)

echo "==========================================="
echo "🔒 INSTALLPROTECT13: Proteksi Application API"
echo "==========================================="

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BERSIHKAN CACHE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "🧹 Membersihkan cache..."

# Apply brand customization
if [ -f "$API_CONTROLLER" ]; then
  sed -i "s|Akses Application API tidak diizinkan|${BRAND_TEXT} - Akses ditolak|g" "$API_CONTROLLER" 2>/dev/null || true
fi

echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo ""
echo "==========================================="
echo "✅ INSTALLPROTECT13 SELESAI!"
echo "==========================================="
echo "🔒 Menu Application API disembunyikan (selain ID 1)"
echo "🔒 Akses controller Application API diblock (selain ID 1)"
echo "==========================================="
echo ""
echo "⚠️ Jika ada masalah, restore:"
[ -f "${SIDEBAR_FILE}.bak_${TIMESTAMP}" ] && echo "   cp ${SIDEBAR_FILE}.bak_${TIMESTAMP} ${SIDEBAR_FILE}"
[ -f "${API_CONTROLLER}.bak_${TIMESTAMP}" ] && echo "   cp ${API_CONTROLLER}.bak_${TIMESTAMP} ${API_CONTROLLER}"
echo "   cd $PANEL_DIR && php artisan view:clear && php artisan route:clear"
