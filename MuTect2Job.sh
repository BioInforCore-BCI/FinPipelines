today=`date +%Y-%m-%d`

CHROM=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y)

for ((index=0; index <= ${#CHROM[@]}-1; index++)); do

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

#
## MuTect2 - no dbsnp or cosmic file here as this can be done later with ANNOVAR
#

echo Running MuTect2

java -Xmx4g -jar ~/Software/GenomeAnalysisTK.jar \
        -T MuTect2 \
        -R $refGenome \
        -I:tumor $tumorBAM \
        -I:normal $normalBAM \
        -o $DIR/VCF/Mutect2/$sampleName'_'${CHROM[$index]}.vcf \
	-L ${CHROM[$index]} || exit 1 
#        -nct 8 \ running in parallel causes an exception.


qstat |
grep -q MuTect2 || { echo $sampleName >> $DIR/.MuTect2Samples.txt ;
/data/home/hfx472/Software/LymphSched/NextSampleLymph.sh -d $DIR -p MuTect2 }

" > $DIR/jobDir/Mutect2'_'$sampleName'_chr'${CHROM[$index]}'_'$today.sh

done

for job in $DIR/jobDir/Mutect2"_"$sampleName"_chr"*"_"$today.sh; do
	qsub $job
done 
