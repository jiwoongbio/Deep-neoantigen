# Author: Jiwoong Kim (jiwoongbio@gmail.com)
use strict;
use warnings;
local $SIG{__WARN__} = sub { die $_[0] };

use Getopt::Long qw(:config no_ignore_case);

GetOptions(
	'h' => \(my $help = ''),
);
if($help || scalar(@ARGV) == 0) {
	die <<EOF;

Usage:   perl netMHCpan_peptide.pl [options] peptide.txt HLA_allele [...] > netMHCpan.txt

Options: -h       display this help message

EOF
}
my ($peptideInputFile, @hlaAlleleList) = @ARGV;
foreach my $hlaAllele (@hlaAlleleList) {
	open(my $reader, "netMHCpan -a '$hlaAllele' -p $peptideInputFile |");
	while(my $line = <$reader>) {
		chomp($line);
		next if($line =~ /^#/);
		if($line =~ /^(.*) <= (.*)$/) {
			my @tokenList = split(/\s+/, $1);
			my ($peptide, $icore, $bind) = ($tokenList[3], $tokenList[10], $2);
			print join("\t", $peptide, $icore, $hlaAllele, $bind), "\n";
		}
#		if($line =~ /^Protein PEPLIST\. Allele (.*)\. Number of high binders ([0-9]*)\. Number of weak binders ([0-9]*)\. Number of peptides ([0-9]*)/) {
#			print join("\t", $1, $2, $3, $4), "\n";
#		}
	}
	close($reader);
}
