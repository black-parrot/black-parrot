
# source-only guard
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && return
# include guard
[ -n "${_COMMON_SH_INCLUDE}" ] && return

# enable automatic export
set -o allexport

# enable unofficial bash strict mode
set -eo pipefail
IFS=$'\n\t'

######################
# global variables
######################

# constants
readonly _COMMON_SH_INCLUDE=1

readonly _BSG_HDR_RAW="         "
readonly _BSG_HDR_ERR="[BSG-ERR]"
readonly _BSG_HDR_WRN="[BSG-WRN]"
readonly _BSG_HDR_INF="[BSG    ]"
readonly _BSG_HDR_DBG="[BSG-DBG]"

readonly _BSG_HDR_PASS="[BSG-PASS]"
readonly _BSG_HDR_FAIL="[BSG-FAIL]"

readonly _BSG_E_LOG_LEVEL_MIN=-99
readonly _BSG_E_LOG_LEVEL_ERR=0
readonly _BSG_E_LOG_LEVEL_WRN=1
readonly _BSG_E_LOG_LEVEL_INF=2
readonly _BSG_E_LOG_LEVEL_DBG=3
readonly _BSG_E_LOG_LEVEL_MAX=99

# defaults
_BSG_LOG_LEVEL=-1
_BSG_LOG_INIT=0
_BSG_MONITOR_LINES=5
_BSG_MONITOR_WAIT=5
_BSG_LOG_FILE=/dev/null
_BSG_RPT_FILE=/dev/null
_BSG_OUT_FILE=/dev/null

######################
# helper variables
######################
bsg_top=$(git rev-parse --show-toplevel)
bsg_ci=${bsg_top}/ci
bsg_wrap=$(basename $0)
bsg_script=$(basename $1 2> /dev/null || true)

######################
# helper functions
######################
# desc: non-fancy argparser this will set _arg1="val1", _arg2="val2", etc.
# usage: _bsg_check_args N arg1 arg2 ... $@
# caveats: no optional arguments or nested functions
_bsg_parse_args() {
    local N="$1"
    local vars=("${@:2:$(($N))}")
    local vals=("${@:$(($N+2)):$((2*$N+2))}")

    if [[ "${#vals[@]}" -ne $N ]]; then
        local call="${FUNCNAME[1]}"
        printf "usage: ${call} ${vars[*]}\n"
        return 1
    fi

    for i in "${!vars[@]}"; do
        eval _${vars[i]}=\"${vals[i]}\"
    done
}

# desc: print formatter with level comparison
# usage: _bsg_log_level msg level
_bsg_log_level() {
    local _msg="$1"
    local _level="$2"

    if [ ${_BSG_LOG_INIT} -ne 1 ]; then
        printf "WARNING: logging not initialized...\n"
    fi

    if [ ${_BSG_LOG_LEVEL} -ge "${_level}" ]; then
        _bsg_print_log "${_msg}\n"
    fi
}

# desc: set the logging level
# usage: _bsg_set_log_level level
_bsg_set_loglevel() {
    local _level="$1"
    printf "Setting logging level to: ${_level}\n"
    _BSG_LOG_LEVEL="${_level}"
}

