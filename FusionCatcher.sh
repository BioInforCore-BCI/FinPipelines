#!/bin/sh
today=`date +%Y-%m-%d`

DIR=$PWD
JOBNAME=Fusion_Catcher_Array_Job

AUTOSTART=0
fastqDIR=FASTQ_Raw/
REFDIR=/data/BCI-Haemato/Refs/FusionCatcher_Build_hg38/current

while [ "$1" != "" ]; do
        case $1 in
		-a | --auto-start )	AUTOSTART=1
					;;
                -n | --name )           shift
                                        JOBNAME=$1
                                        ;;
		-f | --fastqDIR )	shift
					fastqDIR=$1
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
-f | --fastqDIR			The folder your FASTQ files are stored in (default $fastqDIR)
-d | --directory 	      	The root directory for the project (default $PWD)
-r | --refdir 			Directory in BCI-Haemato/Refs containing the reference (default GRCh37/)
-h | --help 			Display this message and exit"
					exit 1
					;;
        esac
        shift
done

FILES=(ls $DIR/$fastqDIR/*)
MAX=$(echo ${#FILES[@]})
MAX=$( expr $MAX - 1 )

echo "
#!/bin/sh
#$ -wd $DIR			# Set wd
#$ -V                   	# this makes it verbose
#$ -o /data/scratch/hfx472/
#$ -j y                 	# and put all output (inc errors) into it
#$ -m a                 	# Email on abort
#$ -pe smp 1            	# Request 1 CPU cores
#$ -l h_rt=240:0:0
#$ -l h_vmem=36G		# Request 4G RAM / Core
#$ -t 1-$MAX			# run an array job of all the samples listed in FASTQ_Raw
##$ -tc 10			# You may want to set a maximum number of concurrant tasks.
#$ -N Poor_Risk_Fusion

FOLDERS=( ls $fastqDIR/* )
REFDIR=$REFDIR
" > $DIR/$JOBNAME_FC_Array.sh

echo '
FOLDER=${FOLDERS[${SGE_TASK_ID}]}
sample=$(basename $FOLDER)

mkdir -p Fusion/$sample/

time ~/Software/fusioncatcher/bin/fusioncatcher \
	-d $REFDIR \
	-i $FOLDER \
	-p 1 \
	-o Fusion/$sample
' >> $DIR/$JOBNAME_FC_Array.sh

if [[ $AUTOSTART -eq 1 ]]; then
	echo autostarting Fusion Catcher
	qsub $DIR/$JOBNAME_FC_Array.sh
fi
