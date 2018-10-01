# array-job_building_scripts
Pipelines that generate array jobs.

# Prerequisites

<a href="https://github.com/broadinstitute/picard/releases/tag/2.18.14">
Picard tools</a> - The picard.jar file should be found in /data/home/$USER/Software  
Genome Analysis Toolkit - The GenomeAnalysisTK.jar should be in /data/home/$USER/Software

# BWA_Align_Array_Job_Build.sh

This script will automatically generate job scripts to be run on apocrita that will take fastq files, align them with bwa-aln, mark duplicates using picard tools and then realign around indels using GATK.

These scripts were written to run on 60X WGS data so the times can probably be reduced if you're looking at smaller files.

The avaliable options are as follow:
```bash
-a | --auto-start )             Automatically start the jobs on creation (default off)
-n | --name )                   The name for the job (default BWA_Align)
-d | --directory )              The root directory for the project (default $PWD)
-r | --refdir                   Directory in BCI-Haemato/Refs containing the reference (default GRCh37/)
-h | --help                     Display this message and exit"
```
