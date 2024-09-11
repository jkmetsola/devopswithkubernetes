#!/bin/bash
parse_git_branch() {
  if [ -n "$(git rev-parse --git-dir 2> /dev/null)" ]; then
    echo "($(git rev-parse --abbrev-ref HEAD)) "
  fi
}

export LS_OPTIONS="--color=auto"
eval "$(dircolors)"
alias ls="ls \$LS_OPTIONS"
alias ll="ls \$LS_OPTIONS -l"
alias l="ls \$LS_OPTIONS -lA"


PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
PS1="${PS1}\[\033[01;33m\]\$(parse_git_branch)\[\033[00m\]"
export PS1

# shellcheck source=/dev/null
source <(kubectl completion bash)
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
