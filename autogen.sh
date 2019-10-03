#!/bin/bash
# Run this to generate all the initial makefiles, etc.

DIE=0
CLEANONLY=0
NOCONFIGURE=0
CONFIGURE_ARGS=()

for __AG_ARG__; do
	case "${__AG_ARG__}" in
		-h|--help)
			echo "Usage: ${0##*/} [OPTION]"
			echo
			echo 'Options:'	
			echo '    -h, --help          Show this help message'
			echo '    -m, --multiversion  Build a package able to coexist with other major'
			echo '                        versions of itself on the same machine - using this'
			echo '                        argument has the same effects as setting a'
			echo '                        $MULTIVERSION_PACKAGE environment variable to any'
			echo '                        non-empty value other than `no` before manually running'
			echo '                        automake on this package'
			echo '    -z, --noconfigure   Prepare the build system without launching the'
			echo '                        configure process'
			echo '        --clean         Removes all files generated by this script'
			echo
			echo 'If this script is invoked without the `--noconfigure` option all unrecognized'
			echo 'arguments will be passed to `configure`.'
			exit 0
			;;
		-m|--multiversion)
			export MULTIVERSION_PACKAGE=yes
			;;
		-z|--noconfigure)
			NOCONFIGURE=1
			;;
		--clean)
			CLEANONLY=1
			;;
		*)
			CONFIGURE_ARGS+=("${__AG_ARG__}")
			;;
	esac
done

if test "${CLEANONLY}" -ne 0; then
	echo 'Cleaning package...'
	test -f 'Makefile' && make maintainer-clean
	rm -Rf autom4te.cache m4 build-aux `find . -type d -name .deps`
	rm -f aclocal.m4 compile config.* configure depcomp install-sh libtool ltmain.sh missing `find . -name Makefile.in`
	echo 'Done'
	exit 0
fi

srcdir=`dirname ${0}`
test -z "${srcdir}" && srcdir=.

if [[ `test -z "${OSTYPE}" && uname -s || echo "${OSTYPE}"` =~ ^[Dd]arwin* ]]; then
	if test -z "${LIBTOOL}"; then
		echo 'macOS detected. Using glibtool.'
		LIBTOOL='glibtool'
	fi
	if test -z "${LIBTOOLIZE}"; then
		echo 'macOS detected. Using glibtoolize.'
		LIBTOOLIZE='glibtoolize'
	fi
else
	if test -z "${LIBTOOL}"; then
		LIBTOOL='libtool'
	fi
	if test -z "${LIBTOOLIZE}"; then
		LIBTOOLIZE='libtoolize'
	fi
fi

if test -n "${GNOME2_DIR}"; then
	ACLOCAL_FLAGS="-I ${GNOME2_DIR}/share/aclocal ${ACLOCAL_FLAGS}"
	LD_LIBRARY_PATH="${GNOME2_DIR}/lib:${LD_LIBRARY_PATH}"
	PATH="${GNOME2_DIR}/bin:${PATH}"
	export PATH
	export LD_LIBRARY_PATH
fi

(test -f "${srcdir}/configure.ac") || {
	echo
	echo "**Error**: Directory \`${srcdir}\` does not look like the top-level package directory"
	echo
	exit 1
}

(autoconf --version) < /dev/null > /dev/null 2>&1 || {
	echo
	echo '**Error**: You must have `autoconf` installed. Download the appropriate package'
	echo 'for your distribution, or get the source tarball at ftp://ftp.gnu.org/pub/gnu/'
	echo
	DIE=1
}

(grep "^IT_PROG_INTLTOOL" "${srcdir}/configure.ac" >/dev/null) && {
	(intltoolize --version) < /dev/null > /dev/null 2>&1 || {
		echo
		echo '**Error**: You must have `intltool` installed. You can get it from'
		echo 'ftp://ftp.gnome.org/pub/GNOME/'
		echo
		DIE=1
	}
}

(grep "^AM_PROG_XML_I18N_TOOLS" "${srcdir}/configure.ac" >/dev/null) && {
	(xml-i18n-toolize --version) < /dev/null > /dev/null 2>&1 || {
		echo
		echo '**Error**: You must have `xml-i18n-toolize` installed. You can get it from'
		echo 'ftp://ftp.gnome.org/pub/GNOME/'
		echo
		DIE=1
	}
}

(grep "^LT_INIT" "${srcdir}/configure.ac" >/dev/null) && {
	("${LIBTOOL}" --version) < /dev/null > /dev/null 2>&1 || {
		echo
		echo '**Error**: You must have `libtool` installed. You can get it from'
		echo 'ftp://ftp.gnu.org/pub/gnu/'
		echo
		DIE=1
	}
}

