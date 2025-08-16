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

#
# This is a sample script for use with the dynamic MOTD (Message of the Day)
# feature provided by this library.
#
# See the comment in '10-header-sample.zsh' for more information.
#

source "$(realpath $(dirname ${0}))/motd-helpers/motd-base.zsh" || exit 1

# the lines I like in my MOTD.
declare -a lines=(
    "$(uptime | sed -E -e 's/[0-9]{1,2}:[0-9]{1,2}  //g' -e 's/up  /up /g')"
    "$(date)"
)

# print centered lines.
mm_print_hcenter "lines"
echo "\n"
