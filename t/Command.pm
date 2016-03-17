package t::Command;

use warnings;
use strict;

use Carp qw/ confess /;
use File::Temp qw/ tempfile /;

use base 'Test::Builder::Module';

sub new
{
	my ($class, @args) = @_;
	my $self = bless { @args }, $class;
	print STDERR "Built instance\n";
	return $self;
}

sub run
{
	my ($self) = @_;

	my $run_info = _run_cmd( $self->{'cmd'} );
	print STDERR "running command: $self->{cmd}\n";


	$self->{'result'}{'exit_status'} = $run_info->{'exit_status'};
	$self->{'result'}{'term_signal'} = $run_info->{'term_signal'};
	$self->{'result'}{'stdout_file'} = $run_info->{'stdout_file'};
	$self->{'result'}{'stderr_file'} = $run_info->{'stderr_file'};

	return $self;
}

sub _slurp
{
	my ($file_name) = @_;
	defined $file_name or confess '$file_name is undefined';
	open my $fh, '<', $file_name or confess "$file_name: $!";
	my $text = do { local $/ = undef; <$fh> };
	close $fh or confess "failed to close $file_name: $!";
	return $text;
}

sub _diff_column
{
	my ($line_1, $line_2) = @_;

	my $diff_column;

	my $defined_args = grep defined($_), $line_1, $line_2;

	if (1 == $defined_args) {
		$diff_column = 1;
	} elsif (2 == $defined_args) {
		my $max_length =
			( sort { $b <=> $a } map length($_),  $line_1, $line_2 )[0];

		for my $position (1 .. $max_length) {
			my $char_line_1 = substr $line_1, $position - 1, 1;
			my $char_line_2 = substr $line_2, $position - 1, 1;

			if ($char_line_1 ne $char_line_2) {
				$diff_column = $position;
				last;
			}
		}
	}

	return $diff_column;
}

sub _compare_files
{
   my ($got_file, $exp_file) = @_;

   defined $got_file or confess '$got_file is undefined';
   defined $exp_file or confess '$exp_file is undefined';

   open my $got_fh, '<', $got_file or confess "$got_file: $!";
   open my $exp_fh, '<', $exp_file or confess "$exp_file: $!";

   my $ok = 1;
   my $diff_line;
   my $diff_column;
   my $got_line;
   my $exp_line;
   my $col_mark;

   CHECK_LINE:
      {
      $got_line = <$got_fh>;
      $exp_line = <$exp_fh>;

      last CHECK_LINE if ! defined $got_line &&
                         ! defined $exp_line;

      $diff_line++;

      $ok = defined $got_line &&
            defined $exp_line &&
            $got_line eq $exp_line;

      if (! $ok)
         {
         $diff_column = _diff_column($got_line, $exp_line);
         $col_mark  = ' ' x ( $diff_column - 1 );
         $col_mark .= '^';
         last CHECK_LINE;
         }

      redo CHECK_LINE;

      };

   close $got_fh or confess "failed to close 'got' handle: $!";
   close $exp_fh or confess "failed to close 'exp' handle: $!";

   return $ok, $diff_line, $got_line, $exp_line, $col_mark;
   }

sub _build_name
   {
   my ($name, $cmd, @args) = @_;

   if (defined $name)
      {
      return $name;
      }

   defined $cmd or confess '$cmd is undefined';

   if ( ref $cmd && UNIVERSAL::isa($cmd, 't::Command') ) 
      {
      $cmd = $cmd->{'cmd'};
      }

   if (ref $cmd eq 'ARRAY')
      {
      $cmd = join ' ', @{ $cmd };
      }

   ## remove any leading package information from the subroutine name
   (my $test_sub = (caller 1)[3]) =~ s/.*:://;
   return "$test_sub: " . join ', ', $cmd, @args;
   }

sub _get_result
{
	my ($cmd) = @_;
	defined $cmd or confess '$cmd is undefined';
	if (ref $cmd && UNIVERSAL::isa($cmd, 't::Command')) {
		## run the command if needed
		if (!$cmd->{'result'}) {
			$cmd->run;
		}
		return $cmd->{'result'};
	} else {
		return _run_cmd(@_);
	}
}

