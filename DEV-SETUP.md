# Dev setup (fresh macOS)

Everything a frontend dev needs on a clean Mac, beyond the ricing in `Brewfile`.
Nothing here needs a backup — it all comes from installers or `gh auth login`.

## Order of operations

1. `xcode-select --install` → gives you **git** and the compilers. Wait for the dialog to finish.
2. `git clone https://github.com/0xFrann/dotfiles.git ~/dotfiles && cd ~/dotfiles && ./setup.sh`
   → Homebrew, ricing (AeroSpace, SketchyBar, Cursor, iTerm2, Raycast, fonts) and links `~/.zshrc` + `~/.config/*`.
3. Run the **one-liner** below → all the dev tooling.
4. Open a new terminal, then `gh auth login` and (optionally) the GPG section.

## Programs

### Core (daily drivers)

| Package | Install | Why |
|---|---|---|
| git | Xcode CLT (`xcode-select --install`) | already on macOS once CLT is installed |
| zsh + oh-my-zsh | macOS default + curl installer | shell; config lives in `zsh/.zshrc` |
| `gh` | brew | GitHub auth; also acts as git credential helper |
| `nvm` + Node 24 | brew + `nvm install 24` | node version manager |
| `pnpm` | brew | package manager |
| `corepack` / yarn | ships with Node, `corepack enable` | yarn 1.x when a repo needs it |
| `bun` | curl installer | fast runtime / package manager |
| `uv` | brew | Python + tools, replaces pyenv |
| `jq`, `yq` | brew | JSON / YAML in the terminal |
| `mkcert` | brew | local HTTPS certs for dev servers |
| `typst` | brew | build the CV (`0xFrann/cv`) |
| `gnupg` + `pinentry-mac` | brew | commit signing (see GPG section) |
| Cursor | cask (already in `Brewfile`) | editor |
| Visual Studio Code | cask `visual-studio-code` | second editor |
| iTerm2 | cask (already in `Brewfile`) | terminal |
| Docker Desktop | cask `docker-desktop` | containers (`docker`, `docker compose`, `kubectl`) |
| Google Chrome, Firefox | casks | testing browsers |
| Figma | cask `figma` | design handoff |
| Claude Code | cask `claude-code` | `claude` CLI |
| OpenCode | curl installer | `opencode` CLI |

### Optional (on demand)

| Package | Install | When |
|---|---|---|
| `watchman` | brew | React Native / Metro / Jest watch mode |
| `microsoft-openjdk` | cask | Android builds (React Native) |
| `ffmpeg` | brew | convert screen recordings / video |
| `pandoc` | brew | markdown ↔ docx/pdf |
| `act` | brew | run GitHub Actions locally |
| `ncdu` | brew | find what's eating the disk |
| `fastfetch` | brew | system info banner |
| Foundry (`forge`, `anvil`, `cast`) | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` | web3 work |
| Rust (`rustup`, `cargo`) | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` | web3 / native tooling |
| AWS CLI | `brew install awscli` | if a job needs it |
| Ollama | `brew install --cask ollama` | local LLMs |
| Xcode | App Store | iOS Simulator, full toolchain (CLT alone is enough for web) |

Not brought back (one-off leftovers): aria2, cabextract, cdrtools, chntpw, wimlib, cmatrix, sl, gource, gradle,
guile, gobject-introspection, jpeg, librsvg, poppler, llama.cpp, openssl@1.1, pyenv + python@3.9/3.11, cleardisk, Warp.

## The one-liner

Installs **core + optional** (everything above except Foundry / Rust / AWS / Ollama / Xcode — those are on-demand).
Run it after `./setup.sh`, then open a new terminal.

```bash
brew install gh nvm pnpm uv jq yq mkcert typst gnupg pinentry-mac watchman ffmpeg pandoc act ncdu fastfetch && brew install --cask visual-studio-code docker-desktop google-chrome firefox figma claude-code microsoft-openjdk && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc && curl -fsSL https://bun.sh/install | bash && curl -fsSL https://opencode.ai/install | bash && source /opt/homebrew/opt/nvm/nvm.sh && nvm install 24 && nvm alias default 24 && corepack enable && gh auth login
```

Core only (skip the optionals):

```bash
brew install gh nvm pnpm uv jq yq mkcert typst gnupg pinentry-mac && brew install --cask visual-studio-code docker-desktop google-chrome firefox figma claude-code && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc && curl -fsSL https://bun.sh/install | bash && curl -fsSL https://opencode.ai/install | bash && source /opt/homebrew/opt/nvm/nvm.sh && nvm install 24 && nvm alias default 24 && corepack enable && gh auth login
```

Notes:
- `--keep-zshrc` stops oh-my-zsh from overwriting the linked `~/.zshrc`.
- The bun / opencode installers try to append to `~/.zshrc`; the linked zshrc already has their PATH lines, so delete any duplicate they add.
- Docker Desktop needs to be opened once from `/Applications` to finish installing its CLI symlinks.

## Git identity

`git/config` is linked to `~/.config/git/config`, which git reads natively (no `~/.gitconfig` needed).
It sets `user.name = 0xFrann`, `user.email = francomdalmasso@gmail.com`, `init.defaultBranch = main`.
`gh auth login` adds the credential helper on top.

## GPG commit signing

`zsh/.zshrc` already exports `GPG_TTY=$(tty)` — that's the line that lets gpg-agent open the passphrase prompt
in the right terminal. Everything else:

```bash
# 1. Generate a key (pick: (9) ECC sign+encrypt → Curve 25519 → expiry 2y → name 0xFrann, email francomdalmasso@gmail.com)
gpg --full-generate-key

# 2. Grab the key id (the part after "ed25519/" on the "sec" line)
gpg --list-secret-keys --keyid-format long

# 3. Tell git to sign with it
git config --global user.signingkey <KEYID>
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# 4. Use the macOS pinentry (GUI prompt + "save in keychain" checkbox) and cache the passphrase for 8h
cat > ~/.gnupg/gpg-agent.conf <<'EOF'
pinentry-program /opt/homebrew/bin/pinentry-mac
default-cache-ttl 28800
max-cache-ttl 28800
EOF
gpgconf --kill gpg-agent

# 5. Add the public key to GitHub → Settings → SSH and GPG keys → New GPG key
gpg --armor --export <KEYID> | pbcopy

# 6. Verify
echo test | gpg --clearsign            # should prompt once, then succeed
git commit --allow-empty -m "test signing" && git log --show-signature -1
```

If a commit ever fails with `gpg failed to sign the data`, it's almost always a missing `GPG_TTY` (open a new
terminal) or a dead agent (`gpgconf --kill gpg-agent`).

Back up the private key to 1Password so a future reset doesn't lose the "Verified" badge history:

```bash
gpg --armor --export-secret-keys <KEYID>   # paste into a 1Password Secure Note
# restore later with: gpg --import <file> && gpg --edit-key <KEYID> trust → 5
```
