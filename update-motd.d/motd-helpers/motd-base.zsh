#!/usr/bin/env zsh

################################################################################
#
# This file is part of macMOTD (https://github.com/aremmell/macMOTD/)
#
# Version:   1.0.1
# License:   MIT
# Copyright: (c) 2025 Ryan M. Lederman <lederman@gmail.com>
#
################################################################################
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
################################################################################

################################################################################
# Global variables

declare -rx MM_DEFAULT_MIN_COLS="90"
declare -rx \
    MM_GLYPH_BULLET="\xe2\x80\xa2" \
    MM_GLYPH_RARROW="\xe2\x86\x92" \
    MM_GLYPH_LARROW="\xe2\x86\x90"

declare -rx \
    MM_ESC="\x1b[" \
    MM_ESC_M="m" \
    MM_ESC_RST="${MM_ESC}${MM_ANSI_ALL_END}${MM_ESC_M}"

declare -rx \
    MM_ANSI_INVERT="7" \
    MM_ANSI_INVERT_END="27" \
    MM_ANSI_ULINE="4" \
    MM_ANSI_ULINE_END="24" \
    MM_ANSI_EMPH="3" \
    MM_ANSI_EMPH_END="23" \
    MM_ANSI_BOLD="1" \
    MM_ANSI_BOLD_END="22" \
    MM_ANSI_ALL_END="0"

declare -rx \
    MM_ANSI_FG_BLACK="30" \
    MM_ANSI_FG_RED="31" \
    MM_ANSI_FG_GREEN="32" \
    MM_ANSI_FG_YELLOW="33" \
    MM_ANSI_FG_BLUE="34" \
    MM_ANSI_FG_MAGENTA="35" \
    MM_ANSI_FG_CYAN="36" \
    MM_ANSI_FG_WHITE="37" \
    MM_ANSI_FG_BBLACK="90" \
    MM_ANSI_FG_BRED="91" \
    MM_ANSI_FG_BGREEN="92" \
    MM_ANSI_FG_BYELLOW="93" \
    MM_ANSI_FG_BBLUE="94" \
    MM_ANSI_FG_BMAGENTA="95" \
    MM_ANSI_FG_BCYAN="96" \
    MM_ANSI_FG_BWHITE="97" \
    MM_ANSI_FG_DEFAULT="39" \
    MM_ANSI_BG_BLACK="40" \
    MM_ANSI_BG_RED="41" \
    MM_ANSI_BG_GREEN="42" \
    MM_ANSI_BG_YELLOW="43" \
    MM_ANSI_BG_BLUE="44" \
    MM_ANSI_BG_MAGENTA="45" \
    MM_ANSI_BG_CYAN="46" \
    MM_ANSI_BG_WHITE="47" \
    MM_ANSI_BG_BBLACK="100" \
    MM_ANSI_BG_BRED="101" \
    MM_ANSI_BG_BGREEN="102" \
    MM_ANSI_BG_BYELLOW="103" \
    MM_ANSI_BG_BBLUE="104" \
    MM_ANSI_BG_BMAGENTA="105" \
    MM_ANSI_BG_BCYAN="106" \
    MM_ANSI_BG_DEFAULT="49"

declare -rx \
    MM_ANSI_ATTR_NORMAL="0" \
    MM_ANSI_ATTR_BOLD="1" \
    MM_ANSI_ATTR_DIM="2"

declare -rxi \
    MM_UNINSTALL_LEAVE=1 \
    MM_UNINSTALL_RENAME=2 \
    MM_UNINSTALL_NUKE=3

declare -rx \
    MM_INSTALL_SF="-i" \
    MM_INSTALL_LF="--install" \
    MM_GENERATE_SF="-g" \
    MM_GENERATE_LF="--generate" \
    MM_UNINSTALL_SF="-u" \
    MM_UNINSTALL_LF="--uninstall" \
    MM_LOG_SF="-l" \
    MM_LOG_LF="--log" \
    MM_FREQUENCY_SF="-f" \
    MM_FREQUENCY_LF="--frequency" \
    MM_DEBUG_SF="-d" \
    MM_DEBUG_LF="--debug" \
    MM_HELP_SF="-h" \
    MM_HELP_LF="--help"

declare -rx MM_BACKUP_EXT=".bak"

################################################################################
# Helper functions

# Formats a variable with ANSI-escaped text.
#
# $1: Text.
# $2: ANSI start code(s) (e.g. "1;33;49").
# $3: ANSI end code (e.g. "0").
# $4: The name of a variable that receives the formatted text.
mm_ansi_escape() {
    if [[ -z "${1}" ]] || [[ -z "${2}" ]] || [[ -z "${3}" ]] \
       || [[ -z "${4}" ]]; then
        false; return
    fi

    print -v ${4} -- "${MM_ESC}${2}${MM_ESC_M}${1}${MM_ESC}${3}${MM_ESC_M}"
}

# Outputs ANSI-escaped text to stdout.
#
# $1: Text.
# $2: ANSI start code(s) (e.g. "1;33;49").
# $3: ANSI end code (e.g. "0").
# $4: Whether or not to include a trailing newline (default: true).
mm_ansi_print() {
    escaped_text=""
    if ! mm_ansi_escape "${1}" "${2}" "${3}" "escaped_text"; then
        false; return
    fi

    [[ ${4} != false ]] && 4=true

    echo "-e${${${(M)4:#false}:+n}:-}" "${escaped_text}"
}

# Prints colored text to stdout.
#
# $1: Text.
# $2: Attributes (normal if empty).
# $3: Foreground color ANSI code (default if empty).
# $4: Background color ANSI code (default if empty).
# $5: Whether or not to include a trailing newline (default: true).
mm_ansi_color() {
    [[ -n "${2}" ]] || 2="${MM_ANSI_ATTR_NORMAL}"
    [[ -n "${3}" ]] || 3="${MM_ANSI_FG_DEFAULT}"
    [[ -n "${4}" ]] || 4="${MM_ANSI_BG_DEFAULT}"

    mm_ansi_print "${1}" "${2};${3};${4}" "${MM_ANSI_ALL_END}" "${5}"
}

# Prints inverted text to stdout.
#
# $1: Text.
# $2: Whether or not to include a trailing newline (default: true).
mm_ansi_invert() {
    mm_ansi_print "${1}" "${MM_ANSI_INVERT}" "${MM_ANSI_INVERT_END}" "${2}"
}

# Prints underlined text to stdout.
#
# $1: Text.
# $2: Whether or not to include a trailing newline (default: true).
mm_ansi_uline() {
    mm_ansi_print "${1}" "${MM_ANSI_ULINE}" "${MM_ANSI_ULINE_END}" "${2}"
}

# Prints emphasized text to stdout.
#
# $1: Text.
# $2: Whether or not to include a trailing newline (default: true).
mm_ansi_emph() {
    mm_ansi_print "${1}" "${MM_ANSI_EMPH}" "${MM_ANSI_EMPH_END}" "${2}"
}

# Prints text in bold to stdout.
#
# $1: Text.
# $2: Whether or not to include a trailing newline (default: true).
mm_ansi_bold() {
    mm_ansi_print "${1}" "${MM_ANSI_BOLD}" "${MM_ANSI_BOLD_END}" "${2}"
}

# Determines whether the input is numeric (only contains characters 0-9) or not.
#
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
