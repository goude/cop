# crypto.sh — openssl helpers, b64_encode/b64_decode

# --- Base64 Helpers ----------------------------------------------------------
b64_encode() {
  if base64 --wrap=0 2>/dev/null; then return 0; fi
  if base64 2>/dev/null | tr -d '\n'; then return 0; fi
  python3 -c 'import sys,base64;print(base64.b64encode(sys.stdin.buffer.read()).decode(),end="")' 2>/dev/null || cat
}

b64_decode() {
  local input
  input=$(cat)
  base64 --decode 2>/dev/null <<<"$input" && return 0
  base64 -D 2>/dev/null <<<"$input" && return 0
  base64 -d 2>/dev/null <<<"$input" && return 0
  python3 -c 'import sys,base64;sys.stdout.write(base64.b64decode(sys.stdin.read().strip()).decode())' 2>/dev/null <<<"$input" && return 0
  printf "%s" "$input"
}

# --- Crypto helper -----------------------------------------------------------
ensure_openssl() {
  if ! command -v openssl &>/dev/null; then
    log "openssl not found"
    return 1
  fi
}
