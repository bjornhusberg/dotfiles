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
if [ -f "$HOME/.bash_local" ]; then
  source "$HOME/.bash_local"
fi

# Prompt
function promptcmd () {

  local last_exit_code="$?"

  if [ "$OSTYPE" = "cygwin" ]; then
    if [ -x /usr/bin/tput ]; then
      LINES=$(tput lines)
      export LINES
      COLUMNS=$(tput cols)
      export COLUMNS
    fi
  fi

  # Variables
  local current_width="$COLUMNS"
  local current_dir="${PWD/#$HOME/~}"
  local current_time="$(date '+%H:%M:%S')"
  local current_date="$(date '+%Y-%m-%d')"
  local current_devenv="$DEVENV"

  local current_dotfiles_status=""
  if [ -f "$HOME/.dotfiles_dirty" ]; then
    local current_dotfiles_status="!"
  fi

  local current_user="$USER@$HOSTNAME"
  if [ -f "$HOME/.promptuser" ]; then
    local current_user="$(cat $HOME/.promptuser)"
  fi

  # Color settings
  local reset_color="\[\033[0m\]"
  local line_color="\[\033[1;36m\]"
  local frame_color="\[\033[1;34m\]"
  local user_color="\[\033[1;32m\]"
  local devenv_color="\[\033[1;33m\]"
  local dir_color="\[\033[1;35m\]"
  local time_color="\[\033[1;33m\]"
  local date_color="\[\033[1;33m\]"
  local warning_color="\[\033[1;35m\]"

  # Box drawing in Unicode
  local line_h=$(echo -e "\xe2\x94\x80")
  local line_ul=$(echo -e "\xe2\x94\x8c")
  local line_ur=$(echo -e "\xe2\x94\x90")
  local line_ll=$(echo -e "\xe2\x94\x94")
  local line_lr=$(echo -e "\xe2\x94\x98")

  # Get the current cursor column position
  exec < /dev/tty
  local old_stty=$(stty -g)
  stty raw -echo min 0
  echo -en "\033[6n" > /dev/tty
  IFS=';' read -r -d R -a pos
  stty $old_stty
  local current_column=${pos[1]}

  # Optional extra linefeed
  local optional_lf=""
  if [ "${current_column}" != "1" ]; then
    optional_lf="\n"
  fi

  local frame_left="$frame_color$line_h("
  local frame_right="$frame_color)$line_h"
  local frame_line="$line_color$line_h"

  local dir_length=$((${#current_dir} + 4))
  local user_length=$((${#current_user} + 5))
  local date_length=$((${#current_date} + 5))

  local formatted_dir="$frame_left$dir_color$current_dir$frame_right"
  local formatted_user="$frame_left$user_color$current_user$frame_right"
  local formatted_time="$frame_left$time_color$current_time$frame_right"
  local formatted_date="$frame_left$date_color$current_date$frame_right"
  local formatted_exit_code=""
  local formatted_devenv=""
  local devenv_length="0"
  local formatted_dotfiles_status=""
  local dotfiles_status_length="0"

  # Development environment
  if [ "$current_devenv" != "" ]; then
    formatted_devenv="$frame_left$devenv_color$current_devenv$frame_right$frame_line"
    devenv_length=$((${#current_devenv} + 5))
  fi

  # Optional exit code
  if [ "$last_exit_code" != "0" ]; then
    formatted_exit_code="$frame_left${warning_color}$last_exit_code$frame_right$frame_line"
  fi

  # Dotfiles status
  if [ "$current_dotfiles_status" != "" ]; then
    formatted_dotfiles_status="$frame_left${warning_color}${current_dotfiles_status}$frame_right$frame_line"
    dotfiles_status_length=$((${#current_dotfiles_status} + 5))
  fi

  # Upper line fill
  local prompt_u=""
  local upper_fill_length=$(($current_width - $user_length - $dir_length - $devenv_length - $dotfiles_status_length - 2))
  if [ $upper_fill_length -lt 0 ]; then
    local max_dir_length=$(($dir_length + $upper_fill_length))
    if [ $max_dir_length -lt 8 ]; then
      upper_fill_length=$(($upper_fill_length + $dir_length))
      formatted_dir=""
    else
      upper_fill_length=0
      truncated_dir="...${current_dir:$((7-$max_dir_length))}"
      formatted_dir="$frame_left$dir_color$truncated_dir$frame_right"
    fi
  fi
  for ((; upper_fill_length > 0; upper_fill_length--)) {
    prompt_u="$prompt_u$line_h"
  }

  local ur_start=$(($current_width - $date_length))

  # Construct the prompt
  local prompt_ul="$line_color$line_ul$formatted_user$frame_line$formatted_dotfiles_status$formatted_devenv"
  local prompt_ur="$formatted_dir$line_color$line_ur"
  local prompt_lr="$frame_line$formatted_date$line_color$line_lr"
  local prompt_ll="$line_color$line_ll$formatted_exit_code$formatted_time$frame_line$reset_color "
  PS1="$optional_lf\n\033[1A$prompt_ul$prompt_u$prompt_ur\033[1B\033[${ur_start}G$prompt_lr\033[1A\n$prompt_ll"
}
export PROMPT_COMMAND=promptcmd
