#!/usr/bin/env zsh

################################################################################
#
# This file is part of macMOTD (https://github.com/aremmell/macMOTD/)
#
# Version:   1.0.0
# License:   MIT
# Copyright: (c) 2024 Ryan M. Lederman <lederman@gmail.com>
#
##############################################################################
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
##############################################################################

##############################################################################
# Global variables

typeset -rx MM_DEFAULT_MIN_COLS="90"
typeset -rx MM_BULLET_GLYPH="\xe2\x80\xa2"

typeset -rx MM_ESC_EMPH="\x1b[3m"
typeset -rx MM_ESC_EMPH_END="\x1b[23m"

typeset -rxi \
    MM_UNINSTALL_LEAVE=1 \
    MM_UNINSTALL_RENAME=2 \
    MM_UNINSTALL_NUKE=3

typeset -rx \
    MM_INSTALL_SF="-i" \
    MM_INSTALL_LF="--install" \
    MM_GENERATE_SF="-g" \
    MM_GENERATE_LF="--generate" \
    MM_UNINSTALL_SF="-u" \
    MM_UNINSTALL_LF="--uninstall" \
    MM_DISABLE_SF="-D" \
    MM_DISABLE_LF="--disable" \
    MM_ENABLE_SF="-e" \
    MM_ENABLE_LF="--enable" \
    MM_LOG_SF="-l" \
    MM_LOG_LF="--log" \
    MM_FREQUENCY_SF="-f" \
    MM_FREQUENCY_LF="--frequency" \
    MM_DEBUG_SF="-d" \
    MM_DEBUG_LF="--debug" \
    MM_HELP_SF="-h" \
    MM_HELP_LF="--help"

typeset -rx MM_BACKUP_EXT=".bak"

##############################################################################
# Helper functions

# Determines whether the input is numeric (only contains characters 0-9) or not.
# $1: Variable to inspect
mm_is_number() {
    [[ ${1} =~ ^[0-9]+$ ]]
}

# Prints center-justified lines of text, given a number of columns wide the
# display area is.
#
# $1: The name of a variable containing an array of lines to print.
# $2: The lowest number of columns to use (leave empty to use MM_DEFAULT_MIN_COLS).
mm_print_hcenter() {
    local min_cols="${MM_DEFAULT_MIN_COLS}"
    mm_is_number "${1}" && min_cols="${1}"

    local tput_cols="$(tput -Txterm-256color cols)"
    [[ "${tput_cols}" -lt ${min_cols} ]] && tput_cols="${min_cols}"

    declare -a text=(${(P)1})
    for (( i=0;i<=${#text[@]};i++ )); do
        printf "%*s\n" $(( (${#text[i]} + tput_cols) / 2)) "${text[i]}"
    done
}
