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
	pod2man -c "" -s 8 $< $@
