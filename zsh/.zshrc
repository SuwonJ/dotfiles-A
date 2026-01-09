source ~/powerlevel10k/powerlevel10k.zsh-theme
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/.npm-global/bin:$PATH
alias gemini='npx @google/gemini-cli'
export XMODIFIERS="@im=fcitx"
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export HISTFILE="$HOME/.zsh_history"
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
export HISTSIZE=10000
export SAVEHIST=10000
export GTK_USE_PORTAL=1
alias doom2='chocolate-doom -iwad /home/suwonj/.local/share/chocolate-doom/doom2.wad'
