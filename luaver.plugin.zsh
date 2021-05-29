#!/usr/bin/env zsh

# According to the Zsh Plugin Standard:
# http://zdharma.org/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"
# Then ${0:h} to get plugin’s directory
export LUAVER_PLUGIN_DIR="${0:A:h}"

# Modified zsh version of the original script
local luaver_zsh_scriptname='luaver'

source $LUAVER_PLUGIN_DIR/${luaver_zsh_scriptname}

fpath+=( $LUAVER_PLUGIN_DIR/completions )
