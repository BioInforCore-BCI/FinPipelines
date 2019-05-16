#!/bin/bash

today=`date +%Y-%m-%d`
DIR=$PWD
JOBNAME=Strelka_Pipeline
## Location of reference files
REFDIR=/data/BCI-Haemato/Refs/
## By Default use the hg37 reference genome
REF=GRCh37
ScirptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
AUTOSTART=0

while [ "$1" != "" ]; do
        case $1 in
                -a | --auto-start )     AUTOSTART=1
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
                -r | --refdir )         shift
                                        if [[ -d $REFDIR/$1 ]]; then
                                                REF=$1
                                                echo reference $REF will be used
                                        else
                                                echo Reference Not Found
                                                exit 1
                                        fi
                                        ;;
                -h | --help )           echo "\
-a | --auto-start		Automatically start the jobs on creation (default off)
-n | --name			The name for the job (default BWA_Align)
-d | --directory		The root directory for the project (default $PWD)
-r | --refdir			Directory in BCI-Haemato/Refs containing the reference (default GRCh37/)
-h | --help			Display this message and exit"
                                        exit 1
                                        ;;
        esac
        shift
done

## Output job script in project root dir
JOBDIR=$DIR
STRELKAJOB=$JOBDIR/$JOBNAME-$today-strelka.sh

## Location of correct version of reference
REFDIR=$REFDIR/$REF
## This automatically gets the correct reference as long as it is the only .fa file in the directory.
reference=$( ls  $REFDIR/*.fa )

# Get max number of files. 
normalBams=(ls $DIR/Alignment/*normal*.bam)
MAX=$(echo ${#normalBams[@]})
MAX=$( expr $MAX - 1 )

echo "
#!/bin/bash
#$ -wd $DIR		# Set the working directory for the job to the current directory
#$ -pe smp 8		# 8 cores
#$ -l h_rt=4:0:0	# Request 10 hours First run tool ~6 hours so leave a bit of a buffer
#$ -l h_vmem=4G		# Request 4GB RAM PER CORE
#$ -m a			# email on abort
#$ -o /data/scratch/$USER/
#$ -j y			# Join output
#$ -t 1-$MAX		# Run as an array
#$ -N Strelka-$JOBNAME

STRELKA=/data/home/$USER/Software/strelka-2.9.4/bin/configureStrelkaSomaticWorkflow.py
DIR=$DIR
reference=$reference
" > $STRELKAJOB

echo '
## This script will look at the normal bam files and extract a prefix that will identify them and their tumour pair.
## If this prefix does not exist this will cause problems.
## Ensure you have a prefix at the start of your files to identify patients followed by a period
## TODO - Make this smarter. Maybe allow a file to be submitted which contains the pairing?
normalBams=(ls $DIR/Alignment/*normal*.bam)
Patient=$(basename ${normalBams[${SGE_TASK_ID}]} | cut -d'.' -f 1)
normalBam=$DIR/Alignment/$Patient*normal*.bam
tumourBam=$DIR/Alignment/$Patient*tumour*.bam

if ! [[ -d $DIR/VCF ]]; then mkdir $DIR/VCF

echo Configuring Strelka workflow

## Configure strelka to run on the bam files taken from above.
## Output directory is set to be the Patient directory inside of the VCF file.
## if it fails, exit with status 1
time $STRELKA \
        --normalBam $normalBam \
        --tumorBam $tumourBam \
        --ref $reference  \
        --runDir $DIR/VCF/$Patient || exit 1

## Run Strelka on 8 cores
## if it fails exit with status 1 
echo running Strelka
time $DIR/VCF/$Patient/runWorkflow.py -m local -j 8 || exit 1
' >> $STRELKAJOB

if [[ $AUTOSTART -eq 1 ]]; then
        echo Submitting the job to the queue
        qsub $STRELKAJOB
fi                 
