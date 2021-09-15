#!/bin/bash

for file in *; 
	do head -n 1 $file/final-list_candidate-fusion-genes.hg19.txt > $file/$file.final.fin.txt 
	tail -n +7 $file/summary_candidate_fusions.txt  | 
	head -n -4 | 
	grep -v false | 
	sed 's/.*\*.//;s/\-\-/\t/;s/\s*(.*//' | 
	xargs -I{} \
	grep {} $file/final-list_candidate-fusion-genes.hg19.txt >> $file/$file.final.fin.txt; 
done

awk 'NR==1, /Gene_/ {print "Sample\t" $0}; 
	FNR>1 {print FILENAME "\t" $0} ' \
	*/*.final.fin.txt |
		sed 's/\/.*.txt//' > Analysis/Fusions.All.txt
