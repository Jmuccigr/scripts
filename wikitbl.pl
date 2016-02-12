#!/usr/bin/perl -w

my $optionalstring = '';

use Getopt::Long;
GetOptions("c"=>   \$cflag,
           "t"=>   \$tflag,
           "h"=>   \$hflag,
           "s:s"=> \$sepstring);

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
