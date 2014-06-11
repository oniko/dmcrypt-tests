#!/usr/bin/env perl
use strict;
use warnings;
use POSIX;
use Text::Table;

if (scalar @ARGV != 2) {
	print STDERR "usage:\n./pstatus.pl <path_to_log_a> <path_to_log_b>\n";
	exit 1;
}

open( my $in_a, $ARGV[0] ) or die "Couldn't open $ARGV[0]: $!";
open( my $in_b, $ARGV[1] ) or die "Couldn't open $ARGV[1]: $!";

my $table_x = Text::Table->new( "TEST NAME\n-------------------------", "OPERATION\n---------", "AGGRB_A KB/s\n------------\n&right", "AGGRB_B KB/s\n------------\n&right", "DIFF A->B\n---------\n&right" );

my $line_count = 1;
my $test_name;
my $value_a; my $unit_a;
my $value_b; my $unit_b;
my $line_a; my $line_b;

while ((my $line_a = <$in_a>) &&(my $line_b = <$in_b>)) {

	#remove any whitespace
	$line_a =~ s/\s+//g;
	$line_b =~ s/\s+//g;

	if (length $line_a > 0 && length $line_b > 0) {

		#get TEST name
		if (index($line_a, "TEST") == 0 && index($line_b, "TEST") == 0) {
			($test_name = $line_a) =~ s/^TEST:(.*)/$1/;
		} #TEST results
		else {
			if (($line_a !~ /^(READ|WRITE).*/) || ($line_b !~ /^(READ|WRITE).*/)) {
				print STDERR 'line nr. ' . $line_count . ' ignored.' . "\n";
			}
			else {

				(my $io_a = $line_a) =~ s/^(READ|WRITE):.*/$1/;
				(my $io_b = $line_b) =~ s/^(READ|WRITE):.*/$1/;

				if ($io_a eq $io_b) {

					$line_a =~ s/^(READ|WRITE):(.*)/$2/;
					$line_b =~ s/^(READ|WRITE):(.*)/$2/;

					foreach my $xxx (split /,/, $line_a) {
						if ($xxx =~ /^aggrb.*/) {
							$value_a = (split( /=/, $xxx))[1];
						}
					}

					foreach my $xxx (split /,/, $line_b) {
						if ($xxx =~ /^aggrb.*/) {
							$value_b = (split( /=/, $xxx))[1];
						}
					}

					($unit_a = $value_a) =~ s/[0-9\.]+(.*)/$1/;
					($unit_b = $value_b) =~ s/[0-9\.]+(.*)/$1/;

					$value_a =~ s/([0-9\.]+).*/$1/;
					$value_b =~ s/([0-9\.]+).*/$1/;
					if ("$unit_a" eq "MB/s") { $value_a *= 1024; };
					if ("$unit_b" eq "MB/s") { $value_b *= 1024; };

					$table_x->add($test_name, $io_a, floor($value_a), floor($value_b), sprintf('%.2f ', ((($value_b / $value_a)) * 100) - 100) . '%' );
				}
				else {
					print STDERR "logs are different at line $line_count: io_a = $io_a, io_b = $io_b\n";
					exit 1;
				}
			}
		}
		$line_count++;
	}
}

close $in_a;
close $in_b;

print $table_x;
