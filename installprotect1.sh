#!/bin/bash

BRAND_NAME="${BRAND_NAME:-Jhonaley Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"

REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Delete Server..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Exceptions\DisplayException;
use Illuminate\Http\Response;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Log;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Services\Databases\DatabaseManagementService;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class ServerDeletionService
{
    protected bool $force = false;

    /**
     * ServerDeletionService constructor.
     */
    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $daemonServerRepository,
        private DatabaseManagementService $databaseManagementService
    ) {
    }

    /**
     * Set if the server should be forcibly deleted from the panel (ignoring daemon errors) or not.
     */
    public function withForce(bool $bool = true): self
    {
        $this->force = $bool;
        return $this;
    }

    /**
     * Delete a server from the panel and remove any associated databases from hosts.
     *
     * @throws \Throwable
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function handle(Server $server): void
    {
        $this->assertDeletionAllowed($server);

        try {
            $this->daemonServerRepository->setServer($server)->delete();
        } catch (DaemonConnectionException $exception) {
            // Abaikan error 404, tapi lempar error lain jika tidak mode force
            if (!$this->force && $exception->getStatusCode() !== Response::HTTP_NOT_FOUND) {
                throw $exception;
            }

            Log::warning($exception);
        }

        $this->connection->transaction(function () use ($server) {
            foreach ($server->databases as $database) {
                try {
                    $this->databaseManagementService->delete($database);
                } catch (\Exception $exception) {
                    if (!$this->force) {
                        throw $exception;
                    }

                    // Jika gagal delete database di host, tetap hapus dari panel
                    $database->delete();
                    Log::warning($exception);
                }
            }

            $server->delete();
        });
    }

    private function assertDeletionAllowed(Server $server): void
    {
        // 🔒 Jalur PLTA/PLTC diblok total karena panel hanya melihat owner API key,
        // bukan ID Telegram/user bot yang menjalankan perintah delserveroff.
        if ($this->isApiDeleteRequest()) {
            throw new DisplayException('Akses ditolak: hapus server via API/PLTA/PLTC diblokir. Hanya Admin ID 1 lewat panel yang dapat menghapus server @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇.');
        }

        // 🔒 Mode ketat: delete server normal hanya boleh oleh User ID 1.
        $user = $this->resolveActingUser();

        if ($user && (int) $user->id === 1) {
            return;
        }

        // Request HTTP/API tanpa user yang bisa dibaca tetap ditolak agar tidak bypass via token/bot.
        if ($this->isHttpRequest()) {
            throw new DisplayException('Akses ditolak: hanya Admin ID 1 yang dapat menghapus server @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇.');
        }

        // CLI/background job bawaan panel tetap aman; bot/API tidak lewat CLI.
    }

    private function resolveActingUser(): mixed
    {
        $request = null;
        try {
            $request = request();
        } catch (\Throwable $e) {}

        foreach ([null, 'web', 'api', 'application', 'client'] as $guard) {
            try {
                $user = $guard === null ? Auth::user() : Auth::guard($guard)->user();
                if ($user) {
                    return $user;
                }
            } catch (\Throwable $e) {}
        }

        try {
            $user = $request ? $request->user() : null;
            if ($user) {
                return $user;
            }
        } catch (\Throwable $e) {}

        try {
            // Beberapa versi Pterodactyl menyimpan pemilik API key di attribute request.
            $apiKey = $request ? ($request->attributes->get('api_key') ?? $request->attributes->get('apiKey') ?? $request->attributes->get('token')) : null;
            return $apiKey ? ($apiKey->user ?? null) : null;
        } catch (\Throwable $e) {}

        return null;
    }

    private function isHttpRequest(): bool
    {
        try {
            $request = request();
            return $request && app()->runningInConsole() === false;
        } catch (\Throwable $e) {
            return false;
        }
    }

    private function isApiDeleteRequest(): bool
    {
        try {
            $request = request();
            if (!$request || app()->runningInConsole()) {
                return false;
            }

            $path = trim($request->path(), '/');
            return $request->isMethod('delete') && (
                strpos($path, 'api/application/servers') === 0 ||
                strpos($path, 'api/client/servers') === 0
            );
        } catch (\Throwable $e) {
            return false;
        }
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Fallback tambahan: pasang guard di model Server agar jalur force/offline/API yang bypass ServerDeletionService tetap diblokir.
SERVER_MODEL="/var/www/pterodactyl/app/Models/Server.php"
if [ -f "$SERVER_MODEL" ]; then
  cp "$SERVER_MODEL" "${SERVER_MODEL}.bak_${TIMESTAMP}"
  if ! grep -q "PROTEKSI_JHONALEY_SERVER_MODEL_DELETE_GUARD" "$SERVER_MODEL"; then
    TMP_FILE=$(mktemp)
    awk '
      BEGIN { inserted=0 }
      /^}[[:space:]]*$/ && inserted==0 {
        print ""
        print "    // PROTEKSI_JHONALEY_SERVER_MODEL_DELETE_GUARD: fallback anti delete server dari jalur offline/API/bot"
        print "    protected static function booted(): void"
        print "    {"
        print "        static::deleting(function ($server) {"
        print "            try {"
        print "                if (app()->runningInConsole()) { return; }"
        print "                $request = request();"
        print "                $user = null;"
        print "                foreach ([null, 'web', 'api', 'application', 'client'] as $guard) {"
        print "                    try {"
        print "                        $user = $guard === null ? \\Illuminate\\Support\\Facades\\Auth::user() : \\Illuminate\\Support\\Facades\\Auth::guard($guard)->user();"
        print "                        if ($user) { break; }"
        print "                    } catch (\\Throwable $e) {}"
        print "                }"
        print "                if (!$user && $request) {"
        print "                    try { $user = $request->user(); } catch (\\Throwable $e) {}"
        print "                }"
        print "                if (!$user && $request) {"
        print "                    $apiKey = $request->attributes->get('api_key') ?? $request->attributes->get('apiKey') ?? $request->attributes->get('token');"
        print "                    $user = $apiKey ? ($apiKey->user ?? null) : null;"
        print "                }"
        print "                $path = $request ? trim($request->path(), '/') : '';"
        print "                if ($request && $request->isMethod('delete') && (strpos($path, 'api/application/servers') === 0 || strpos($path, 'api/client/servers') === 0)) {"
        print "                    throw new \\Pterodactyl\\Exceptions\\DisplayException('Akses ditolak: hapus server via API/PLTA/PLTC diblokir. Hanya Admin ID 1 lewat panel yang dapat menghapus server @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇.');"
        print "                }"
        print "                if (!$user || (int) $user->id !== 1) {"
        print "                    throw new \\Pterodactyl\\Exceptions\\DisplayException('Akses ditolak: hanya Admin ID 1 yang dapat menghapus server @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇.');"
        print "                }"
        print "            } catch (\\Pterodactyl\\Exceptions\\DisplayException $e) {"
        print "                throw $e;"
        print "            } catch (\\Throwable $e) {"
        print "                throw new \\Pterodactyl\\Exceptions\\DisplayException('Akses ditolak: validasi hapus server gagal @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇.');"
        print "            }"
        print "        });"
        print "    }"
        inserted=1
      }
      { print }
    ' "$SERVER_MODEL" > "$TMP_FILE" && mv "$TMP_FILE" "$SERVER_MODEL"
    chmod 644 "$SERVER_MODEL"
    echo "✅ Fallback guard Server model terpasang."
  else
    echo "⚠️ Fallback guard Server model sudah ada, skip."
  fi
else
  echo "⚠️ Server model tidak ditemukan, fallback guard dilewati: $SERVER_MODEL"
fi

# Fallback khusus PLTA: blok langsung endpoint Application API delete server.
# delserveroff di panel.js memakai DELETE /api/application/servers/{id}, sehingga API key milik ID 1
# tetap tidak boleh dipakai bot/user lain untuk menghapus server.
APP_SERVER_CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Api/Application/Servers/ServerController.php"
if [ -f "$APP_SERVER_CONTROLLER" ]; then
  cp "$APP_SERVER_CONTROLLER" "${APP_SERVER_CONTROLLER}.bak_${TIMESTAMP}"
  if ! grep -q "PROTEKSI_JHONALEY_BLOCK_APPLICATION_API_SERVER_DELETE" "$APP_SERVER_CONTROLLER"; then
    TMP_FILE=$(mktemp)
    awk '
      BEGIN { in_delete=0; inserted=0 }
      /function[[:space:]]+delete[[:space:]]*\(/ { in_delete=1 }
      {
        print
        if (in_delete==1 && inserted==0 && $0 ~ /^[[:space:]]*\{[[:space:]]*$/) {
          print "        // PROTEKSI_JHONALEY_BLOCK_APPLICATION_API_SERVER_DELETE: blok delserveroff/PLTA delete server"
          print "        throw new \\Pterodactyl\\Exceptions\\DisplayException('\''Akses ditolak: hapus server via API/PLTA diblokir. Hanya Admin ID 1 lewat panel yang dapat menghapus server @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇.'\'');"
          inserted=1
          in_delete=0
        }
      }
    ' "$APP_SERVER_CONTROLLER" > "$TMP_FILE" && mv "$TMP_FILE" "$APP_SERVER_CONTROLLER"
    chmod 644 "$APP_SERVER_CONTROLLER"
    echo "✅ Guard Application API delete server terpasang."
  else
    echo "⚠️ Guard Application API delete server sudah ada, skip."
  fi
else
  echo "⚠️ Controller Application API server tidak ditemukan, guard PLTA dilewati: $APP_SERVER_CONTROLLER"
fi

# Apply brand customization
sed -i "s|Protect By Jhonaley|${BRAND_TEXT}|g" "$REMOTE_PATH" 2>/dev/null || true
sed -i "s|Jhonaley Tech|${BRAND_NAME}|g" "$REMOTE_PATH" 2>/dev/null || true
sed -i "s|𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇|${BRAND_TEXT}|g" "$REMOTE_PATH" 2>/dev/null || true
if [ -f "$SERVER_MODEL" ]; then
  sed -i "s|𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇|${BRAND_TEXT}|g" "$SERVER_MODEL" 2>/dev/null || true
fi
if [ -f "$APP_SERVER_CONTROLLER" ]; then
  sed -i "s|𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘 𝐉𝐇𝐎𝐍𝐀𝐋𝐄𝐘 𝐓𝐄𝐂𝐇|${BRAND_TEXT}|g" "$APP_SERVER_CONTROLLER" 2>/dev/null || true
fi

echo "✅ Proteksi Anti Delete Server berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hapus server via API/PLTA/PLTC diblokir; hapus normal lewat panel hanya Admin ID 1."
