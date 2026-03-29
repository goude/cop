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
Usage: cop [OPTIONS] [FILE...]

Clipboard helper — auto-selects pbcopy / wl-copy / xclip / OSC 52.

Options:
  -p  --paste              Paste from clipboard or remote
  -n  --network            Sync via cloud clipboard service
  -e  --encrypted          AES-256-CBC encrypt/decrypt ($COP_SECRET)
  -c  --copy               Also copy fetched data locally (with -n)
  -t  --tee                Also emit copied payload to stdout
  -a  --append             Append to existing clipboard contents
  -i  --info               Show clipboard backend info
  -h  --help [TOPIC]       This help; topics: examples  templates  network
      --notes              Open/create NOTES.md in current directory
      --template NAME      Copy template to current directory
      --templates          List available templates
      --test               Run self-tests
      --completions SHELL  Emit shell completions (fish)

Quick:  echo "hi" | cop    cop file.txt    cop -p    cop -ne file.txt

Details:  cop --help examples  |  cop --help templates  |  cop --help network
```

### Examples

```sh
echo "hello" | cop      # copy text
cop file.txt            # copy file contents
cop dir/                # copy all files in directory

cop -p                  # paste to stdout
cop -p out.txt          # paste into file

cop -ne file.txt        # encrypt & sync to remote
cop -pne                # decrypt & paste from remote

echo "more" | cop -a    # append to existing clipboard
cop --notes             # open/create NOTES.md here
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

## Cloudflare Worker

The cloud clipboard (`cop -n`) is backed by a Cloudflare Worker stored in
`cloudflare/worker.js`. GET (fetch) is public; POST (store) requires a Bearer
token.

### First-time setup

1. **Create a Worker** in the Cloudflare dashboard (Workers & Pages → Create).
   Paste the contents of `cloudflare/worker.js` into the editor.

2. **Create a KV namespace** (Workers & Pages → KV → Create namespace).
   Name it anything (e.g. `COP_STORE`).

3. **Bind the KV namespace** to the worker: Worker Settings → Variables →
   KV Namespace Bindings → Add binding.
   - Variable name: `COP_STORE`
   - KV namespace: the one you just created

4. **Set the write secret**: Worker Settings → Variables → Secrets → Add secret.
   - Name: `COP_WRITE_SECRET`
   - Value: a random string (e.g. `openssl rand -hex 32`)

   This secret must be kept out of the repo. It lives only in Cloudflare and
   in the environment of machines that need to push to the cloud clipboard.

5. **Deploy** the worker. Note the `*.workers.dev` URL.

### Connecting a client machine

The worker URL is hardcoded to `https://cop.daniel-goude.workers.dev/cop` by
default. Override it with an env var if you deploy your own worker:

```sh
export COP_SERVICE_URL=https://your-worker.workers.dev/cop
```

To enable pushing (`cop -n` in copy mode), also set the write secret:

```sh
export COP_WRITE_SECRET=<the secret you set in Cloudflare>
```

Fetching (`cop -pn`) works without `COP_WRITE_SECRET` — reads are always
public.

Add both vars to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) to persist
them across sessions. Do not commit them to any repo.

### Updating the worker

Edit `cloudflare/worker.js`, then paste the updated code into the Cloudflare
dashboard editor and redeploy (or use `wrangler deploy` if you have the CLI
set up).
