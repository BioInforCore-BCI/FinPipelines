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
-a | --autostart	Automaticall start the job
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

## This automatically gets the correct reference files. This means reference directory structure is important.
REFDIR=$REFDIR/$REF
idxPre=( $REFDIR/BWA/* )
refIndex=$( echo $idxPre | cut -d'.' -f 1 )
reference=$( ls  $REFDIR/*.fa )
dbsnp=$( ls $REFDIR/*no_M.vcf )

# Job script files
#jobOutputDir=/data/autoScratch/weekly/hfx472/
jobOutputDir=$DIR/
trimJob=$jobOutputDir$jobName\.01.Trim_Job.$today\.sh
alignJob=$jobOutputDir$jobName\.02.Align_Job.$today\.sh
fgbioJob=$jobOutputDir$jobName\.03.fgbio_Job.$today\.sh
fastqconJob=$jobOutputDir$jobName\.04.fastqCon_Job.$today\.sh
conAlignJob=$jobOutputDir$jobName\.05.ConAlign_Job.$today\.sh
realignJob=$jobOutputDir$jobName\.06.realign.$today\.sh
varScanJob=$jobOutputDir$jobName\.07.varScan.$today\.sh
varFiltJob=$jobOutputDir$jobName\.08.varFilt.$today\.sh

##
# Set up the directory structure (don't run this as a job as it is needed to find MAX for sample numbers.)
# Shouldn't take long. ENSURE this is run on an interactive machine and not the login node. 
##

if [[ SETUP -eq 1 ]] && ! [[ -d FASTQ_TRIM ]] && ! [[ -d FASTQ_Con ]]; then
	# I like to keep each samples FASTQ file in a directory called SAMPLE NAME
	# This makes it easy to grab sample names in the future as you just get all the directories in the FASTQ folder
	for file in $DIR/FASTQ_Raw/*L001_R1*;

		# Get the name of the sample by cutting off the rest of the filename for lane 1 read 1
		do sample=$(basename $file | awk -F '_L00' '{print $1}' );
		echo $sample
		
		mkdir $DIR/FASTQ_Raw/$sample;
		cat $DIR/FASTQ_Raw/$sample*R1* > $DIR/FASTQ_Raw/$sample/$sample\_R1.fastq.gz;
	        cat $DIR/FASTQ_Raw/$sample*R2* > $DIR/FASTQ_Raw/$sample/$sample\_UMI.fastq.gz;
	        cat $DIR/FASTQ_Raw/$sample*R3* > $DIR/FASTQ_Raw/$sample/$sample\_R2.fastq.gz;

		if [[ $? -eq 0 ]]; 
			then rm $DIR/FASTQ_Raw/$sample*$fastqSuffix
		else 
			exit 1;
		fi

	done
fi

# Guess at the max number of samples TODO I should probably change this to be input on formation as this requires the samples to have been sorted already.
# ls doesn't actually do anything here, except occupy the first space [0] in the array. Without it ${FILES[1]} returns the second sample etc ...
# However this is inelegant and means that I have to remove 1 from the count
# Really I should be removing one from the task ID. TODO make this more elegant not a bodge.
FILES=(ls FASTQ_Raw/*)
MAX=$(echo ${#FILES[@]})
MAX=$( expr $MAX - 1 )
##
# Trimming Job
##

echo "
#!/bin/sh
#$ -wd $DIR		# use current working directory
#$ -V			# this makes it verbose
#$ -o $jobOutputDir	# specify an output file
#$ -j y			# and put all output (inc errors) into it
#$ -m a			# Email on abort
#$ -pe smp 1		# Request 1 CPU cores
#$ -l h_rt=24:0:0	# Request 4 hour runtime (This shouldn't last more than a few minutes but in the case of large fastq might take longer)
#$ -l h_vmem=4G		# Request 4G RAM / Core
#$ -t 1-$MAX		# run an array job of all the samples listed in FASTQ_Raw
#$ -N $jobName-Trim_Job
" > $trimJob

echo '
module load trimgalore

mkdir $DIR/FASTQ_TRIM;
mkdir -p $DIR/QC/TRIM;

## Get all the sample names from FASTQ_Raw
Samples=(ls FASTQ_Raw/*)
## Extract the file name at the position of the array job task ID
Sample=$(basename ${Samples[${SGE_TASK_ID}]})

## Make directory for output
mkdir FASTQ_TRIM/$Sample

echo $Sample/*R1.fastq;
# Trim adapters using trim_galore
time trim_galore --paired --retain_unpaired --illumina --gzip \
        --fastqc_args "-o QC/TRIM/" \
        -o FASTQ_TRIM/$Sample/ \
        FASTQ_Raw/$Sample/*R1.fastq.gz FASTQ_Raw/$Sample/*R2.fastq.gz

# As long as the trim runs successfully run some clean up.
if [[ $? -eq 0 ]]; then

	# Move UMI file to FASTQ_TRIM	
	mv FASTQ_Raw/$sample/*UMI* FASTQ_TRIM/$sample/*UMI*;
	# if moving the file worked fine, remove the FASTQ_Raw folder. 
	if [[ $? -eq 0 ]];
		then
		rm -rf FASTQ_Raw/$Sample
	fi
fi
' >> $trimJob

##
# Align Job
##

echo "
#!/bin/sh
#$ -wd $DIR		# use current working directory
#$ -V			# this makes it verbose
#$ -o $jobOutputDir	# specify an output file
#$ -j y			# and put all output (inc errors) into it
#$ -m a			# Email on abort
#$ -pe smp 8		# Request 1 CPU cores
#$ -l h_rt=8:0:0	# Request 8 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=4G		# Request 4G RAM / Core
#$ -t 1-$MAX		# run an array job of all the samples listed in FASTQ_Raw
#$ -N $jobName-Align_Job

refIndex=$refIndex" > $alignJob

echo '
module load bwa
module load java

## Get all the sample names from FASTQ_Raw
Samples=(ls FASTQ_TRIM/*)
## Extract the file name at the position of the array job task ID
Sample=$(basename ${Samples[${SGE_TASK_ID}]})
echo $Sample

if ! [[ -d Alignment ]];then mkdir Alignment; fi

# Align the trimmed FASTQ 
time bwa mem -t 8 -M $refIndex \
-R "@RG\tID:$Sample\tLB:$Sample\tSM:$Sample\tPL:Illumina" \
FASTQ_TRIM/$Sample/*val_1* FASTQ_TRIM/$Sample/*val_2* |
# Sort aligned file by coordinate
java -Xmx4g -jar ~/Software/picard.jar SortSam \
        SORT_ORDER=coordinate \
	I=/dev/stdin \
	O=Alignment/$Sample.bam;
' >> $alignJob

##
# fgbio job 
##

echo "
#!/bin/sh
#$ -wd $DIR		# use current working directory
#$ -V			# this makes it verbose
#$ -o $jobOutputDir	# specify an output file
#$ -j y			# and put all output (inc errors) into it
#$ -m a			# Email on abort
#$ -pe smp 1		# Request 1 CPU cores
#$ -l h_rt=4:0:0	# Request 4 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=24G		# Request 4G RAM / Core
#$ -t 1-$MAX		# run an array job of all the samples listed in FASTQ_Raw
#$ -N $jobName-fgbio_Job" > $fgbioJob

echo '
module load java
## Set fgbio parameters - NB this needs to have enough ram to load the whole fastq files.
fgbio=\"java -Xmx24g -XX:+AggressiveOpts -XX:+AggressiveHeap -jar /data/home/hfx472/Software/fgbio-0.6.1.jar --compression=0\"

## Get all the sample names from FASTQ_TRIM
Samples=(ls FASTQ_TRIM/*)
## Extract the file name at the position of the array job task ID
sampleName=$(basename ${Samples[${SGE_TASK_ID}]})

echo Use fgbio to generate consensus bam of $sampleName

echo $sampleName
echo Annotate with UMI
$fgbio AnnotateBamWithUmis \
	-i Alignment/$sampleName\.bam \
	-f FASTQ_TRIM/$sampleName/$sampleName\_UMI.fastq.gz \
	-o Alignment/$sampleName\.fg.bam 

if [[ $? -eq 0 ]] && [[ -s Alignment/$sampleName\.fg.bam ]];
	then
	rm Alignment/$sampleName\.bam
fi

echo Sort bam query name
$fgbio SortBam \
	-i Alignment/$sampleName\.fg.bam \
	-s Queryname \
	-o Alignment/$sampleName\.fgsort.bam

if [[[ $? -eq 0 ]] && [ -s Alignment/$sampleName\.fgsort.bam ]];
        then
        rm Alignment/$sampleName\.fg.bam
fi

echo Set mate info
$fgbio SetMateInformation \
	-i Alignment/$sampleName\.fgsort.bam \
	-o Alignment/$sampleName\.fgmate.bam

if [[ $? -eq 0 ]] && [[ -s Alignment/$sampleName\.fgmate.bam ]];
        then
        rm Alignment/$sampleName\.fgsort.bam
fi

echo Group reads by UMI 
$fgbio GroupReadsByUmi \
	-i Alignment/$sampleName\.fgmate.bam \
	-f Alignment/$sampleName\.family_size_histogram.txt \
	-s adjacency \
	-o Alignment/$sampleName\.fggrp.bam |

if [[ $? -eq 0 ]] && [[ -s Alignment/$sampleName\.fggrp.bam ]];
        then
        rm Alignment/$sampleName\.fgmate.bam
fi


echo Call molecular consensus reads
$fgbio CallMolecularConsensusReads \
	-i Alignment/$sampleName\.fggrp.bam \
	-o Alignment/$sampleName\.fgcon.bam \
	-M 2

if [[ -s Alignment/$sampleName\.fgcon.bam ]] && [[ $? -eq 0 ]];
        then
        rm Alignment/$sampleName\.fggrp.bam
fi


if ! [[ $? -eq 0 ]]; then echo $sampleName >> FAIL.txt;  continue; fi

# This extracts the number of duplicates per UMI for QC checking. 
samtools view Alignment/$sampleName\.fgcon.bam | cut -f 12 > Stats/UMIcount/$sampleName.UMIcount

mkdir -p Stats/UMIcount
paste Stats/UMIcount/*.UMIcount | sed -e "s/cD:i://g" > Stats/UMIcount/AllUMICount.txt
' >> $fgbioJob


echo "
#!/bin/sh
#$ -wd /data/home/hfx472/CurrentProjects/Giuseppe_TP            # use current working directory
#$ -V			# this makes it verbose
#$ -j y			# Join output
#$ -o /data/autoScratch/weekly/hfx472   # specify an output file
#$ -m a			# Email on abort
#$ -pe smp 1		# Request 1 CPU cores
#$ -l h_rt=8:0:0	# Request 8 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=12G	# Request 4G RAM / Core
#$ -t 1-$MAX		# run an array job of all the samples listed in FASTQ_Raw
#$ -N $jobName-bam2fastq
" > $fastqconJob

echo '
module load java

if ! [[ -d FASTQ_Con ]]; then mkdir FASTQ_Con; fi

## Get all the sample names from FASTQ_TRIM
Samples=(ls FASTQ_TRIM/*)
## Extract the file name at the position of the array job task ID
sampleName=$(basename ${Samples[${SGE_TASK_ID}]})
echo $Sample

if ! [[ -d FASTQ_Con/$sampleName ]]; then mkdir FASTQ_Con/$sampleName; fi

echo fastq generation starting
if ! [[ -f FASTQ_Con/$sampleName\_R1.fastq ]] && ! [[ -f FASTQ_Con/$sampleName\_R2.fastq ]]; then
	java -jar ~/Software/picard.jar SamToFastq \
		I=Alignment/$sampleName\.fgcon.bam \
		FASTQ=FASTQ_Con/$sampleName/$sampleName\_R1.fastq.gz \
		SECOND_END_FASTQ=FASTQ_Con/$sampleName/$sampleName\_R2.fastq.gz \
		VALIDATION_STRINGENCY=LENIENT
fi
if [[ $? -eq 0 ]]; then
	rm Alignment/$sampleName\*bam
fi
' >> $fastqconJob

echo "
#!/bin/sh
#$ -wd $DIR             # use current working directory
#$ -V                   # this makes it verbose
#$ -o $jobOutputDir     # specify an output file
#$ -j y                 # and put all output (inc errors) into it
#$ -m a                 # Email on abort
#$ -pe smp 8            # Request 1 CPU cores
#$ -l h_rt=8:0:0        # Request 8 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=4G         # Request 4G RAM / Core
#$ -t 1-$MAX            # run an array job of all the samples listed in FASTQ_Raw
#$ -N $jobName-ConAlign_Job

refIndex=$refIndex" > $conAlignJob

echo '
module load bwa
module load java

## Get all the sample names from FASTQ_Raw
Samples=(ls FASTQ_Con/*)
## Extract the file name at the position of the array job task ID
Sample=$(basename ${Samples[${SGE_TASK_ID}]})
echo $Sample

if ! [[ -d Alignment ]];then mkdir Alignment; fi

# Align the trimmed FASTQ 
time bwa mem -t 8 -M $refIndex \
-R "@RG\tID:$Sample\tLB:$Sample\tSM:$Sample\tPL:Illumina" \
FASTQ_Con/$Sample/*_R1* FASTQ_Con/$Sample/*_R2* |
# Sort aligned file by coordinate
java -Xmx4g -jar ~/Software/picard.jar SortSam \
        SORT_ORDER=coordinate \
        I=/dev/stdin \
        O=Alignment/$Sample.con.bam;
' >> $conAlignJob

echo "
#!/bin/sh
#$ -wd $DIR             # use current working directory
#$ -V                   # this makes it verbose
#$ -o $jobOutputDir     # specify an output file
#$ -j y                 # and put all output (inc errors) into it
#$ -m a                 # Email on abort
#$ -pe smp 1            # Request 1 CPU cores
#$ -l h_rt=24:0:0        # Request 24 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=4G         # Request 4G RAM / Core
#$ -t 1-$MAX            # run an array job of all the samples listed in FASTQ_Raw
#$ -N $jobName-Realign_Job

GATK=$GATK
PICARD=$PICARD

reference=$reference
referenceindex=$refIndex
dbsnp=$dbsnp
BED=$BED" > $realignJob

echo '
module load java

Samples=(ls FASTQ_Con/*)
## Extract the file name at the position of the array job task ID
Sample=$(basename ${Samples[${SGE_TASK_ID}]})
echo $Sample

consensusbam=Alignment/$Samples\.rehead.bam
realignmentlist=Alignment/$Samples\.bam.list
realignmentbam=Alignment/$Samples\.realigned.bam
realignmentfixbam=Alignment/$Samples\.fixed.bam
baserecaldata=Alignment/$Samples\.recal_data.grp
recalioutbam=Alignment/$Samples\.recalib.bam

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
#$ -V                   # this makes it verbose
#$ -o $jobOutputDir     # specify an output file
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
varScan=/data/home/hfx472/Software/VarScan/VarScan.v2.4.3.jar
refGenome=/data/BCI-Haemato/Refs/GRCh37/hg37.fa

## get recalibrated Bam file
Samples=(ls FASTQ_Con/*)
## Extract the file name at the position of the array job task ID
Sample=$(basename ${Samples[${SGE_TASK_ID}]})
echo $Sample

## Output Files
outSnp=VCF/$sample\_snp.vcf
outIndel=VCF/$sample\_indel.vcf
outSnp_fil=VCF/$sample\.pass.snp.vcf
outIndel_fil=VCF/$sample\.pass.indel.vcf

time samtools mpileup -B -q 40 -l $BED -f $refGenome $Sample |
java -jar $varScan mpileup2snp \
	--min-coverage 20 \
        --min-avg-qual 20 \
	--min-read2 4 \
        --p-value 1 \
        --min-var-freq 0.01 \
        --strand-filter 1 \
        --output-vcf 1 > $outSnp

time samtools mpileup -B -q 40 -l $BED -f $refGenome $Sample |
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
#$ -V                   # this makes it verbose
#$ -o $jobOutputDir     # specify an output file
#$ -j y                 # and put all output (inc errors) into it
#$ -m a                 # Email on abort
#$ -pe smp 1            # Request 1 CPU cores
#$ -l h_rt=24:0:0        # Request 8 hour runtime (This is an overestimation probably. Alter based on your needs.) 
#$ -l h_vmem=4G         # Request 4G RAM / Core
#$ -N $jobName-Varscan_Job
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
	qsub $trimJob
fi
