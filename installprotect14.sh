#!/bin/bash
# ============================================
# installprotect14.sh
# Proteksi: hanya Admin ID 1 yang boleh membuat/mengubah
# user menjadi Administrator (root_admin = 1).
# User biasa (root_admin = 0) tetap bebas dibuat siapa saja
# yang berwenang.
# ============================================

set -e

BRAND_NAME="${BRAND_NAME:-Jhonaley Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "==========================================="
echo "🔒 INSTALLPROTECT14: Proteksi Create Admin Panel"
echo "==========================================="

MARKER="PROTEKSI_JHONALEY_BLOCK_CREATE_ADMIN"

# Guard PHP yang akan diinjeksi di beberapa titik.
read -r -d '' GUARD_PHP <<'PHP' || true
        // PROTEKSI_JHONALEY_BLOCK_CREATE_ADMIN
        try {
            $__req = request();
            $__isConsole = app()->runningInConsole();
            $__user = null;
            foreach ([null, 'web', 'api', 'application', 'client'] as $__g) {
                try {
                    $__user = $__g === null ? \Illuminate\Support\Facades\Auth::user() : \Illuminate\Support\Facades\Auth::guard($__g)->user();
                    if ($__user) { break; }
                } catch (\Throwable $e) {}
            }
            if (!$__user && $__req) { try { $__user = $__req->user(); } catch (\Throwable $e) {} }
            if (!$__user && $__req) {
                $__k = $__req->attributes->get('api_key') ?? $__req->attributes->get('apiKey') ?? $__req->attributes->get('token');
                $__user = $__k ? ($__k->user ?? null) : null;
            }
            $__wantsAdmin = false;
            if ($__req) {
                $__ra = $__req->input('root_admin');
                if ($__ra !== null && (int) $__ra === 1) { $__wantsAdmin = true; }
                if ($__req->boolean('root_admin')) { $__wantsAdmin = true; }
            }
            if ($__wantsAdmin && !$__isConsole) {
                if (!$__user || (int) $__user->id !== 1) {
                    throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: hanya Admin ID 1 yang dapat membuat/mengubah Administrator @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇.');
                }
            }
        } catch (\Pterodactyl\Exceptions\DisplayException $e) { throw $e; } catch (\Throwable $e) {}
PHP

