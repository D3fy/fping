dnl Process this file with autoconf to produce a configure script.

dnl Minimum Autoconf version required.
AC_PREREQ(2.63)
AC_INIT([fping], [3.13],,, [http://fping.org/])

AC_CONFIG_SRCDIR([src/fping.h])
AC_CONFIG_AUX_DIR([build])
AC_CONFIG_MACRO_DIR([build])
AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE([-Wall -Werror foreign subdir-objects])

dnl AC_CANONICAL_TARGET
dnl AM_MAINTAINER_MODE

dnl Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL

dnl make ipv4 and ipv6 options
AC_ARG_ENABLE([ipv4],
  [  --enable-ipv4    Build IPv4 capable fping],
  [case "${enableval}" in
   yes)	ipv4=true ;;
   no)	ipv4=false ;;
   *)	AC_MSG_ERROR([bad value ${enableval} for --enable-ipv4]) ;;
   esac],[ipv4=true])
  AM_CONDITIONAL([IPV4], [test x$ipv4 = xtrue])

AC_ARG_ENABLE([ipv6],
  [  --enable-ipv6    Build IPv6 capable fping6],
  [case "${enableval}" in
   yes)	ipv6=true ;;
   no)	ipv6=false ;;
   *)	AC_MSG_ERROR([bad value ${enableval} for --enable-ipv6]) ;;
   esac],[ipv6=false])
  AM_CONDITIONAL([IPV6], [test x$ipv6 = xtrue])

if test x$ipv4 = xfalse && test x$ipv6 = xfalse; then
  AC_MSG_ERROR([You must enable at least one of IPv4 and IPv6.])
fi


dnl Checks for libraries.
AC_CHECK_FUNC(gethostbyname)
if test $ac_cv_func_gethostbyname = no; then
    AC_CHECK_LIB(nsl, gethostbyname)
fi
AC_CHECK_FUNC(connect)
if test $ac_cv_func_connect = no; then
    AC_CHECK_LIB(socket, connect)
fi


AH_TOP([
#ifndef CONFIG_H
#define CONFIG_H
])

AH_BOTTOM([
/* some OSes do not define this ... lets take a wild guess */

#ifndef INADDR_NONE
#  define INADDR_NONE 0xffffffffU
#endif

#endif /* CONFIG_H */
])


dnl Checks for header files.
AC_CHECK_HEADERS(unistd.h sys/file.h stdlib.h sys/select.h)

AC_CONFIG_FILES([Makefile contrib/fping.spec])
AC_OUTPUT
