# Author: Jiwoong Kim (jiwoongbio@gmail.com)
use strict;
use warnings;
local $SIG{__WARN__} = sub { die $_[0] };

use List::Util qw(max);
use Getopt::Long qw(:config no_ignore_case);

GetOptions(
	'd=s' => \(my $delimiter = ','),
	'q' => \(my $quote = ''),
);
my ($tableFile, @indexesList) = @ARGV;
my %indexHash = map {$_ => 1} map {eval($_)} @indexesList;
open(my $reader, $tableFile);
while(my $line = <$reader>) {
	chomp($line);
	my @tokenList = split(/\t/, $line, -1);
	my @tokenListList = map {scalar(@$_) > 0 ? $_ : ['']} map {$indexHash{$_} ? [split(/$delimiter/, $tokenList[$_], -1)] : [$tokenList[$_]]} 0 .. $#tokenList;
	@tokenListList = map {[rejoinQuote(@$_)]} @tokenListList if($quote);
	my $number = max(map {scalar(@$_)} @tokenListList);
	@tokenListList = map {scalar(@$_) == 1 ? [(@$_) x $number] : $_} @tokenListList if($number > 1);
	for(my $index = 0; $index < $number; $index++) {
		print join("\t", map {$_->[$index]} @tokenListList), "\n";
	}
}
close($reader);

sub rejoinQuote {
	my ($count, @tokenList) = (0);
	foreach my $token (@_) {
		if($count % 2 == 1) {
			$tokenList[-1] = join($delimiter, $tokenList[-1], $token);
		} else {
			push(@tokenList, $token);
		}
		$count += ($token =~ tr/"//);
	}
	return @tokenList;
}