# desc: initialize logging
# usage: _bsg_log_init logfile rptfile outfile loglevel
_bsg_log_init() {
    _bsg_parse_args 4 logfile rptfile outfile loglevel $@

    #_bsg_set_loglevel ${_loglevel}
    _BSG_LOG_LEVEL="${_loglevel}"

    printf "****************************************************************\n"
    printf "Initializing logging...\n"

	# Extract bases and extensions
    logext="${_logfile##*.}"
    logbase="${_logfile%.*}"
    rptext="${_rptfile##*.}"
    rptbase="${_rptfile%.*}"
    outext="${_outfile##*.}"
    outbase="${_outfile%.*}"

    # 1. Gather all existing files for all three types
    all_files=$(ls -1 "${logbase}"* "${rptbase}"* "${outbase}"* 2>/dev/null)

    # 2. Find the global maximum suffix across all of them
    if [ -z "$all_files" ]; then
        # No files exist yet
        next_num=""
    else
        # Extract numbers (e.g., from .3.log or .3), remove dots, sort, and grab the highest
        max_num=$(echo "$all_files" | grep -oE '\.[0-9]+(\.|$)' | tr -d '.' | sort -n | tail -n 1)
        
        if [ -z "$max_num" ]; then
            # Files exist (e.g., sim.log), but none have a numeric suffix yet
            next_num=1
        else
            # Synchronize all files to the global highest number + 1
            next_num=$((max_num + 1))
        fi
    fi

    # 3. Construct the synchronized filenames
    if [ -z "$next_num" ]; then
        _BSG_LOG_FILE="${logbase}.${logext}"
        _BSG_RPT_FILE="${rptbase}.${rptext}"
        _BSG_OUT_FILE="${outbase}.${outext}"
    else
        _BSG_LOG_FILE="${logbase}.${next_num}.${logext}"
        _BSG_RPT_FILE="${rptbase}.${next_num}.${rptext}"
        _BSG_OUT_FILE="${outbase}.${next_num}.${outext}"
    fi

    printf "\tlogfile: ${_BSG_LOG_FILE} with log level ${_BSG_LOG_LEVEL}\n"
    printf "\trptfile: ${_BSG_RPT_FILE}\n"
    printf "\toutfile: ${_BSG_OUT_FILE}\n"
    printf "****************************************************************\n"

    mkdir -p $(dirname ${_BSG_LOG_FILE}) $(dirname ${_BSG_RPT_FILE}) $(dirname ${_BSG_OUT_FILE})
    touch ${_BSG_LOG_FILE} ${_BSG_RPT_FILE} ${_BSG_OUT_FILE}

    _BSG_LOG_INIT=1
}

_bsg_print_log() {
    local _msg="$1"

    printf "${_msg}" | tee -a ${_BSG_LOG_FILE}
}

_bsg_print_out() {
    local _msg="$1"

    printf "${_msg}" >> ${_BSG_OUT_FILE}
}

_bsg_print_rpt() {
    local _msg="$1"

    printf "${_msg}" >> ${_BSG_RPT_FILE}
}

######################
# user functions
######################
bsg_log() {
    _bsg_parse_args 1 str "$@" || return 1

    _bsg_log_level "${_BSG_HDR_INF} ${_str}" ${_BSG_E_LOG_LEVEL_MIN}
}

bsg_log_raw() {
    _bsg_parse_args 1 str "$@" || return 1

    _bsg_log_level "${_BSG_HDR_RAW} ${_str}" ${_BSG_E_LOG_LEVEL_MIN}
}

bsg_log_error() {
    _bsg_parse_args 1 str "$@" || return 1

    _bsg_log_level "${_BSG_HDR_ERR} ${_str}" ${_BSG_E_LOG_LEVEL_ERR}
}

bsg_log_warn() {
    _bsg_parse_args 1 str "$@" || return 1

    _bsg_log_level "${_BSG_HDR_WRN} ${_str}" ${_BSG_E_LOG_LEVEL_WRN}
}

bsg_log_info() {
    _bsg_parse_args 1 str "$@" || return 1

    _bsg_log_level "${_BSG_HDR_INF} ${_str}" ${_BSG_E_LOG_LEVEL_INF}
}

bsg_log_debug() {
    _bsg_parse_args 1 str "$@" || return 1

    _bsg_log_level "${_BSG_HDR_DBG} ${_str}" ${_BSG_E_LOG_LEVEL_DBG}
}

_bsg_check_var() {
    _bsg_parse_args 1 var "$@" || return 1

    printf "\tChecking ${_var}... "
    if [ -z "${!_var}" ] || [ "${!_var}" == "setme" ]; then
        printf "UNSET!\n"
        return 1
    else
        printf "${!_var}\n"
    fi
}

