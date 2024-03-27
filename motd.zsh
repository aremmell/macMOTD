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

zmodload zsh/stat 2>/dev/null || true
zmodload zsh/files 2>/dev/null || true
zmodload zsh/regex 2>/dev/null || true

unsetopt case_match

MOTD_FILE="/etc/motd"
MOTD_TMP_FILE="/etc/motd.tmp"
MOTD_LOG_FILE="/var/log/macMOTD.log"
MOTD_REGEN_FREQUENCY="600"
MOTD_MIN_FREQUENCY="10"
UPDATE_MOTD_D="update-motd.d"
MOTD_HELPERS="motd-helpers"
UPDATE_MOTD_D_DEST="/etc/${UPDATE_MOTD_D}"
MOTD_HELPERS_DEST="${UPDATE_MOTD_D_DEST}/${MOTD_HELPERS}"
LAUNCH_DAEMON_DIR="/Library/LaunchDaemons"
LAUNCH_DAEMON_NAME="com.github.aremmell.macMOTD"
LAUNCH_DAEMON_PATH="${LAUNCH_DAEMON_DIR}/${LAUNCH_DAEMON_NAME}.plist"
LAUNCH_DAEMON_INSTALL_CMD="bootstrap"
LAUNCH_DAEMON_UNINSTALL_CMD="bootout"
LAUNCH_DAEMON_ENABLE_CMD="enable"
LAUNCH_DAEMON_DISABLE_CMD="disable"
SYSTEM_BIN_DIR="/usr/local/bin"
SCRIPT_NAME="$(basename ${0})"
SCRIPT_PATH="$(realpath $(dirname ${0}))"
SCRIPT_DEPS=(
    "${SCRIPT_PATH}/${MOTD_HELPERS}/motd-base.zsh"
)

