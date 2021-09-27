#!/bin/bash
today=`date +%Y-%m-%d`

SuppScirptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"/SupplementaryScripts/
DIR=$PWD
JOBNAME=HTSEQ_Count
FILES=(ls $(find Alignment/ -name "*.bam") )
MAX=$(echo ${#FILES[@]})
MAX=$( expr $MAX - 1 )
GTF=/data/home/$USER/BCI-Haemato/Refs/GRCh38/Annotation/hg38.gtf

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
                -g | --gtf )		shift
					GTF=$1
                			;;
                -h | --help )           echo "\
-a | --auto-start               Automatically start the jobs on creation (default off)
-n | --name                     The name for the job (default BWA_Align)
-d | --directory                The root directory for the project (default $PWD)
-g | --gtf			gtf file (default GRCh38/Annotation/hg38.gtf)
-h | --help                     Display this message and exit"
                                        exit 1

                                        ;;
        esac
        shift
done

HTSEQ=$DIR/HTSEQ_$JOBNAME\_count_array_$today\.sh

echo "
#!/bin/sh
#$ -wd $DIR							# set working directory
#$ -o /data/scratch/$USER/
#$ -j y                 					# and put all output (inc errors) into it
#$ -m a                 					# Email on abort
#$ -pe smp 1            					# Request 1 CPU cores
#$ -l h_rt=120:0:0						# Request 120 hour runtime
#$ -l h_vmem=4G							# Request 4G RAM / Core
#$ -t 1-$MAX							# Run an array of $MAX jobs 
#$ -N $JOBNAME-HTSEQ						# Set Jobname

JOBNAME=$JOBNAME
SuppScirptDir=$SuppScirptDir
refGTF=$GTF
MAX=$MAX
source /data/home/$USER/envs/htseq-count/bin/activate
" > $HTSEQ

echo ' 
if ! [[ -d Expression ]]; then mkdir Expression; fi

BAMS=( ls  $(find Alignment/ -name "*.bam") )
BAM=${BAMS[SGE_TASK_ID]}
SAMPLE=$(basename $BAM | cut -d'.' -f 1)
if ! [[ -s Expression/$SAMPLE\.Counts.txt ]];
then
	echo Now processing $BAM
	
	htseq-count -f bam -s reverse $BAM $refGTF >> Expression/$SAMPLE\.Counts.txt
else
	echo output file found. Have you already run this sample?
fi

deactivate

if [[ $(ls Expression/*Counts.txt | wc -l ) -eq $MAX ]] &&
	[[ $(qstat -r | grep Full | grep $JOBNAME-HTSEQ | wc -l) -eq 1 ]];

then
	awk -f $SuppScirptDir/Combine.awk Expression/*.Counts.txt > Expression/Counts.Combo.txt
fi
' >>  $HTSEQ