# runs an arbitrary command with a CI wrapper
# usage: bsg_run_task name [--expect-pass] [--expect-fail] desc cmd <opts>
bsg_run_task() {
    _name="$1"; shift

    if [ "$1" = "--expect-pass" ]; then
        shift
    fi
    local _expect_fail=0
    if [ "$1" = "--expect-fail" ]; then
        _expect_fail=1
        shift
    fi
    # Intentional duplication to allow for reordering
    if [ "$1" = "--expect-pass" ]; then
        shift
    fi

    _desc="$1"; shift; _cmd=("$@")

    bsg_log_raw "###################################################"
    if [ ${_expect_fail} -eq 1 ]; then
        bsg_log_raw "running task '${_name}'... (expected failure)"
    else
        bsg_log_raw "running task '${_name}..."
    fi
    bsg_log_raw "description: ${_desc}"
    bsg_log_raw "command: ${_cmd[*]}"
    bsg_log_raw "###################################################"

    # execute command, piping output to file
    # print out first N lines of file, then wait for execution to finish
    "${_cmd[@]}" >> ${_BSG_OUT_FILE} 2>&1 &
    pid=$!

    while [ $(wc -l < ${_BSG_OUT_FILE}) -eq 0 ]; do
        if ! kill -0 ${pid} 2>/dev/null; then
            break
        fi
        sleep 0.1;
    done
    while : ; do
        tail -n ${_BSG_MONITOR_LINES} ${_BSG_OUT_FILE}
        bsg_log_raw "..."
        _timer=0
        _is_dead=0
        while [ ${_timer} -lt ${_BSG_MONITOR_WAIT} ]; do
            if ! kill -0 ${pid} 2>/dev/null; then
                _is_dead=1
                break
            fi
            sleep 0.1
            _timer=$((_timer + 1))
        done
        [ ${_is_dead} -eq 1 ] && break
    done
    wait ${pid}
    _exit_code=$?

    if [ ${_expect_fail} -eq 0 ] && [ ${_exit_code} -ne 0 ] ; then
        bsg_log_error "task returned non-zero (${_exit_code}), but expected success"
        exit ${_exit_code}
    else
        _bsg_print_rpt "${_name}: PASS\n"
        _bsg_print_out "\n"
    fi

    if [ ${_expect_fail} -eq 1 ] && [ ${_exit_code} -eq 0 ] ; then
        bsg_log_error "task returned zero: ${_exit_code}, but expected failure"
    else
        _bsg_print_rpt "${_name}: FAIL (expected)\n"
        _bsg_print_out "\n"
    fi
}

# fails if last bsg_run task printed the sentinel string
# usage: bsg_sentinel_fail "regex"
bsg_sentinel_fail() {
    _bsg_parse_args 1 regex "$@" || exit 1

    bsg_log_info "searching ${_BSG_OUT_FILE} (fail) for ${_regex}"
    grep -- "${_regex}" ${_BSG_OUT_FILE} &>/dev/null && bsg_fail $(basename $0)
}

# fails if last bsg_run task did not print the sentinel string
# usage: bsg_sentinel_cont "regex"
bsg_sentinel_cont() {
    _bsg_parse_args 1 regex "$@" || exit 1

    bsg_log_info "searching ${_BSG_OUT_FILE} (cont) for ${_regex}"
    grep -- "${_regex}" ${_BSG_OUT_FILE} &>/dev/null || bsg_fail $(basename $0)
}

# passes the current test
# usage: bsg_pass info
bsg_pass() {
    _bsg_parse_args 1 str "$@" || return 1

    _bsg_print_log "${_BSG_HDR_PASS} ${_str}\n"
    exit 0
}

# fails the current test
# usage: bsg_fail info
bsg_fail() {
    _bsg_parse_args 1 str "$@" || return 1

    _bsg_print_log "${_BSG_HDR_FAIL} ${_str}\n"
    exit 1
}

# disable automatic export
set +o allexport

