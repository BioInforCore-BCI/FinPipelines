#!/bin/bash

## This script will create all the jobs needed to get variant calls from UMI tagged sequencing.
## N.B. be aware this script has not been written with WGS in mind, if you will have huge files look as restricting the number of concurrent jobs that can run. 
## This script creates array jobs that can be submitted to the Sun Grid Engine on Apocrita
## This script has been written by Findlay Bewicke-Copley August 2018

today=`date +%Y-%m-%d`
DIR=$PWD
jobOutputDir=$DIR
jobName=Trim-$(basename $DIR)
fastqSuffix=.fastq.gz
AUTOSTART=0
ADAPTER=illumina

## Process Arguments
while [ "$1" != "" ]; do
        case $1 in
		-a | --autostart )	AUTOSTART=1
					;;
		-n | --name )		shift
					jobName=$1
					;;
		-p | --adapter )	shift
					ADAPTER=$1
					echo Will trim $ADAPTER adapters
					;;
		-d | --directory )	shift
					if [[ -d $1 ]]; then
					        DIR=$1
					        echo "Will run on files in $DIR"
					else
					        echo "Specified directory $1 doesn't exist"
					        exit 1
					fi
					;;
                -f | --fastq-suffix )   shift
                                        fastqSuffix=$1
                                        ;;
		-h | --help )		echo "\
-a | --autostart	Automaticall start the jobs, holding jobs so they run in the correct order
-n | --name		Sets the job name (default - UMI-VCF-$PWD)
-p | --adapter		Adapter to trim (illumina)
-d | --directory	Root directory for the project
-r | --ref 		Reference directory for the project, look for this in BCI-Haemato/Refs (default GRCh37)
-s | --setup 		Run the set up (cat the files together and create sample directories) (default off)
-f | --fastq-suffix 	Suffix for the fastq files (default .fastq.gz)
-h | --help		Display this message"
					exit 1
					;;
	esac
	shift
done

# Job script files
#jobOutputDir=/data/scratch/$USER/
trimJob=$jobOutputDir/$jobName\Trim_Job.$today\.sh
# Guess at the max number of samples TODO I should probably change this to be input on formation as this requires the samples to have been sorted already.
# ls doesn't actually do anything here, except occupy the first space [0] in the array. Without it ${FILES[1]} returns the second sample etc ...
# However this is inelegant and means that I have to remove 1 from the count
# Really I should be removing one from the task ID. TODO make this more elegant not a bodge.
FILES=(ls FASTQ_Raw/*)
MAX=$(echo ${#FILES[@]})
MAX=$( expr $MAX - 1 )
##
# Trimming Job
##

echo "
##!/bin/sh
#$ -wd $DIR		# use current working directory
#$ -V			# this makes it verbose
#$ -o $jobOutputDir	# specify an output file
#$ -j y			# and put all output (inc errors) into it
#$ -m a			# Email on abort
#$ -pe smp 1		# Request 1 CPU cores
#$ -l h_rt=24:0:0	# Request 24 hour runtime
#$ -l h_vmem=4G		# Request 4G RAM / Core
#$ -t 1-$MAX		# run an array job of all the samples listed in FASTQ_Raw
#$ -N $jobName-Trim_Job

DIR=$DIR
ADAPTER=$ADAPTER
fastqSuffix=$fastqSuffix
" > $trimJob

echo '
module load trimgalore

mkdir $DIR/FASTQ_TRIM;
mkdir -p $DIR/QC/TRIM;

## Get all the sample names from FASTQ_Raw
Samples=(ls FASTQ_Raw/*)
## Extract the file name at the position of the array job task ID
Sample=$(basename ${Samples[${SGE_TASK_ID}]})

## Make directory for output
mkdir FASTQ_TRIM/$Sample

echo $Sample/*R1.fastq;
# Trim adapters using trim_galore
time trim_galore --paired --retain_unpaired --$ADAPTER --gzip \
        --fastqc_args "-o QC/TRIM/" \
        -o FASTQ_TRIM/$Sample/ \
        FASTQ_Raw/$Sample/*R1*$fastqSuffix FASTQ_Raw/$Sample/*R2*$fastqSuffix

# As long as the trim runs successfully run some clean up.
if [[ $? -eq 0 ]]; then

	# Move UMI file to FASTQ_TRIM	
	mv FASTQ_Raw/$sample/*UMI* FASTQ_TRIM/$sample/*UMI*;
	# if moving the file worked fine, remove the FASTQ_Raw folder. 
	if [[ $? -eq 0 ]];
		then
		rm -rf FASTQ_Raw/$Sample
	fi
fi
' >> $trimJob


if [[ $AUTOSTART -eq 1 ]]; then
	echo Starting the jobs. Good luck!
	qsub $trimJob
fi
