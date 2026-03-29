# core.sh — do_copy, do_paste, do_notes, main

# --- Notes -------------------------------------------------------------------
do_notes() {
  local notes_file="NOTES.md"
  if [[ ! -f "$notes_file" ]]; then
    do_template "NOTES.md"
  fi
  local editor="${EDITOR:-vi}"
  exec "$editor" "$notes_file"
}

# --- Main Operations ---------------------------------------------------------
do_paste() {
  local network=$1 enc=$2 copy_local=$3 output_file="${4:-}"
  local raw out

  # Resolve symlink if output_file is one
  local resolved_file=""
  if [[ -n "$output_file" && -L "$output_file" ]]; then
    resolved_file=$(readlink -f "$output_file")
  fi

  if ((network)); then
    raw=$(kv_fetch) || exit 1
    printf "📋 %s✓ Fetched%s from %scloud clipboard%s\n" \
      "$C_MINT" "$C_RESET" "$C_SKY" "$C_RESET" >&2
  else
    raw=$(get_local_clipboard)
    local via="${PASTE_USED:-clipboard}"
    printf "📋 %s✓ Pasted%s via %s%s%s\n" \
      "$C_MINT" "$C_RESET" "$C_SKY" "$via" "$C_RESET" >&2
  fi

  if ((enc)); then
    ensure_openssl || exit 1
    if [[ -z "${COP_SECRET:-}" ]]; then
      if [[ "${COP_TESTING:-}" == "1" ]]; then
        log "[TEST] COP_SECRET not set (expected)"
      else
        log "COP_SECRET not set"
      fi
      exit 1
    fi
    # raw is expected to be base64(ciphertext) in both local and network modes.
    out=$(printf "%s" "$raw" | openssl enc -d -aes-256-cbc -pbkdf2 -pass env:COP_SECRET -base64) || exit 1
  else
    if ((network)); then
      # raw is base64(plaintext) from the cloud clipboard
      out=$(printf "%s" "$raw" | b64_decode)
    else
      # local clipboard is plain text
      out="$raw"
    fi
  fi

  ((copy_local)) && printf "%s" "$out" | copy_to_clipboard

  if [[ -n "$output_file" ]]; then
    local target="${resolved_file:-$output_file}"
    printf "%s" "$out" >"$target"
    if [[ -n "$resolved_file" ]]; then
      printf "📋 %s✓ Written%s → %s%s%s %s→%s %s%s%s %s│%s %s\n" \
        "$C_MINT" "$C_RESET" "$C_SKY" "$output_file" "$C_RESET" \
        "$C_DIM" "$C_RESET" "$C_SKY" "$resolved_file" "$C_RESET" \
        "$C_DIM" "$C_RESET" "$(content_stats "$out")" >&2
    else
      printf "📋 %s✓ Written%s → %s%s%s %s│%s %s\n" \
        "$C_MINT" "$C_RESET" "$C_SKY" "$output_file" "$C_RESET" "$C_DIM" "$C_RESET" "$(content_stats "$out")" >&2
    fi
  else
    printf "%s" "$out"
  fi
}

do_copy() {
  local network=$1 enc=$2 copy_local=$3 stdout_flag=$4 append=$5 payload="$6"
  local to_send net_payload

  # Append mode: prepend existing local clipboard contents
  if ((append)); then
    local existing
    existing=$(get_local_clipboard 2>/dev/null || true)
    payload="${existing}${payload}"
  fi

  if ((stdout_flag)); then
    printf "%s" "$payload"
  fi

  if ((enc)); then
    ensure_openssl || return 1
    if [[ -z "${COP_SECRET:-}" ]]; then
      if [[ "${COP_TESTING:-}" == "1" ]]; then
        log "[TEST] COP_SECRET not set (expected)"
      else
        log "COP_SECRET not set"
      fi
      return 1
    fi
    # Base64-encoded ciphertext
    to_send=$(printf "%s" "$payload" | openssl enc -aes-256-cbc -salt -pbkdf2 -pass env:COP_SECRET -base64) || return 1
    net_payload="$to_send" # already base64(ciphertext)
  else
    to_send="$payload"
    # For non-encrypted network sync, store base64(plaintext)
    net_payload=$(printf "%s" "$payload" | b64_encode)
  fi

  ((copy_local)) && printf "%s" "$to_send" | copy_to_clipboard

  if ((network)); then
    confirm_send "$payload" "$enc" && kv_send "$net_payload"
  fi

  printf "📋 %s✓ Copied%s %s│%s %s\n" "$C_MINT" "$C_RESET" "$C_DIM" "$C_RESET" "$(content_stats "$payload")" >&2
}