sub _run_cmd
   {
   my ($cmd) = @_;

   ## do as much as we can before redirecting STDOUT and STDERR, we want
   ## to avoid getting our peanut butter in their chocolate

   defined $cmd or confess '$cmd is undefined';

   if ( ! ref $cmd )
      {
      $cmd = [ $cmd ];
      }

   ## save copies of STDOUT and STDERR
   open my $saved_stdout, '>&STDOUT' or confess 'Cannot duplicate STDOUT';
   open my $saved_stderr, '>&STDERR' or confess 'Cannot duplicate STDERR';

   ## create tempfiles for capturing STDOUT and STDERR
   my ($temp_stdout_fh, $temp_stdout_file) = tempfile(UNLINK => 1);
   my ($temp_stderr_fh, $temp_stderr_file) = tempfile(UNLINK => 1);

   ## close and reopen STDOUT and STDERR to temp files
   close STDOUT or confess "failed to close STDOUT: $!";
   close STDERR or confess "failed to close STDERR: $!";
   open STDOUT, '>&' . fileno $temp_stdout_fh or confess 'Cannot duplicate temporary STDOUT';
   open STDERR, '>&' . fileno $temp_stderr_fh or confess 'Cannot duplicate temporary STDERR';

   ## run the command
   system(@{ $cmd });
   
   my $system_return = defined ${^CHILD_ERROR_NATIVE} ? ${^CHILD_ERROR_NATIVE} : $?; 
   
   my $exit_status;
   my $term_signal;

   my $wait_status = $system_return & 127;
   if ($wait_status)
      {
      $exit_status = undef;
      $term_signal = $wait_status;
      }
   else
      {
      $exit_status = $system_return >> 8;
      $term_signal = undef;
      }

   ## close and restore STDOUT and STDERR to original handles
   close STDOUT or confess "failed to close STDOUT: $!";
   close STDERR or confess "failed to close STDERR: $!";
   open STDOUT, '>&' . fileno $saved_stdout or confess 'Cannot restore STDOUT';
   open STDERR, '>&' . fileno $saved_stderr or confess 'Cannot restore STDERR';

   return { exit_status => $exit_status,
            term_signal => $term_signal,
            stdout_file => $temp_stdout_file,
            stderr_file => $temp_stderr_file };

   }

sub exit_value
{
	my ($cmd) = @_;
	my $result = _get_result($cmd);
	return $result->{'exit_status'};
}

sub exit_is_num
{
	my ($cmd, $exp, $name) = @_;
	my $result = _get_result($cmd);
	$name = _build_name($name, @_);
	return __PACKAGE__->builder->is_num($result->{'exit_status'}, $exp, $name);
}

sub exit_isnt_num
{
	my ($cmd, $not_exp, $name) = @_;
	my $result = _get_result($cmd);
	$name = _build_name($name, @_);
	return __PACKAGE__->builder->isnt_num($result->{'exit_status'}, $not_exp, $name);
}

sub exit_cmp_ok
{
	my ($cmd, $op, $exp, $name) = @_;
	my $result = _get_result($cmd);
	$name = _build_name($name, @_);
	return __PACKAGE__->builder->cmp_ok($result->{'exit_status'}, $op, $exp, $name);
}

sub exit_is_defined
{
	my ($cmd, $op, $exp, $name) = @_;
	my $result = _get_result($cmd);
	$name = _build_name($name, @_);
	return __PACKAGE__->builder->ok(defined $result->{'exit_status'}, $name);
}

sub exit_is_undef
{
	my ($cmd, $op, $exp, $name) = @_;
	my $result = _get_result($cmd);
	$name = _build_name($name, @_);
	return __PACKAGE__->builder->ok(! defined $result->{'exit_status'}, $name);
}

=head2 Testing Terminating Signal

The test routines below compare against the lower 8 bits of the exit status
of the executed command.

=head3 signal_value

   signal_value($cmd)

Return the signal code of the command. Useful for performing arbitrary tests
not covered by this module.

=cut

sub signal_value
   {
   my ($cmd) = @_;

   my $result = _get_result($cmd);
   
   return $result->{'term_signal'};
   }

=head3 signal_is_num

   signal_is_num($cmd, $exp_num, $name)

If the terminating signal of the command is numerically equal to the expected number,
this passes. Otherwise it fails.

=cut

sub signal_is_num
   {
   my ($cmd, $exp, $name) = @_;

   my $result = _get_result($cmd);
   
   $name = _build_name($name, @_);

   return __PACKAGE__->builder->is_num($result->{'term_signal'}, $exp, $name);
   }

=head3 signal_isnt_num

   signal_isnt_num($cmd, $unexp_num, $name)

If the terminating signal of the command is B<not> numerically equal to the given
number, this passes. Otherwise it fails.

=cut

sub signal_isnt_num
   {
   my ($cmd, $not_exp, $name) = @_;

   my $result = _get_result($cmd);

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->isnt_num($result->{'term_signal'}, $not_exp, $name);
   }

=head3 signal_cmp_ok

   signal_cmp_ok($cmd, $op, $operand, $name)

