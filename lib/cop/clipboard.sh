# clipboard.sh — copy/paste detection, OSC 52

# --- Environment Detection ---------------------------------------------------
is_wayland() { [[ -n "${WAYLAND_DISPLAY:-}" && -S "/run/user/$(id -u)/${WAYLAND_DISPLAY}" ]]; }
is_x11() { [[ -n "${DISPLAY:-}" ]]; }
is_ssh_session() { [[ -n "${SSH_CLIENT:-}${SSH_TTY:-}${SSH_CONNECTION:-}" ]]; }

# --- OSC 52 clipboard (SSH / terminal-carried) -------------------------------
osc52_copy() {
  local b64
  b64=$(base64 | tr -d '\n')
  # Write directly to /dev/tty so it reaches the terminal even through pipes.
  # BEL terminator (\007) is universally supported (Ghostty, kitty, iTerm2, …).
  printf '\033]52;c;%s\007' "$b64" >/dev/tty
}

# OSC 52 paste: send a read request and wait for the terminal's response.
# Support is limited: Ghostty, kitty, xterm, and a handful of others respond.
# Most terminals (including tmux by default) silently ignore the request.
osc52_paste() {
  # Save terminal state, switch to raw mode to read response
  local old_stty
  old_stty=$(stty -g </dev/tty)
  stty raw -echo min 0 time 2 </dev/tty

  # Send OSC 52 read request
  printf '\033]52;c;?\007' >/dev/tty

  # Read response: OSC 52 ; c ; <base64> BEL  (or ST = ESC \)
  local response=""
  local char
  while IFS= read -r -s -n1 char </dev/tty; do
    response+="$char"
    # Stop on BEL or ESC-backslash terminator
    if [[ "$char" == $'\007' ]]; then break; fi
    if [[ "${response}" == *$'\033\\'* ]]; then break; fi
    # Bail if response grows unreasonably (unsupported terminal returning noise)
    ((${#response} > 8192)) && break
  done

  stty "$old_stty" </dev/tty

  # Extract base64 payload from:  ESC ] 52 ; c ; <b64> BEL
  local b64
  b64=$(printf "%s" "$response" | sed 's/.*52;c;//; s/\x07//g; s/\x1b\\//g')

  if [[ -z "$b64" ]]; then
    return 1
  fi

  printf "%s" "$b64" | b64_decode
}

# --- Copy Command Detection --------------------------------------------------
COPY_CMDS=(wl-copy pbcopy clip.exe xclip xsel termux-clipboard-set putclip)
COPY_USED=""

find_copy_cmd() {
  # Respect explicit override
  [[ -n "${COP_CMD:-}" ]] && command -v "$COP_CMD" &>/dev/null && {
    echo "$COP_CMD"
    return 0
  }

  # SSH session without a local pbcopy: use OSC 52 (terminal carries clipboard)
  if is_ssh_session && ! command -v pbcopy &>/dev/null; then
    echo "__osc52__"
    return 0
  fi

  for cmd in "${COPY_CMDS[@]}"; do
    command -v "$cmd" &>/dev/null || continue
    case "$cmd" in
    wl-copy) is_wayland || continue ;;
    xclip | xsel) is_x11 || continue ;;
    esac
    echo "$cmd"
    return 0
  done
  return 1
}

copy_to_clipboard() {
  local cmd
  cmd=$(find_copy_cmd) || {
    log "No copy utility found"
    exit 1
  }
  COPY_USED="$cmd"
  case "$cmd" in
  __osc52__)                                                    osc52_copy ;;
  wl-copy | pbcopy | termux-clipboard-set | putclip | clip.exe) "$cmd" ;;
  xclip) "$cmd" -selection clipboard ;;
  xsel) "$cmd" --clipboard --input ;;
  *) "$cmd" ;; # fallback for COP_CMD override
  esac
}

# --- Paste Command Detection -------------------------------------------------
PASTE_CMDS=(wl-paste pbpaste powershell.exe xclip xsel termux-clipboard-get getclip)
PASTE_USED=""

find_paste_cmd() {
  for cmd in "${PASTE_CMDS[@]}"; do
    command -v "$cmd" &>/dev/null || continue
    case "$cmd" in
    wl-paste) is_wayland || continue ;;
    xclip | xsel) is_x11 || continue ;;
    esac
    echo "$cmd"
    return 0
  done
  return 1
}

get_local_clipboard() {
  # SSH session without a local paste tool: try OSC 52 read
  if is_ssh_session && ! find_paste_cmd &>/dev/null; then
    local out
    if out=$(osc52_paste 2>/dev/null) && [[ -n "$out" ]]; then
      PASTE_USED="osc52"
      printf "%s" "$out"
      return 0
    fi
    log "OSC 52 paste unsupported by terminal — try cop -pn or ensure terminal supports OSC 52 read"
    exit 1
  fi

  local cmd
  cmd=$(find_paste_cmd) || {
    log "No paste utility found"
    exit 1
  }
  PASTE_USED="$cmd"
  case "$cmd" in
  wl-paste | pbpaste | termux-clipboard-get | getclip) "$cmd" ;;
  powershell.exe) "$cmd" -Command "Get-Clipboard" ;;
  xclip) "$cmd" -selection clipboard -o ;;
  xsel) "$cmd" --clipboard --output ;;
  esac
}
