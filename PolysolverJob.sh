#!/bin/bash

today=`date +%Y-%m-%d`
DIR=$PWD
JOBNAME=Polysolver_Pipeline_$DIR
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
POLYJOB=$JOBDIR/$JOBNAME-$today-Polysolver.sh

## Location of correct version of reference
REFDIR=$REFDIR/$REF
## This automatically gets the correct reference as long as it is the only .fa file in the directory.
reference=$( ls  $REFDIR/*.fa )

# Get max number of files. 
normalBams=(ls $DIR/Alignment/*normal*.bam)
MAX=$(echo ${#normalBams[@]})
MAX=$( expr $MAX - 1 )

echo "
#!/bin/sh
#$ -wd $DIR		# Set the working directory for the job to $DIR
#$ -pe smp 1		# 1 cores
#$ -l h_rt=48:0:0	# Request 48 hour runtime. Over estimated for now, change later.
#$ -l h_vmem=4G         # Request 4GB RAM PER CORE
#$ -m a                 # email on abort
#$ -o /data/autoScratch/weekly/hfx472/
#$ -j y
#$ -t 1-$MAX
#$ -N $JobName\_Polysolver
" > $POLYJOB

echo '
## This script will look at the normal bam files and extract a prefix that will identify them and their tumour pair.
## If this prefix does not exist this will cause problems.
## Ensure you have a prefix at the start of your files to identify patients followed by a period
## TODO - Make this smarter. Maybe allow a file to be submitted which contains the pairing?
normalBams=(ls $DIR/Alignment/*normal*.bam)
Patient=$(basename ${normalBams[${SGE_TASK_ID}]} | cut -d'.' -f 1)
normalBam=$DIR/Alignment/$Patient*normal*.bam
tumourBam=$DIR/Alignment/$Patient*tumour*.bam

if ! [[ -d HLA_Type ]]; then mkdir HLA_Type; fi
if ! [[ -d HLA_Type/$Patient ]]; then mkdir HLA_Type/$Patient ; fi

source activate polysolver

time shell_call_hla_type $normalBam Unknown 1 hg19 STDFQ 0 HLA_Type/$Patient

mv HLA_Type/$Patient/winners.hla.txt HLA_Type/$Patient/Normal.hla.txt

find HLA_Type/$Patient ! -name "*hla.txt" -delete
' >> $POLYJOB

if [[ $AUTOSTART -eq 1 ]]; then
        echo Submitting the job to the queue
        qsub $POLYJOB
fi                 
~                      