If the terminating signal of the command is compared with the given operand
using the given operator, and that operation returns true, this passes. Otherwise
it fails.

=cut

sub signal_cmp_ok
   {
   my ($cmd, $op, $exp, $name) = @_;

   my $result = _get_result($cmd);

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->cmp_ok($result->{'term_signal'}, $op, $exp, $name);
   }

=head3 signal_is_defined

   signal_is_defined($cmd, $name)

If the terminating signal of the command is defined, this passes. Otherwise it
fails. A defined signal indicates that the command likely exited due to a
signal.

=cut

sub signal_is_defined
   {
   my ($cmd, $op, $exp, $name) = @_;

   my $result = _get_result($cmd);

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->ok(defined $result->{'term_signal'}, $name);
   }

=head3 signal_is_undef

   signal_is_undef($cmd, $name)

If the terminating signal of the command is not defined, this passes.
Otherwise it fails. An undefined signal indicates that the command exited
normally by calling exit() or running off the end of the program.

=cut

sub signal_is_undef
   {
   my ($cmd, $name) = @_;

   my $result = _get_result($cmd);

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->ok(! defined $result->{'term_signal'}, $name);
   }

=head2 Testing STDOUT

Except where specified, the test routines below treat STDOUT as a single slurped
string.

=head3 stdout_value

   stdout_value($cmd)

Return the STDOUT of the command. Useful for performing arbitrary tests
not covered by this module.

=cut

sub stdout_value
   {
   my ($cmd) = @_;

   my $result      = _get_result($cmd);
   my $stdout_text = _slurp($result->{'stdout_file'});
   
   return $stdout_text;
   }

=head3 stdout_file

   stdout_file($cmd)

Return the file name containing the STDOUT of the command. Useful for
performing arbitrary tests not covered by this module.

=cut

sub stdout_file
   {
   my ($cmd) = @_;

   my $result = _get_result($cmd);

   return $result->{'stdout_file'};
   }

=head3 stdout_is_eq

   stdout_is_eq($cmd, $exp_string, $name)

If the STDOUT of the command is equal (compared using C<eq>) to the expected
string, then this passes. Otherwise it fails.

=cut

