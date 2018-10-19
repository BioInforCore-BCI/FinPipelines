#!/bin/bash
today=`date +%Y-%m-%d`

DIR=$PWD
JOBNAME=BWA_Align
FILES=(ls FASTQ_Raw/*/*)
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
		-h | --help )		echo "\
-a | --auto-start 		Automatically start the jobs on creation (default off)
-n | --name 	           	The name for the job (default BWA_Align)
-d | --directory 	      	The root directory for the project (default $PWD)
-h | --help 			Display this message and exit"
					exit 1
					;;
        esac
        shift
done

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
#$ -N fastqc-$JOBNAME " > $JobScript

echo '

if ! [[ -f QC/ ]]; then mkdir QC; fi

module load fastqc
## Get all the sample names from FASTQ_Raw
FASTQS=(ls FASTQ_Raw/*/*)
## Extract the file name at the position of the array job task ID
FASTQ=$(basename ${FASTQS[${SGE_TASK_ID}]})

fastqc -o QC/ -f $FASTQ
' > $JobScript

