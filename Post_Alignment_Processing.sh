#!/bin/bash

## This script will create all the jobs needed to get variant calls from UMI tagged sequencing.
## N.B. be aware this script has not been written with WGS in mind, if you will have huge files look as restricting the number of concurrent jobs that can run. 
## This script creates array jobs that can be submitted to the Sun Grid Engine on Apocrita
## This script has been written by Findlay Bewicke-Copley August 2018

SuppScirptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"/SupplementaryScripts/
today=`date +%Y-%m-%d`
DIR=$PWD
jobName=UMI-VCF-$(basename $DIR)
BED=''
REFDIR=/data/BCI-Haemato/Refs/
## By Default use the hg37 reference genome
REF=GRCh38

## Job Constants
fastqSuffix=.fastq.gz
SETUP=0

AUTOSTART=0

## Process Arguments
while [ "$1" != "" ]; do
        case $1 in
		-n | --name )		shift
					jobName=$1
					;;
		-b | --bed )		shift
					BED=$1
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
                -r | --ref )		shift
					if [[ -d $REFDIR/$1 ]]; then
						REF=$1
						echo reference $REF will be used
					else
						echo Reference Not Found
						exit 1
					fi
					;;
		-f | --fastq-suffix )	shift
					fastqSuffix=$1
					;;
		-h | --help )		echo "\
-n | --name		Sets the job name (default - UMI-VCF-$PWD)
-d | --directory	Root directory for the project
-r | --ref 		Reference directory for the project, look for this in BCI-Haemato/Refs (default $REF )
-h | --help		Display this message"
					exit 1
					;;
	esac
	shift
done


## This automatically gets the correct reference files. This means reference directory structure is important.
REFDIR=$REFDIR/$REF
reference=$( ls  $REFDIR/*.fa )
dbsnp=$( ls $REFDIR/DBSNP/*latest*.vcf.gz )

# Job script files
realignJob=$jobName\.PostProcessing.$today\.sh

# Guess at the max number of samples TODO I should probably change this to be input on formation as this requires the samples to have been sorted already.
# ls doesn't actually do anything here, except occupy the first space [0] in the array. Without it ${FILES[1]} returns the second sample etc ...
# However this is inelegant and means that I have to remove 1 from the count
# Really I should be removing one from the task ID. TODO make this more elegant not a bodge.
FILES=(ls FASTQ_Raw/*)
MAX=$(echo ${#FILES[@]})
MAX=$( expr $MAX - 1 )

echo "
#!/bin/sh
#$ -wd $DIR             # use current working directory
#$ -o /data/scratch/$USER/
#$ -j y                 # and put all output (inc errors) into it
#$ -m a                 # Email on abort
#$ -pe smp 1            # Request 1 CPU cores
#$ -l h_rt=24:0:0        # Request 24 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=4G         # Request 4G RAM / Core
#$ -t 1-$MAX            # run an array job of all the samples listed in FASTQ_Raw
#$ -N $jobName-postprocessing

module load gatk/4.1.6.0

reference=$reference
dbsnp=$dbsnp" > $realignJob

echo '
Samples=(ls FASTQ_Raw/*)
## Extract the file name at the position of the array job task ID
Sample=$(basename ${Samples[${SGE_TASK_ID}]})
echo $Sample

bam=Alignment/$Sample\.bam
markedbam=Alignment/$Sample\.marked.bam
baserecaldata=Alignment/$Sample\.recal_data.grp
recalioutbam=Alignment/$Sample\.recalib.bam

## step 3: Marking PCR duplicates
echo "####MESS Step 3: Marking PCR duplicates using Picard"
if ! [[ -f $markedbam ]]; then
	time gatk --java-options "-Xmx16g -Djava.io.tmpdir=$TEMP_FILES" MarkDuplicatesSpark \
	        -O $mmarkedbam \
	        -I $bam \
	        -M Alignment/$Sample\.metrics.txt \
	        -OBI true \
		--create-output-bam-splitting-index false \
	        -VS LENIENT ||
	                ##If fails delete output and exit
	                { echo Marking duplicates failed removing $outputbammarked;
	                        rm $outputbammarked;
	                        exit 1; }
fi
## base quality score recalibration
echo "####MESS Step 4: base quality score recalibration"
if ! [[ -f $baserecaldata ]]; then 
	time gatk --java-options "-Xmx4g" BaseRecalibrator \
		-I $markedbam \
		-R $reference \
		-knownSites $dbsnp \
		-o $baserecaldata ||
		{ echo recalibration failed, deleteing $baserecaldata;
			rm $baserecaldata;
			 exit 1; }
fi

echo "####MESS Step 5: Apply base score recalibration"
if ! [[ -f $recalioutbam ]]; then
	time gatk ApplyBQSR \
		-R $reference \
		-I $markedbam \
		--bqsr-recal-file $baserecaldata \
		-O $recalioutbam || 
		{ echo Print reads failed, deleteing $recalioutbam;
			rm $recalioutbam;
			 exit 1; }
fi

## Can run AnalyseCovariates on recal tables to see how things look if need be 

' >> $realignJob

