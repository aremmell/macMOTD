#!/usr/bin/env zsh

################################################################################
#
# This file is part of macMOTD (https://github.com/aremmell/macMOTD/)
#
# Version:   1.1.0
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

###############
# WIP scratchpad for utility functions to ship as part of macMOTD
###############

# sample code from 10-header-sample.zsh
# =====================================
#
# declare -a test_lines=(
#     "line 1"
#     "line 2"
#     "line 3"
# )

# mm_print_hcenter "test_lines"

# echo "\n==== begin ANSI escape code test ===="
# echo "---- COLORS ----\n"

# declare -A fg_color_map=(
#  [black]="${MM_ANSI_FG_BLACK}"
#  [red]="${MM_ANSI_FG_RED}"
#  [green]="${MM_ANSI_FG_GREEN}"
#  [yellow]="${MM_ANSI_FG_YELLOW}"
#  [blue]="${MM_ANSI_FG_BLUE}"
#  [magenta]="${MM_ANSI_FG_MAGENTA}"
#  [cyan]="${MM_ANSI_FG_CYAN}"
#  [white]="${MM_ANSI_FG_WHITE}"
# )

# declare -A bg_color_map=(
#  [black]="${MM_ANSI_BG_BLACK}"
#  [red]="${MM_ANSI_BG_RED}"
#  [green]="${MM_ANSI_BG_GREEN}"
#  [yellow]="${MM_ANSI_BG_YELLOW}"
#  [blue]="${MM_ANSI_BG_BLUE}"
#  [magenta]="${MM_ANSI_BG_MAGENTA}"
#  [cyan]="${MM_ANSI_BG_CYAN}"
#  [white]="${MM_ANSI_BG_WHITE}"
# )

# for key value in ${(kv)fg_color_map}; do
#     mm_ansi_color "This is normal ${key} text." "" "${value}"
# done

# for key value in ${(kv)fg_color_map}; do
#     mm_ansi_color "This is bold ${key} text." "${MM_ANSI_ATTR_BOLD}" "${value}"
# done

# for key value in ${(kv)fg_color_map}; do
#     mm_ansi_color "This is dim ${key} text." "${MM_ANSI_ATTR_DIM}" "${value}"
# done

# for key value in ${(kv)fg_color_map}; do
#     local rnd=$(( $RANDOM % ${#bg_color_map} - 1 ))
#     local idx=0
#     for bgkey bgvalue in ${(kv)bg_color_map}; do
#         if [[ ${idx} -eq ${rnd} ]]; then
#             mm_ansi_color "This is black text with ${bgkey} background." "" "${MM_ANSI_FG_BLACK}" "${bgvalue}"
#             break
#         fi
#         (( idx++ ))
#     done
# done

# echo "\n---- ATTRS ----\n"

# mm_ansi_invert "This is inverted text."
# mm_ansi_uline "This is underlined text."
# mm_ansi_emph "This is emphasized text."
# mm_ansi_bold "This is bold text."
#
# =====================================

print_storage_stats() {
    local storage_data=$(system_profiler -json SPStorageDataType)
    echo "${storage_data//$'\n'/}" | \
        awk '
        function hr_bytes(b) {
            one_kb=1000
            if (b < one_kb) {
                return sprintf("%d", b);
            }
            suff1="KMGT"
            suff2="B"
            for (n=4;n>=0;n--) {
                if (b >= one_kb ^ n) {
                    return sprintf("%.02f%s%s", b / one_kb ^ n,
                        substr(suff1, n, 1), suff2);
                }
            }
        }
        {
            f=substr($75, 0, length($75)-1)
            t=substr($112, 0, length($112)-1)
            printf("Total: %s, Used: %s, Free: %s (%.2f%% available)\n",
                hr_bytes(t), hr_bytes(t-f), hr_bytes(f), ((t-(t-f)) * 100) / t);
        }'
}

# $1: The sysctl key path of the entry to retrieve.
# $2: The name of a variable that receives the entry's value if successful.
_get_sysctl_entry() {
    if [[ -z "${2}" ]]; then
        false; return
    fi

    print -v ${2} -- "$(sysctl -n ${1})"
}

