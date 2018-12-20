#!/bin/bash
today=`date +%Y-%m-%d`

DIR=$PWD
JOBNAME=HTSEQ_Count
FILES=(ls $(find Alignment/ -name "*.bam") )
MAX=$(echo ${#FILES[@]})
MAX=$( expr $MAX - 1 )
GTF=/data/home/$USER/BCI-Haemato/Refs/GRCh38/Annotation/hg38.gtf

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
                -g | --gtf )		shift
					GTF=$1
                			;;
                -h | --help )           echo "\
-a | --auto-start               Automatically start the jobs on creation (default off)
-n | --name                     The name for the job (default BWA_Align)
-d | --directory                The root directory for the project (default $PWD)
-g | --gtf			gtf file (default GRCh37/Annotation/hg38.gtf)
-h | --help                     Display this message and exit"
                                        exit 1

                                        ;;
        esac
        shift
done

HTSEQ=$DIR/HTSEQ_$JOBNAME\_count_array.sh

echo "
#!/bin/sh
#$ -wd $DIR							# set working directory
#$ -V                   					# this makes it verbose
#$ -o /data/autoScratch/weekly/$USER				# specify an output file
#$ -j y                 					# and put all output (inc errors) into it
#$ -m a                 					# Email on abort
#$ -pe smp 1            					# Request 1 CPU cores
#$ -l h_rt=120:0:0						# Request 120 hour runtime
#$ -l h_vmem=4G							# Request 4G RAM / Core
#$ -t 1-$MAX							# Run an array of $MAX jobs 
#$ -N $JOBNAME\_HTSEQ						# Set Jobname

refGTF=$GTF
MAX=$MAX
source /data/home/$USER/envs/htseq-count/bin/activate
" > $HTSEQ

echo ' 
BAMS=( ls  $(find Alignment/ -name "*.bam") )
BAM=${BAMS[SGE_TASK_ID]}
SAMPLE=$(basename $BAM | cut -d'.' -f 1)
if ! [[ -s Expression/$SAMPLE\.Counts.txt ]];
then
	echo Now processing $BAM
	
	htseq-count -f bam -s reverse $BAM $refGTF >> Expression/$SAMPLE\.Counts.txt
else
	echo output file found. Have you already run this sample?
fi

deactivate

if [[ $(ls Expression/*Counts.txt | wc -l ) -eq $MAX ]] &&
	[[ $(qstat -r | grep Full | grep HTSEQ_Fin | wc -l) -eq 1 ]];
' >> $HTSEQ

echo "
then
	awk '
	        ## FNR - per file line count, 1 is the first line of the file.
	        ## L is an array 1D array which will contain my lines
	        ## Here I add the filename of the file being looped to the first index. 
	        FNR==1 {L[0]=L[0] "\t" FILENAME }
	        ## NR is a running total of the number of lines gone through
	        ## So NR only == FNR when you are on the first file.
	        ## So only on the first file take the first column and add to the array.
	        NR==FNR { L[FNR]=L[FNR] $1}
	        ## add a tab and the contents of column 2 to the array.
	        {L[FNR]=L[FNR]  "\t" $2}
	        ## at the end loop through the array starting at index 0 (the file names)
	        END { for ( i=0; i<=length(L)-1;i++) print L[i]}
	' Expression/*.Counts.txt > Expression/Counts.Combo.txt
fi
" >>  $HTSEQ

