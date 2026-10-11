# Powerlevel10k instant prompt. Keep near the top; anything that prints or
# prompts for input has to go above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

# Prompt config: run `p10k configure` or edit ~/.p10k.zsh
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Tools
command -v pyenv >/dev/null && eval "$(pyenv init -)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"  # z <dir>; also feeds the sesh picker

# Aliases
alias lz="lazygit"
alias venv="source venv/bin/activate"
alias ghostty-theme="~/.config/ghostty/set-theme.sh"
# Restart Karabiner when key repeat gets stuck (karabiner_grabber leaks memory)
alias fix-keys='launchctl kickstart -k gui/$(id -u)/org.pqrs.service.agent.karabiner_console_user_server'

# API keys and tokens (untracked, never in this repo)
[[ -f ~/.zshrc.secrets ]] && source ~/.zshrc.secrets
