#!/bin/bash

## This script will create all the jobs needed to get variant calls from UMI tagged sequencing.
## N.B. be aware this script has not been written with WGS in mind, if you will have huge files look as restricting the number of concurrent jobs that can run. 
## This script creates array jobs that can be submitted to the Sun Grid Engine on Apocrita
## This script has been written by Findlay Bewicke-Copley August 2018

SuppScirptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"/SupplementaryScripts/
today=`date +%Y-%m-%d`
DIR=$PWD
jobName=UMI-VCF-$(basename $DIR)
BED=''
REFDIR=/data/BCI-Haemato/Refs/
## By Default use the hg37 reference genome
REF=GRCh37

## Job Constants
fastqSuffix=.fastq.gz
SETUP=0

##Software
GATK=/data/home/$USER/Software/GenomeAnalysisTK.jar
PICARD=/data/home/$USER/Software/picard.jar

AUTOSTART=0

## Process Arguments
while [ "$1" != "" ]; do
        case $1 in
		-a | --autostart )	AUTOSTART=1
					;;
		-n | --name )		shift
					jobName=$1
					;;
		-b | --bed )		shift
					BED=$1
					;;
		-d | --directory )	shift
					if [[ -d $1 ]]; then
					        DIR=$1
					        echo "Will run on files in $DIR"
					else
					        echo "Specified directory $1 doesn't exist"
					        exit 1
					fi
					;;
                -r | --ref )		shift
					if [[ -d $REFDIR/$1 ]]; then
						REF=$1
						echo reference $REF will be used
					else
						echo Reference Not Found
						exit 1
					fi
					;;
		-s | --setup )		SETUP=1
					;;
		-f | --fastq-suffix )	shift
					fastqSuffix=$1
					;;
		-h | --help )		echo "\
-a | --autostart	Automaticall start the jobs, holding jobs so they run in the correct order
-n | --name		Sets the job name (default - UMI-VCF-$PWD)
-b | --bed		Bed file for the project (default none - change this!)
-d | --directory	Root directory for the project
-r | --ref 		Reference directory for the project, look for this in BCI-Haemato/Refs (default GRCh37)
-s | --setup 		Run the set up (cat the files together and create sample directories) (default off)
-f | --fastq-suffix 	Suffix for the fastq files (default .fastq.gz)
-h | --help		Display this message"
					exit 1
					;;
	esac
	shift
done

#refIndex=/data/BCI-Haemato/Refs/GRCh37/BWA/hg37
#reference=/data/BCI-Haemato/Refs/GRCh37/hg37.fa
#dbsnp=/data/BCI-Haemato/Refs/GRCh37/dbsnp_137.hg19.no_chr_no_M.vcf