sub stdout_is_eq
   {
   my ($cmd, $exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stdout_text = _slurp($result->{'stdout_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->is_eq($stdout_text, $exp, $name);
   }

=head3 stdout_isnt_eq

   stdout_isnt_eq($cmd, $unexp_string, $name)

If the STDOUT of the command is B<not> equal (compared using C<eq>) to the
given string, this passes. Otherwise it fails.

=cut

sub stdout_isnt_eq
   {
   my ($cmd, $not_exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stdout_text = _slurp($result->{'stdout_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->isnt_eq($stdout_text, $not_exp, $name);
   }

=head3 stdout_is_num

   stdout_is_num($cmd, $exp_num, $name)

If the STDOUT of the command is equal (compared using C<==>) to the expected
number, then this passes. Otherwise it fails.

=cut

sub stdout_is_num
   {
   my ($cmd, $exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stdout_text = _slurp($result->{'stdout_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->is_num($stdout_text, $exp, $name);
   }

=head3 stdout_isnt_num

   stdout_isnt_num($cmd, $unexp_num, $name)

If the STDOUT of the command is B<not> equal (compared using C<==>) to the
given number, this passes. Otherwise it fails.

=cut

sub stdout_isnt_num
   {
   my ($cmd, $not_exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stdout_text = _slurp($result->{'stdout_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->isnt_num($stdout_text, $not_exp, $name);
   }

=head3 stdout_like

   stdout_like($cmd, $exp_regex, $name)

If the STDOUT of the command matches the expected regular expression,
this passes. Otherwise it fails.

=cut

sub stdout_like
   {
   my ($cmd, $exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stdout_text = _slurp($result->{'stdout_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->like($stdout_text, $exp, $name);
   }

=head3 stdout_unlike

   stdout_unlike($cmd, $unexp_regex, $name)

If the STDOUT of the command does B<not> match the given regular
expression, this passes. Otherwise it fails.

=cut

sub stdout_unlike
   {
   my ($cmd, $exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stdout_text = _slurp($result->{'stdout_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->unlike($stdout_text, $exp, $name);
   }

=head3 stdout_cmp_ok

   stdout_cmp_ok($cmd, $op, $operand, $name)

If the STDOUT of the command is compared with the given operand using
the given operator, and that operation returns true, this passes. Otherwise
it fails.

=cut

sub stdout_cmp_ok
   {
   my ($cmd, $op, $exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stdout_text = _slurp($result->{'stdout_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->cmp_ok($stdout_text, $op, $exp, $name);
   }

=head3 stdout_is_file

   stdout_is_file($cmd, $exp_file, $name)

If the STDOUT of the command is equal (compared using C<eq>) to the contents of
the given file, then this passes. Otherwise it fails. Note that this comparison
is performed line by line, rather than slurping the entire file.

=cut

sub stdout_is_file
   {
   my ($cmd, $exp_file, $name) = @_;

   my $result = _get_result($cmd);

   my ($ok, $diff_start, $got_line, $exp_line, $col_mark) =
      _compare_files($result->{'stdout_file'}, $exp_file);

   $name = _build_name($name, @_);

   my $is_ok = __PACKAGE__->builder->ok($ok, $name);

   if (! $is_ok)
      {
      chomp( $got_line, $exp_line );
      __PACKAGE__->builder->diag(<<EOD);
STDOUT differs from $exp_file starting at line $diff_start.
got: $got_line
exp: $exp_line
     $col_mark
EOD
      }

   return $is_ok;
   }

=head2 Testing STDERR

Except where specified, the test routines below treat STDERR as a single slurped
string.

=head3 stderr_value

   stderr_value($cmd)

Return the STDERR of the command. Useful for performing arbitrary tests
not covered by this module.

=cut

sub stderr_value
   {
   my ($cmd) = @_;

   my $result      = _get_result($cmd);
   my $stderr_text = _slurp($result->{'stderr_file'});
   
   return $stderr_text;
   }

=head3 stderr_file

   stderr_file($cmd)

Return the file name containing the STDERR of the command. Useful for
performing arbitrary tests not covered by this module.

=cut

sub stderr_file
   {
   my ($cmd) = @_;

   my $result = _get_result($cmd);

   return $result->{'stderr_file'};
   }

=head3 stderr_is_eq

   stderr_is_eq($cmd, $exp_string, $name)

If the STDERR of the command is equal (compared using C<eq>) to the expected
string, then this passes. Otherwise it fails.

=cut

sub stderr_is_eq
   {
   my ($cmd, $exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stderr_text = _slurp($result->{'stderr_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->is_eq($stderr_text, $exp, $name);
   }

=head3 stderr_isnt_eq

   stderr_isnt_eq($cmd, $unexp_string, $name)

If the STDERR of the command is B<not> equal (compared using C<eq>) to the
given string, this passes. Otherwise it fails.

=cut

sub stderr_isnt_eq
   {
   my ($cmd, $not_exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stderr_text = _slurp($result->{'stderr_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->isnt_eq($stderr_text, $not_exp, $name);
   }

sub stderr_is_num
   {
   my ($cmd, $exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stderr_text = _slurp($result->{'stderr_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->is_num($stderr_text, $exp, $name);
   }

sub stderr_isnt_num
   {
   my ($cmd, $not_exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stderr_text = _slurp($result->{'stderr_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->isnt_num($stderr_text, $not_exp, $name);
   }

sub stderr_like
   {
   my ($cmd, $exp, $name) = @_;

   my $result = _get_result($cmd);

   my $stderr_text = _slurp($result->{'stderr_file'});

   $name = _build_name($name, @_);

   return __PACKAGE__->builder->like($stderr_text, $exp, $name);
   }

sub stderr_unlike
{
	my ($cmd, $exp, $name) = @_;
	my $result = _get_result($cmd);
	my $stderr_text = _slurp($result->{'stderr_file'});
	$name = _build_name($name, @_);
	return __PACKAGE__->builder->unlike($stderr_text, $exp, $name);
}

sub stderr_cmp_ok
{
	my ($cmd, $op, $exp, $name) = @_;
	my $result = _get_result($cmd);
	my $stderr_text = _slurp($result->{'stderr_file'});
	$name = _build_name($name, @_);
	return __PACKAGE__->builder->cmp_ok($stderr_text, $op, $exp, $name);
}

sub stderr_is_file
{
	my ($cmd, $exp_file, $name) = @_;

	my $result = _get_result($cmd);
	my ($ok, $diff_start, $got_line, $exp_line, $col_mark) =
		_compare_files($result->{'stderr_file'}, $exp_file);

	$name = _build_name($name, @_);
	my $is_ok = __PACKAGE__->builder->ok($ok, $name);

	if (! $is_ok) {
		chomp($got_line, $exp_line);
		__PACKAGE__->builder->diag(<<EOD);
STDERR differs from $exp_file starting at line $diff_start.
got: $got_line
exp: $exp_line
     $col_mark
EOD
	}

	return $is_ok;
}

1;
