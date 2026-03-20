# cop repo restructure

## Context

`cop` is a bash clipboard helper that currently lives as a single script in a
dotfiles repo, symlinked via homeshick to `~/bin/cop`. We are moving it to its
own repo (`goude/cop`) and splitting it into modules, while keeping it
deployable via `homeshick clone` + `homeshick link` with zero manual path
configuration.

The existing `cop` script is already in the repo. Use it as the source of
truth for all logic — do not rewrite behaviour, only reorganise.

---

## Target layout

```
cop/
├── home/
│   └── bin/
│       └── cop                  ← bootstrap only (homeshick links this)
├── lib/
│   └── cop/
│       ├── ui.sh                ← colors, banner, show_usage, print_info
│       ├── clipboard.sh         ← copy/paste detection, OSC 52
│       ├── crypto.sh            ← openssl helpers, b64_encode/b64_decode
│       ├── network.sh           ← kv_send, kv_fetch, confirm_send
│       ├── templates.sh         ← do_template + template list command
│       ├── tests.sh             ← cop_run_tests
│       ├── core.sh              ← do_copy, do_paste, do_notes, main
│       └── templates/
│           ├── .gitignore
│           ├── .editorconfig
│           └── NOTES.md
├── .gitignore
└── README.md
```

homeshick only symlinks the `home/` subtree, so everything under `lib/` stays
in the repo and is never directly in `PATH`.

---

## Bootstrap script: home/bin/cop

The bootstrap must locate `lib/cop/` relative to its own real path — without
any hardcoded paths or env vars. The symlink chain is:

```
~/bin/cop  →  ~/.homesick/repos/cop/home/bin/cop
```

Use the following resolution logic (macOS + Linux + Raspberry Pi safe):

```bash
resolve_realpath() {
  # readlink -f is GNU only (not available on macOS BSD)
  # python3 fallback covers macOS Homebrew and any system without GNU coreutils
  if readlink -f "$1" 2>/dev/null | grep -q .; then
    readlink -f "$1"
  elif command -v python3 &>/dev/null; then
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
  else
    # last resort: resolve one level manually
    local target
    target=$(readlink "$1" 2>/dev/null || echo "$1")
    case "$target" in
      /*) echo "$target" ;;
      *)  echo "$(dirname "$1")/$target" ;;
    esac
  fi
}
```

From the resolved real path of the bootstrap script, walk up to the repo root
with three `dirname` calls (script lives at `home/bin/cop`), then set:

```bash
LIB="$REPO_ROOT/lib/cop"
```

Validate that `$LIB` exists and is a directory; print a clear error and exit 1
if not.

Source the modules in this order (dependency order matters):

```
ui.sh → clipboard.sh → crypto.sh → network.sh → templates.sh → tests.sh → core.sh
```

Then call `main "$@"`.

The bootstrap itself should contain no other logic.

---

## Module extraction rules

- Move functions from the existing `cop` into the modules listed above.
  Match the groupings described in the layout section.
- Each module may assume all previously sourced modules are available.
- Keep `set -euo pipefail` only in the bootstrap; do not repeat it in modules.
- Do not change any function signatures, flag behaviour, or test logic.
- `LIB` is set by the bootstrap and available to all sourced modules —
  `templates.sh` should use it to locate `$LIB/templates/`.

---

## templates.sh

Add a `do_template` function:

```
do_template NAME
```

- Looks up `$LIB/templates/NAME`
- If found: copies the file into the current working directory as `./NAME`
  (preserving the filename, including leading dot for dotfiles)
- If not found: prints an error listing available templates (just the filenames,
  one per line) and exits 1
- Prints a confirmation line using the existing cop log style on success

Add a `list_templates` function that prints the filenames of everything in
`$LIB/templates/`, one per line.

---

## Template files

Populate `lib/cop/templates/` with these three files.

### .gitignore

```
# Glob reference:
#   foo/        ignore dir foo/ anywhere in the tree
#   /foo/       ignore only top-level foo/
#   *.log       ignore all .log files anywhere
#   /*.log      ignore .log files only at root
#   !foo.log    un-ignore foo.log (negate a previous rule)
#   **/foo/     same as foo/ — explicit recursive form
#   foo/*       contents of foo/, but not foo/ itself

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Windows
Thumbs.db
Desktop.ini
$RECYCLE.BIN/

# Linux
*~

# Editors
.vscode/
.idea/
*.swp
*.swo
*~

# Logs & temps
*.log
*.tmp
*.bak

# Environment
.env
.env.local
```

### .editorconfig

```ini
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
```

### NOTES.md

```markdown
# NOTES.md

---

[NOTES.md convention](https://github.com/goude/NOTES.md)
```

---

## CLI changes

Add `--template NAME` and `--templates` to the option parser in `core.sh`:

- `--template NAME` → call `do_template "$NAME"`
- `--templates`     → call `list_templates`

Add them to the help text in `ui.sh` under their own section:

```
Templates:
  cop --template .gitignore    copy .gitignore into current directory
  cop --template NOTES.md      copy NOTES.md into current directory
  cop --templates              list available templates
```

Add completions for these flags in the `emit_completions_fish` function:

```fish
complete -c cop -l template    -r -d 'Copy template to current directory'
complete -c cop -l templates   -d 'List available templates'
```

---

## repo .gitignore

Create a `.gitignore` at the repo root appropriate for a bash project:

```
*.swp
*.swo
*~
.env
.env.local
```

(The repo's own `.gitignore` should be minimal — the template version is for
 use in other projects.)

---

## README.md

Write a concise README covering:

1. What cop is (one paragraph)
2. Installation (`homeshick clone gh:goude/cop && homeshick link cop`)
3. Usage — copy the usage block from `show_usage` in the existing script,
   strip the ANSI codes, keep the structure
4. Templates section listing the available templates and how to use them
5. Development notes: repo layout, how to add a new template, how to add a
   new module

Tone: terse, technical, no marketing language.

---

## Validation

After restructuring, verify:

1. `bash -n home/bin/cop` passes
2. `bash -n lib/cop/*.sh` all pass
3. `home/bin/cop --test` passes (run it — it has a self-test suite)
4. `home/bin/cop --template .gitignore` in a temp dir creates `.gitignore`
5. `home/bin/cop --templates` lists at least the three template files

If any check fails, fix it before finishing.

---

## What not to do

- Do not rename any existing flags or functions
- Do not change test logic
- Do not add dependencies (no Python for runtime logic, no external tools
  beyond what cop already uses)
- Do not add a Makefile or install script — homeshick is the only install path
- Do not modify the OSC 52 or crypto logic
