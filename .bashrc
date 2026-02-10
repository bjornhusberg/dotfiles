# Common
source "$HOME/.commonrc"

# Prompt
function promptCommand() {
  export PROMPT_EXIT=$?
  export PROMPT_USER
  export PROMPT_STYLE
  export COLUMNS
  export PS1=$("$HOME/bin/prompt")
}

export PROMPT_COMMAND="promptCommand"

# Local config
if [ -f "$HOME/.bash_local" ]; then
  source "$HOME/.bash_local"
fi

