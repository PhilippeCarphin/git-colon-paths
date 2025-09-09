#!/usr/bin/env bash

_setup(){
    local this_dir="$(command cd -P $(dirname ${BASH_SOURCE[0]}) && pwd)"
    source ${this_dir}/etc/profile.d/git-colon-path-support.bash

    alias vim='_gcps_wrap_command vim'
    alias cd='_gcps_wrap_command cd'

    complete -F _gcps_complete_files vim
    complete -F _gcps_complete_cd cd
    export MANPATH=${MANPATH}:${this_dir}/share/man
}
_setup ; unset _
