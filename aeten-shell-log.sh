#!/bin/sh

__colorize() {
	local color=$1
	shift
	echo $(test $(tput colors 2>/dev/null) -ge 8 && printf "\033[${color}${*}\033[0;0m" || echo "${*}")
}

__tag() {
	printf "\r${OPEN_BRACKET}${1}${CLOSE_BRACKET}${RESTORE_CURSOR_POSITION}\n"
}

SAVE_CURSOR_POSITION='\033[s'
RESTORE_CURSOR_POSITION='\033[u'
MOVE_CURSOR_UP='\033[1A'
TITLE_COLOR='1;37m'
INFO=$(__colorize '1;37m' INFO)
WARN=$(__colorize '1;33m' WARN)
PASS=$(__colorize '1;32m' PASS)
FAIL=$(__colorize '1;31m' FAIL)
ERROR=${FAIL}
OPEN_BRACKET=$(__colorize '0;37m' '[ ')
CLOSE_BRACKET=$(__colorize '0;37m' ' ]')
EMPTY_TAG=$(printf "%4s")

__log() {
	local level
	level=${1}; shift
	printf "\r${OPEN_BRACKET}${level}${CLOSE_BRACKET} ${*}"
}

title() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	while test ${#} -ne 0; do
		case "${1}" in
			-*) args+=" ${1}"; shift;;
			*) break ;;
		esac
	done
	echo ${args} $(__colorize ${TITLE_COLOR} "${*}")
}

inform() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${INFO}" "${*}\n"
}

pass() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${PASS}" "${*}\n"
}

warn() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${WARN}" "${*}\n"
}

error() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${FAIL}" "${*}\n"
}

fatal() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${FAIL}" "${*}\n"
	exit 1
}

query() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	local out
	out=/proc/${$}/fd/1
	__log "${WARN}" "${*} " > ${out}
	printf ${SAVE_CURSOR_POSITION} > ${out}
	read REPLY
	[ -t 0 ] && printf "${MOVE_CURSOR_UP}" > ${out}
	__tag "${INFO}" > ${out}
	[ -t 0 ] && printf "${MOVE_CURSOR_UP}" > ${out}
	echo ${REPLY}
}

check() {
	local level
	local message
	local errno
	local output
	local usage
	usage="${FUNCNAME:-${0}} [--level|-l warn|error|fatal] [--errno|-e <errno>] [--message|-m <message>] [--] <command>"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			--message|-m) message=${2}; shift ;;
			--level|-l)   level=${2}; shift ;;
			--errno|-e)   errno=${2}; shift ;;
			--help|-h)    echo "${usage}"; exit 0 ;;
			--)           shift; break ;;
			-*)           echo "Usage: ${usage}" >&2; exit 1 ;;
			*)            break ;;
		esac
		shift
	done
	: ${level=fatal}
	: ${message=${*}}
	printf "${OPEN_BRACKET}${EMPTY_TAG}${CLOSE_BRACKET} ${message}${SAVE_CURSOR_POSITION}"
	output=$(eval ${*} 2>&1)
	if [ 0 -eq ${?} ]; then
		errno=0
	else
		errno=${errno:-${?}}
	fi
	[ 0 -eq "${errno}" ] && __tag "${PASS}" || case ${level} in
		warn) __tag "${WARN}" ;;
		error) __tag "${ERROR}"; echo "${*}"; echo "${output}"|sed '$,/^\s*$/d' ;;
		fatal) __tag "${FAIL}";  echo "${*}"; echo "${output}"|sed '$,/^\s*$/d'; exit ${errno} ;;
	esac
	return ${errno}
}

if [ -L ${0} ]; then
	$(basename ${0}) "${@}"
fi
