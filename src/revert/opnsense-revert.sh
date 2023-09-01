#!/bin/sh

# Copyright (c) 2016-2023 Franco Fichtner <franco@veritawall.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

set -e

if [ "$(id -u)" != "0" ]; then
	echo "Must be root." >&2
	exit 1
fi

WORKPREFIX="/tmp/veritawall-revert"
WORKDIR=${WORKPREFIX}/${$}
PKG="pkg-static"

DO_INSECURE=
DO_LOCKKEEP=
DO_RELEASE=

while getopts ilr:z OPT; do
	case ${OPT} in
	i)
		DO_INSECURE="-i"
		;;
	l)
		LOCKKEEP="-l"
		;;
	r)
		DO_RELEASE="-r ${OPTARG}"
		;;
	z)
		DO_RELEASE="-z"
		;;
	*)
		echo "Usage: man ${0##*/}" >&2
		exit 1
		;;
	esac
done

shift $((OPTIND - 1))

for PACKAGE in ${@}; do
	if ! ${PKG} query %n ${PACKAGE} > /dev/null; then
		echo "Package '${PACKAGE}' is not installed" >&2
		exit 1
	fi
done

export ASSUME_ALWAYS_YES=yes

MIRROR="$(veritawall-update -M)/MINT/${DO_RELEASE#-r }/latest/Latest"
COREPKG=$(veritawall-version -n 2> /dev/null || true)
COREDEP=

if [ "${DO_RELEASE}" = "-z" ]; then
	MIRROR="$(veritawall-update -Mz)/latest/Latest"
fi

if [ -n "${COREPKG}" ]; then
	COREDEP=$(echo ${COREPKG}; ${PKG} query %dn ${COREPKG})
fi

fetch()
{
	STAGE1="veritawall-fetch -a -w 1 -T 30 -q -o ${WORKDIR}/${1}.sig ${MIRROR}/${1}.sig"
	STAGE2="veritawall-fetch -a -w 1 -T 30 -q -o ${WORKDIR}/${1} ${MIRROR}/${1}"
	STAGE3="veritawall-verify ${WORKDIR}/${1}"

	if [ -n "${DO_INSECURE}" ]; then
		# no signature, no cry
		STAGE1=":"
		STAGE3=":"
	fi

	echo -n "Fetching ${1}: ."

	mkdir -p ${WORKDIR} && ${STAGE1} && ${STAGE2} && \
	    echo " done" && ${STAGE3} && return

	echo " failed"
	exit 1
}

for PACKAGE in ${@}; do
	if [ -z "${DO_RELEASE}" ]; then
		${PKG} fetch ${PACKAGE}
	else
		fetch ${PACKAGE}.pkg
	fi
done

for PACKAGE in ${@}; do
	# reset automatic, vital as per package metadata
	AUTOMATIC="1"

	if [ -n "${COREPKG}" -a "$(echo "${COREDEP}" | grep -c ${PACKAGE})" != "0" ]; then
		if [ "${COREPKG}" = ${PACKAGE} -o "pkg" = ${PACKAGE}  ]; then
			AUTOMATIC="0"
		fi
	elif [ "$(${PKG} query %a ${PACKAGE})" = "0" ]; then
		AUTOMATIC="0"
	fi

	if [ -z "${DO_LOCKKEEP}" ]; then
		# ignore active locks and do not let them persist
		${PKG} unlock ${PACKAGE}
	fi

	if [ -z "${DO_RELEASE}" ]; then
		${PKG} install -f ${PACKAGE}
	else
		${PKG} install -f ${WORKDIR}/${PACKAGE}.pkg
	fi

	${PKG} set -A ${AUTOMATIC} ${PACKAGE}
done

rm -rf ${WORKPREFIX}/*
