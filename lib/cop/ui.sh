# ui.sh — colors, banner, show_usage, print_info

# --- Pastel Colors (soft, beautiful) -----------------------------------------
C_ROSE=$'\033[38;5;218m'     # soft pink
C_PEACH=$'\033[38;5;223m'    # warm peach
C_MINT=$'\033[38;5;158m'     # fresh mint
C_SKY=$'\033[38;5;117m'      # morning sky
C_LAVENDER=$'\033[38;5;183m' # gentle lavender
C_GOLD=$'\033[38;5;222m'     # sunrise gold
C_CORAL=$'\033[38;5;210m'    # soft coral
C_DIM=$'\033[2m'             # dimmed
C_RESET=$'\033[0m'           # reset
C_BOLD=$'\033[1m'            # bold

# Honour NO_COLOR (https://no-color.org/) and dumb terminals
if [[ -n "${NO_COLOR+x}" || "${TERM:-}" == "dumb" ]]; then
  C_ROSE="" C_PEACH="" C_MINT="" C_SKY="" C_LAVENDER="" C_GOLD=""
  C_CORAL="" C_DIM="" C_RESET="" C_BOLD=""
fi

# --- ASCII Art (single default banner) ---------------------------------------
art_banner() {
  cat <<'EOF'
  ██████╗ ██████╗ ██████╗
 ██╔════╝██╔═══██╗██╔══██╗
 ██║     ██║   ██║██████╔╝
 ██║     ██║   ██║██╔═══╝
 ╚██████╗╚██████╔╝██║
  ╚═════╝ ╚═════╝ ╚═╝
EOF
}

print_rainbow_line() {
  printf "  %s━%s━%s━%s━%s━%s━%s━%s━%s━%s━%s━%s━%s━%s━%s━%s━%s━%s━%s━%s%s\n" \
    "$C_GOLD" "$C_PEACH" "$C_CORAL" "$C_ROSE" "$C_LAVENDER" \
    "$C_SKY" "$C_MINT" "$C_GOLD" "$C_PEACH" "$C_CORAL" \
    "$C_ROSE" "$C_LAVENDER" "$C_SKY" "$C_MINT" "$C_GOLD" \
    "$C_PEACH" "$C_CORAL" "$C_ROSE" "$C_LAVENDER" "$C_SKY" "$C_RESET"
}

show_horizon() {

  # Top line
  print_rainbow_line

  # Art in gradient colors
  local colors=("$C_PEACH" "$C_GOLD" "$C_CORAL" "$C_ROSE" "$C_LAVENDER" "$C_SKY")
  local i=0
  while IFS= read -r line; do
    printf "%s%s%s\n" "${colors[$((i % ${#colors[@]}))]}" "$line" "$C_RESET"
    ((i++)) || true
  done < <(art_banner)

  # Bottom line
  print_rainbow_line

  # Tagline
  printf "  %s☀ clipboard helper%s\n\n" "$C_DIM" "$C_RESET"
}

# --- Logging -----------------------------------------------------------------
log() { printf "📋 %s%s%s\n" "$C_CORAL" "$*" "$C_RESET" >&2; }

# --- Content Stats -----------------------------------------------------------
format_size() {
  local bytes=$1
  if ((bytes >= 1048576)); then
    printf "%.2f MB" "$(( bytes * 100 / 1048576 ))e-2"
  elif ((bytes >= 1024)); then
    printf "%.2f kB" "$(( bytes * 100 / 1024 ))e-2"
  else
    printf "%d B" "$bytes"
  fi
}

