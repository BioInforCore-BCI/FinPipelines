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
#$ -cwd           # Set the working directory for the job to the current directory
#$ -pe smp 1      # Request 1 cores - running multiple cores seems to cause issues.
#$ -l h_rt=24:0:0 # Request 24 hour runtime
#$ -l h_vmem=4G   # Request 4GB RAM per core
#$ -m a
#$ -o /data/home/hfx472/.JobOutput
#$ -e /data/home/hfx472/.JobOutput
#$ -N MuTect2_${CHROM[$index]}
# TODO work out what times I need.

GATK=/data/home/hfx472/Software/GenomeAnalysisTK.jar
TEMP_FILES=/data/auoScratch/weekly/hfx472
export reference=$reference
" > MUTECT2JOB

echo '

normalBams=(ls $DIR/Alignment/*normal*.bam)
export Patient=$(basename ${normalBams[${SGE_TASK_ID}]} | cut -d'.' -f 1)
export normalBam=$DIR/Alignment/$Patient*normal*.bam
export tumourBam=$DIR/Alignment/$Patient*tumour*.bam

Chrom=(  $( cat $reference'.fai' | cut -f 1 )  )

module load parallel

Mutect2() {

java -Xmx4g -jar ~/Software/GenomeAnalysisTK.jar \
        -T MuTect2 \
        -R $reference \
        -I:tumor $tumorBAM \
        -I:normal $normalBAM \
        -o $DIR/VCF/Mutect2/$Patient'_'$1.vcf \
	-L $1 || exit 1 

}

export -f Mutect2

time parallel -j 8 varScan ::: ${Chrom[@]}
' >> MUTECT2JOB
