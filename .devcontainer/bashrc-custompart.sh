#!/bin/bash

export LS_OPTIONS="--color=auto"
eval "$(dircolors)"
alias ls="ls \$LS_OPTIONS"
alias ll="ls \$LS_OPTIONS -l"
alias l="ls \$LS_OPTIONS -lA"

# shellcheck disable=SC1090
. ~/git-prompt.sh

export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWSTASHSTATE=1
export GIT_PS1_SHOWUNTRACKEDFILES=1

git_info() {
    __git_ps1 " (%s)"
}

PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]"
PS1="${PS1}\[\033[01;33m\]\$(git_info) \[\033[00m\]\$ "
export PS1

# shellcheck source=/dev/null
source <(kubectl completion bash)
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
