eval "$(/opt/homebrew/bin/brew shellenv)"

# ~/.local/bin: herdr, uv tools. ~/go/bin: gopls, goimports, gofumpt.
export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"

command -v pyenv >/dev/null && eval "$(pyenv init --path)"
