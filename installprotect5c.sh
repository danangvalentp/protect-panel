#!/bin/bash

set -e

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

BRAND_NAME="${BRAND_NAME:-Jhonaley Store}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@JhoanleystoreId}"
BOT_LINK="${BOT_LINK:-@upgradeuser_bot}"
WELCOME_TITLE="${WELCOME_TITLE:-Welcome To Server $BRAND_NAME}"
WELCOME_MESSAGE="${WELCOME_MESSAGE:-Butuh panel legal yang anti mokad? langsung aja ke <a href=\"https://t.me/upgradeuser_bot\">@upgradeuser_bot</a>. Jangan Lupa join Channel <a href=\"https://t.me/jhonaleytesti3\">@jhonaleytesti3</a>.}"

TELEGRAM_USERNAME="${CONTACT_TELEGRAM#@}"
BOT_USERNAME="${BOT_LINK#@}"

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

js_escape() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e "s/'/\\\\'/g"
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

BRAND_NAME_HTML=$(html_escape "$BRAND_NAME")
BRAND_TEXT_HTML=$(html_escape "$BRAND_TEXT")
CONTACT_TELEGRAM_HTML=$(html_escape "$CONTACT_TELEGRAM")
BOT_LINK_HTML=$(html_escape "$BOT_LINK")
BRAND_NAME_JS=$(js_escape "$BRAND_NAME")
CONTACT_TELEGRAM_JS=$(js_escape "$CONTACT_TELEGRAM")
WELCOME_TITLE_JS=$(js_escape "$WELCOME_TITLE")
WELCOME_MESSAGE_JS=$(js_escape "$WELCOME_MESSAGE")
SAFE_TITLE=$(sed_escape "${PANEL_TITLE:-Pterodactyl - $BRAND_NAME}")

can_modify_file() {
  local file="$1"
  if [ -f "$file" ] && [ -w "$file" ]; then
    return 0
  fi

  local dir
  dir=$(dirname "$file")
  [ -w "$dir" ]
}

write_temp_to_target() {
  local temp_file="$1"
  local target_file="$2"
  local label="$3"

  if [ -f "$target_file" ]; then
    chmod u+w "$target_file" 2>/dev/null || true
    chown --reference="$target_file" "$temp_file" 2>/dev/null || true
    chmod --reference="$target_file" "$temp_file" 2>/dev/null || true
  fi

  if cat "$temp_file" > "$target_file" 2>/dev/null; then
    return 0
  fi

  if cp "$temp_file" "$target_file" 2>/dev/null; then
    return 0
  fi

  echo "⚠️ Tidak bisa menulis ke $label, skip. Cek permission file/folder target."
  return 1
}

