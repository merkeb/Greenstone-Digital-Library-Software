###########################################################################
#
# TabSeparatedPlugin.pm -- A plugin for tab-separated metadata files
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright 2006 New Zealand Digital Library Project
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###########################################################################

# Based on CVSPlugin

package TabSeparatedPlugin;


use SplitTextFile;
use MetadataRead;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa


# TabSeparatedPlugin is a sub-class of SplitTextFile.
sub BEGIN {
    @TabSeparatedPlugin::ISA = ('MetadataRead', 'SplitTextFile');
}


my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "split_exp",
	'desc' => "{SplitTextFile.split_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_split_exp(),
        'hiddengli' => "yes" }
      ];


my $options = { 'name'     => "TabSeparatedPlugin",
		'desc'     => "{TabSeparatedPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'explodes' => "yes",
		'args'     => $arguments };


# This plugin processes files with the suffix ".tab"
sub get_default_process_exp {
    return q^(?i)(\.tab)$^;
}

    
# This plugin splits the input text by line
sub get_default_split_exp {
    return q^\r?\n^;
}


sub new
{
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}}, @{$arguments});
    push(@{$hashArgOptLists->{"OptList"}}, $options);

    my $self = new SplitTextFile($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}


sub read_file
{
    my $self = shift (@_);
    my ($filename, $encoding, $language, $textref) = @_;

    # Read in file the usual ReadTextFile way
    # This ensure that $textref is a unicode aware string
    $self->SUPER::read_file(@_);

    #
    # Now top-up the processing of the text with what this plugin
    # needs
    #

    # Remove any blank lines so the data is split and processed properly
    $$textref =~ s/\n(\s*)\n/\n/g;

    # The first line contains the metadata element names
    $$textref =~ s/^(.*?)\r?\n//;
    my @tab_file_fields = ();
    my $tab_file_field_line = $1 . "\t";  # To make the regular expressions simpler
    while ($tab_file_field_line ne "") {
	if ($tab_file_field_line =~ s/^(.*?)\t//) {
	    my $tab_file_field = $1;
	    $tab_file_field =~ s/ //g;  # Remove any spaces from the field names
	    push(@tab_file_fields, $tab_file_field);
	}
	# The line must be formatted incorrectly
	else {
	    print STDERR "Error: Badly formatted Tab field line: $tab_file_field_line.\n";
	    last;
	}
    }
    $self->{'tab_file_fields'} = \@tab_file_fields;
}


sub process
{
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    my $section = $doc_obj->get_top_section();
    my $tab_line = $$textref;
    my @tab_file_fields = @{$self->{'tab_file_fields'}};

    # Add the raw line as the document text
    $doc_obj->add_utf8_text($section, $tab_line);

    # Build a hash of metadata name to metadata value for this line
    my $i = 0;
    $tab_line .= "\t";  # To make the regular expressions simpler
    while ($tab_line ne "") {
	if ($tab_line =~ s/^(.*?)\t//) {
	    # Only bother with non-empty values
	    if ($1 ne "" && defined($tab_file_fields[$i])) {
		$doc_obj->add_utf8_metadata($section, $tab_file_fields[$i], $1);
	    }
	}
	# The line must be formatted incorrectly
	else {
	    print STDERR "Error: Badly formatted Tab line: $tab_line.\n";
	    last;
	}

	$i++;
    }

    # Record was processed successfully
    return 1;
}


1;
