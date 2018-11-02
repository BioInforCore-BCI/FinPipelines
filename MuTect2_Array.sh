#!/bin/bash

today=`date +%Y-%m-%d`
DIR=$PWD
JOBNAME=Mutect2_Pipeline_$DIR
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
MUTECT2JOB=$JOBDIR/$JOBNAME-$today-mutect2.sh

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
#$ -wd $DIR      # Set the working directory for the job to the current directory
#$ -pe smp 1      # Request 1 cores - running multiple cores seems to cause issues.
#$ -l h_rt=120:0:0 # Request 120 hour runtime
#$ -l h_vmem=4G   # Request 4GB RAM per core
#$ -m a
#$ -o /data/autoScratch/weekly/hfx472/
#$ -j y
#$ -t 1-$MAX
#$ -N MuTect2_$JOBNAME
# TODO work out what times I need.

GATK=/data/home/hfx472/Software/GenomeAnalysisTK.jar
TEMP_FILES=/data/auoScratch/weekly/$USER
reference=$reference
" > $MUTECT2JOB

echo '
normalBams=(ls Alignment/*normal*.bam)
Patient=$(basename ${normalBams[${SGE_TASK_ID}]} | cut -d'.' -f 1)
normalBam=Alignment/$Patient*normal*.bam
tumourBam=Alignment/$Patient*tumour*.bam

module load java

if ! [[ -d VCF/Mutect2 ]]; then mkdir -p VCF/Mutect2/; fi

java -Xmx4g -jar ~/Software/GenomeAnalysisTK.jar \
        -T MuTect2 \
        -R $reference \
        -I:tumor $tumourBam \
        -I:normal $normalBam \
        -o VCF/Mutect2/$Patient.vcf || exit 1 

' >> $MUTECT2JOB

if [[ $AUTOSTART -eq 1 ]]; then
	echo Submitting array to the queue
	qsub $MUTECT2JOB
fi