remove_block_by_markers() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip cleanup branding di $file karena tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)
  awk -v start="$start_marker" -v end="$end_marker" '
    index($0, start) { skip=1; next }
    skip && index($0, end) { skip=0; next }
    !skip { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

cleanup_old_branding() {
  local file="$1"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip branding cleanup di $file karena tidak writable"
    return 0
  fi

  remove_block_by_markers "$file" "<!-- BRANDING_JHONALEY_START -->" "<!-- BRANDING_JHONALEY_END -->"
  remove_block_by_markers "$file" "<!-- BRANDING_JHONALEY: Custom Branding -->" "</style>"

  tmp_file=$(mktemp)
  awk '
    BEGIN { skip=0; depth=0; seen_div=0 }
    /<!-- BRANDING_JHONALEY: Footer -->/ { skip=1; depth=0; seen_div=0; next }
    skip {
      line=$0
      opens=gsub(/<div[^>]*>/, "&", line)
      closes=gsub(/<\/div>/, "&", line)
      if (opens > 0) {
        depth += opens
        seen_div = 1
      }
      if (closes > 0) {
        depth -= closes
      }
      if (seen_div && depth <= 0) {
        skip=0
      }
      next
    }
    { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

inject_before_closing() {
  local file="$1"
  local snippet_file="$2"
  local label="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip inject ke $label karena file tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)

  if grep -q "</body>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/body>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </body> di $label"
  elif grep -q "</html>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/html>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </html> di $label"
  else
    cat "$snippet_file" > "$tmp_file"
    cat "$file" >> "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten ditambahkan di akhir $label"
  fi

  rm -f "$tmp_file"
}

echo "==========================================="
echo "📋 PROTECT 5C: Welcome Banner Client Dashboard"
echo "==========================================="
echo ""
# ============================================================
# === BAGIAN 3: Welcome Banner di Client Dashboard ===
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Welcome Banner Client Dashboard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WRAPPER_FILE="/var/www/pterodactyl/resources/views/templates/wrapper.blade.php"
MASTER_FILE="/var/www/pterodactyl/resources/views/layouts/master.blade.php"

WELCOME_TARGET=""
if [ -f "$WRAPPER_FILE" ]; then
  WELCOME_TARGET="$WRAPPER_FILE"
elif [ -f "$MASTER_FILE" ]; then
  WELCOME_TARGET="$MASTER_FILE"
else
  WELCOME_TARGET=$(find /var/www/pterodactyl/resources/views/ -name "wrapper.blade.php" 2>/dev/null | head -1)
  if [ -z "$WELCOME_TARGET" ]; then
    WELCOME_TARGET=$(find /var/www/pterodactyl/resources/views/templates/ -name "*.blade.php" 2>/dev/null | head -1)
  fi
fi

if [ -z "$WELCOME_TARGET" ] || [ ! -f "$WELCOME_TARGET" ]; then
  echo "⚠️ File layout client tidak ditemukan, skip welcome banner."
else
  echo "📂 Target: $WELCOME_TARGET"

  cp "$WELCOME_TARGET" "${WELCOME_TARGET}.bak_${TIMESTAMP}" 2>/dev/null || true
  remove_block_by_markers "$WELCOME_TARGET" "<!-- WELCOME_JHONALEY: Welcome Banner -->" "<!-- /WELCOME_JHONALEY -->"
  # Bersihkan juga marker legacy dari versi sebelumnya
  remove_block_by_markers "$WELCOME_TARGET" "<!-- JHONALEY_WELCOME_START -->" "<!-- JHONALEY_WELCOME_END -->"
  remove_block_by_markers "$WELCOME_TARGET" "<!-- JHONALEY_WELCOME: Welcome Banner -->" "<!-- /JHONALEY_WELCOME -->"
  remove_block_by_markers "$WELCOME_TARGET" "<!-- WELCOME_JHONALEY_START -->" "<!-- WELCOME_JHONALEY_END -->"

  WELCOME_TEMP=$(mktemp)
  cat > "$WELCOME_TEMP" << WELCOME_EOF
<!-- WELCOME_JHONALEY: Welcome Banner -->
<style>
  .jhonaley-welcome {
    background: #0a0a0a;
    border: 2px solid #dc2626;
    border-radius: 0;
    margin: 20px 24px 0 24px;
    font-family: 'JetBrains Mono', 'Courier New', monospace;
    color: #fafafa;
    box-shadow: 6px 6px 0 0 #dc2626;
    overflow: hidden;
    position: relative;
  }
  .jhonaley-welcome::before {
    content: "";
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 3px;
    background: repeating-linear-gradient(90deg, #dc2626 0 12px, #fbbf24 12px 24px, #0a0a0a 24px 36px);
  }
  .jhonaley-welcome .jw-header {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 16px;
    background: #dc2626;
    border-bottom: 2px solid #0a0a0a;
  }
  .jhonaley-welcome .jw-header .jw-dot {
    width: 10px;
    height: 10px;
    border-radius: 0;
    background: #fbbf24;
    border: 1.5px solid #0a0a0a;
  }
  .jhonaley-welcome .jw-header .jw-title {
    color: #0a0a0a;
    font-size: 12px;
    font-weight: 900;
    text-transform: uppercase;
    letter-spacing: 2px;
    margin: 0;
    flex: 1;
    font-family: 'JetBrains Mono', monospace;
  }
  .jhonaley-welcome .jw-header .jw-tag {
    font-size: 10px;
    font-weight: 900;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    color: #0a0a0a;
    border: 1.5px solid #0a0a0a;
    padding: 2px 8px;
    background: #fbbf24;
  }
  .jhonaley-welcome .jw-body {
    display: flex;
    align-items: flex-start;
    gap: 16px;
    padding: 20px 22px;
    background: #0a0a0a;
  }
  .jhonaley-welcome .jw-icon {
    width: 46px;
    height: 46px;
    min-width: 46px;
    border-radius: 0;
    background: #dc2626;
    color: #fafafa;
    border: 2px solid #fbbf24;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .jhonaley-welcome .jw-icon svg { width: 22px; height: 22px; fill: currentColor; }
  .jhonaley-welcome .jw-content { flex: 1; min-width: 0; }
  .jhonaley-welcome .jw-content h3 {
    color: #fbbf24;
    font-size: 18px;
    font-weight: 900;
    margin: 0 0 6px 0;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    font-family: 'JetBrains Mono', monospace;
  }
  .jhonaley-welcome .jw-content h3::before {
    content: "[ ";
    color: #dc2626;
  }
  .jhonaley-welcome .jw-content h3::after {
    content: " ]";
    color: #dc2626;
  }
  .jhonaley-welcome .jw-content p {
    color: #e5e5e5;
    font-size: 13px;
    margin: 0;
    line-height: 1.65;
    font-family: 'Segoe UI', system-ui, sans-serif;
  }
  .jhonaley-welcome .jw-content a {
    color: #fbbf24;
    font-weight: 700;
    text-decoration: none;
    border-bottom: 1.5px solid #dc2626;
    padding: 0 2px;
    transition: all 0.15s ease;
  }
  .jhonaley-welcome .jw-content a:hover {
    background: #dc2626;
    color: #fafafa;
    border-bottom-color: #fbbf24;
  }
  @media (max-width: 640px) {
    .jhonaley-welcome { margin: 14px 12px 0 12px; box-shadow: 4px 4px 0 0 #dc2626; }
    .jhonaley-welcome .jw-body { padding: 16px; gap: 12px; }
    .jhonaley-welcome .jw-content h3 { font-size: 15px; letter-spacing: 1px; }
    .jhonaley-welcome .jw-content p { font-size: 12px; }
    .jhonaley-welcome .jw-header .jw-tag { display: none; }
  }
</style>
<script>
document.addEventListener("DOMContentLoaded", function() {
  var ICON_SVG = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/></svg>';
  function injectWelcome() {
    if (document.getElementById("jhonaley-welcome-banner")) return;
    var containers = [
      document.querySelector("[class*=ContentContainer]"),
      document.querySelector("[class*=content-wrapper]"),
      document.querySelector("#app > div > div:last-child"),
      document.querySelector("main"),
      document.querySelector(".content-wrapper"),
      document.querySelector("#app")
    ];
    var target = null;
    for (var i = 0; i < containers.length; i++) {
      if (containers[i]) { target = containers[i]; break; }
    }
    if (!target) return;
    var banner = document.createElement("div");
    banner.id = "jhonaley-welcome-banner";
    banner.className = "jhonaley-welcome";
    banner.innerHTML = ''
      + '<div class="jw-header">'
      +   '<span class="jw-dot"></span>'
      +   '<h4 class="jw-title">// SYSTEM_NOTICE.SYS</h4>'
      +   '<span class="jw-tag">● VERIFIED</span>'
      + '</div>'
      + '<div class="jw-body">'
      +   '<div class="jw-icon">' + ICON_SVG + '</div>'
      +   '<div class="jw-content"><h3>$WELCOME_TITLE_JS</h3><p>$WELCOME_MESSAGE_JS</p></div>'
      + '</div>';
    if (target.firstChild) { target.insertBefore(banner, target.firstChild); }
    else { target.appendChild(banner); }
  }
  injectWelcome();
  var observer = new MutationObserver(function() {
    if (!document.getElementById("jhonaley-welcome-banner")) injectWelcome();
  });
  var appEl = document.getElementById("app") || document.body;
  observer.observe(appEl, { childList: true, subtree: true });
});
</script>
<!-- /WELCOME_JHONALEY -->
WELCOME_EOF

  inject_before_closing "$WELCOME_TARGET" "$WELCOME_TEMP" "$(basename "$WELCOME_TARGET")"
  rm -f "$WELCOME_TEMP"
  echo "✅ Welcome banner diperbarui di $(basename "$WELCOME_TARGET")"
fi

# ===================================================================
# RE-INJECT SIDEBAR PROTECT MANAGER (jika hilang setelah modifikasi admin.blade.php)
# ===================================================================
ADMIN_LAYOUT=""
for CANDIDATE in \
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"; do
  if [ -f "$CANDIDATE" ]; then
    ADMIN_LAYOUT="$CANDIDATE"
    break
  fi
done

if [ -f "$ADMIN_LAYOUT" ] && ! grep -q "PROTEKSI_JHONALEY_MASTER_SIDEBAR" "$ADMIN_LAYOUT" 2>/dev/null; then
  echo "🔧 Re-inject sidebar Protect Manager..."

  SIDEBAR_SNIPPET=$(mktemp)
  cat > "$SIDEBAR_SNIPPET" << 'SIDEBAR_PM_EOF'
                {{-- PROTEKSI_JHONALEY_MASTER_SIDEBAR: Protect Manager Menu --}}
                @if(Auth::user() && Auth::user()->id === 1)
                <li class="{{ Route::currentRouteName() === 'admin.protect-manager' ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>
                @endif
                {{-- END PROTEKSI_JHONALEY_MASTER_SIDEBAR --}}
SIDEBAR_PM_EOF

  INSERT_LINE=""
  SETTINGS_LINE=$(grep -n "admin.settings\|Configuration\|Settings\|settings" "$ADMIN_LAYOUT" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$SETTINGS_LINE" ]; then
    INSERT_LINE=$((SETTINGS_LINE - 1))
    while [ "$INSERT_LINE" -gt 0 ]; do
      if sed -n "${INSERT_LINE}p" "$ADMIN_LAYOUT" | grep -q "<li"; then
        break
      fi
      INSERT_LINE=$((INSERT_LINE - 1))
    done
  fi

  if [ -z "$INSERT_LINE" ] || [ "$INSERT_LINE" -le 0 ]; then
    INSERT_LINE=$(grep -n "</ul>" "$ADMIN_LAYOUT" | tail -1 | cut -d: -f1)
    if [ -n "$INSERT_LINE" ]; then
      INSERT_LINE=$((INSERT_LINE - 1))
    fi
  fi

  if [ -n "$INSERT_LINE" ] && [ "$INSERT_LINE" -gt 0 ]; then
    TEMP_LAYOUT=$(mktemp)
    head -n "$INSERT_LINE" "$ADMIN_LAYOUT" > "$TEMP_LAYOUT"
    cat "$SIDEBAR_SNIPPET" >> "$TEMP_LAYOUT"
    tail -n +"$((INSERT_LINE + 1))" "$ADMIN_LAYOUT" >> "$TEMP_LAYOUT"
    if cat "$TEMP_LAYOUT" > "$ADMIN_LAYOUT" 2>/dev/null; then
      echo "✅ Sidebar Protect Manager berhasil di-re-inject"
    else
      echo "⚠️ Gagal re-inject sidebar, skip"
    fi
    rm -f "$TEMP_LAYOUT"
  else
    echo "⚠️ Tidak bisa menemukan posisi sidebar untuk re-inject"
  fi
  rm -f "$SIDEBAR_SNIPPET"
fi

# ===================================================================
# CLEAR CACHE - paksa clear di sini agar welcome banner langsung tampil
# ===================================================================
if [ -d /var/www/pterodactyl ]; then
  cd /var/www/pterodactyl
  php artisan view:clear 2>/dev/null || true
  php artisan cache:clear 2>/dev/null || true
  rm -rf /var/www/pterodactyl/storage/framework/views/*.php 2>/dev/null || true
  echo "✅ View & compiled blade cache dibersihkan"
fi


echo ""
echo "✅ PROTECT 5C SELESAI: Welcome banner terpasang di dashboard client"
