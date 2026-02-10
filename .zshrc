# Common
source "$HOME/.common"

# Set up the prompt
setopt histignorealldups sharehistory
unsetopt PROMPT_CR

bindkey '\e[A' up-line-or-search
bindkey '\e[B' down-line-or-search

# Use emacs keybindings even if our EDITOR is set to vi
bindkey -e
ZLE_RPROMPT_INDENT=0

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE="$HOME/.zsh_history"

# Use modern completion system
autoload -Uz compinit
compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
# eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

function precmd() {
  export PROMPT_EXIT=$?
  export PROMPT_USER
  export PROMPT_STYLE
  export COLUMNS
  lines="$("$HOME/bin/prompt" zsh)"
  export PROMPT="$(LC_CTYPE=C && LANG=C && echo -n -e $lines | cut -f1)"
  export RPROMPT="$(LC_CTYPE=C && LANG=C && echo -n -e $lines | cut -s -f2)"
}

export precmd_functions=(precmd)

if [ -f "$HOME/.zsh_local" ]; then 
  source "$HOME/.zsh_local"
fi

