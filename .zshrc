# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY
unsetopt beep
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename "$HOME/.zshrc"

autoload -Uz compinit
compinit
# End of lines added by compinstall

bindkey "^[[1;5D" backward-word # for Ctrl + ←
bindkey "^[[1;5C" forward-word # for Ctrl + →

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

source <(fzf --zsh)

eval "$(starship init zsh)"

fastfetch \
--config ~/.config/fastfetch/config.nano.jsonc \
--logo "/opt/pokemon-colorscripts/colorscripts/small/regular/$(pokemon-colorscripts -l | head -251 | shuf -n 1)"

alias vim="nvim"
alias vi="nvim"
alias ls="eza"
alias paru="paru --skipreview"
