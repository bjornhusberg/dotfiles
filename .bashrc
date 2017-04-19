export CLICOLOR=1
export LSCOLORS=DxGxcxdxCxegedabagacad

# Paths
export PATH=$HOME/bin:$PATH
if [ -x /usr/libexec/path_helper ]; then
	eval `/usr/libexec/path_helper -s`
fi

# Aliases
alias mvn=\$HOME/lib/colorant/colorant-mvn.sh
alias ant=\$HOME/lib/colorant/colorant.sh
alias index=\$HOME/lib/index/index.rb
alias serve=\$HOME/lib/serve/serve
alias wallpaper=\$HOME/lib/wallpaper/wallpaper.rb
alias arkivera=\$HOME/lib/arkivera/arkivera.sh
alias backup=\$HOME/lib/backup/backup
alias devenv="source devenv"
alias mci="mvn clean install"

# Cygwin customizations
if [ "$OSTYPE" == "cygwin" ]; then
  export TERM=cygwin
  alias less="less -r"
  stty lnext ^q stop undef start undef
fi

# OSX customizations
if [ "$OSTYPE" == darwin* ]; then
  alias kdiff3="/Applications/kdiff3.app/Contents/MacOS/kdiff3"
fi

# Dotfiles sync
dotfiles > /dev/null &
disown

# Dev environment
if [ -f "$HOME/.devenv" ]; then
  DEVENV="$(cat $HOME/.devenv)"
  if [ -f "$HOME/.devenv_${DEVENV}" ]; then
    DEVENV_HOME=$HOME
    source "$HOME/.devenv_${DEVENV}"
  else
    DEVENV=""
    DEVENV_HOME=$HOME
  fi
fi
export DEVENV
export DEVENV_HOME
alias cde="cd \$DEVENV_HOME"

# Local config
if [ -f "$HOME/.bash_local" ]; then
  source "$HOME/.bash_local"
fi

# Prompt
function promptCommand() {
	export PS1="$(prompt $? $COLUMNS)"
}
export PROMPT_COMMAND=promptCommand
