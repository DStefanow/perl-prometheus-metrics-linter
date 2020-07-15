#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;

my $metrics_file = $ARGV[0];

if ( !$metrics_file ) {
	print "Usage:
$0 <metrics file>
Example: $0 /var/db/metrics/usage.txt
";
	exit 9;
}

if ( ! -f $metrics_file ) {
	print "Missing metrics file: $metrics_file\n";
	exit 9;
}

sub read_file {
	local $/ = undef;
	open my $FH, '<', $metrics_file or do {
		print "Cannot open $metrics_file for reading\n";
		exit 9;
	};
	binmode $FH;
	my $file_content = <$FH>;

	return $file_content;
}

# Main validation function
sub is_valid_metrics_file {
	my $prom_data = shift;

	if ( !$prom_data ) {
		print("Missing prometheus metrics data\n");
		exit 8;
	}

	my @flines = split("\r\n|\n", $prom_data);

	my ($key, $is_valid_chunk, $chunk_counter);

	foreach my $fline (@flines) {
		# Check if the following line starts a new chunk
		if ( $fline =~ /^# HELP/ ) {
			# Reset valid chunk flag
			$is_valid_chunk = 0;

			# Extract the key from help section
			$key = retrive_key_from_help_block($fline);
			if( !$key ) {
				print "Invalid HELP section on line:\n$fline\nExiting!\n\n";
				exit 6;
			}

			# Reset the counter
			$chunk_counter = 1;
		}

		# Time to check type section
		elsif ( $chunk_counter == 1 ) {
			if( !is_valid_type_block($fline, $key) ) {
				print "Invalid TYPE section on line:\n$fline\nExiting!\n\n";
				exit 7;
			}

			# Increment chunk for next lines validation
			$chunk_counter++;
		}

		# Data block check
		elsif ( $chunk_counter == 2 ) {
			if ( !is_valid_metrics_data_block($fline, $key) ) {
				print "Invalid data section on line:\n$fline\nExiting!\n\n";
				exit 4;
			}

			$is_valid_chunk = 1;
		}

		else {
			print "There was a problem with the chunk block!\n";
			exit 5;
		}
	}

	return $is_valid_chunk;
}

# HELP metadata block validation
sub retrive_key_from_help_block {
	my $fline = shift;

	return if $fline !~ /^# HELP ([a-zA-Z_:][a-zA-Z0-9_:]*)/;
	return $1;
}

# TYPE metadata block validation
sub is_valid_type_block {
	my ($fline, $key) = @_;

	return $fline =~ /^# TYPE $key (counter|gauge|histogram|summary)+$/;
}

# DATA block validation
sub is_valid_metrics_data_block {
	my ($fline, $key) = @_;

	return $fline =~ /^$key.* [-+]?[0-9]+[.]?[0-9]*([eE][-+]?[0-9]+)?$/;
}

if ( is_valid_metrics_file(read_file($metrics_file)) ) {
	print "Metrics file: $metrics_file: OK\n";
} else {
	print "Invalid metrics file $metrics_file: ERROR\n";
}

exit 0;
