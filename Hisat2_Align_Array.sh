
#!/bin/bash
today=`date +%Y-%m-%d`

DIR=$PWD
JOBNAME=HiSat2_Align
FILES=(ls FASTQ_Raw/*)
MAX=$(echo ${#FILES[@]})
MAX=$( expr $MAX - 1 )
TotalSAI=$( expr $MAX + $MAX )

REFDIR=/data/BCI-Haemato/Refs/
## By Default use the hg38 reference genome
REF=GRCh38

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
-n | --name 	           	The name for the job (default Hisat2_Align)
-d | --directory 	      	The root directory for the project (default $PWD)
-r | --refdir 			Directory in BCI-Haemato/Refs containing the reference (default GRCh37/)
-h | --help 			Display this message and exit"
					exit 1
					;;
        esac
        shift
done

REFDIR=$REFDIR/$REF

## This automatically gets the correct reference files. This means reference directory structure is important.
idxPre=( $REFDIR/Hisat2/*.ht2 )
referenceindex=$( echo $idxPre | cut -d'.' -f 1 )
refSites=$REFDIR/Hisat2/splice_sites.txt
reference=$( ls  $REFDIR/*.fa )

## Store job files in the job directory.
JOBDIR=$DIR

HISAT2JOB=$JOBDIR/$JOBNAME-$today-hisat2.sh

echo "
#!/bin/sh
#$ -wd $DIR		# use current working directory
#$ -V                   # this makes it verbose
#$ -o /data/autoScratch/weekly/$USER/        # specify an output file - change 'outputfile.out'
#$ -j y                 # and put all output (inc errors) into it
#$ -m a
#$ -pe smp 4		# Request 4 CPU cores
#$ -l h_rt=12:0:0	# Request 12 hour runtime (upto 240 hours)
#$ -l h_vmem=4G		# Request 4GB RAM / core
#$ -t 1-$MAX
#$ -N Hisat2-$JOBNAME-$today

HISAT2=/data/home/$USER/Software/hisat2-2.1.0/hisat2
referenceindex=$referenceindex
refSites=$refSites
DIR=$DIR
" > $HISAT2JOB

echo '
if ! [ -d $DIR/Alignment ]; then
	mkdir $DIR/Alignment
fi

module load samtools

FASTQ_Raw=( ls FASTQ_Raw/* )
Sample=${FASTQ_Raw[${SGE_TASK_ID}]}

READ1=$Sample/*R1*
READ2=$Sample/*R2*
outBam=$DIR/Alignment/$(basename $Sample).bam

time $HISAT2 -p 4 \
	--dta \
	-x $referenceindex \
	--known-splicesite-infile $refSites \
	-1 $READ1 \
	-2 $READ2 |
	samtools view -Shbu - |
	samtools sort -@ 4 -n -o $outBam -
' >> $HISAT2JOB

if [[ $AUTOSTART -eq 1 ]]; then
	echo Starting the job.
	qsub $HISAT2JOB
fi
