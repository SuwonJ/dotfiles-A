
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/.npm-global/bin:$PATH
alias gemini='npx @google/gemini-cli'
# Shared input method environment (managed by ~/.local/bin/im-switch).
if [[ -f "$HOME/.config/im-framework/current.env" ]]; then
  source "$HOME/.config/im-framework/current.env"
fi
export HISTFILE="$HOME/.zsh_history"
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
export HISTSIZE=10000
export SAVEHIST=10000
export GTK_USE_PORTAL=1
alias doom2='chocolate-doom -iwad "$HOME/.local/share/chocolate-doom/doom2.wad"'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$(command -v conda >/dev/null 2>&1 && conda shell.zsh hook 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    unset __conda_setup
fi
unset __conda_setup
# <<< conda initialize <<<
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
source <(fzf --zsh)

ytclip() {
    mpv --hwdec=auto --ytdl-format="bestvideo[height<=2160]+bestaudio/best" "$(wl-paste)"
}


# Added by Antigravity CLI installer
export PATH="/home/suwonj/.local/bin:$PATH"
