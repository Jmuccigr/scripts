#!/usr/bin/perl -w

my $optionalstring = '';

use Getopt::Long;
GetOptions("c"=>    \$cflag,
           "t"=>    \$tflag,
           "h"=>    \$hflag,
           "s:s"=>  \$sepstring,
           "help"=> \$helpflag);

# Handle a request for help
if ($helpflag) {
	print "SYNOPSIS\n\n";
	print "	wikitbl.pl [-c|-t|-s <text>] [-h] [-help] <input file> [<output file>]\n\n";
	print "DESCRIPTION\n\n";
	print "	A script to convert simple text tables to simple Wikipedia-style tables. The\n";
	print "	script assumes that the columns are separated by commas (also can be forced\n";
	print "	by -c), but will accept tabs (-t) and any other string (-s <text>). If the \n";
	print "	-h option is used, the script will treat the first line as a header. No\n";
	print "	effort is made to give all rows an equal number of cells.\n\n";
	print "	The following options are available:\n";
	print "		-c        columns are separated by comma (the default when no option is present)\n";
	print "		-t        columns are separated by tab\n";
	print "		-s <text> columns are separated by <text>\n";
	print "		-h        first row of file is treated as a table header\n";
	print "		-help     print this information\n\n";
	print "	If no output file is indicated, the output will go to STDOUT.\n";
	exit;
}

# When no help request or input file.
if (!$ARGV[0]) {
	print chr(7),"\nError: Must include at least an input file. Try 'wikitbl.pl -help' for more information.\n\n";
	exit;
}

open(INPUT, $ARGV[0]) or die "Couldn't open file for reading: $!\n";

# If an output filename is passed, use it. Otherwise print to STDOUT.
if ($ARGV[1]) {
	open(OUTPUT, "> $ARGV[1]") or die "Couldn't open file for writing: $!\n";   
	select OUTPUT;
}

# Handle the options to determine the separator. Comma is the default.
$sep = ',';
$sep = ","  if $cflag;
$sep = "\t" if $tflag;
$sep = "$sepstring" if $sepstring;

$setHeader = 0;

# Print the modified lines to the output
printf "{|\n";
while (<INPUT>) {
	@fields = split($sep);
	$line = "|-\n| " . join (" || ", @fields);
	# If the header option is present, convert first line into a heading
	if ($hflag && $setHeader == 0) {
		$line =~ s/\|\|/!!/g;
		$line =~ s/\n\| /\n! /g;
		$setHeader = 1;
	}
	printf $line;
}
printf  "|}\n";

close INPUT;
close OUTPUT;
