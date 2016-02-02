#!/usr/bin/perl

package t::common;

use strict;
use warnings;

use Test::More;
use Test::Command;
use Cwd;

my $pwd = cwd;
use base 'Exporter';
our $FPING  = "$pwd/fping";
our $FPING6 = "$pwd/fping6";
our @EXPORT = qw($FPING $FPING6);
