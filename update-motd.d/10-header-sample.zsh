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

#
# This is a sample script for use with the dynamic MOTD (Message of the Day)
# feature provided by this library.
#
# If you're not familiar with MOTD, or what 'update-motd' does on some *nix
# distributions, you should read the MOTD.md file in the root of this repository.
#
# However, if you're feeling adventerous, I'll give you the TLDR here:
#
# MOTD is a dynamically generated (usually, but can be static too) file that
# is sent to your terminal whenever you initiate an SSH or other login session.
#
# This mechanism is what provides the information that you see when you log in to a
# remote server and you are shown details about the host name, uptime, OS,
# whether updates are available to packages, etc.
#
# On macOS, there is no dynamic MOTD generation mechanism that I'm aware of. This
# implementation is simple, though: a script (motd.zsh) generates the necessary
# files and directories in preparation for its use.
#
# A cron-like task is installed which periodically enumerates the scripts in the
# MOTD update script folder, and sends their output to the MOTD file, causing it
# to be nice and fresh.
#
# This script is one that lives in that folder, and typically these scripts are given
# names like 10-header-hello. This is because when the scripts are executed, they are
# done so in a descending alphabetical order; a script that starts with '1' is going
# to run before one that starts with '2', and so on. This ensures that the MOTD file
# always has the content in the right order.
#
# All of the output generated by this script to stdout is piped into the MOTD file,
# so all you have to do is generate useful output.
#
# If you don't want to spend the time and effort setting up the MOTD update feature,
# you can just execute this script from a terminal and observe the output.
#

source "$(dirname ${0})/motd-helpers/motd-base.zsh" || exit 1

declare -a test_lines=(
    "line 1"
    "line 2"
    "line 3"
)

mm_print_hcenter "test_lines"

