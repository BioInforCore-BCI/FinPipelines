#!/bin/bash
today=`date +%Y-%m-%d`

DIR=$PWD
JOBNAME=BWA_Align
FILES=(ls FASTQ_Raw/*)
MAX=$(echo ${#FILES[@]})
MAX=$( expr $MAX - 1 )
TotalSAI=$( expr $MAX + $MAX )

REFDIR=/data/BCI-Haemato/Refs/

AUTOSTART=0

while [ "$1" != "" ]; do
        case $1 in
		-a | --auto-start )	AUTOSTART=1
					;;
                -n | --name )           shift
                                        JOBNAME=$1
                                        ;;
                -d | --directory )      shift
                                        if [[ -d $1 ]]; then
                                                DIR=$1
                                                echo Will run on files in $DIR
                                        else
                                                echo "Specified directory $1 doesn't exist"
                                                exit 1
                                        fi
                                        ;;
                -r | --refdir )		shift
					if [[ -d $REFDIR/$1 ]]; then
						REF=$1
						echo reference $REF will be used
					else
						echo Reference Not Found
						exit 1
					fi
					;;
		-h | --help )		echo "\
-a | --auto-start 		Automatically start the jobs on creation (default off)
-n | --name 	           	The name for the job (default BWA_Align)
-d | --directory 	      	The root directory for the project (default $PWD)
-r | --refdir 			Directory in BCI-Haemato/Refs containing the reference (default GRCh37/)
-h | --help 			Display this message and exit"
					exit 1
					;;
        esac
        shift
done


## By Default use the hg37 reference genome
if ! [[ $REF ]];then REF=GRCh37; fi

REFDIR=$REFDIR/$REF

## This automatically gets the correct reference files. This means reference directory structure is important.
idxPre=( $REFDIR/BWA/* )
referenceindex=$( echo $idxPre | cut -d'.' -f 1 )
reference=$( ls  $REFDIR/*.fa )
dbsnp=$( ls $REFDIR/*no_M.vcf )

## Store job files in the job directory.
#JOBDIR=/data/autoScratch/weekly/hfx472/
JOBDIR=$DIR

## Names for the job files.
READ1JOB=$JOBDIR/$JOBNAME.$today.read1.sh
READ2JOB=$JOBDIR/$JOBNAME.$today.read2.sh
COMBOJOB=$JOBDIR/$JOBNAME.$today.combo.sh
REALIGNJOB=$JOBDIR/$JOBNAME.$today.realign.sh

## All job files
#$READ1JOB $READ2JOB $COMBOJOB $CONVERTJOB $DUPJOB $REALIGNJOB $RECALJOB

####################
## Make Sai
####################

## Run BWA aln scripts simultaneously in an array

## Setup scripts
echo "
#!/bin/sh
#$ -wd $DIR		# use current working directory
#$ -V                   # this makes it verbose
#$ -o /data/autoScratch/weekly/hfx472/        # specify an output file - change 'outputfile.out'
#$ -j y                 # and put all output (inc errors) into it
#$ -m a
#$ -pe smp 8		# Request 8 CPU cores
#$ -l h_rt=38:0:0	# Request 48 hour runtime (upto 240 hours)
#$ -l h_vmem=4G		# Request 4GB RAM / core
#$ -t 1-$MAX" | tee $READ1JOB $READ2JOB

echo "#$ -N BWA-$JOBNAME-read1" >> $READ1JOB
echo "#$ -N BWA-$JOBNAME-read2" >> $READ2JOB

echo "
referenceindex=$referenceindex
JOBNAME=$JOBNAME
TotalSAI=$TotalSAI
COMBOJOB=$COMBOJOB
" | tee -a $READ1JOB $READ2JOB

echo '
Samples=(ls FASTQ_Raw/*)
Sample=${Samples[${SGE_TASK_ID}]}
sampleName=$(echo $Sample | cut -d'/' -f 2)
read1name=$(echo $Sample/*_1.fq.gz)
read1sai=Alignment/$sampleName\_1.sai

module load bwa
## Do not make sai if the sai already exists and is not 0 bytes.
if ! [[ -s $read1sai ]]; then
	echo ####MESS Step 1: Make SAI
	time bwa aln -t 8 $referenceindex $read1name > $read1sai
	if ! [[ $? -eq 0 ]]; then
		rm $read1sai
		exit 1
	fi
fi
' >> $READ1JOB 

echo '
Samples=(ls FASTQ_Raw/*)
Sample=${Samples[${SGE_TASK_ID}]}
sampleName=$(echo $Sample | cut -d'/' -f 2)
read2name=$(echo $Sample/*_2.fq.gz)
read2sai=Alignment/$sampleName\_2.sai

module load bwa
## Do not make sai if the sai already exists and is not 0 bytes.
if ! [[ -s $read2sai ]]; then
	echo ####MESS Step 1: Make SAI
	time bwa aln -t 8 $referenceindex $read2name > $read2sai
	if ! [[ $? -eq 0 ]]; then
		rm $read2sai
		exit 1
	fi
fi
' >> $READ2JOB

echo ' 
if [[ $(ls Alignment/*.sai | wc -l ) -eq $TotalSAI ]] && [[ $(qstat -r | grep Full | grep BWA-$JOBNAME-read | wc -l ) -eq 1 ]];
	then echo Starting SAM production
	qsub $COMBOJOB
fi 
' | tee -a $READ1JOB $READ2JOB

######################
## Make BAM
######################

## Setup scripts
echo "
#!/bin/sh
#$ -wd $DIR		# use current working directory
#$ -V                   # this makes it verbose
#$ -o /data/autoScratch/weekly/hfx472/        # specify an output file - change 'outputfile.out'
#$ -e /data/autoScratch/weekly/hfx472/        # specify an output file - change 'outputfile.out'
#$ -m a			# email on abort
#$ -pe smp 1		# Request 1 CPU cores
#$ -l h_rt=120:0:0	# Request 48 hour runtime (upto 240 hours)
#$ -l h_vmem=16G	# Request 16GB RAM / core
#$ -t 1-$MAX
#$ -tc 2		# only two jobs can run at the same time as the sams are massive, hopefully this will limit everything filling up.
#$ -N BWA-$JOBNAME-MakeBam

referenceindex=$referenceindex
JOBNAME=$JOBNAME
REALIGNJOB=$REALIGNJOB
MAX=$MAX
" | tee $COMBOJOB

echo '
Samples=(ls FASTQ_Raw/*)
Sample=${Samples[${SGE_TASK_ID}]}
sampleName=$(echo $Sample | cut -d'/' -f 2)
read1name=$(echo $Sample/*_1.fq.gz)
read2name=$(echo $Sample/*_2.fq.gz)
read1sai=Alignment/$sampleName\_1.sai
read2sai=Alignment/$sampleName\_2.sai
outputsam=Alignment/$sampleName\.sam
outputbam=Alignment/$sampleName\.bam

module load bwa
## There is a problem with default java, so need to load it here. 
module load java
echo ####MESS Step 1: Make Sam

if ! [[ -s $outputsam ]] && ! [[ -s $outputbam ]]; then
	time bwa sampe -r \
		"@RG\tID:$sampleName\tLB:$sampleName\tSM:$sampleName\tPL:Illumina" \
		$referenceindex \
		$read1sai \
		$read2sai \
		$read1name \
		$read2name > $outputsam

	## If the job fails remove the sam file and exit
	if ! [[ $? -eq 0 ]]; then rm $outputsam; exit 1; fi 

fi
echo ####MESS Step 2: Make Bam
## If the bam file does not exist or is smaller than 0 and the sam size is greater than 0 run the sort.
if ! [[ -s $outputbam ]] && [[ -s $outputsam ]]; then
	java -Xmx16g -Djava.io.tmpdir=/data/autoScratch/weekly/hfx472 -jar ~/Software/picard.jar SortSam \
		SO=coordinate \
		INPUT=$outputsam \
		OUTPUT=$outputbam \
		VALIDATION_STRINGENCY=LENIENT \
		CREATE_INDEX=true \
		MAX_RECORDS_IN_RAM=5000000
	
	## If thejob does not fail and the bam size is greater than 0 delete the precursor files.
	if [[ $? -eq 0 ]] && [[ -s $outputbam ]]; 
		then echo deleting precursors;
		rm $outputsam $read1sai $read2sai;
	else
		rm $outputbam
	fi

fi

if [[ $(ls Alignment/*.bam | wc -l ) -eq $MAX ]] && [[ $(qstat -r | grep Full | grep BWA-$JOBNAME-MakeBam | wc -l) -eq 1 ]];
	then echo Starting realignment
	qsub $REALIGNJOB
fi 
' >> $COMBOJOB

echo "
#!/bin/bash
#$ -wd $DIR		# use current working directory
#$ -V                   # this makes it verbose
#$ -o /data/autoScratch/weekly/hfx472/     # specify an output file
#$ -j y                 # and put all output (inc errors) into it
#$ -m a                 # Email on abort
#$ -pe smp 1            # Request 1 CPU cores
#$ -l h_rt=120:0:0        # Request 8 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=16G         # Request 4G RAM / Core
#$ -t 1-$MAX            # run an array job of all the samples listed in FASTQ_Raw
#$ -N BWA-$JOBNAME-Realign

reference=$reference
dbsnp=$dbsnp
" | tee $REALIGNJOB

echo '
## There are problems with system java so load the newer version here
module load java

GATK=/data/home/hfx472/Software/GenomeAnalysisTK.jar
PICARD=/data/home/hfx472/Software/picard.jar
TEMP_FILES=/data/auoScratch/weekly/hfx472

Samples=(ls FASTQ_Raw/*)
## Extract the file name at the position of the array job task ID
Sample=$(basename ${Samples[${SGE_TASK_ID}]})

echo $Sample

outputbam=Alignment/$Sample\.bam
outputbammarked=Alignment/$Sample\.marked\.bam
realignmentlist=Alignment/$Sample\.bam.list
realignmentbam=Alignment/$Sample\.realigned.bam
realignmentfixbam=Alignment/$Sample\.fixed.bam
baserecaldata=Alignment/$Sample\.recal_data.grp
recalioutbam=Alignment/$Sample\.recalib.bam

## step 3: Marking PCR duplicates
echo "####MESS Step 3: Marking PCR duplicates using Picard"
time java -Xmx16g -Djava.io.tmpdir=$TEMP_FILES -jar $PICARD MarkDuplicates \
	INPUT=$outputbam \
	OUTPUT=$outputbammarked \
	METRICS_FILE=$sampleName\.metrics.txt \
	CREATE_INDEX=true \
	VALIDATION_STRINGENCY=LENIENT

## local alignment around indels
echo "####MESS Step 4: local alignment around indels"
echo "####MESS Step 4: first create a table of possible indels"
time java -Xmx16g -jar $GATK -T RealignerTargetCreator \
        -R $reference \
        -o $realignmentlist \
        -I $outputbammarked

if [[ $? -eq 0 ]] && [[ -s $outputbammarked ]];
	then 
		rm $outputbam
	else
		exit 1
fi

echo "####MESS Step 4: realign reads around those targets"
time java -Xmx16g -Djava.io.tmpdir=$TEMP_FILES -jar $GATK \
        -I $outputbammarked \
        -R $reference \
        -T IndelRealigner \
        -targetIntervals $realignmentlist \
        -o $realignmentbam

if [[ $? -eq 0 ]] && [[ -s $realignmentbam ]];
	then
		rm $outputbammarked
	else
		exit 1
fi

echo "####MESS Step 4: fix paired end mate information using Picard"
time java -Xmx16g -Djava.io.tmpdir=$TEMP_FILES -jar $PICARD FixMateInformation \
        INPUT=$realignmentbam \
        OUTPUT=$realignmentfixbam \
        SO=coordinate \
        VALIDATION_STRINGENCY=LENIENT \
        CREATE_INDEX=true
date

if [[ $? -eq 0 ]] && [[ -s $realignmentfixbam ]]; 
	then 
		rm $realignmentbam
	else
		exit 1
fi

## base quality score recalibration
echo "####MESS Step 5: base quality score recalibration"
time java -Xmx16g -jar $GATK -T BaseRecalibrator \
        -I $realignmentfixbam \
        -R $reference \
        -knownSites $dbsnp \
        -o $baserecaldata

if ! [[ $? -eq 0 ]]; then exit 1; fi

echo "####MESS Step 5: print recalibrated reads into BAM"
time java -Xmx16g -jar $GATK -T PrintReads \
        -R $reference \
        -I $realignmentfixbam \
        -BQSR $baserecaldata \
        -o $recalioutbam

if [[ $? -eq 0 ]] && [[ -s $recalioutbam ]];
	then
		rm $realignmentfixbam \
        	$realignmentlist \
        	$baserecaldata
		find -name "Alignment/*$Sample*" ! -name "*recalib*" -delete
	else
   		exit 1;

fi
' >> $REALIGNJOB

if [[ $AUTOSTART -eq 1 ]]; then 
	echo autostarting pipeline
	qsub $READ1JOB
	qsub $READ2JOB
fi
