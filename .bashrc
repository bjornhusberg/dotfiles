source "$HOME/.common"

function promptCommand() {
  export PROMPT_EXIT=$?
  export PROMPT_USER
  export PROMPT_STYLE
  export COLUMNS
  export PS1=$("$HOME/bin/prompt")
}

export PROMPT_COMMAND="promptCommand"

sourceIfExists .bash_local .bashrc_local
