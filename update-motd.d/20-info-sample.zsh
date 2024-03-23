#!/usr/bin/env zsh

#
# This is a sample script for use with the dynamic MOTD (Message of the Day)
# feature provided by this library.
#
# See the comment in '10-header-sample.zsh' for more information.
#

# try to determine a good guesstimate for terminal column count, since
# we're not running under a terminal.
_columns="$(tput -Txterm-256color cols)"
if [ "${_columns}" -lt 90 ]; then
    _columns="90"
fi

# prints text horizontally centered in the terminal.
# args = an array of lines to print
centerText() {
    declare -a text=()
    text+=($*)
    for (( i=0;i<=${#text[@]};i++ )); do
        printf "%*s\n" $(( (${#text[i]} + _columns) / 2)) "${text[i]}"
        if [ ${i} -ge ${#text[@]} ]; then
            break
        fi
    done
}

# the lines I like in my MOTD.
declare -a lines=(
    "$(uptime | sed -E 's/[0-9]{1,2}:[0-9]{1,2}  //g')"
    "$(date)"
)

# print centered lines.
centerText "${lines[@]}"
echo "\n"