content_stats() {
  local data="$1"
  local bytes chars words lines md5h sha256h compress_ratio ftype enc_info

  bytes=${#data}
  chars=$(printf "%s" "$data" | wc -m | tr -d ' ')
  words=$(printf "%s" "$data" | wc -w | tr -d ' ')
  lines=$(printf "%s" "$data" | wc -l | tr -d ' ')

  # Hashes (first 6 chars)
  md5h=$(printf "%s" "$data" | md5sum 2>/dev/null | cut -c1-6 || echo "------")
  sha256h=$(printf "%s" "$data" | sha256sum 2>/dev/null | cut -c1-6 || echo "------")

  # Compressibility (gzip ratio)
  if command -v gzip &>/dev/null && ((bytes > 0)); then
    local compressed
    compressed=$(printf "%s" "$data" | gzip -c | wc -c | tr -d ' ')
    compress_ratio=$(echo "scale=0; 100 - ($compressed * 100 / $bytes)" | bc 2>/dev/null || echo "0")
  else
    compress_ratio="?"
  fi

  # File type detection
  ftype=$(printf "%s" "$data" | file -b - 2>/dev/null | cut -d, -f1 | head -c30 || echo "unknown")

  # Encoding detection
  enc_info=$(printf "%s" "$data" | file -b --mime-encoding - 2>/dev/null || echo "?")

  # Single-line output with icons
  printf "%s📊%s %s %s│%s %s%dC %dW %dL%s %s│%s %s#%s%s/%s%s%s %s│%s %s↘%s%%%s %s│%s %s%s%s %s[%s]%s" \
    "$C_SKY" "$C_RESET" "$(format_size "$bytes")" \
    "$C_DIM" "$C_RESET" "$C_PEACH" "$chars" "$words" "$lines" "$C_RESET" \
    "$C_DIM" "$C_RESET" "$C_LAVENDER" "$md5h" "$C_RESET" "$C_LAVENDER" "$sha256h" "$C_RESET" \
    "$C_DIM" "$C_RESET" "$C_MINT" "$compress_ratio" "$C_RESET" \
    "$C_DIM" "$C_RESET" "$C_GOLD" "$ftype" "$C_RESET" \
    "$C_DIM" "$enc_info" "$C_RESET"
}

# --- Help --------------------------------------------------------------------
show_usage() {
  local topic="${1:-}"
  case "$topic" in
    examples)  _show_usage_examples  ;;
    templates) _show_usage_templates ;;
    network)   _show_usage_network   ;;
    *)         _show_usage_short     ;;
  esac
}

_show_usage_short() {
  cat >&2 <<EOF
${C_GOLD}Usage:${C_RESET} cop [OPTIONS] [FILE...]

${C_DIM}Clipboard helper — auto-selects pbcopy / wl-copy / xclip / OSC 52.${C_RESET}

${C_GOLD}Options:${C_RESET}
  ${C_SKY}-p${C_RESET}  --paste              Paste from clipboard or remote
  ${C_SKY}-n${C_RESET}  --network            Sync via cloud clipboard service
  ${C_SKY}-e${C_RESET}  --encrypted          AES-256-CBC encrypt/decrypt (\$COP_SECRET)
  ${C_SKY}-c${C_RESET}  --copy               Also copy fetched data locally (with -n)
  ${C_SKY}-t${C_RESET}  --tee                Also emit copied payload to stdout
  ${C_SKY}-a${C_RESET}  --append             Append to existing clipboard contents
  ${C_SKY}-i${C_RESET}  --info               Show clipboard backend info
  ${C_SKY}-h${C_RESET}  --help [TOPIC]       This help; topics: examples  templates  network
      --notes              Open/create NOTES.md in current directory
      --template NAME      Copy template to current directory
      --templates          List available templates
      --test               Run self-tests
      --completions SHELL  Emit shell completions (fish)

${C_DIM}Quick:  echo "hi" | cop    cop file.txt    cop -p    cop -ne file.txt${C_RESET}

${C_DIM}Details:  cop --help examples  |  cop --help templates  |  cop --help network${C_RESET}
EOF
}

_show_usage_examples() {
  cat >&2 <<EOF
${C_GOLD}Examples — cop${C_RESET}

${C_GOLD}Copy:${C_RESET}
  ${C_DIM}echo "hello" | cop${C_RESET}      copy text
  ${C_DIM}cop file.txt${C_RESET}            copy file contents
  ${C_DIM}cop < file.txt${C_RESET}          copy via redirect
  ${C_DIM}cop dir/${C_RESET}                copy all files in directory

${C_GOLD}Paste:${C_RESET}
  ${C_DIM}cop -p${C_RESET}                  paste to stdout
  ${C_DIM}cop -p out.txt${C_RESET}          paste into file
  ${C_DIM}cop -p > out.txt${C_RESET}        paste via redirect
  ${C_DIM}pas${C_RESET}                     paste (pas is a symlink to cop)

${C_GOLD}Modify:${C_RESET}
  ${C_DIM}echo "more" | cop -a${C_RESET}    append to existing clipboard
  ${C_DIM}cop -a file.txt${C_RESET}         append file to existing clipboard
  ${C_DIM}ls | cop -t${C_RESET}             copy and also print what was copied

${C_GOLD}Notes:${C_RESET}
  ${C_DIM}cop --notes${C_RESET}             open/create NOTES.md here
  ${C_DIM}notes${C_RESET}                   same (notes is a symlink to cop)

${C_DIM}Around the survivors, a perimeter create!${C_RESET}
EOF
}

_show_usage_templates() {
  cat >&2 <<EOF
${C_GOLD}Templates — cop${C_RESET}

  ${C_DIM}cop --templates${C_RESET}              list available templates
  ${C_DIM}cop --template .gitignore${C_RESET}    copy .gitignore into current directory
  ${C_DIM}cop --template .editorconfig${C_RESET} copy .editorconfig into current directory
  ${C_DIM}cop --template NOTES.md${C_RESET}      copy NOTES.md into current directory

Templates are copied as-is into the current working directory.
The filename is preserved (including leading dot for dotfiles).
EOF
}