print_cpu_info() {
    cpu_brand=""
    _get_sysctl_entry "machdep.cpu.brand_string" "cpu_brand"

    total_num_cores=""
    _get_sysctl_entry "hw.physicalcpu_max" "total_num_cores"

    cpu_level0_name=""
    _get_sysctl_entry "hw.perflevel0.name" "cpu_level0_name"

    cpu_level0_num_cores=""
    _get_sysctl_entry "hw.perflevel0.physicalcpu_max" "cpu_level0_num_cores"

    cpu_level1_name=""
    _get_sysctl_entry "hw.perflevel1.name" "cpu_level1_name"

    cpu_level1_num_cores=""
    _get_sysctl_entry "hw.perflevel1.physicalcpu_max" "cpu_level1_num_cores"

    printf "CPU: %s, %s cores (%s %s, %s %s)\n" "${cpu_brand}" "${total_num_cores}" \
        "${cpu_level0_num_cores}" "${cpu_level0_name}" "${cpu_level1_num_cores}" \
            "${cpu_level1_name}"
}

print_os_info() {
    os_product_ver=""
    _get_sysctl_entry "kern.osproductversion" "os_product_ver"

    os_ver=""
    _get_sysctl_entry "kern.osversion" "os_ver"

    declare -rlA os_names=(
        ['10.12']="Sierra"
        ['10.13']="High Sierra"
        ['10.14']="Mojave"
        ['10.15']="Catalina"
        ['11']="Big Sur"
        ['12']="Monterey"
        ['13']="Ventura"
        ['14']="Sonoma"
        ['15']="Sequoia"
        ['26']="Tahoe"
    )

    local os_name="Unknown"
    local segments=(${(@s:.:)os_product_ver})

    if [[ "${segments[1]}" = "10" ]]; then
        os_name="${os_names[${segments[1]}.${segments[2]}]}"
    else
        os_name="${os_names[${segments[1]}]}"
    fi

    printf "macOS %s %s (%s)\n" "${os_name}" "${os_product_ver}" "${os_ver}"
}

human_readable_bytes() {
}

print_memory_info() {
    declare -al vms=($(vm_stat | sed -nE "s/[^0-9]*([0-9]+).*/\1/p"))
    declare -al scs=($(sysctl -n hw.memsize vm.page_pageable_internal_count))

    # Rafał Zarajczyk
    # https://rzarajczyk.github.io/
    #
    # page size =
    #   vm_stat "Mach Virtual Memory Statistics: (page size of 16384 bytes)" vms[0]
    # total = sysctl hw.memsize scs[0]
    # pageable = sysctl vm.page_pageable_internal_count scs[1]
    # purgeable = vm_stat "Pages purgeable:  765339." vms[7]
    # app = pageable - purgeable
    # wired = vm_stat "Pages wired down:  246972." vms[6]
    # compressed = vm_stat "Pages occupied by compressor: 0." vms[16]
    # used = app + wired + compressed

    local page_size="${vms[1]}"
    local total="${scs[1]}"
    local pageable="$(( ${scs[2]} * ${page_size} ))"
    local purgeable="$(( ${vms[8]} * ${page_size} ))"
    local app="$(( ${pageable} - ${purgeable} ))"
    local wired="$(( ${vms[7]} * ${page_size} ))"
    local compressed="$(( ${vms[17]} * ${page_size} ))"
    local used="$(( ${app} + ${wired} + ${compressed} ))"

    printf "total: %s\npage size: %s\npageable: %s\npurgeable: %s\napp: %s\nwired: %s\ncompressed: %s\nused: %s\n" \
        "${total}" "${page_size}" "${pageable}" "${purgeable}" "${app}" "${wired}" \
        "${compressed}" "${used}"
}

print_cpu_info
print_os_info
print_memory_info

# print_storage_stats
# busted on:
# Darwin kenny 24.6.0 Darwin Kernel Version 24.6.0
# Mon Jul 14 11:30:55 PDT 2025; root:xnu-11417.140.69~1/RELEASE_ARM64_T6031 arm64

