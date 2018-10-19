#!/bin/bash
today=`date +%Y-%m-%d`

DIR=$PWD
JOBNAME=FASTQC
MODE=fastq
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
		-m | --mode )		shift
					MODE=$1
					echo MODE set to $MODE
					;;
		-h | --help )		echo "\
-a | --auto-start	Automatically start the jobs on creation (default off)
-n | --name		The name for the job (default FASTQC)
-d | --directory	The root directory for the project (default $PWD)
-m | --mode		Switches the files to run on (default fastq)
-h | --help		Display this message and exit"
					exit 1
					;;
        esac
        shift
done

if [[ $MODE == fastq ]]; then
	FILEDIR=FASTQ_Raw/*/*
elif [[ $MODE == bam ]]; then
	FILEDIR=Alignment/*.bam
else
	echo Invalid MODE selected. Please choose either fastq or bam
fi

# Get the number of files
FILES=( ls $FILEDIR )
MAX=$(echo ${#FILES[@]})
MAX=$( expr $MAX - 1 )

JobScript=$DIR/Fastqc-$today-array.sh

echo "
#!/bin/sh
#$ -wd $DIR		# use current working directory
#$ -V			# this makes it verbose
#$ -o $jobOutputDir	# specify an output file
#$ -j y			# and put all output (inc errors) into it
#$ -m a			# Email on abort
#$ -pe smp 1		# Request 1 CPU cores
#$ -l h_rt=48:0:0	# Request 48 hour runtime (This shouldn't last more than a few minutes but in the case of large fastq might take longer)
#$ -l h_vmem=4G		# Request 4G RAM / Core
#$ -t 1-$MAX		# run an array job of all the samples listed in FASTQ_Raw
#$ -N fastqc-$JOBNAME

FILEDIR=$FILEDIR" > $JobScript

echo '

if ! [[ -f QC/ ]]; then mkdir QC; fi

module load fastqc
## Get all the sample names from FASTQ_Raw
Files=(ls FASTQ_Raw/*/*)
## Extract the file name at the position of the array job task ID
File=$(basename ${Files[${SGE_TASK_ID}]})

fastqc -o QC/ -f $File
' >> $JobScript

if [[ $AUTOSTART -eq 1 ]]; then
	qsub $JobScript
fi

