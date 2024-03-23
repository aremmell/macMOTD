#!/usr/bin/env zsh

################################################################################
#
# macMOTD
# Version: 1.0.0
#
##############################################################################
#
# SPDX-License-Identifier: MIT
#
# Copyright (c) 2024 Ryan M. Lederman <lederman@gmail.com>
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

zmodload zsh/stat
zmodload zsh/files

MOTD_FILE="/etc/motd"
MOTD_TMP_FILE="/etc/motd.tmp"
UPDATE_MOTD_D="update-motd.d"
MOTD_SCRIPT_DIR="/etc/${UPDATE_MOTD_D}"
LAUNCH_DAEMON_DIR="/Library/LaunchDaemons"
LAUNCH_DAEMON_NAME="com.github.aremmell.macMOTD.plist"
SYSTEM_BIN_DIR="/usr/local/bin"
SCRIPT_NAME=$(basename ${0})

# $1: log level (e.g. "debug", "info", "warn", "error")
# $2: ANSI color code (e.g. "31")
_mm_echo() {
    if [[ ${#@} -gt 2 ]]; then
        printf "\033[0;%s;49m%s [%s]: %s\033[0m\n" "${2}" "${SCRIPT_NAME}" "${1}" "$@[3,-1]"
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

    if touch "${MOTD_TMP_FILE}"; then
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

_mm_prepare_motd_script_dir() {
    if [[ ! -d "${MOTD_SCRIPT_DIR}" ]] && \
       ! mkdir -p "${MOTD_SCRIPT_DIR}" >/dev/null 2>&1; then
        _mm_error "failed to create ${MOTD_SCRIPT_DIR}!"
        false; return
    fi
}

_mm_populate_motd_script_dir() {
    _mm_debug "making scripts in ${UPDATE_MOTD_D} executable..."
    if ! chmod 744 "${UPDATE_MOTD_D}/"*.zsh >/dev/null 2>&1; then
        _mm_error "failed to set permissions on one or more scripts in ${MOTD_SCRIPT_DIR}!"
        false; return
    fi

    local scripts_copied=0
    _mm_debug "copying scripts from ${UPDATE_MOTD_D} to ${MOTD_SCRIPT_DIR}..."
    for f in ${UPDATE_MOTD_D}/*.zsh(*); do
        _mm_debug "copying ${f} to ${MOTD_SCRIPT_DIR}..."
        if ! cp -f "${f}" "${MOTD_SCRIPT_DIR}" >/dev/null 2>&1; then
            _mm_error "failed to copy ${f} to ${MOTD_SCRIPT_DIR}!"
            false; return
        fi
        (( scripts_copied++ ))
    done

    if [[ ${scripts_copied} -gt 0 ]]; then
        _mm_info "successfully copied ${scripts_copied} scripts to ${MOTD_SCRIPT_DIR}."
    else
        _mm_error "no viable scripts (executable with .zsh extension) located in ${UPDATE_MOTD_D}!"
        false; return
    fi
}

# _mm_update_motd
#
# Optionally configures the MOTD system for use: installs sample scripts, copies
# this script to a system bin directory, and installs/starts the launch daemon.
# Otherwise, updates the MOTD by iterating over the relevant scripts and copying
# their output to the MOTD file.
#
# $1: true = install *and* update, false = just update.
_mm_update_motd() {
    if ! _mm_prepare_temp_motd || ! _mm_prepare_motd_script_dir; then
        false; return
    fi

    if [[ ${1} = true ]]; then
        if ! _mm_populate_motd_script_dir; then
            false; return
        fi

        _mm_debug "copying ${PWD}/${SCRIPT_NAME} to ${SYSTEM_BIN_DIR}..."
        if ! cp -f "${SCRIPT_NAME}" "${SYSTEM_BIN_DIR}" >/dev/null 2>&1; then
            _mm_error "failed to copy ${SCRIPT_NAME} to ${SYSTEM_BIN_DIR}!"
            false; return
        fi

        _mm_info "successfully copied ${SCRIPT_NAME} to ${SYSTEM_BIN_DIR}."

read -r -d '' _ld_file_contents <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>KeepAlive</key>
        <false />
        <key>Label</key>
        <string>com.github.aremmell.macMOTD</string>
        <key>UserName</key>
        <string>root</string>
        <key>ProgramArguments</key>
        <array>
            <string>zsh</string>
            <string>/usr/local/bin/motd.zsh</string>
            <string>--update</string>
        </array>
        <key>StartInterval</key>
        <integer>600</integer>
        <key>RunAtLoad</key>
        <true />
        <key>StandardErrorPath</key>
        <string>/dev/null</string>
        <key>StandardOutPath</key>
        <string>/dev/null</string>
    </dict>
</plist>
EOF
        local ld_filename="${LAUNCH_DAEMON_DIR}/${LAUNCH_DAEMON_NAME}"
        if [[ -f "${ld_filename}" ]]; then
            _mm_debug "launch daemon file is already present;" \
                      "running 'launchctl unload'..."
            if launchctl unload "${ld_filename}"; then
                _mm_debug "successfully unloaded launch daemon."
            else
                _mm_warn "unable to unload launch daemon; not loaded to begin with?"
            fi
        fi

        _mm_debug "writing launch daemon file..."
        if ! echo "${_ld_file_contents}" > "${ld_filename}"; then
            _mm_error "failed to write launch daemon file (${ld_filename})!"
            false; return
        fi

        _mm_debug "successfully wrote launch daemon file (${ld_filename})."

        if ! launchctl load "${ld_filename}"; then
            _mm_error "failed to load launch daemon (${ld_filename})!"
            false; return
        fi

        _mm_info "successfully loaded launch daemon; use 'TODO'."
    fi

    local scripts_total=0
    local scripts_failed=0

    for s in ${MOTD_SCRIPT_DIR}/*.zsh(.); do
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
        _mm_error "no viable scripts (executable with .zsh extension) located in ${MOTD_SCRIPT_DIR}!"
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

_mm_print_usage() {
    echo "Usage:"
    printf "\t[-i|--install]\tInstalls %s before updating (implies --update)\n" \
        "sample MOTD scripts, launch daemon, and this script"
    printf "\t[-u|--update]\tGenerates %s by executing scripts in %s.\n" \
        "${MOTD_FILE}" "${MOTD_SCRIPT_DIR}"
    echo "\t[-d|--debug]\tEnables debug mode, which produces more detailed output."
    echo "\t[-h|--help]\tPrints this help message."
}

_mm_main() {
    if [[ ${EUID} -ne 0 ]]; then
        _mm_error "this script must be executed by root or with sudo; exiting!"
        false; return
    fi

    _mm_debug "debug mode enabled."

    if [[ ${_install} = true ]]; then
        _mm_update_motd true
    elif [[ ${_update} = true ]]; then
        _mm_update_motd false
    else
        _mm_error "no command to execute!"
        _mm_print_usage
        false; return
    fi
}

_args=( "$@" )
_update=false
_install=false
_print_usage=false
_debug=false

if [[ ! ${#_args[@]} -gt 0 ]]; then
    _print_usage=true
else
    for arg in "${_args[@]}"; do
        #_mm_echo "evaluating arg: '${arg}'..."
        case ${arg} in
            -i|--install)
                _install=true
            ;;
            -u|--update)
                _update=true
            ;;
            -d|--debug)
                _debug=true
            ;;
            -h|--help)
                _print_usage=true
            ;;
            *)
                _mm_error "unknown option: ${arg}"
                _print_usage=true
            ;;
        esac
    done
fi

if [[ ${_print_usage} = true ]]; then
    _mm_print_usage
    exit 1
fi

_mm_main "${_install}"
