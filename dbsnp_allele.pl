# Author: Jiwoong Kim (jiwoongbio@gmail.com)
use strict;
use warnings;
local $SIG{__WARN__} = sub { die $_[0] };

use List::Util qw(sum max);
use Bio::DB::Fasta;
use Getopt::Long qw(:config no_ignore_case);

GetOptions(
	'h' => \(my $help = ''),
);
if($help || scalar(@ARGV) == 0) {
	die <<EOF;

Usage:   perl dbsnp_allele.pl [options] snp.txt reference.fasta > snp.allele.txt

Options: -h       display this help message

EOF
}
my ($dbsnpFile, $referenceFastaFile) = @ARGV;
my $db = Bio::DB::Fasta->new($referenceFastaFile);
my @chromosomeList = getChromosomeList();
my %chromosomeIndexHash = map {$chromosomeList[$_] => $_} 0 .. $#chromosomeList;
print join("\t", 'chromosome', 'start', 'end', 'haplotypeReference', 'haplotypeAlternate', 'name', 'subset', 'alleleN', 'alleleFreq'), "\n";
open(my $reader, $dbsnpFile);
while(my $line = <$reader>) {
	chomp($line);
	my ($bin, $chrom, $chromStart, $chromEnd, $name, $score, $strand, $refNCBI, $refUCSC, $observed, $molType, $class, $valid, $avHet, $avHetSE, $func, $locType, $weight, $exceptions, $submitterCount, $submitters, $alleleFreqCount, $alleles, $alleleNs, $alleleFreqs, $bitfields) = split(/\t/, $line, my $length = ($line =~ tr/\t//) + 1);
	next unless(defined($chromosomeIndexHash{$chrom}));
	next if($observed eq 'lengthTooLong');
	next if($class eq 'microsatellite');
	next if($class eq 'named');
	my $referenceAllele = $chromStart < $chromEnd ? uc($db->seq($chrom, $chromStart + 1, $chromEnd)) : '';
	next if($refUCSC =~ /^\( ([0-9]+)bp insertion \)$/ && $1 == $chromEnd - $chromStart);
	unless(($refUCSC eq '-' && $chromStart == $chromEnd) || $refUCSC eq $referenceAllele) {
		print STDERR "$line\n";
		next;
	}
	my %alleleNFreqHash = map {$_ => ['', '']} map {$_ eq '-' ? '' : $_} split(/\//, $observed);
	if($alleleFreqCount > 0) {
		my @alleleList = map {$_ eq '-' ? '' : $_} split(/,/, $alleles);
		my @alleleNList = split(/,/, $alleleNs);
		my @alleleFreqList = split(/,/, $alleleFreqs);
		s/\.0+$// foreach(@alleleNList, @alleleFreqList);
		s/(\.[0-9]*[^0])0+$/$1/ foreach(@alleleNList, @alleleFreqList);
		for(my $index = 0; $index < $alleleFreqCount; $index++) {
			$alleleNFreqHash{$alleleList[$index]} = [$alleleNList[$index], $alleleFreqList[$index]];
		}
	}
	print STDERR "$line\n" if(grep {!/^[ACGTN]*$/ && $_ ne '0'} keys %alleleNFreqHash);
	my $subset = '';
	if(grep {$_ eq 'MultipleAlignments'} split(/,/, $exceptions)) {
		$subset = 'Mult';
	} elsif($alleleFreqCount > 1 && sum(split(/,/, $alleleNs)) >= 10 && max(split(/,/, $alleleFreqs)) <= 0.99) {
		$subset = 'Common';
	} elsif(grep {$_ eq 'clinically-assoc'} split(/,/, $bitfields)) {
		$subset = 'Flagged';
	}
	foreach my $allele (grep {/^[ACGT]*$/} keys %alleleNFreqHash) {
		my $alternateAllele = $allele;
		($alternateAllele = reverse($alternateAllele)) =~ tr/ACGT/TGCA/ if($strand eq '-');
		next if($referenceAllele eq $alternateAllele);
		my ($start, $haplotypeReference, $haplotypeAlternate) = leftalignIndel($chrom, stripIdentical($chromStart + 1, $referenceAllele, $alternateAllele));
		my $end = $start + length($haplotypeReference) - 1;
		print join("\t", $chrom, $start, $end, $haplotypeReference, $haplotypeAlternate, $name, $subset, @{$alleleNFreqHash{$allele}}), "\n";
	}
}
close($reader);

sub leftalignIndel {
	my ($chromosome, $position, @sequenceList) = @_;
	if(grep {$_ eq ''} @sequenceList) {
		while(my $base = uc($db->seq($chromosome, $position = $position - 1, $position))) {
			@sequenceList = map {"$base$_"} @sequenceList;
			my @baseList = map {substr($_, -1, 1)} @sequenceList;
			last if(grep {$baseList[$_ - 1] ne $baseList[$_]} 1 .. $#baseList);
			substr($_, -1, 1, '') foreach(@sequenceList);
		}
	}
	return ($position, @sequenceList);
}

sub stripIdentical {
	my ($position, @sequenceList) = @_;
	while(my @baseList = map {substr($_, -1, 1)} @sequenceList) {
		last if(grep {$baseList[$_ - 1] ne $baseList[$_]} 1 .. $#baseList);
		substr($_, -1, 1, '') foreach(@sequenceList);
	}
	while(my @baseList = map {substr($_, 0, 1)} @sequenceList) {
		last if(grep {$baseList[$_ - 1] ne $baseList[$_]} 1 .. $#baseList);
		substr($_, 0, 1, '') foreach(@sequenceList);
		$position += 1;
	}
	return ($position, @sequenceList);
}

sub getChromosomeList {
	my @chromosomeList = ();
	if(my $faiFile = `find $referenceFastaFile.fai -newer $referenceFastaFile 2> /dev/null`) {
		chomp($faiFile);
		open(my $reader, $faiFile);
		while(my $line = <$reader>) {
			chomp($line);
			my @tokenList = split(/\t/, $line);
			push(@chromosomeList, $tokenList[0]);
		}
		close($reader);
	} else {
		open(my $reader, $referenceFastaFile);
		while(my $line = <$reader>) {
			chomp($line);
			push(@chromosomeList, $1) if($line =~ /^>(\S*)/);
		}
		close($reader);
	}
	return @chromosomeList;
}