inject_guard_into_method() {
    local FILE="$1"
    local METHOD_REGEX="$2"

    if [ ! -f "$FILE" ]; then
        echo "⚠️ File tidak ditemukan: $FILE (skip)"
        return 0
    fi

    if grep -q "$MARKER" "$FILE"; then
        echo "⚠️ Guard sudah ada di $FILE (skip)"
        return 0
    fi

    cp "$FILE" "${FILE}.bak_${TIMESTAMP}"

    local GUARD_FILE
    GUARD_FILE=$(mktemp)
    printf '%s\n' "$GUARD_PHP" > "$GUARD_FILE"

    local TMP
    TMP=$(mktemp)

    awk -v method="$METHOD_REGEX" -v guardfile="$GUARD_FILE" '
        BEGIN {
            while ((getline line < guardfile) > 0) {
                guard = guard line "\n"
            }
            close(guardfile)
            in_method = 0
            inserted = 0
            brace = 0
        }
        {
            print
            if (inserted == 0 && in_method == 0 && $0 ~ method) {
                in_method = 1
                next
            }
            if (in_method == 1 && inserted == 0) {
                if ($0 ~ /\{[[:space:]]*$/) {
                    printf "%s", guard
                    inserted = 1
                    in_method = 0
                }
            }
        }
    ' "$FILE" > "$TMP" && mv "$TMP" "$FILE"

    rm -f "$GUARD_FILE"
    chmod 644 "$FILE"
    echo "✅ Guard terpasang di $FILE"
}

# 1) Admin UI: Pterodactyl\Http\Controllers\Admin\UserController (store & update)
ADMIN_USER_CTRL="$PANEL_DIR/app/Http/Controllers/Admin/UserController.php"
inject_guard_into_method "$ADMIN_USER_CTRL" "function[[:space:]]+store[[:space:]]*\\("
inject_guard_into_method "$ADMIN_USER_CTRL" "function[[:space:]]+update[[:space:]]*\\("

# 2) Application API: Api\Application\Users\UserController (store & update)
APP_USER_CTRL="$PANEL_DIR/app/Http/Controllers/Api/Application/Users/UserController.php"
inject_guard_into_method "$APP_USER_CTRL" "function[[:space:]]+store[[:space:]]*\\("
inject_guard_into_method "$APP_USER_CTRL" "function[[:space:]]+update[[:space:]]*\\("

# 3) Fallback: guard di service level (UserCreationService & UserUpdateService)
USER_CREATE_SVC="$PANEL_DIR/app/Services/Users/UserCreationService.php"
inject_guard_into_method "$USER_CREATE_SVC" "function[[:space:]]+handle[[:space:]]*\\("

USER_UPDATE_SVC="$PANEL_DIR/app/Services/Users/UserUpdateService.php"
inject_guard_into_method "$USER_UPDATE_SVC" "function[[:space:]]+handle[[:space:]]*\\("

# 4) Fallback model-level: guard di User model saat saving jika root_admin = 1
USER_MODEL="$PANEL_DIR/app/Models/User.php"
if [ -f "$USER_MODEL" ]; then
    if ! grep -q "PROTEKSI_JHONALEY_USER_MODEL_ADMIN_GUARD" "$USER_MODEL"; then
        cp "$USER_MODEL" "${USER_MODEL}.bak_${TIMESTAMP}"
        TMP=$(mktemp)
        awk '
            BEGIN { inserted=0 }
            /^}[[:space:]]*$/ && inserted==0 {
                print ""
                print "    // PROTEKSI_JHONALEY_USER_MODEL_ADMIN_GUARD"
                print "    protected static function booted(): void"
                print "    {"
                print "        static::saving(function ($model) {"
                print "            try {"
                print "                if (app()->runningInConsole()) { return; }"
                print "                if ((int) ($model->root_admin ?? 0) !== 1) { return; }"
                print "                $original = method_exists($model, \"getOriginal\") ? (int) ($model->getOriginal(\"root_admin\") ?? 0) : 0;"
                print "                if ($model->exists && $original === 1) { return; }"
                print "                $user = null;"
                print "                foreach ([null, \"web\", \"api\", \"application\", \"client\"] as $g) {"
                print "                    try {"
                print "                        $user = $g === null ? \\Illuminate\\Support\\Facades\\Auth::user() : \\Illuminate\\Support\\Facades\\Auth::guard($g)->user();"
                print "                        if ($user) { break; }"
                print "                    } catch (\\Throwable $e) {}"
                print "                }"
                print "                if (!$user) {"
                print "                    try { $req = request(); if ($req) { $user = $req->user(); } } catch (\\Throwable $e) {}"
                print "                }"
                print "                if (!$user || (int) $user->id !== 1) {"
                print "                    throw new \\Pterodactyl\\Exceptions\\DisplayException(\"Akses ditolak: hanya Admin ID 1 yang dapat membuat/mengubah Administrator @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇.\");"
                print "                }"
                print "            } catch (\\Pterodactyl\\Exceptions\\DisplayException $e) { throw $e; } catch (\\Throwable $e) {}"
                print "        });"
                print "    }"
                inserted=1
            }
            { print }
        ' "$USER_MODEL" > "$TMP" && mv "$TMP" "$USER_MODEL"
        chmod 644 "$USER_MODEL"
        echo "✅ Guard model User terpasang."
    else
        echo "⚠️ Guard model User sudah ada, skip."
    fi
else
    echo "⚠️ User model tidak ditemukan: $USER_MODEL"
fi

# Terapkan branding
for F in "$ADMIN_USER_CTRL" "$APP_USER_CTRL" "$USER_CREATE_SVC" "$USER_UPDATE_SVC" "$USER_MODEL"; do
    [ -f "$F" ] && sed -i "s|𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇|${BRAND_TEXT}|g" "$F" 2>/dev/null || true
done

# Clear cache Laravel
cd "$PANEL_DIR" 2>/dev/null && {
    php artisan config:clear >/dev/null 2>&1 || true
    php artisan cache:clear >/dev/null 2>&1 || true
    php artisan view:clear >/dev/null 2>&1 || true
}

echo ""
echo "==========================================="
echo "✅ Proteksi Create Admin Panel terpasang!"
echo "🔒 Hanya Admin ID 1 yang bisa membuat/mengubah user menjadi Administrator."
echo "👥 Membuat user biasa (non-admin) tetap diizinkan seperti biasa."
echo "==========================================="
