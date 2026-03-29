# network.sh — kv_send, kv_fetch, confirm_send

# --- Configuration -----------------------------------------------------------
COP_SERVICE_URL="${COP_SERVICE_URL:-https://cop.daniel-goude.workers.dev/cop}"

# --- Cloud clipboard API (via Worker) ---------------------------------------
kv_send() {
  # Expects: $1 is already base64 (plaintext or ciphertext, depending on mode)
  local data="$1"
  local status
  local -a auth_header=()
  if [[ -n "${COP_WRITE_SECRET:-}" ]]; then
    auth_header=(-H "Authorization: Bearer ${COP_WRITE_SECRET}")
  fi
  status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${auth_header[@]}" --data-binary "$data" "$COP_SERVICE_URL")
  [[ "$status" =~ ^20[01]$ ]] || {
    log "Cloud clipboard POST failed ($status)"
    return 1
  }
  printf "📋 %s✓ Synced%s to %scloud clipboard%s\n" \
    "$C_MINT" "$C_RESET" "$C_SKY" "$C_RESET" >&2
}

kv_fetch() {
  local tmp
  tmp=$(mktemp)
  local status
  status=$(curl -s -o "$tmp" -w "%{http_code}" "$COP_SERVICE_URL")
  [[ "$status" == "200" ]] || {
    log "Cloud clipboard GET failed ($status)"
    rm -f "$tmp"
    return 1
  }
  local raw
  raw=$(<"$tmp")
  rm -f "$tmp"
  # Trim trailing CR/LF but don't touch content
  raw=${raw//$'\r'/}
  raw=${raw%$'\n'}
  printf "%s" "$raw"
}

# --- User Confirmation -------------------------------------------------------
confirm_send() {
  # Test / non-interactive override: auto-confirm
  if [[ "${COP_ASSUME_Y:-}" == "1" ]]; then
    printf "📋 %s[TEST]%s auto-confirming upload\n" "$C_DIM" "$C_RESET" >&2
    return 0
  fi

  local payload="$1"
  local enc="$2"
  local preview

  if ((${#payload} > 120)); then
    preview="${payload:0:120}…"
  else
    preview="$payload"
  fi

  if ((enc)); then
    printf "📋 %s🔒 Will encrypt before upload:%s\n" "$C_LAVENDER" "$C_RESET" >&2
  else
    printf "📋 %s⚠ Public upload:%s\n" "$C_GOLD" "$C_RESET" >&2
  fi

  printf "   %s\"%s\"%s\n" "$C_DIM" "$preview" "$C_RESET" >&2
  printf "📋 Proceed? [y/N] " >&2

  local ans=""
  if [[ -r /dev/tty ]]; then
    read -r ans </dev/tty
  else
    read -r ans
  fi

  if [[ "$ans" =~ ^[Yy] ]]; then
    return 0
  fi

  printf "📋 %sAborted%s\n" "$C_CORAL" "$C_RESET" >&2
  return 1
}