FILES=(ls $DIR/Alignment/*recalib.bam)
MAX=$(echo ${#FILES[@]})
MAX=$( expr $MAX - 1 )
TotalSAI=$( expr $MAX + $MAX )

## This automatically gets the correct reference files. This means reference directory structure is important.
REFDIR=$REFDIR/$REF
idxPre=( $REFDIR/BWA/* )
refIndex=$( echo $idxPre | cut -d'.' -f 1 )
reference=$( ls  $REFDIR/*.fa )
dbsnp=$( ls $REFDIR/*no_M.vcf )

# Job script files
#jobOutputDir=/data/scratch/$USER/
jobOutputDir=/data/scratch/$USER/
realignJob=$jobName\.01.realign.$today\.sh
varScanJob=$jobName\.02.varScan.$today\.sh
varFiltJob=$jobName\.03.varFilt.$today\.sh

echo "
#!/bin/sh
#$ -wd $DIR             # use current working directory
#$ -o /data/scratch/$USER/
#$ -j y                 # and put all output (inc errors) into it
#$ -m a                 # Email on abort
#$ -pe smp 1            # Request 1 CPU cores
#$ -l h_rt=24:0:0        # Request 24 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=4G         # Request 4G RAM / Core
#$ -t 1-$MAX            # run an array job of all the samples listed in FASTQ_Raw
#$ -N $jobName-Realign_Job

GATK=$GATK
PICARD=$PICARD
SuppScirptDir=$SuppScirptDir

reference=$reference
referenceindex=$refIndex
dbsnp=$dbsnp
BED=$BED" > $realignJob

echo '
module load java

Samples=(ls Alignment/*.bam)
## Extract the file name at the position of the array job task ID
Sample=$(basename ${Samples[${SGE_TASK_ID}]})
echo $Sample

consensusbam=Alignment/$Sample\.con.bam
realignmentlist=Alignment/$Sample\.bam.list
realignmentbam=Alignment/$Sample\.realigned.bam
realignmentfixbam=Alignment/$Sample\.fixed.bam
baserecaldata=Alignment/$Sample\.recal_data.grp
recalioutbam=Alignment/$Sample\.recalib.bam

## local alignment around indels
echo "####MESS Step 4: local alignment around indels"
echo "####MESS Step 4: first create a table of possible indels"
java -Xmx4g -jar $GATK -T RealignerTargetCreator \
	-R $reference \
	-o $realignmentlist \
	-I $consensusbam
if ! [[ $? -eq 0 ]]; then exit 1; fi
echo "####MESS Step 4: realign reads around those targets"
java -Xmx4g -Djava.io.tmpdir=/tmp -jar $GATK \
	-I $consensusbam \
	-R $reference \
	-T IndelRealigner \
	-targetIntervals $realignmentlist \
	-o $realignmentbam
if ! [[ $? -eq 0 ]]; then exit 1; fi
echo "####MESS Step 4: fix paired end mate information using Picard"
java -Djava.io.tmpdir=/tmp -jar $PICARD FixMateInformation \
	INPUT=$realignmentbam \
	OUTPUT=$realignmentfixbam \
	SO=coordinate \
	VALIDATION_STRINGENCY=LENIENT \
	CREATE_INDEX=true
date
if ! [[ $? -eq 0 ]]; then exit 1; fi
## base quality score recalibration
echo "####MESS Step 5: base quality score recalibration"
java -Xmx4g -jar $GATK -T BaseRecalibrator \
	-I $realignmentfixbam \
	-R $reference \
	-knownSites $dbsnp \
	-o $baserecaldata
if ! [[ $? -eq 0 ]]; then exit 1; fi
echo "####MESS Step 5: print recalibrated reads into BAM"
java -jar $GATK -T PrintReads \
	-R $reference \
	-I $realignmentfixbam \
	-BQSR $baserecaldata \
	-o $recalioutbam
date

if ! [[ $? -eq 0 ]]; then exit 1; fi

$SuppScirptDir/get_coverage_targeted_regions.sh $BED
perl $SuppScirptDir/get_coverage_info.pl $BED
' >> $realignJob

echo "
#!/bin/sh
#$ -wd $DIR             # use current working directory
#$ -o /data/scratch/$USER/
#$ -j y                 # and put all output (inc errors) into it
#$ -m a                 # Email on abort
#$ -pe smp 8            # Request 1 CPU cores
#$ -l h_rt=24:0:0        # Request 8 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=4G         # Request 4G RAM / Core
#$ -t 1-$MAX
#$ -N $jobName-Varscan_Job

BED=$BED
" > $varScanJob

echo '
module load samtools
module load annovar
module load java

## Constants
varScan=/data/home/$USER/Software/VarScan/VarScan.v2.4.3.jar
refGenome=/data/BCI-Haemato/Refs/GRCh37/hg37.fa

if ! [[ -d VCF/ ]]; then mkdir VCF/; fi

## get recalibrated Bam file
Samples=(ls Alignment/*recalib.bam)
## Extract the file name at the position of the array job task ID
Sample=$(basename ${Samples[${SGE_TASK_ID}]})
echo $Sample

## Output Files
outSnp=VCF/$Sample\_snp.vcf
outIndel=VCF/$Sample\_indel.vcf
outSnp_fil=VCF/$Sample\.pass.snp.vcf
outIndel_fil=VCF/$Sample\.pass.indel.vcf
$Bam=Alignment/$Sample\.recalib.bam

time samtools mpileup -B -q 40 -l $BED -f $refGenome $Bam |
java -jar $varScan mpileup2snp \
	--min-coverage 20 \
        --min-avg-qual 20 \
	--min-read2 4 \
        --p-value 1 \
        --min-var-freq 0.01 \
        --strand-filter 1 \
        --output-vcf 1 > $outSnp

time samtools mpileup -B -q 40 -l $BED -f $refGenome $Bam |
java -jar $varScan mpileup2indel \
	--min-coverage 20 \
        --min-avg-qual 20 \
	--min-read2 4 \
        --p-value 1 \
        --min-var-freq 0.01 \
        --strand-filter 1 \
        --output-vcf 1 > $outIndel

echo converting to annovar input 
convert2annovar.pl --format vcf4 $outSnp --includeinfo --filter PASS --withzyg --outfile $outSnp_fil
convert2annovar.pl --format vcf4 $outIndel --includeinfo --filter PASS --withzyg --outfile $outIndel_fil
' >> $varScanJob

echo "
#!/bin/sh
#$ -wd $DIR             # use current working directory
#$ -o /data/scratch/$USER/
#$ -j y                 # and put all output (inc errors) into it
#$ -m a                 # Email on abort
#$ -pe smp 1            # Request 1 CPU cores
#$ -l h_rt=24:0:0        # Request 8 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=4G         # Request 4G RAM / Core
#$ -N $jobName-VarFilt_Job
SuppScirptDir=$SuppScirptDir" > $varFiltJob

echo '
# Combine the first 8 columns, remove duplicates ignoring the 8th column and store in Combined.Unique.vcf
# Need 8 columns for annovar or it throws a fit. Can just get rid of it in a bit.
VARIANTS=VCF/
Combo_vcf=$VARIANTS/Combined.Unique.vcf
Combo_avinput=$VARIANTS/Combined.Unique.avinput
AnnoFilt=$VARIANTS/Annotation.filter
Refs=/data/BCI-Haemato/Refs/

cat $VARIANTS/*.pass.* |  sort -Vuk 1,5 > $Combo_avinput

module load annovar

#Filter out mutations from 1000g2015aug_all with maf > 0.01
annotate_variation.pl -filter -dbtype 1000g2015aug_all -buildver hg19 \
        -out $AnnoFilt $Combo_avinput $Refs/humandb/ \
        -maf 0.01

#Filter our mutations in esp6500siv2_all with maf > 0.01
annotate_variation.pl -filter -dbtype esp6500siv2_all -buildver hg19 \
        -out $AnnoFilt $VARIANTS/Annotation.filter.hg19_ALL.sites.2015_08_filtered $Refs/humandb/ \
        -score_threshold 0.01

# Annotate the VCF giving Refgene, clinvar, rs name, comicID, exac03, fathmm prediction and cytoband
table_annovar.pl $VARIANTS/Annotation.filter.hg19_esp6500siv2_all_filtered $Refs/humandb/ -buildver hg19 -out $VARIANTS/Annotation.out -remove \
        -protocol ensGene,refgene,clinvar_20170905,snp142,cosmic70,exac03,dbnsfp33a,cytoband \
        -operation g,g,f,f,f,f,f,r -nastring .

# check lines against varscan output (filtered for "PASS")
# if variant found copy the line to the file with the annotations.
cd $VARIANTS # TODO make it so this doesnt need to be run in the directory.
python $SuppScirptDir/get_mutation_info.py

# filter out all non exonic/splicing variants
grep "exonic\|splicing" get_mutation_info.out.txt | sort -V > Variants.exon.filter.txt
grep -v "exonic\|splicing" get_mutation_info.out.txt | sort -V > Variants.intron.filter.txt

# Grab Header, add sample and varinf
head -n 1 Annotation.out.hg19_multianno.txt |
        cut -f 1,2,3,4,5,6,7,12,8,9,10,16,21,22,23,31,33,34,36,37,39,97 |
        sed " 1 s/.*/&\tSample\tCount\tGenotype\tVarinf/" | 
	tee Variants.exon.filter.cut.txt Variants.intron.filter.cut.txt

# Cut unwanted columns
cat Variants.exon.filter.txt |
        cut -f 1,2,3,4,5,6,7,8,9,10,12,16,21,22,23,31,33,34,36,37,39,97,98,99,105,117 >> Variants.exon.filter.cut.txt
cat Variants.intron.filter.txt |
        cut -f 1,2,3,4,5,6,7,8,9,10,12,16,21,22,23,31,33,34,36,37,39,97,98,99,105,117 >> Variants.intron.filter.cut.txt

if [[ $? -eq 0 ]]; then
	rm Variants.exon.filter.txt Variants.intron.filter.txt
fi

Rscript $SuppScirptDir/VariantFix.r
' >> $varFiltJob

if [[ $AUTOSTART -eq 1 ]]; then
	echo Starting the jobs. Good luck!
	qsub $realignJob
	qsub -hold_jid $jobName-Realign_Job $varScanJob
	qsub -hold_jid $jobName-Varscan_Job $varFiltJob
fi
