#!/bin/bash

module load bedtools

if ! [[ -d Stats ]]; then mkdir Stats; fi

BED=$1
DIR=Alignment

for file in $DIR/*.bam; 
	do echo $file
	sample=$(basename $file );
	echo getting coverage info for $sample;
	coverageBed -b $file -a $BED > Stats/$sample\.coverage;
	coverageBed -hist -b $file -a $BED > Stats/$sample\.coverage.hist;
done

