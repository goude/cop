# templates.sh — do_template + list_templates

do_template() {
  local name="$1"
  local src="$LIB/templates/$name"

  if [[ ! -f "$src" ]]; then
    printf "📋 %sTemplate not found:%s %s\n" "$C_CORAL" "$C_RESET" "$name" >&2
    printf "Available templates:\n" >&2
    list_templates >&2
    exit 1
  fi

  cp "$src" "./$name"
  printf "📋 %s✓ Copied%s template %s%s%s → %s./%s%s\n" \
    "$C_MINT" "$C_RESET" "$C_SKY" "$name" "$C_RESET" "$C_SKY" "$name" "$C_RESET" >&2
}

list_templates() {
  for f in "$LIB/templates/"* "$LIB/templates/".*; do
    [[ -f "$f" ]] && printf "%s\n" "$(basename "$f")"
  done
}
