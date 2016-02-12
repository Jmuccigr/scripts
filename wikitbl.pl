#!/usr/bin/perl -w

#use Getopt::Std;
#%options=();
#getopt("cts",\%options);

my $optionalstring = '';

use Getopt::Long;
GetOptions("c"=>\$cflag,
           "t"=> \$tflag,
           "s:s"=>\$sepstring);

open(INPUT, $ARGV[0]) or die "Couldn't open file for reading: $!\n";
open(OUTPUT, "> $ARGV[1]") or die "Couldn't open file for writing: $!\n";   

# Handle the options to determine the separator. Comma is the default.
$sep = ',';
$sep = ","  if $cflag;
$sep = "\t" if $tflag;
$sep = "$sepstring" if $sepstring;
print "optionalstring $optionalstring\n" if $optionalstring;

# Print the modified lines to the output file
printf OUTPUT "{|\n";
while (<INPUT>) {
	@fields = split($sep);
	$line = "|-\n" . join (" || ", @fields);
	printf OUTPUT $line;
}
printf OUTPUT "|}\n";
close INPUT;
close OUTPUT;

