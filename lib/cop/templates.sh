# templates.sh — do_template + list_templates

list_templates() {
  local f
  for f in "$LIB/templates/"* "$LIB/templates/".*; do
    [[ -f "$f" ]] && basename "$f"
  done | sort
}

# resolve_template QUERY → print matched name; return 1 if not found
resolve_template() {
  local query="$1" name

  # Exact match wins immediately
  [[ -f "$LIB/templates/$query" ]] && { printf "%s\n" "$query"; return 0; }

  # Prefix match — first sorted hit wins
  while IFS= read -r name; do
    [[ "$name" == "$query"* ]] && { printf "%s\n" "$name"; return 0; }
  done < <(list_templates)

  return 1
}

do_template() {
  local query="${1:-}"

  if [[ -z "$query" ]]; then
    printf "📋 %sNo template name given.%s Available templates:\n" "$C_CORAL" "$C_RESET" >&2
    list_templates >&2
    exit 1
  fi

  local name
  name=$(resolve_template "$query") || {
    printf "📋 %sTemplate not found:%s %s\n" "$C_CORAL" "$C_RESET" "$query" >&2
    printf "Available templates:\n" >&2
    list_templates >&2
    exit 1
  }

  cp "$LIB/templates/$name" "./$name"
  printf "📋 %s✓ Copied%s template %s%s%s → %s./%s%s\n" \
    "$C_MINT" "$C_RESET" "$C_SKY" "$name" "$C_RESET" "$C_SKY" "$name" "$C_RESET" >&2
}
