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
LAUNCH_DAEMON_NAME="com.github.aremmell.macMOTD.plist"
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
    [[ ${_debug} = true ]] && _mm_echo "debug" "90" "$*"
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

_mm_prepare_update_motd_d_dest() {
    if [[ ! -d "${UPDATE_MOTD_D_DEST}" ]] && \
       ! mkdir -p "${UPDATE_MOTD_D_DEST}" >/dev/null 2>&1; then
        _mm_error "failed to create ${UPDATE_MOTD_D_DEST}!"
        false; return
    fi
}

# Makes executable, then copies all .zsh files from one directory to another.
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

    _mm_debug "making scripts in ${1} executable..."
    if ! chmod 744 "${1}/"*.zsh >/dev/null 2>&1; then
        _mm_error "failed to set permissions on one or more scripts in ${1}!"
        false; return
    fi

    local scripts_copied=0
    _mm_debug "copying scripts from ${1} to ${2}..."
    for f in ${1}/*.zsh(*); do
        _mm_debug "copying ${f} to ${2}..."
        if ! cp -f "${f}" "${2}" >/dev/null 2>&1; then
            _mm_error "failed to copy ${f} to ${2}!"
            false; return
        fi
        (( scripts_copied++ ))
    done

    if [[ ${scripts_copied} -gt 0 ]]; then
        _mm_info "successfully copied ${scripts_copied} scripts to ${2}."
    else
        _mm_error "no viable scripts (executable with .zsh extension) located in ${1}!"
        false; return
    fi
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
        _mm_debug "copying scripts from ${UPDATE_MOTD_D} to ${UPDATE_MOTD_D_DEST}..."
        if ! _mm_deploy_scripts "${UPDATE_MOTD_D}" "${UPDATE_MOTD_D_DEST}"; then
            false; return
        fi

        _mm_debug "copying scripts from ${MOTD_HELPERS} to ${MOTD_HELPERS_DEST}..."
        if ! _mm_deploy_scripts "${MOTD_HELPERS}" "${MOTD_HELPERS_DEST}"; then
            false; return
        fi

        _mm_debug "copying ${SCRIPT_NAME} to ${SYSTEM_BIN_DIR}..."
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
            <string>${SYSTEM_BIN_DIR}/motd.zsh</string>
            <string>--generate</string>
        </array>
        <key>StartInterval</key>
        <integer>${MOTD_REGEN_FREQUENCY}</integer>
        <key>RunAtLoad</key>
        <true />
        <key>StandardErrorPath</key>
        <string>${MOTD_LOG_FILE}</string>
        <key>StandardOutPath</key>
        <string>${MOTD_LOG_FILE}</string>
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

        _mm_debug "writing launch daemon file (log: '${MOTD_LOG_FILE}', frequency:" \
                  "${MOTD_REGEN_FREQUENCY}sec)..."
        if ! echo "${_ld_file_contents}" >! "${ld_filename}"; then
            _mm_error "failed to write launch daemon file (${ld_filename})!"
            false; return
        fi

        _mm_debug "successfully wrote launch daemon file (${ld_filename})."

        if ! launchctl load "${ld_filename}"; then
            _mm_error "failed to load launch daemon (${ld_filename})!"
            false; return
        fi

        _mm_info "successfully loaded launch daemon; run 'TODO'."
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

# $1: The CLI option that requires an argument.
# $2: The expected argument.
# $3: The current option/argument index.
# $4: The total count of CLI arguments.
_mm_validate_cli_arg() {
    if [[ ${3} -gt ${4} ]] || [[ -z "${2}" ]]; then
        _mm_error "required argument for '${1}' not found."
        _print_usage=true
        false; return
    fi
}

_mm_print_usage() {
    read -r -d '' usage_message <<-EOF
Usage:
    -i, --install          Installs and enables macMOTD on this machine, then generates the MOTD (implies -g/--generate)
    -g, --generate         Generates the MOTD file by executing the scripts in ${UPDATE_MOTD_D_DEST}.
    -l, --log       <path> Overrides the default log file path (${MOTD_LOG_FILE}).
    -f, --frequency <secs> Overrides the default MOTD regeneration frequency (${MOTD_REGEN_FREQUENCY}sec).
    -d, --debug            Enables debug mode, which produces more detailed output.
    -h, --help             Prints this help message.
EOF
    echo "${usage_message}"
    exit 1
}

_mm_main() {
    if [[ ${_install} = true ]]; then
        _mm_update_motd true
    elif [[ ${_generate} = true ]]; then
        _mm_update_motd false
    else
        _mm_error "no command to execute (-i/--install or -g/--generate required)!"
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

_argv=("$@")
_generate=false
_install=false
_debug=false

_argc="${#_argv[@]}"
[[ ${_argc} -gt 0 ]] || _mm_print_usage

for (( i=0;i<=${_argc};i++ )); do
    [[ -z "${_argv[i]}" ]] && continue
    _mm_debug "evaluating option: '${_argv[i]}'..."
    case ${_argv[i]} in
        -i|--install)
            _install=true
        ;;
        -g|--generate)
            _generate=true
        ;;
        -d|--debug)
            _debug=true
            _mm_debug "debug mode enabled."
        ;;
        -l|--log)
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
        -f|--frequency)
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
        -h|--help)
            _mm_print_usage
        ;;
        *)
            _mm_error "unknown option: ${arg}"
            _mm_print_usage
        ;;
    esac
done

_mm_main
