# Paths
export PATH=$HOME/bin:$PATH
if [ -x /usr/libexec/path_helper ]; then
  eval `/usr/libexec/path_helper -s`
fi

# Start dotfiles sync
dotfiles > /dev/null &
disown

# Colors
export CLICOLOR=1
export LSCOLORS=DxGxcxdxCxegedabagacad

# Aliases
alias mvn=\$HOME/lib/colorant/colorant-mvn.sh
alias ant=\$HOME/lib/colorant/colorant.sh
alias index=\$HOME/lib/index/index.rb
alias serve=\$HOME/lib/serve/serve
alias wallpaper=\$HOME/lib/wallpaper/wallpaper.rb
alias arkivera=\$HOME/lib/arkivera/arkivera.sh
alias backup=\$HOME/lib/backup/backup
alias mci="mvn clean install"
alias devenv="source devenv"
alias cde="cd \$DEVENV_HOME"

# Cygwin customizations
if [ "$OSTYPE" == "cygwin" ]; then
  source "$HOME/.bash_win"
fi

# OSX customizations
if [ "$OSTYPE" == darwin* ]; then
  source "$HOME/.bash_osx"
fi

# Local config
if [ -f "$HOME/.bash_local" ]; then
  source "$HOME/.bash_local"
fi

# Dev environment
export DEVENV=""
export DEVENV_HOME=$HOME
if [ -f "$HOME/.devenv" ]; then
  export DEVENV="$(cat $HOME/.devenv)"
  if [ -f "$HOME/.devenv_${DEVENV}" ]; then
    source "$HOME/.devenv_${DEVENV}"
  fi
fi

# Prompt
function promptCommand() {
  EXIT=$?
  export COLUMNS
  export PS1="$(prompt $EXIT)"
}
export PROMPT_COMMAND=promptCommand
