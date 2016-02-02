AUTOMAKE_OPTIONS = foreign subdir-objects
ACLOCAL_AMFLAGS = -I build
EXTRA_DIST =

AM_CFLAGS  =
AM_CFLAGS += -Wall
AM_CFLAGS += -Wextra
AM_CFLAGS += -g
AM_CFLAGS += -Wno-sign-compare

CORE_SRC  =
CORE_SRC += src/fping.h src/fping.c
CORE_SRC += src/options.h
CORE_SRC += src/seqmap.h src/seqmap.c
CORE_SRC += src/socket.c

sbin_PROGRAMS =
dist_man_MANS =

EXTRA_DIST += man

if IPV4
sbin_PROGRAMS      += fping
dist_man_MANS      += man/fping.8
fping_DEPENDENCIES  = config.h
fping_SOURCES       = $(CORE_SRC) src/socket4.c
endif

if IPV6
sbin_PROGRAMS       += fping6
dist_man_MANS       += man/fping6.8
fping6_CFLAGS        = $(AM_CFLAGS) -DIPV6
fping6_DEPENDENCIES  = config.h
fping6_SOURCES       = $(CORE_SRC) src/socket6.c
endif

man/%.8: man/@PACKAGE@.pod
	pod2man -c "" -s 8 -n $* -r "@PACKAGE_STRING@" $< $@

FPING_TESTS  =
FPING_TESTS += t/01-basics
FPING_TESTS += t/02-help
FPING_TESTS += t/03-forbidden
FPING_TESTS += t/04-options-a-b
FPING_TESTS += t/05-options-c-e
FPING_TESTS += t/06-options-f-h
FPING_TESTS += t/07-options-i-m
FPING_TESTS += t/08-options-n-q
FPING_TESTS += t/09-option-r-t
FPING_TESTS += t/10-option-u-v
FPING_TESTS += t/11-nopriv
FPING_TESTS += t/12-option-type
FPING_TESTS += t/13-unknown-host
FPING_TESTS += t/14-ping-internet-hosts
FPING_TESTS += t/issue-56
FPING_TESTS += t/issue-58

TESTS = $(FPING_TESTS)

test: check
