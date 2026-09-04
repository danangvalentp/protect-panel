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
echo "🎨 PROTECT 5B: Branding Footer Panel"
echo "==========================================="
echo ""
# ============================================================
# === BRANDING: Inject footer brand ke layout panel ===
# ============================================================
echo ""
echo "🎨 Memasang branding $BRAND_NAME..."

LAYOUT_FILES=(
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"
)

# Cleanup branding lama dari master.blade.php dan auth.blade.php jika ada
for CLEANUP_FILE in "/var/www/pterodactyl/resources/views/layouts/master.blade.php" "/var/www/pterodactyl/resources/views/layouts/auth.blade.php"; do
  if [ -f "$CLEANUP_FILE" ] && grep -q "BRANDING_JHONALEY" "$CLEANUP_FILE" 2>/dev/null; then
    cleanup_old_branding "$CLEANUP_FILE"
    echo "🧹 Branding lama dihapus dari $(basename "$CLEANUP_FILE")"
  fi
done

BRANDING_FOUND=0

inject_branding() {
  local FILE="$1"
  local LABEL="$2"

  if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "⚠️ File $LABEL tidak ditemukan: $FILE"
    return
  fi

  BRANDING_FOUND=1

  if ! can_modify_file "$FILE"; then
    echo "⚠️ File $LABEL tidak writable, skip branding di file ini"
    return
  fi

  if [ ! -f "${FILE}.bak_${TIMESTAMP}" ]; then
    cp "$FILE" "${FILE}.bak_${TIMESTAMP}" 2>/dev/null || true
  fi

  cleanup_old_branding "$FILE"

  BRANDING_TMP="/tmp/branding_inject_${TIMESTAMP}_$(basename "$FILE").html"
  cat > "$BRANDING_TMP" << BRANDHTML
<!-- BRANDING_JHONALEY_START -->
<style>
  .jhonaley-footer {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 9999;
    background: #1f1f27;
    padding: 8px 18px;
    border-top: 1px solid #2c2c34;
    font-family: 'Source Sans Pro', 'Helvetica Neue', Helvetica, Arial, sans-serif;
    font-size: 12px;
    color: #9b9bb0;
    box-shadow: 0 -1px 0 rgba(0,0,0,0.25);
  }
  .jhonaley-footer .jt-inner {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 14px;
    flex-wrap: wrap;
    line-height: 1.4;
  }
  .jhonaley-footer .jt-brand {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    color: #c7c7d1;
    font-weight: 600;
    letter-spacing: 0.2px;
  }
  .jhonaley-footer .jt-brand-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #0697e2;
    box-shadow: 0 0 6px rgba(6,151,226,0.6);
  }
  .jhonaley-footer .jt-divider {
    width: 1px;
    height: 12px;
    background: #34343f;
  }
  .jhonaley-footer a {
    color: #0697e2;
    text-decoration: none;
    font-weight: 600;
    transition: color 0.15s ease;
  }
  .jhonaley-footer a:hover {
    color: #38b6ff;
    text-decoration: underline;
  }
  .jhonaley-footer .jt-tg {
    display: inline-flex;
    align-items: center;
    gap: 5px;
  }
  .jhonaley-footer .jt-tg svg {
    width: 12px;
    height: 12px;
    fill: currentColor;
    opacity: 0.85;
  }
  body { padding-bottom: 38px !important; }
  @media (max-width: 640px) {
    .jhonaley-footer { font-size: 11px; padding: 7px 12px; }
    .jhonaley-footer .jt-inner { gap: 10px; }
    .jhonaley-footer .jt-divider { display: none; }
    body { padding-bottom: 56px !important; }
  }
</style>
<div class="jhonaley-footer">
  <div class="jt-inner">
    <span class="jt-brand"><span class="jt-brand-dot"></span>$BRAND_TEXT_HTML</span>
    <span class="jt-divider"></span>
    <span>Powered by <a href="https://t.me/$TELEGRAM_USERNAME" target="_blank" rel="noopener">$BRAND_NAME_HTML</a></span>
    <span class="jt-divider"></span>
    <a class="jt-tg" href="https://t.me/$TELEGRAM_USERNAME" target="_blank" rel="noopener">
      <svg viewBox="0 0 24 24"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>
      $CONTACT_TELEGRAM_HTML
    </a>
    <span class="jt-divider"></span>
    <span>Order panel via <a href="https://t.me/$BOT_USERNAME" target="_blank" rel="noopener">$BOT_LINK_HTML</a></span>
  </div>
</div>
<!-- BRANDING_JHONALEY_END -->
BRANDHTML

  inject_before_closing "$FILE" "$BRANDING_TMP" "$LABEL"
  rm -f "$BRANDING_TMP"
  echo "✅ Branding diperbarui di $LABEL"
}

BRANDING_APPLIED=0
for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ]; then
    inject_branding "$LF" "$(basename "$LF")"
    if grep -q "BRANDING_JHONALEY" "$LF" 2>/dev/null; then
      BRANDING_APPLIED=1
    fi
  fi
done

if [ "$BRANDING_APPLIED" -eq 0 ]; then
  echo "❌ Branding admin gagal dipasang: layout admin tidak ditemukan atau tidak termodifikasi"
  exit 1
fi

for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ] && grep -q "<title>" "$LF"; then
    sed -i "s|<title>.*</title>|<title>$SAFE_TITLE</title>|g" "$LF" 2>/dev/null || true
    echo "✅ Title diubah di $(basename "$LF")"
  fi
done

echo "✅ Branding selesai!"

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
echo "✅ PROTECT 5B SELESAI: Branding footer $BRAND_NAME terpasang"
echo "📱 Kontak: $CONTACT_TELEGRAM"
