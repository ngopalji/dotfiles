#!/usr/bin/env bash
# Set up a Mac from this repo. Safe to re-run.
# Fresh Mac: install Homebrew (https://brew.sh), clone to ~/dotfiles, run this.
set -euo pipefail
cd "$(dirname "$0")"

brew bundle --file=Brewfile

# Cloned directly because the Oh My Zsh installer writes its own ~/.zshrc
[[ -d ~/.oh-my-zsh ]] || git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
p10k=~/.oh-my-zsh/custom/themes/powerlevel10k
[[ -d $p10k ]] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k"
[[ -d ~/.tmux/plugins/tpm ]] || git clone --depth=1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# herdr writes sockets/logs/sessions next to config.toml, so ~/.config/herdr must
# stay a real directory. Creating it first stops stow from folding it into a link.
mkdir -p ~/.config/herdr

packages=(*/)
stow -v "${packages[@]%/}"

# Karabiner only notices a newly symlinked config dir after a restart
if pgrep -q karabiner_console_user_server; then
  launchctl kickstart -k "gui/$(id -u)/org.pqrs.service.agent.karabiner_console_user_server"
fi

herdr integration install claude
herdr integration install codex
herdr plugin list | grep -q herdr-auto-title || herdr plugin install kryptamine/herdr-auto-title --yes
