#!/bin/bash
#
# Bash completion for Knife 0.10+
#
# Original code has been taken from knife-hack repo by Opscode
# Modifications were done bya Opsway.
#
# LICENSE
# Copyright 2011 Opscode, Inc
#
# Author:: Steven Danna (steve@opcsode.com)
#
# Licensed under the Apache License,
# Version 2.0 (the "License");
#
# This is short part from original code
# autocompletion only for first argument and for sshx plugin
#

cached_nodelist=~/.chef/knife-nodelist-*

if [ $(uname) = "Darwin" ]; then
    SED="gsed"
else
    SED="sed"
fi

_escape() {
    echo "$1" | $SED -r s'/([^a-zA-Z0-9])/\\\1/g'
}

_flatten_command() {
    local cur
    _get_comp_words_by_ref cur
    echo ${COMP_WORDS[*]} |  $SED -r -e 's/[[:space:]]-[[:alnum:]-]+//g' \
        -e "s/[[:space:]]*$(_escape $cur)\$//" -e 's/[[:space:]]+/_/g'
}

# Helper functions to get lists of
# Unfortunately knife pollutes STDOUT
# on errors, making this more complicated then it needs to be.

_output_on_success() {
    local out
    out=$($* 2>/dev/null)
    [ $? -eq 0 ] && echo $out
}

_chef_nodes() {
    if [ -f $cachedd_nodelist ] ; then
      _output_on_success cat $cached_nodelist
    else
     echo  _output_on_success knife node list
    fi
}

_knife() {
    local cur prev opts candidates
    _get_comp_words_by_ref cur prev

    if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "${opts}" -- ${cur}))
        return 0
    fi

    case $(_flatten_command) in
        knife)
            candidates="bootstrap client configure cookbook data_bag environment exec help index_rebuild node recipe role search ssh sshx sslconfig status tag"
            ;;
        knife_sshx)
            candidates=$(_chef_nodes)
            ;;
        *)
            _filedir
            return 0;
            ;;
    esac
    COMPREPLY=($(compgen -W "${candidates}" -- ${cur}))
    return 0
}

complete -F _knife knife
