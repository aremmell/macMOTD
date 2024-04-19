#!/usr/bin/env zsh

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

#    printf "total: %s\npage size: %s\npageable: %s\npurgeable: %s\napp: %s\nwired: %s\ncompressed: %s\nused: %s\n" \
#        "${total}" "${page_size}" "${pageable}" "${purgeable}" "${app}" "${wired}" \
#        "${compressed}" "${used}"
}

# uname -n = kenny
# uname -m = arm64

print_cpu_info
print_os_info
print_memory_info
