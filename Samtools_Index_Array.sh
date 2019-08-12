## Pass this script the file you want to index and it will send an indexing job to the scheduler
#!/bin/bash

today=`date +%Y-%m-%d`
DIR=$PWD
JOBNAME=Samtools_Index
AUTOSTART=1

while [ "$1" != "" ]; do
        case $1 in
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
                -h | --help )           echo "\
-n | --name			The name for the job (default BWA_Align)
-d | --directory		The root directory for the project (default $PWD)
-h | --help			Display this message and exit"
                                        exit 1
                                        ;;
        esac
        shift
done

JOBDIR=$DIR
SAMTOOLSJOB=$JOBDIR/$JOBNAME-$today-samtools_index.sh

Bams=(ls $DIR/Alignment/*.bam)
MAX=$(echo ${#Bams[@]})
MAX=$( expr $MAX - 1 )

echo "
#!/bin/bash
#$ -wd $DIR		# set current working dir
#$ -pe smp 1		# Can't multithread
#$ -l h_rt=4:0:0	# Should only take a few hours, ask for 4 to be safe.
#$ -l h_vmem=1G		# Shouldn't need much ram ask for 1 G
#$ -o /data/scratch/$USER/
#$ -j y			# Join error and output
#$ -m a			# Email on abort
#$ -t 1-$MAX		# Set as array
#$ -N $JOBNAME-samtools

module load samtools
" >  $SAMTOOLSJOB

echo '
Bams=(ls Alignment/*.bam)
Bam=${Bams[${SGE_TASK_ID}]}

samtools index $Bam
' >>  $SAMTOOLSJOB

qsub $SAMTOOLSJOB
