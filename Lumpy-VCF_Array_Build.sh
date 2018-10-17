today=`date +%Y-%m-%d`

DIR=$PWD
JOBNAME=Lumpy_Array
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
                -h | --help )		echo "\
This script will create an array job that can be run on Apocrita.
-a | --auto-start               Automatically start the jobs on creation (default on)
-n | --name                     The name for the job (default Lumpy_Array)
-d | --directory                The root directory for the project (default $PWD)"
					exit 1
					;;
	esac
	shift
done

## Setup
LumpyJob=$DIR/$JOBNAME\-lumpy-$today.sh
BAMS=( $DIR/Alignment/*recalib.bam )
MAX=$(echo ${#BAMS[@]})

echo "
#!/bin/sh
#$ -wd $DIR		# use current working directory
#$ -V			# this makes it verbose
#$ -o /data/autoScratch/weekly/hfx472/        # specify an output file - change 'outputfile.out'
#$ -j y			# Join output
#$ -m a                 # email on abort
#$ -pe smp 1		# Request 1 CPU cores
#$ -l h_rt=10:0:0	# Request 48 hour runtime (upto 240 hours)
#$ -l h_vmem=4G		# Request 16GB RAM / core
#$ -t 1-$MAX
#$ -N Giuseppe_Lumpy

module load samtools
DIR=$DIR
" > $LumpyJob

echo '
BAMS=( 0 $DIR/Alignment/*recalib.bam )
SampleBam=${BAMS[${SGE_TASK_ID}]}
SampleName=$(basename $SampleBam | cut -d"." -f1)

echo $SampleName

# Extract the discordant reads
echo getting discordant reads
samtools view -b -F 1294 $SampleBam > $DIR/Alignment/$SampleName.discordants.unsorted.bam

# Extract the split-read $DIR/Alignments
echo getting split reads
samtools view -h $SampleBam \
    | /data/home/hfx472/Software/lumpy-sv/scripts/extractSplitReads_BwaMem -i stdin \
    | samtools view -Sb - \
    > $DIR/Alignment/$SampleName.splitters.unsorted.bam

# Sort both $DIR/Alignments
echo sorting discordant reads
samtools sort $DIR/Alignment/$SampleName.discordants.unsorted.bam -o $DIR/Alignment/$SampleName.discordants.bam
echo sorting discordant reads
samtools sort $DIR/Alignment/$SampleName.splitters.unsorted.bam -o $DIR/Alignment/$SampleName.splitters.bam

## Get distribution and mean/stdev values
STATS=$(samtools view -r $SampleName $SampleBam \
    | tail -n+100000 \
    | /data/home/hfx472/Software/lumpy-sv/scripts/pairend_distro.py \
    -r 101 \
    -X 4 \
    -N 10000 \
    -o $DIR/Alignment/$SampleName.lib1.histo | sed -e "s/mean://g" | sed -e "s/stdev://g" | tr "\t" ",")

## Run Lumpy
/data/home/hfx472/Software/lumpy-sv/bin/lumpy \
    -mw 4 \
    -tt 0 \
    -pe id:$SampleName,\
bam_file:$DIR/Alignment/$SampleName.discordants.bam,\
histo_file:$DIR/Alignment/$SampleName.lib1.histo,\
mean:$(echo $STATS | cut -d"," -f1),\
stdev:$(echo $STATS | cut -d"," -f2),\
read_length:101,\
min_non_overlap:101,\
discordant_z:5,\
back_distance:10,\
weight:1,\
min_mapping_threshold:20 \
    -sr id:SP2_FLB_GP_S1,\
bam_file:$DIR/Alignment/$SampleName.splitters.bam,\
back_distance:10,\
weight:1,\
min_mapping_threshold:20 > VCF/SV/$SampleName.vcf
' >> $LumpyJob


if [[ $AUTOSTART -eq 1 ]]; then 
	qsub $LumpyJob
fi
