@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
IF EXIST "%~dp0perl.exe" (
"%~dp0perl.exe" -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
) ELSE IF EXIST "%~dp0..\..\bin\perl.exe" (
"%~dp0..\..\bin\perl.exe" -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
) ELSE (
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
)

goto endofperl
:WinNT
IF EXIST "%~dp0perl.exe" (
"%~dp0perl.exe" -x -S %0 %*
) ELSE IF EXIST "%~dp0..\..\bin\perl.exe" (
"%~dp0..\..\bin\perl.exe" -x -S %0 %*
) ELSE (
perl -x -S %0 %*
)

if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!/usr/bin/perl -w
#line 29
use strict;
use warnings;
use CPAN::Mini::App;
CPAN::Mini::App->run;

# PODNAME: minicpan
# ABSTRACT: uses CPAN::Mini to create or update a local mirror

__END__

=pod

=encoding UTF-8

=head1 NAME

minicpan - uses CPAN::Mini to create or update a local mirror

=head1 VERSION

version 1.111015

=head1 SYNOPSIS

 minicpan [options]

 Options
   -l LOCAL    - where is the local minicpan?     (required)
   -r REMOTE   - where is the remote cpan mirror? (required)
   -d 0###     - permissions (numeric) to use when creating directories
   -f          - check all directories, even if indices are unchanged
   -p          - mirror perl, ponie, and parrot distributions
   --debug     - run in debug mode (print even banal messages)
   -q          - run in quiet mode (don't print status)
   -qq         - run in silent mode (don't even print warnings)
   -c CLASS    - what class to use to mirror (default: CPAN::Mini)
   -C FILE     - what config file to use (default: ~/.minicpanrc)
   -h          - print help and exit
   -v          - print version and exit
   -x          - build an exact mirror, getting even normally disallowed files
   -t SEC      - timeout in sec. Defaults to 180 sec
   --offline   - operate in offline mode (generally: do nothing)
   --log-level - provide a log level; instead of --debug, -q, or -qq
   --remote-from TYPE - cpan remote from 'cpan' or 'cpanplus' configs

=head1 DESCRIPTION

This simple shell script just updates (or creates) a miniature CPAN mirror as
described in CPAN::Mini.

=head1 CONFIGURATION FILE

By default, C<minicpan> will read a configuration file to get configuration
information.  The file is a simple set of names and values, as in the following
example:

 local:  /home/rjbs/mirrors/minicpan/
 remote: http://your.favorite.cpan/cpan/
 exact_mirror: 1

C<minicpan> tries to find a configuration file through the following process.
It takes the first defined it finds:

=over 4

=item * Use the value specified by C<-C> on the command line

=item * Use the value in the C<CPAN_MINI_CONFIG> environment variable

=item * Use F<~/.minicpanrc>

=item * Use F<CPAN/Mini/minicpan.conf>

=back

If the selected file does not exist, C<minicpan> does not keep looking.

You can override this process with a C<config_file> method in your subclass.

See C<CPAN::Mini> for a full listing of available options.

=head1 TO DO

Improve command-line options.

=head1 SEE ALSO 

Randal Schwartz's original article, which can be found here:

  http://www.stonehenge.com/merlyn/LinuxMag/col42.html

=head1 AUTHORS

=over 4

=item *

Ricardo SIGNES <rjbs@cpan.org>

=item *

Randal Schwartz <merlyn@stonehenge.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2004 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__END__
:endofperl
