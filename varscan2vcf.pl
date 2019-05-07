# Author: Jiwoong Kim (jiwoongbio@gmail.com)
use strict;
use warnings;
local $SIG{__WARN__} = sub { die "ERROR in $0: ", $_[0] };

use List::Util qw(max sum);
use Getopt::Long qw(:config no_ignore_case);

GetOptions(
	'h' => \(my $help = ''),
	'n=s' => \(my $sampleNormal = 'normal'),
	't=s' => \(my $sampleTumor = 'tumor'),
);
if($help || scalar(@ARGV) == 0) {
	die <<EOF;

Usage:   perl varscan2vcf.pl [options] varscan.{snp,indel}.Somatic [...] > varscan.somatic.vcf

Options: -h       display this help message
         -n STR   normal sample name [$sampleNormal]
         -t STR   tumor sample name [$sampleTumor]

EOF
}
my @varscanFileList = @ARGV;
my %iupacBaseListHash = ('A' => ['A'], 'C' => ['C'], 'G' => ['G'], 'T' => ['T'], 'U' => ['U'], 'W' => ['A', 'T'], 'S' => ['C', 'G'], 'M' => ['A', 'C'], 'K' => ['G', 'T'], 'R' => ['A', 'G'], 'Y' => ['C', 'T'], 'B' => ['C', 'G', 'T'], 'D' => ['A', 'G', 'T'], 'H' => ['A', 'C', 'T'], 'V' => ['A', 'C', 'G'], 'N' => ['A', 'C', 'G', 'T']);
print "##fileformat=VCFv4.0\n";
print '#', join("\t", 'CHROM', 'POS', 'ID', 'REF', 'ALT', 'QUAL', 'FILTER', 'INFO', 'FORMAT', $sampleNormal, $sampleTumor), "\n";
foreach my $varscanFile (@varscanFileList) {
	open(my $reader, $varscanFile);
	chomp(my $line = <$reader>);
	my @columnList = split(/\t/, $line);
	while($line = <$reader>) {
		chomp($line);
		my %tokenHash = ();
		@tokenHash{@columnList} = split(/\t/, $line, scalar(@columnList));
		my @alleleList = ($tokenHash{'ref'}, split(/\//, $tokenHash{'var'}));
		my %alleleIndexHash = map {$alleleList[$_] => $_} 0 .. $#alleleList;
		my %genotypeHash = ();
		foreach my $sample ('normal', 'tumor') {
			my @alleleIndexList = ();
			my $baseList = $iupacBaseListHash{$tokenHash{"${sample}_gt"}};
			foreach my $allele (defined($baseList) ? @$baseList : map {$_ eq '*' ? $tokenHash{'ref'} : $_} split(/\//, $tokenHash{"${sample}_gt"})) {
				$alleleList[$alleleIndexHash{$allele} = scalar(@alleleList)] = $allele unless(defined($alleleIndexHash{$allele}));
				push(@alleleIndexList, $alleleIndexHash{$allele});
			}
			@alleleIndexList = (@alleleIndexList, @alleleIndexList) if(scalar(@alleleIndexList) == 1);
			$genotypeHash{$sample} = join(':', join('/', sort {$a <=> $b} @alleleIndexList), join(',', $tokenHash{"${sample}_reads1"}, $tokenHash{"${sample}_reads2"}), $tokenHash{"${sample}_reads1"} + $tokenHash{"${sample}_reads2"});
		}
		my ($deletion) = sort {length($b) <=> length($a)} map {/^[-]([A-Z]+)$/ ? $1 : ()} @alleleList;
		foreach my $index (0 .. $#alleleList) {
			$alleleList[$index] = "$tokenHash{'ref'}$1" if($alleleList[$index] =~ /^[+]([A-Z]+)$/);
			if($alleleList[$index] =~ /^[-]([A-Z]+)$/) {
				$alleleList[$index] = "$tokenHash{'ref'}$1" if($deletion =~ /^$1(.*)$/);
			} else {
				$alleleList[$index] .= $deletion if(defined($deletion));
			}
		}
		my ($chromosome, $position, $refBase, $altBase) = (@tokenHash{'chrom', 'position'}, $alleleList[0], join(',', @alleleList[1 .. $#alleleList]));
		my ($id, $quality, $filter) = ('.', '.', '.');
		my $info = "somatic_status=$tokenHash{'somatic_status'};variant_p_value=$tokenHash{'variant_p_value'};somatic_p_value=$tokenHash{'somatic_p_value'}";
		my $format = 'GT:AD:DP';
		print join("\t", $chromosome, $position, $id, $refBase, $altBase, $quality, $filter, $info, $format, @genotypeHash{'normal', 'tumor'}), "\n";
	}
	close($reader);
}
