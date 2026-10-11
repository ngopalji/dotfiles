# dotfiles

My macOS configs, symlinked into place with [GNU Stow](https://www.gnu.org/software/stow/).

nvim · tmux · karabiner · ghostty · hammerspoon · zsh · git · ideavim · herdr

## Install

```bash
git clone https://github.com/ngopalji/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` installs the [Brewfile](Brewfile) and links everything in.

Each folder mirrors where its files live in `~`, so `nvim/.config/nvim` becomes `~/.config/nvim`.