(grep "^AM_GLIB_GNU_GETTEXT" "${srcdir}/configure.ac" >/dev/null) && {
	(grep "sed.*POTFILES" "${srcdir}/configure.ac") > /dev/null || \
	(glib-gettextize --version) < /dev/null > /dev/null 2>&1 || {
		echo
		echo '**Error**: You must have `glib` installed. You can get it from'
		echo 'ftp://ftp.gtk.org/pub/gtk'
		echo
		DIE=1
	}
}

(automake --version) < /dev/null > /dev/null 2>&1 || {
	echo
	echo '**Error**: You must have `automake` installed. You can get it from'
	echo 'ftp://ftp.gnu.org/pub/gnu/'
	echo
	DIE=1
	NO_AUTOMAKE=yes
}


# if no automake, don't bother testing for aclocal
test -n "${NO_AUTOMAKE}" || (aclocal --version) < /dev/null > /dev/null 2>&1 || {
	echo
	echo '**Error**: Missing `aclocal`. The version of `automake` installed doesn'\''t appear'
	echo 'recent enough. You can get automake from ftp://ftp.gnu.org/pub/gnu/'
	echo
	DIE=1
}

if test "${DIE}" -ne 0; then
	exit 1
fi

echo

if test "${NOCONFIGURE}" -eq 0; then
	echo 'I am going to prepare the build system and then run the `configure` script. If'
	echo 'you wish differently, please specify the `--noconfigure` argument on the'
	echo "\`${0##*/}\` command line."
	echo
	if test -z "$*"; then
		echo '**Warning**: I am going to run `configure` with no arguments. If you wish to'
		echo "pass any, please specify them on the \`${0##*/}\` command line."
		echo
	fi
else
	echo 'I am going to prepare the build system without running the `configure` script.'
	echo
	if test ${#CONFIGURE_ARGS[@]} -gt 0; then
		echo '**Warning**: The following arguments will be ignored:'
		for __IDX__ in ${!CONFIGURE_ARGS[@]}; do
			echo " $((__IDX__ + 1)). \`${CONFIGURE_ARGS[$__IDX__]}\`"
		done
		echo
	fi
fi

echo 'Preparing the build system... please wait'

case "${CC}" in
	xlc )
		am_opt=--include-deps
		;;
esac

for coin in `find "${srcdir}" -path "${srcdir}/CVS" -prune -o -name configure.ac -print`; do
	dr=`dirname "${coin}"`
	if test -f "${dr}/NO-AUTO-GEN"; then
		echo "skipping ${dr} -- flagged as no auto-gen"
	else
		echo "Processing '${dr}' ..."
		( cd "${dr}"

			aclocalinclude="${ACLOCAL_FLAGS}"
			[[ -d 'm4' ]] || mkdir 'm4'

			if grep "^AM_GLIB_GNU_GETTEXT" configure.ac >/dev/null; then
				echo "Creating ${dr}/aclocal.m4..."
				test -r "${dr}/aclocal.m4" || touch "${dr}/aclocal.m4"
				echo 'Running glib-gettextize...  Ignore non-fatal messages.'
				echo 'no' | glib-gettextize --force --copy
				echo "Making ${dr}/aclocal.m4 writable..."
				test -r "${dr}/aclocal.m4" && chmod u+w "${dr}/aclocal.m4"
			fi
			if grep "^IT_PROG_INTLTOOL" configure.ac >/dev/null; then
				echo 'Running intltoolize...'
				intltoolize --copy --force --automake
			fi
			if grep "^AM_PROG_XML_I18N_TOOLS" configure.ac >/dev/null; then
				echo 'Running xml-i18n-toolize...'
				xml-i18n-toolize --copy --force --automake
			fi
			if grep "^LT_INIT" configure.ac >/dev/null; then
				if test -z "${NO_LIBTOOLIZE}" ; then
					echo 'Running libtoolize...'
					"${LIBTOOLIZE}" --force --copy
				fi
			fi
			echo "Running aclocal ${aclocalinclude} ..."
			aclocal ${aclocalinclude}
			if grep "^A[CM]_CONFIG_HEADER" configure.ac >/dev/null; then
				echo 'Running autoheader...'
				autoheader
			fi
			echo "Running automake --gnu ${am_opt} ..."
			automake --add-missing --copy --gnu ${am_opt}
			echo 'Running autoconf...'
			autoconf
		)
	fi
done

if test "${NOCONFIGURE}" -eq 0; then
	echo -n "Running ${srcdir}/configure"
	for __CF_ARG__ in "${CONFIGURE_ARGS[@]}"; do
		echo -n " [${__CF_ARG__}]"
	done
	echo ' ...'
	if "${srcdir}/configure" "${CONFIGURE_ARGS[@]}"; then
		echo "Now type \`make\` to compile, or type \`${0} --clean\` to delete all the"
		echo 'files generated by this script'
	else
		exit 1
	fi
else
	echo 'Skipping configure process. Type `configure --help` to list the configure'
	echo "options, or type \`${0} --clean\` to delete all the files generated by"
	echo 'this script'
fi

# EOF

