#!/bin/sh
#$ -cwd 
#$ -V                   	# this makes it verbose
#$ -o /data/scratch/hfx472/
#$ -j y                 	# and put all output (inc errors) into it
#$ -m a                 	# Email on abort
#$ -pe smp 1            	# Request 1 CPU cores
#$ -l h_rt=240:0:0
#$ -l h_vmem=36G		# Request 4G RAM / Core
###$ -t 1-55			# run an array job of all the samples listed in FASTQ_Raw
#$ -t 2-55			# run an array job of all the samples listed in FASTQ_Raw
#$ -tc 10
#$ -N Poor_Risk_Fusion

FOLDERS=( ls FASTQ/* )
FOLDER=${FOLDERS[${SGE_TASK_ID}]}
sample=$(basename $FOLDER)

mkdir -p Fusion/$sample/

time ~/Software/fusioncatcher/bin/fusioncatcher \
	-d Build/human_v95/ \
	-i $FOLDER \
	-p 1 \
	-o Fusion/$sample
