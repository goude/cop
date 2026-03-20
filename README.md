# cop

`cop` is a bash clipboard helper. It abstracts over platform clipboard tools
(`pbcopy`, `wl-copy`, `xclip`, etc.) so you don't need to remember which one
works where. It also supports network sync via a cloud clipboard service,
AES-256-CBC encryption, OSC 52 for SSH sessions, and a small template library
for bootstrapping common project files.

## Installation

```sh
homeshick clone gh:goude/cop
homeshick link cop
```

`homeshick` symlinks `~/.homesick/repos/cop/home/bin/cop` → `~/bin/cop`.
No manual path configuration required.

## Usage

```
Usage:
  cop [OPTIONS] [FILE...]

cop automatically uses your system's clipboard tools (pbcopy, wl-copy, xclip, etc.)
so you don't have to remember which command works on which platform.

Options:
  -p  --paste      Paste from clipboard or remote
  -n  --network    Sync via cloud clipboard service
  -e  --encrypt    AES-256-CBC encrypt/decrypt ($COP_SECRET)
  -c  --copy       Also copy fetched data locally (with -n)
  -t  --tee        Also emit copied payload to stdout
  -a  --append     Append new content to existing clipboard contents
  -i  --info       Show clipboard command info
  -h  --help       Show this help
      --notes      Open (or create) NOTES.md in current directory
      --test       Run tests
      --completions SHELL  Emit shell completions (fish supported)

Templates:
  cop --template .gitignore    copy .gitignore into current directory
  cop --template NOTES.md      copy NOTES.md into current directory
  cop --templates              list available templates

Examples:
  echo "hello" | cop      copy text
  cop file.txt            copy file contents
  cop < file.txt          copy file contents

  cop -p                  paste from clipboard
  cop -p out.txt          paste into file
  cop -p > out.txt        paste into file
  pas                     paste from clipboard (pas is a symlink to cop)

  cop -ne file.txt        encrypt & sync to remote
  cop -pne                decrypt & paste from remote

  echo "more" | cop -a    append to existing clipboard
  cop -a file.txt         append file to existing clipboard

  ls | cop -s             copy and also print what was copied

  cop --notes             open/create NOTES.md here
  notes                   same (notes is a symlink to cop)
```

## Templates

Templates are files in `lib/cop/templates/` that `cop` can copy into your
current working directory.

| Template       | Description                              |
|----------------|------------------------------------------|
| `.gitignore`   | Sensible gitignore for most projects     |
| `.editorconfig`| EditorConfig with common defaults        |
| `NOTES.md`     | NOTES.md stub with convention link       |

```sh
cop --templates              # list available templates
cop --template .gitignore    # copy .gitignore into current directory
cop --template NOTES.md      # copy NOTES.md into current directory
```

## Development

### Repo layout

```
cop/
├── home/
│   └── bin/
│       └── cop                  ← bootstrap (homeshick links this)
├── lib/
│   └── cop/
│       ├── ui.sh                ← colors, banner, show_usage, print_info
│       ├── clipboard.sh         ← copy/paste detection, OSC 52
│       ├── crypto.sh            ← openssl helpers, b64_encode/b64_decode
│       ├── network.sh           ← kv_send, kv_fetch, confirm_send
│       ├── templates.sh         ← do_template + list_templates
│       ├── tests.sh             ← cop_run_tests
│       ├── core.sh              ← do_copy, do_paste, do_notes, main
│       └── templates/
│           ├── .gitignore
│           ├── .editorconfig
│           └── NOTES.md
├── .gitignore
└── README.md
```

The bootstrap (`home/bin/cop`) resolves its real path, walks up to the repo
root, sets `LIB=$REPO_ROOT/lib/cop`, then sources modules in dependency order:
`ui.sh → clipboard.sh → crypto.sh → network.sh → templates.sh → tests.sh → core.sh`.

### Adding a new template

Drop a file into `lib/cop/templates/`. It becomes immediately available via
`cop --template <name>` and appears in `cop --templates`.

### Adding a new module

1. Create `lib/cop/<module>.sh` with your functions.
2. Add `source "$LIB/<module>.sh"` to `home/bin/cop` in the appropriate
   position (before any module that depends on it).
3. Run `home/bin/cop --test` to verify nothing broke.