# $1: log level (e.g. "debug", "info", "warn", "error")
# $2: ANSI color code (e.g. "31")
_mm_echo() {
    if [[ ${#@} -gt 2 ]]; then
        local padding=""
        [[ ${#1} -lt 5 ]] && padding=" "
        printf -v line "%s [%s]:%s %s" "$(date +"%d %h '%y %H:%M:%S %Z")" \
            "${1}" "${padding}" "$@[3,-1]"
        printf "\033[0;%s;49m%s\033[0m\n" "${2}" "${line}"
    fi
}

_mm_debug() {
    if [[ ${_debug} = true ]]; then
        _mm_echo "debug" "90" "$*"
    fi
}

_mm_info() {
    _mm_echo "info" "37" "$*"
}

_mm_warn() {
    _mm_echo "warn" "33" "$*"
}

_mm_error() {
    _mm_echo "error" "31" "$*"
}

_mm_prepare_temp_motd() {
    if [[ -f "${MOTD_TMP_FILE}" ]]; then
        _mm_debug "${MOTD_TMP_FILE} exists; removing..."
        if ! rm -f "${MOTD_TMP_FILE}" >/dev/null 2>&1; then
            _mm_error "failed to remove ${MOTD_TMP_FILE}!"
            false; return
        fi
    else
        _mm_debug "${MOTD_TMP_FILE} does not exist; creating..."
    fi

    if touch "${MOTD_TMP_FILE}" 2>/dev/null; then
        _mm_debug "successfully created ${MOTD_TMP_FILE}."
    else
        _mm_error "failed to create ${MOTD_TMP_FILE}!"
        false; return
    fi
}

_mm_update_motd_from_temp() {
    _mm_debug "moving ${MOTD_TMP_FILE} to ${MOTD_FILE}..."
    if ! mv -f "${MOTD_TMP_FILE}" "${MOTD_FILE}" >/dev/null 2>&1; then
        _mm_error "failed to move ${MOTD_TMP_FILE} to ${MOTD_FILE}!"
        false; return
    fi
    sync
}

_mm_prepare_update_motd_d_dest() {
    if [[ ! -d "${UPDATE_MOTD_D_DEST}" ]] && \
       ! mkdir -p "${UPDATE_MOTD_D_DEST}" >/dev/null 2>&1; then
        _mm_error "failed to create ${UPDATE_MOTD_D_DEST}!"
        false; return
    fi
}

# Copies a script from one location to another, unless the target file exists
# and the files are identical. Sets permissions on the target file, and optionally
# creates a backup of the target file if it exists and the files are not identical.
#
# $1: The source file.
# $2: The target file.
# $3: The octal mode to set on the target file.
# $4: Whether or not to create a backup of the target file as described above.
# $5: The name of a variable that receives a boolean value indicating whether
#     or not the file was copied.
_mm_copy_script() {
    local copy_required=true

    if [[ -f "${2}" ]]; then
        local src_sum=$(shasum -a 256 "${1}" | awk '{ print $1; }' )
        local dst_sum=$(shasum -a 256 "${2}" | awk '{ print $1; }' )

        if [[ "${src_sum}" = "${dst_sum}" ]]; then
            copy_required=false
            _mm_debug "${1} and ${2} are identical."
        else
            if [[ ${4} = true ]]; then
                local backup_file="${2}-$(date -Iseconds)${MM_BACKUP_EXT}"
                _mm_warn "${2} exists and is different than ${1}" \
                            "; making backup at ${backup_file}..."
                if ! mv -f "${2}" "${backup_file}" >/dev/null 2>&1; then
                    _mm_error "failed to back up ${2} to ${backup_file}!"
                    false; return
                fi
            fi
        fi
    fi

    ${(P)5}=${copy_required}

    if [[ ${copy_required} = true ]]; then
        _mm_debug "copying ${1} to ${2}..."
        if ! cp -f "${1}" "${2}" >/dev/null 2>&1; then
            _mm_error "failed to copy ${1} to ${2}!"
            false; return
        fi
    fi

    stat -L -A cur_mode +mode "${2}"
    local octal_mode=$(( [#8] $cur_mode ))
    octal_mode="${octal_mode[${#octal_mode}-2,-1]}"
    if [[ "${octal_mode}" != "${3}" ]]; then
        _mm_debug "setting permissions on ${2} (${octal_mode} -> ${3})..."
        if ! chmod "${3}" "${2}" >/dev/null 2>&1; then
            _mm_error "failed to set permissions on ${2}!"
            false; return
        fi
    else
        _mm_debug "permissions on ${2} are already ${3}."
    fi

    if [[ ${copy_required} = true ]]; then
        _mm_info "successfully copied ${1} to $(dirname ${2})."
    else
        _mm_info "${2} is already up-to-date."
    fi
}

# Copies all .zsh files from one directory to another, and sets permissions on
# the target files. If a target file already exists, and is not identical to the
# source file, it is backed up in its current directory before the copy operation.
#
# $1: The source directory.
# $2: The destination directory.
_mm_deploy_scripts() {
    if [[ -n "${2}" ]]; then
        mkdir -p "${2}" 2>/dev/null
    fi

    if [[ ! -d "${1}" ]] || [[ ! -d "${2}" ]]; then
        _nv_error "either the source or destination directory does not exist (" \
                  "src: '${1}', dst: '${2}')!"
        false; return
    fi

    local scripts_copied=0
    local scripts_skipped=0
    _mm_debug "copying scripts from ${1} to ${2}..."
    for f in ${1}/*.zsh(*); do
        local src_file=$(basename "${f}")
        local dst_file="${2}/${src_file}"
        was_copied=false
        if ! _mm_copy_script "${f}" "${dst_file}" "744" "was_copied"; then
            break
        fi

        if [[ ${was_copied} = true ]]; then
            (( scripts_copied++ ))
        else
            (( scripts_skipped++ ))
        fi
    done

    if [[ $(( $scripts_copied + $scripts_skipped )) -eq 0 ]]; then
        _mm_error "no viable scripts (executable with .zsh extension) located in ${1}!"
        false; return
    fi
}

# $1: The verb to use in log messages (e.g. 'install').
# $2" The past tense form of $1 (e.g. 'installed').
# $2: The launchctl subcommand.
# $3: The remaining arguments to the subcommand.
_mm_launch_daemon_operation() {
    _mm_debug "${1}ing launch daemon; 'launchctl ${3} ${4}'..."

    if ! launchctl ${=3} ${=4}; then
        _mm_error "failed to ${1} launch daemon (${LAUNCH_DAEMON_PATH})!"
        false; return
    fi

    _mm_info "successfully ${2} launch daemon (${LAUNCH_DAEMON_PATH})."
}

_mm_install_launch_daemon() {
    _mm_launch_daemon_operation "install" "installed" \
        "${LAUNCH_DAEMON_INSTALL_CMD}" "system ${LAUNCH_DAEMON_PATH}"
}

_mm_uninstall_launch_daemon() {
    _mm_launch_daemon_operation "uninstall" "uninstalled" \
        "${LAUNCH_DAEMON_UNINSTALL_CMD}" "system ${LAUNCH_DAEMON_PATH}"
}

_mm_enable_launch_daemon() {
    _mm_launch_daemon_operation "enable" "enabled" \
        "${LAUNCH_DAEMON_ENABLE_CMD}" "system/${LAUNCH_DAEMON_NAME}"
}

_mm_disable_launch_daemon() {
    _mm_launch_daemon_operation "disable" "disabled" \
        "${LAUNCH_DAEMON_DISABLE_CMD}" "system/${LAUNCH_DAEMON_NAME}"
}

# Optionally configures the MOTD system for use: installs sample scripts, copies
# this script to a system bin directory, and installs/starts the launch daemon.
# Otherwise, updates the MOTD by iterating over the relevant scripts and copying
# their output to the MOTD file.
#
# $1: true = install *and* update, false = just update.
_mm_update_motd() {
    if ! _mm_prepare_temp_motd || ! _mm_prepare_update_motd_d_dest; then
        false; return
    fi

    if [[ ${1} = true ]]; then
        if ! _mm_deploy_scripts "${UPDATE_MOTD_D}" "${UPDATE_MOTD_D_DEST}"; then
            false; return
        fi

        if ! _mm_deploy_scripts "${MOTD_HELPERS}" "${MOTD_HELPERS_DEST}"; then
            false; return
        fi

        was_copied=false
        if ! _mm_copy_script "${SCRIPT_NAME}" "${SYSTEM_BIN_DIR}/${SCRIPT_NAME}" \
                "744" "was_copied"; then
            false; return
        fi

read -r -d '' _ld_file_contents <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>KeepAlive</key>
        <false/>
        <key>Label</key>
        <string>com.github.aremmell.macMOTD</string>
        <key>UserName</key>
        <string>root</string>
        <key>GroupName</key>
        <string>root</string>
        <key>ProgramArguments</key>
        <array>
            <string>zsh</string>
            <string>${SYSTEM_BIN_DIR}/motd.zsh</string>
            <string>${MM_GENERATE_LF}</string>
        </array>
        <key>StartInterval</key>
        <integer>${MOTD_REGEN_FREQUENCY}</integer>
        <key>RunAtLoad</key>
        <true/>
        <key>ProcessType</key>
        <string>Background</string>
        <key>LowPriorityIO</key>
        <true/>
        <key>StandardErrorPath</key>
        <string>${MOTD_LOG_FILE}</string>
        <key>StandardOutPath</key>
        <string>${MOTD_LOG_FILE}</string>
    </dict>
</plist>
EOF

        if [[ -f "${LAUNCH_DAEMON_PATH}" ]]; then
            _mm_debug "launch daemon file is already present; executing uninstall" \
                      "command in case it's actively running..."
            if ! _mm_uninstall_launch_daemon; then
                _mm_warn "unable to uninstall launch daemon!"
            fi
        fi

        _mm_debug "writing launch daemon file (log: '${MOTD_LOG_FILE}', frequency:" \
                  "${MOTD_REGEN_FREQUENCY}sec)..."
        if ! echo "${_ld_file_contents}" >! "${LAUNCH_DAEMON_PATH}"; then
            _mm_error "failed to write launch daemon file (${LAUNCH_DAEMON_PATH})!"
            false; return
        fi

        _mm_debug "successfully wrote launch daemon file (${LAUNCH_DAEMON_PATH});" \
                  "setting permissions..."
        if ! chmod 644 "${LAUNCH_DAEMON_PATH}" >/dev/null 2>&1; then
            _mm_error "failed to set permissions on ${LAUNCH_DAEMON_PATH}!"
            false; return
        fi

        if ! _mm_install_launch_daemon; then
            false; return
        fi
    fi

    local scripts_total=0
    local scripts_failed=0
    for s in ${UPDATE_MOTD_D_DEST}/*.zsh(.); do
        (( scripts_total++ ))

        if [[ -x "${s}" ]]; then
            _mm_debug "executing ${s}..."
            if ! print -r -- "$(zsh "${s}" 2>&1)" >>! ${MOTD_TMP_FILE}; then
                (( scripts_failed++ ))
                _mm_warn "got failure exit code $? from ${s}!"
            fi
        else
            (( scripts_failed++ ))
            _mm_warn "${s} is not executuable; skipping!"
        fi
    done

    local scripts_successful=$(( $scripts_total - $scripts_failed ))
    if [[ ${scripts_total} -eq 0 ]]; then
        _mm_error "no viable scripts (executable with .zsh extension) located in ${UPDATE_MOTD_D_DEST}!"
    else
        if [[ ${scripts_successful} -gt 0 ]]; then
            _mm_info "successfully executed ${scripts_successful}/${scripts_total} scripts."
        else
            _mm_error "execution of all ${scripts_total} scripts failed!"
        fi
    fi

    if [[ ${scripts_successful} -gt 0 ]] && _mm_update_motd_from_temp; then
        stat -L -A motd_size +size -- "${MOTD_FILE}"
        _mm_info "successfully updated the contents of ${MOTD_FILE} (${motd_size} bytes); done."
    else
        _mm_error "failed to update the contents of ${MOTD_FILE}!"
        false; return
    fi
}

_mm_uninstall() {
    # 1. disable and bootout the launch daemon
    # 2. delete:
    #   - /etc/motd
    #   - /etc/motd.tmp
    #   - depending on the value of _uninstall_mode:
    #     - leave /etc/update-motd.d/*.zsh alone;
    #     - rename
    #     - nuke
    #   - launch daemon plist
    #   - ourself?
}

# $1: The curent option/argument index.
# $2: The expected argument.
# $3: The total count of CLI arguments.
_mm_have_more_cli_args() {
    [[ ${1} -le ${3} ]] && [[ -n "${2}" ]] && [[ "${2[1,1]}" != "-" ]]
}

# $1: The CLI option that requires an argument.
# $2: The expected argument.
# $3: The current option/argument index.
# $4: The total count of CLI arguments.
_mm_validate_cli_arg() {
    if ! _mm_have_more_cli_args "${3}" "${2}" "${4}"; then
        _mm_error "required argument for '${1}' not found."
        _mm_print_usage
    fi
}

_mm_print_usage() {
    read -r -d '' usage_message <<-EOF
Usage:
    ${MM_INSTALL_SF}, ${MM_INSTALL_LF}          Installs and enables macMOTD, then generates the MOTD file (implies ${MM_GENERATE_SF}/${MM_GENERATE_LF}).
    ${MM_GENERATE_SF}, ${MM_GENERATE_LF}         Generates the MOTD file by executing the scripts in ${UPDATE_MOTD_D_DEST}.
    ${MM_UNINSTALL_SF}, ${MM_UNINSTALL_LF} [lrn]  Uninstalls macMOTD. Optionally choose how the scripts in ${UPDATE_MOTD_D_DEST} are handled:
                             ${MM_BULLET_GLYPH} [l]eave as-is (${MM_ESC_EMPH}default${MM_ESC_EMPH_END}).
                             ${MM_BULLET_GLYPH} [r]ename rather than delete.
                             ${MM_BULLET_GLYPH} [n]uke everything (${MM_ESC_EMPH}irreverisble!${MM_ESC_EMPH_END}).
    ${MM_LOG_SF}, ${MM_LOG_F}       <path> Overrides the default log file path (${MOTD_LOG_LFILE}).
    ${MM_FREQUENCY_SF}, ${MM_FREQUENCY_F} <secs> Overrides the default MOTD regeneration frequency (${MOTD_REGEN_LFREQUENCY}sec).
    ${MM_DEBUG_SF}, ${MM_DEBUG_LF}            Enables debug mode, which results in more detailed output.
    ${MM_HELP_SF}, ${MM_HELP_LF}             Prints this help message.
EOF
    echo "${usage_message}"
    exit 1
}

_mm_main() {
    # mutually exclusive: install + uninstall, generate + uninstall
    if [[ ${_uninstall} = true ]]; then
        if [[ ${_install} = true ]]; then
            _mm_error "${MM_INSTALL_SF}/${MM_INSTALL_LF} and" \
                      "${MM_UNINSTALL_SF}/${MM_UNINSTALL_LF} are mutually exclusive!"
            _mm_print_usage
        elif [[ ${_generate} = true ]]; then
            _mm_error "${MM_GENERATE_SF}/${MM_GENERATE_LF} and" \
                      "${MM_UNINSTALL_SF}/${MM_UNINSTALL_LF} are mutually exclusive!"
            _mm_print_usage
        fi
    fi

    # redundant: install + generate
    if [[ ${_install} = true ]] && [[ ${_generate} = true ]]; then
        _mm_error "${MM_INSTALL_SF}/${MM_INSTALL_LF} and" \
                  "${MM_GENERATE_SF}/${MM_GENERATE_LF} are overlapping; only one" \
                  "may be specified at a time."
        _mm_print_usage
    fi

    if [[ ${_install} = true ]]; then
        _mm_update_motd true
    elif [[ ${_generate} = true ]]; then
        _mm_update_motd false
    elif [[ ${_uninstall} = true ]]; then
        _mm_warn "would be doing uninstall."
    else
        _mm_error "no task to execute (${MM_INSTALL_SF}/${MM_INSTALL_LF}," \
                  "${MM_GENERATE_SF}/${MM_GENERATE_LF}, or" \
                  "${MM_UNINSTALL_SF}/${MM_UNINSTALL_LF} required)!"
        _mm_print_usage
    fi
}

_mm_load_dependencies() {
    for dep in "${SCRIPT_DEPS[@]}"; do
        if ! source "${dep}" 2>/dev/null; then
            _mm_error "failed to load dependency '${dep}'!"
            false; return
        fi
    done
}

###############################################################################
# Entry point

if [[ ${EUID} -ne 0 ]]; then
    _mm_error "this script must be executed by root or with sudo; exiting!"
    exit 1
fi

_mm_load_dependencies || exit 1

[[ ${#@} -gt 0 ]] || _mm_print_usage

_argv=("$@")
_argc="${#_argv[@]}"
_generate=false
_install=false
_uninstall=false
_uninstall_mode=MM_UNINSTALL_LEAVE
_debug=false

for (( i=0;i<=${_argc};i++ )); do
    [[ -z "${_argv[i]}" ]] && continue
    _mm_debug "evaluating option: '${_argv[i]}'..."
    case ${_argv[i]} in
        ${MM_INSTALL_SF}|${MM_INSTALL_LF})
            _install=true
        ;;
        ${MM_UNINSTALL_SF}|${MM_UNINSTALL_LF})
            _uninstall=true
            if _mm_have_more_cli_args "${i}" "${_argv[i+1]}" "${_argc}"; then
                if [[ ${_argv[i+1]} =~ ^[lrn]{1}$ ]]; then
                    case ${_argv[i+1]} in
                        l|L)
                            _uninstall_mode=MM_UNINSTALL_LEAVE
                        ;;
                        r|R)
                            _uninstall_mode=MM_UNINSTALL_RENAME
                        ;;
                        n|N)
                            _uninstall_mode=MM_UNINSTALL_NUKE
                        ;;
                    esac
                    _mm_debug "uninstall mode: ${_uninstall_mode}."
                else
                    _mm_error "invalid argument for '${_argv[i]}'; must be one of 'lrn'!"
                    _mm_print_usage
                fi
                (( i++ ))
                continue
            fi
        ;;
        ${MM_GENERATE_SF}|${MM_GENERATE_LF})
            _generate=true
        ;;
        ${MM_DEBUG_SF}|${MM_DEBUG_LF})
            _debug=true
            _mm_debug "debug mode enabled."
        ;;
        ${MM_LOG_SF}|${MM_LOG_LF})
            if _mm_validate_cli_arg "${_argv[i]}" "${_argv[i+1]}" "${i}" "${_argc}"; then
                if touch "${_argv[i+1]}" 2>/dev/null; then
                    _mm_info "using log file '${_argv[i+1]}'."
                    MOTD_LOG_FILE="${_argv[i+1]}"
                else
                    _mm_error "unable to write to requested log file '${_argv[i+1]}'!"
                    _mm_print_usage
                fi
                (( i++ ))
                continue
            fi
        ;;
        ${MM_FREQUENCY_SF}|${MM_FREQUENCY_LF})
            if _mm_validate_cli_arg "${_argv[i]}" "${_argv[i+1]}" "${i}" "${_argc}"; then
                if mm_is_number "${_argv[i+1]}"; then
                    if [[ ${_argv[i+1]} -ge ${MOTD_MIN_FREQUENCY} ]]; then
                        _mm_info "using regeneration frequency ${_argv[i+1]}sec."
                        MOTD_REGEN_FREQUENCY="${_argv[i+1]}"
                    else
                        _mm_error "the minimum regeneration frequency is ${MOTD_MIN_FREQUENCY}sec."
                        _mm_print_usage
                    fi
                else
                    _mm_error "invalid argument for '${_argv[i]}'; not a number!"
                    _mm_print_usage
                fi
                (( i++ ))
                continue
            fi
        ;;
        ${MM_HELP_SF}|${MM_HELP_LF})
            _mm_print_usage
        ;;
        *)
            _mm_error "unknown option: ${_argv[i]}"
            _mm_print_usage
        ;;
    esac
done

_mm_main
