#!/bin/bash

today=`date +%Y-%m-%d`
DIR=$PWD
JOBNAME=Seqz_Pipeline_$DIR
## Location of reference files
REFDIR=/data/BCI-Haemato/Refs/
## By Default use the hg37 reference genome
REF=GRCh37
ScirptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
AUTOSTART=0
CONTROL="normal"
TUMOUR="tumour"

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
		-c | --control )	CONTROL=$1
					;;
		-t | --tumour )		TUMOUR=$1
					;;
                -h | --help )           echo "\
-a | --auto-start               Automatically start the jobs on creation (default off)
-n | --name                     The name for the job (default BWA_Align)
-d | --directory                The root directory for the project (default $PWD)
-r | --refdir                   Directory in BCI-Haemato/Refs containing the reference (default GRCh37/)
-c | --control			Control sample ID (default normal)
-t | --tumour			Tumour sample ID (default tumour can also be tumor is americans are involved)
-h | --help                     Display this message and exit"
                                        exit 1
                                        ;;
        esac
        shift
done

varScan=/data/home/$USER/Software/VarScan/VarScan.v2.4.3.jar

## Output job script in project root dir
JOBDIR=$DIR
VarscanJob=$JOBDIR/$JOBNAME-$today-Varscan4Seqz.sh

## Location of correct version of reference
REFDIR=$REFDIR/$REF
## This automatically gets the correct reference as long as it is the only .fa file in the directory.
reference=$( ls  $REFDIR/*.fa )

# Get max number of files. 
normalBams=(ls $DIR/Alignment/*$CONTROL*.bam)
MAX=$(echo ${#normalBams[@]})
MAX=$( expr $MAX - 1 )

echo "
#!/bin/sh
#$ -wd $DIR				# use current working directory
#$ -V                   		# this makes it verbose
#$ -o /data/scratch/$USER   # specify an output file
#$ -j y                 		# and put all output (inc errors) into it
#$ -m a                 		# Email on abort
#$ -pe smp 1            		# Request 1 CPU cores
#$ -l h_rt=120:0:0        		# Request 120 hour runtime 
#$ -l h_vmem=12G 			# Request 4G RAM / Core
#$ -t 1-$MAX				# Set array limits
#$ -N $JOBNAME				# Job Name

varScan=varScan
reference=$reference
CONTROL=$CONTROL
TUMOUR=$TUMOUR
" > $VarscanJob

echo '

if ! [[ -d VCF/ ]]; then mkdir VCF; fi
if ! [[ -d VCF/ForSeqz/ ]]; then mkdir VCF/ForSeqz/; fi

BAMLIST=(ls $(find Alignment/ -name "*$CONTROL*.bam"))
normalBam=${BAMLIST[${SGE_TASK_ID}]}
tumourBam=$(echo $(dirname $normalBam )/*$TUMOUR*.bam)
## You will need to edit this potentially to get the patient ID
Patient=$(basename $normalBam | cut -d'.' -f 1)
snpOut=VCF/ForSeqz/$Patient\.snp.vcf
indelOut=VCF/ForSeqz/$Patient\.indel.vcf
copynumberOut=VCF/ForSeqz/$Patient\.cnv.vcf

if ! [[ -f $normalBam ]] || ! [[ -f $tumourBam ]]; then
	echo one or more files not found, exiting
fi
module load java
module load samtools

time samtools mpileup -B -q 40 -f $reference $normalBam $tumourBam |
java -jar -Xmx16g $varScan somatic \
	--output-snp=$snpOut \
	--output-indel=$indelOut \
	--mpileup 1

echo Creating pileup for $Patient
echo file will be saved as $copynumberOut
time samtools mpileup -B -q 40 -f $reference $normalBam $tumourBam |
java -jar -Xmx16g $varScan copynumber - \
	$copynumberOut \
	--mpileup 1
' >> $VarscanJob

if [[ $AUTOSTART -eq 1 ]]; then 
        echo Submitting array to the queue 
        qsub $VarscanJob 
fi 

