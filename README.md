# Array-job_building_scripts
Pipelines that generate array jobs.

## Prerequisites

Software | Expected location on server
--- | ---
<a href="https://github.com/broadinstitute/picard/releases/tag/2.18.14">Picard tools</a> | The picard.jar file should be found in /data/home/$USER/Software 
Genome Analysis Toolkit | The GenomeAnalysisTK.jar should be in /data/home/$USER/Software

The rest should be handled by the moduules on apocrita unless something breaks. If you're not sure try loading the modules before running your scripts or something I don't know I'm not your mother ...

The scripts will expect that the fastq files are stored in a directory called FASTQ_Raw. Inside of this directory should be a directory for each sample containing the samples.

i.e.

Project root | raw | sample | .fastq.gz 
--- | --- | --- | ---
WGS_60X | FASTQ_Raw | Sample1 | Sample1_R1.fastq.gz
|  |  |  | Sample1_R2.fastq.gz
| |  | Sample2 | Sample2_R1.fastq.gz
|  |  |  | Sample2_R2.fastq.gz

Make sure you've checked the files with fastqc etc and trimmed if needed.

***

## BWA_Align_Array_Job_Build.sh

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
If the script is set to autorun then it will load the SAI arrays straight away, otherwise the job files will just sit there waiting for you. The jobs *should* be submitted to the server as they previous job finishes but keep an eye on it. 
