## Pass this script the file you want to index and it will send an indexing job to the scheduler

echo $1 


DIR=$(dirname $1)
SAMPLE=$(basename $1)

echo "
#!/bin/bash
#$ -cwd                 # set current working dir
#$ -pe smp 1            # Can't multithread
#$ -l h_rt=4:0:0        # Should only take a few hours, ask for 4 to be safe.
#$ -l h_vmem=1G          # Shouldn't need much ram ask for 1 G
#$ -o /dev/null
#$ -e /dev/null
#$ -m a
#$ -N Samtools_$SAMPLE

module load samtools

samtools index $1

" >  $DIR/samtoolsJob_$SAMPLE.sh

qsub $DIR'/samtoolsJob_'$SAMPLE.sh
