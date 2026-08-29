# Linked to ~/.zshrc by scripts/link.sh

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

export EDITOR="cursor --wait"

# nvm (installed via brew)
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# user-local binaries (uv, claude, ...)
export PATH="$HOME/.local/bin:$PATH"

# optional toolchains — no-ops until installed
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"
[ -d "$HOME/.foundry/bin" ] && export PATH="$PATH:$HOME/.foundry/bin"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# GPG: tell gpg-agent which terminal to show the passphrase prompt in
export GPG_TTY=$(tty)
