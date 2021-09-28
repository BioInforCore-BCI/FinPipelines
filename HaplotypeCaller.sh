#!/bin/bash

today=`date +%Y-%m-%d`
DIR=$PWD
JOBNAME=Mutect2_Pipeline_$DIR
## Location of reference files
REFDIR=/data/BCI-Haemato/Refs/
## By Default use the hg37 reference genome
REF=GRCh38
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
-r | --refdir			Directory in BCI-Haemato/Refs containing the reference (default $REF)
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
#$ -o /data/scratch/$USER/
#$ -j y
#$ -t 1-$MAX
#$ -N MuTect2_$JOBNAME
# TODO work out what times I need.

TEMP_FILES=/data/auoScratch/weekly/$USER
reference=$reference
" > $MUTECT2JOB

echo '
Controls=( ls $(find Alignment/ -name "*control*.bam") )
normalBam=${Controls[SGE_TASK_ID]}
Patient=$( echo $normalBam | cut -d'_' -f 2 )
tumourBam=$(find Alignment/ -name "tumor*$Patient*bam" ) ||
        { echo No tumour bam found; exit 1; }

echo Normal File: $normalBam
echo Tumour File: $tumourBam

if [[ -s VCF/HaplotypeCaller/$Patient\.vcf ]]; then
        echo VCF already exists. Either you have run this already or there is a problem.
        exit 1
fi

module load gatk/4.1.6.0
module load annovar

if ! [[ -d VCF/HaplotypeCaller ]]; then mkdir -p VCF/HaplotypeCaller/; fi

time gatk --java-options "-Xmx4g" HaplotypeCaller \
        -R $reference \
        -I $tumourBam \
        -O VCF/HaplotypeCaller/$Patient.vcf 
	-ERC GVCF || exit 1 

time gatk --java-options "-Xmx4g" GenotypeGVCFs \
        -R $reference \
        -V VCF/HaplotypeCaller/$Patient.vcf \
        -O VCF/HaplotypeCaller/$Patient.Geno.vcf || exit 1

time gatk VariantFiltration \
	-V VCF/HaplotypeCaller/$Patient.Geno.vcf \
	-O VCF/HaplotypeCaller/$Patient.filter.vcf | exit 1


time convert2annovar.pl -format vcf4 \
	-filter PASS \
	--includeinfo \
	--withfreq \
	VCF/HaplotypeCaller/$Patient.filter.vcf \
	-outfile VCF/HaplotypeCaller/$Patient.pass.vcf



' >> $MUTECT2JOB

if [[ $AUTOSTART -eq 1 ]]; then
	echo Submitting array to the queue
	qsub $MUTECT2JOB
fi
