#!/usr/bin/perl

$infile = $ARGV[0];
open(INF, "<$infile");
@filedata = ();
@filedata = <INF>;
close INF;

$outfile = "get_coverage_info.coverage.txt";
$outfile1 = "get_coverage_info.percentage.txt";
$outfile2 = "get_coverage_info.names.txt";
open(OUT, ">$outfile");
open(OUT1, ">$outfile1");
open(OUT2, ">$outfile2");

foreach my $line (@filedata) {
    @info = ();
    $line =~ s/\n//g;
    $line =~ s/\r//g;
    @info = split(/\t/, $line);
    $chr = $info[0];
    $sta = $info[1];
    $end = $info[2];
    $tag = $info[3];
 #   print "$chr\t$sta\t$end\t$tag";
    print OUT "$chr\t$sta\t$end\t$tag";
    print OUT1 "$chr\t$sta\t$end\t$tag";
    $directory = './';
    opendir (DIR, $directory) or die $!;
    $count = 0;
    while (my $file = readdir(DIR)) {
	if($file =~ /^([\w\-]+)\.coverage$/) {
	    $sample = $1;
            open(INF, "<$file");
	    @filedata1 = ();
	    @filedata1 = <INF>;
	    close INF;
            print OUT2 "$file\n";
            foreach my $line1 (@filedata1) {
                $line1 =~ s/\n//g;
                $line1 =~ s/\r//g;
                @info1 = ();
                @info1 = split(/\t/, $line1);
                $chr1 = $info1[0];
                $sta1 = $info1[1];
                $end1 = $info1[2];
                $assay = $info1[3];
                $coverage = $info1[4];
                $percentage = $info1[7];
                if($chr1 eq $chr && $sta1 == $sta && $end1 == $end) {
#                    print "\t$coverage";
                    print OUT "\t$coverage";
                    print OUT1 "\t$percentage";
		    last;
		}
	    }
	}
    }
#    print "\n";
    print OUT "\n";
    print OUT1 "\n";
}

close OUT;
close OUT1;
close OUT2;