_show_usage_network() {
  cat >&2 <<EOF
${C_GOLD}Network / Encrypt — cop${C_RESET}

${C_GOLD}Sync:${C_RESET}
  ${C_DIM}cop -n file.txt${C_RESET}         encrypt-free sync to remote
  ${C_DIM}cop -pn${C_RESET}                 fetch from remote to stdout
  ${C_DIM}cop -pnc${C_RESET}                fetch from remote and copy locally

${C_GOLD}Encrypted sync:${C_RESET}
  export COP_SECRET=mysecret
  ${C_DIM}cop -ne file.txt${C_RESET}        encrypt & sync to remote
  ${C_DIM}cop -pne${C_RESET}                decrypt & paste from remote

${C_GOLD}Requires:${C_RESET}  \$COP_KV_URL (kv store endpoint), openssl (for -e)
EOF
}

# --- Fish Completions --------------------------------------------------------
emit_completions_fish() {
  cat <<'FISH'
# cop fish completions — generated by: cop --completions fish

# Disable file completion by default; re-enable selectively below
complete -c cop -f

# Flags
complete -c cop -s h -l help     -d 'Show help'
complete -c cop -s p -l paste    -d 'Paste from clipboard or remote'
complete -c cop -s n -l network  -d 'Sync via cloud clipboard service'
complete -c cop -s e -l encrypted  -d 'AES-256-CBC encrypt/decrypt ($COP_SECRET)'
complete -c cop -s c -l copy     -d 'Also copy fetched data locally (with -n)'
complete -c cop -s t -l tee      -d 'Also emit copied payload to stdout'
complete -c cop -s a -l append   -d 'Append to existing clipboard contents'
complete -c cop -s i -l info     -d 'Show clipboard command info'
complete -c cop      -l notes    -d 'Open or create NOTES.md in current directory'
complete -c cop      -l test     -d 'Run self-tests'
complete -c cop      -l completions -r -d 'Emit shell completions (e.g. fish)'
complete -c cop -l template    -r -d 'Copy template to current directory'
complete -c cop -l templates   -d 'List available templates'

# File arguments — only when not in paste mode (no -p / --paste seen)
complete -c cop -F -n 'not __fish_contains_opt p paste'
FISH
}

# --- Info Display ------------------------------------------------------------
print_info() {
  show_horizon >&2
  printf "%sClipboard Info%s\n\n" "$C_GOLD" "$C_RESET" >&2

  # OSC 52 / SSH status
  if is_ssh_session; then
    printf "  %sSSH session detected%s — using %sOSC 52%s (terminal-carried clipboard)\n\n" \
      "$C_GOLD" "$C_RESET" "$C_MINT" "$C_RESET" >&2
  fi

  # Copy commands
  printf "  Copy commands:\n" >&2
  for cmd in "${COPY_CMDS[@]}"; do
    local symbol color note
    symbol="─"
    color="$C_DIM"
    note=""

    if command -v "$cmd" &>/dev/null; then
      symbol="✓"
      color="$C_MINT"
      case "$cmd" in
      wl-copy)
        if ! is_wayland; then
          symbol="○"
          color="$C_GOLD"
          note=" (no Wayland)"
        fi
        ;;
      xclip | xsel)
        if ! is_x11; then
          symbol="○"
          color="$C_GOLD"
          note=" (no X11)"
        fi
        ;;
      esac
    fi

    printf "    %-18s %s%s%s%s\n" "$cmd" "$color" "$symbol" "$note" "$C_RESET" >&2
  done

  # Paste commands
  printf "\n  Paste commands:\n" >&2
  for cmd in "${PASTE_CMDS[@]}"; do
    local symbol color note
    symbol="─"
    color="$C_DIM"
    note=""

    if command -v "$cmd" &>/dev/null; then
      symbol="✓"
      color="$C_MINT"
      case "$cmd" in
      wl-paste)
        if ! is_wayland; then
          symbol="○"
          color="$C_GOLD"
          note=" (no Wayland)"
        fi
        ;;
      xclip | xsel)
        if ! is_x11; then
          symbol="○"
          color="$C_GOLD"
          note=" (no X11)"
        fi
        ;;
      esac
    fi

    printf "    %-18s %s%s%s%s\n" "$cmd" "$color" "$symbol" "$note" "$C_RESET" >&2
  done

  local copy_cmd
  copy_cmd=$(find_copy_cmd 2>/dev/null || echo "none")
  local current
  current=$(find_paste_cmd 2>/dev/null || echo "none")

  printf "\n  %sActive:%s copy=%s, paste=%s\n" \
    "$C_SKY" "$C_RESET" "$copy_cmd" "$current" >&2
}