# --- Entry Point -------------------------------------------------------------
main() {
  local paste=0 network=0 enc=0 copy_flag=0 info_flag=0 stdout_flag=0 append=0

  # Symlink detection
  local basename
  basename="$(basename "$0")"
  [[ "$basename" == "pas" ]]   && paste=1
  [[ "$basename" == "notes" ]] && { do_notes; exit 0; }

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --help)
      shift
      show_usage "${1:-}"
      exit 0
      ;;
    --notes)  do_notes; exit 0 ;;
    --test)   cop_run_tests; exit 0 ;;
    --info)   info_flag=1 ;;
    --paste)  paste=1 ;;
    --network) network=1 ;;
    --encrypt) enc=1 ;;
    --copy)   copy_flag=1 ;;
    --tee)    stdout_flag=1 ;;
    --append) append=1 ;;
    --templates) list_templates; exit 0 ;;
    --template)
      shift
      do_template "${1:-}"
      exit 0
      ;;
    --completions)
      shift
      case "${1:-}" in
      fish) emit_completions_fish; exit 0 ;;
      *) log "Unknown shell: ${1:-} (supported: fish)"; exit 1 ;;
      esac
      ;;
    --)
      shift
      break
      ;;
    -*)
      for ((i = 1; i < ${#1}; i++)); do
        case "${1:i:1}" in
        h)
          show_usage
          exit 0
          ;;
        i) info_flag=1 ;;
        p) paste=1 ;;
        n) network=1 ;;
        e) enc=1 ;;
        c) copy_flag=1 ;;
        t) stdout_flag=1 ;;
        a) append=1 ;;
        *)
          log "Unknown: -${1:i:1}"
          show_usage
          exit 1
          ;;
        esac
      done
      ;;
    *) break ;;
    esac
    shift
  done

  # Copy-to-local logic: default on unless network mode (then explicit -c needed)
  local copy_local=$((network ? copy_flag : 1))

  # Marvin's sigh
  ((copy_flag && !network)) && log "${C_DIM}*sigh* -c without -n… I was copying anyway${C_RESET}"

  # Info mode
  ((info_flag)) && {
    print_info
    exit 0
  }

  # Paste mode
  if ((paste)); then
    (($# > 1)) && {
      log "Only one output file allowed"
      exit 1
    }
    do_paste "$network" "$enc" "$copy_local" "${1:-}"
    exit 0
  fi

  # Copy mode
  local payload
  if (( $# == 1 )) && [[ -d "$1" ]]; then
    # Directory mode: expand with simple glob, delimit files with filepaths
    local dir="$1"
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)

    payload=""
    local sep=""
    for f in "$dir"/*; do
      [[ -f "$f" ]] || continue
      local abs_f display_path
      if [[ "$f" = /* ]]; then
        abs_f="$f"
      else
        abs_f="$PWD/$f"
      fi
      if [[ -n "$repo_root" && "$abs_f" == "$repo_root/"* ]]; then
        display_path="${abs_f#$repo_root/}"
      else
        display_path="$(basename "$f")"
      fi
      local content
      content=$(cat -- "$f")
      payload+="${sep}=== ${display_path} ===
${content}"
      sep=$'\n'
    done

    if [[ -z "$payload" ]]; then
      log "No files found in directory: $dir"
      exit 1
    fi
  elif (( $# > 0 )); then
    # Prefer explicit files over stdin, even in pipelines.
    payload=$(cat -- "$@")
  elif [[ ! -t 0 ]]; then
    payload=$(cat)
  else
    show_usage
    exit 1
  fi

  do_copy "$network" "$enc" "$copy_local" "$stdout_flag" "$append" "$payload"
}
