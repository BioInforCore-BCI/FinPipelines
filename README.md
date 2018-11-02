# Fin's Arrays.
Scripts that generate array jobs for pipelines.\
Avaliable pipelines:

1. [BWA_Align_Array_Job_Build.sh](#bwa_align_array_job_buildsh)  
1. [UMI-VCF_Pipline_Array_Build.sh](#umi-vcf_pipline_array_buildsh)  
1. [Hisat2_Align_Array.sh](#hisat2_align_arraysh)
1. [Strelka_Array.sh](#strelka_arraysh)
1. [MuTect2_Array.sh](#mutect2_arraysh)
1. [Samtools_Index_Array.sh](#samtools_index_arraysh)
1. [Lumpy-VCF_Array_Build.sh](#lumpy-vcf_array_buildsh)
1. [Fastqc_array.sh](#fastqc_arraysh)

## Prerequisites

Software | Expected location on server
--- | ---
<a href="https://github.com/broadinstitute/picard/releases/tag/2.18.14">Picard tools</a> | The picard.jar file should be found in /data/home/$USER/Software 
<a href="https://software.broadinstitute.org/gatk/download/">Genome Analysis Toolkit</a> | symlink to latest GATK release called gatk-latest should be found in /data/home/$USER/Software. Make a symlink using ln -s /path/to/gatk gatk-latest
<a href="https://github.com/Illumina/strelka/tree/master">Strelka</a> | Strelka root dir should be in /data/home/$USER/Software
<a href="https://github.com/arq5x/lumpy-sv">Lumpy</a> | Lumpy root dir should be in /data/home/$USER/Software

Make sure to load java in your scripts, the old java has a memory problem that fill cause nodes to be completely loaded.

The rest should be handled by the modules on apocrita unless something breaks. If you're not sure try loading the modules before running your scripts or something, I don't know I'm not your mother ...

Make sure you've checked the files with fastqc etc and trimmed if needed.

***

## BWA_Align_Array_Job_Build.sh

This script will automatically generate job scripts to be run on apocrita that will take fastq files, align them with bwa-aln, mark duplicates using picard tools and then realign around indels using GATK.

The script will expect that the fastq files are stored in a directory called FASTQ_Raw. Inside of this directory should be a directory for each sample containing the sample_R[1,2].fastq.gz files.

i.e.

Project root | raw | sample | .fastq.gz 
--- | --- | --- | ---
WGS | FASTQ_Raw | Sample1 | Sample1_R1.fastq.gz
|  |  |  | Sample1_R2.fastq.gz
| |  | Sample2 | Sample2_R1.fastq.gz
|  |  |  | Sample2_R2.fastq.gz

These scripts were written to run on 60X WGS data so the times can probably be reduced if you're looking at smaller files.

The avaliable options are as follow:
```bash
-a | --auto-start	Automatically start the jobs on creation (default off)
-n | --name		The name for the job (default BWA_Align)
-d | --directory	The root directory for the project (default $PWD)
-r | --refdir		Directory in BCI-Haemato/Refs containing the reference (default GRCh37/)
-t | -trim		Creates a job to trim the samples. Autostart will submit this job, not make sai (default off)
-h | --help		Display this message and exit"
```
If the script is set to autorun then it will load the SAI arrays straight away, otherwise the job files will just sit there waiting for you. The jobs *should* be submitted to the server as they previous job finishes but keep an eye on it. 

***

## UMI-VCF_Pipline_Array_Build.sh

This script will run a UMI based alignment and realignment around indels. This was written by Findlay Bewicke-Copley based on pipelines used by Nonacus and those developed by Jun Wang.

### Prerequisites

There is a slight difference in the folder set up for this pipeline.

This is due to the extra data needed for the pipeline, namely the UMIs.

Sample name | File
:--- | ---:
R1 | Read 1
R2 | UMI (yeah I know I hate it too ...)
R3 | Read 2
I1 | Index 1
I2 | Index 2

It assumes all the files are stored in FASTQ_Raw and it's first step is to concatenate all the lanes together and store all the fastq files in sample directories and also to delete the index files as they aren't needed (make sure you keep a zip of all the data incase you need to start again).

i.e. the data will start like this:

Project root | raw  | .fastq.gz 
--- | --- | ---
UMI_panel | FASTQ_Raw | Sample1_R1.fastq.gz
|  |  | Sample1_R2.fastq.gz
|  |  | Sample1_R3.fastq.gz
|  |  | Sample1_I1.fastq.gz
|  |  | Sample1_I2.fastq.gz

And end up looking like this:

Project root | raw | sample | .fastq.gz 
--- | --- | --- | ---
UMI_panel | FASTQ_Raw | Sample1 | Sample1_R1.fastq.gz
|  |  |  | Sample1_R2.fastq.gz
|  |  |  | Sample1_UMI.fastq.gz

The avaliable options are as follow:
```bash
-a | --autostart      Automatically start the job
-n | --name           Sets the job name (default - UMI-VCF-$PWD)
-b | --bed            Bed file for the project (default none - change this!)
-d | --directory      Root directory for the project
-r | --ref            Reference directory for the project, look for this in BCI-Haemato/Refs (default GRCh37)
-s | --setup          Run the set up (cat the files together and create sample directories) (default off)
-f | --fastq-suffix   Suffix for the fastq files (default .fastq.gz)
-h | --help           Display this message
```
***
## Hisat2_Align_Array.sh

This will create a array job that will align fastq files using hisat2. 

### Prerequisites

The script will expect that the fastq files are stored in a directory called FASTQ_Raw. Inside of this directory should be a directory for each sample containing the sample_R[1,2].fastq.gz files. You may need to cat the lanes together.

i.e.

Project root | raw | sample | .fastq.gz 
--- | --- | --- | ---
RNAseq_proj | FASTQ_Raw | Sample1 | Sample1_R1.fastq.gz
|  |  |  | Sample1_R2.fastq.gz
| |  | Sample2 | Sample2_R1.fastq.gz
|  |  |  | Sample2_R2.fastq.gz

The avaliable options are as follow:
```bash
-a | --auto-start               Automatically start the jobs on creation (default off)
-n | --name 	           	The name for the job (default BWA_Align)
-d | --directory 	      	The root directory for the project (default $PWD)
-r | --refdir 			Directory in BCI-Haemato/Refs containing the reference (default GRCh38/)
-h | --help 			Display this message and exit"
```

***

## Strelka_Array.sh

This will build a strelka array job for matched tumour/normal pairs.

### Prerequisites

The bam files to be used must be in the same directory called .../Project_Root/Alignment/.
The script picks bam files based on a common prefix at the start of the file.
It takes all the \*normal\*.bam files and then splits at the periods and takes the first section. 
This is then used to find the Prefix\*normal\*.bam and Prefix\*tumour\*.bam.
The Bam files must also be indexed.

i.e.

Patient Prefix | Sample | .suffix 
 --- | --- | ---
Patient_1. | normal | .bam
Patient_1. | normal | .bai
Patient_1. | tumour | .bam
Patient_1. | tumour | .bai
Patient_2. | normal | .bam
Patient_2. | normal | .bai
Patient_2. | tumour | .bam
Patient_2. | tumour | .bai

Options avaliable:
```bash
-a | --auto-start               Automatically start the jobs on creation (default off)
-n | --name                     The name for the job (default BWA_Align)
-d | --directory                The root directory for the project (default $PWD)
-r | --refdir                   Directory in BCI-Haemato/Refs containing the reference (default GRCh37/)
-h | --help                     Display this message and exit"
```
***
## MuTect2_Array.sh

This will build a MuTect 2 array job for matched tumour/normal pairs.

### Prerequisites

The bam files to be used must be in the same directory called .../Project_Root/Alignment/.
The script picks bam files based on a common prefix at the start of the file.
It takes all the *normal*.bam files and then splits at the periods and takes the first section. 
This is then used to find the Prefix\*normal\*.bam and Prefix\*tumour\*.bam.
The Bam files must also be indexed.

i.e.

Patient Prefix | Sample | .suffix 
 --- | --- | ---
Patient_1. | normal | .bam
Patient_1. | normal | .bai
Patient_1. | tumour | .bam
Patient_1. | tumour | .bai
Patient_2. | normal | .bam
Patient_2. | normal | .bai
Patient_2. | tumour | .bam
Patient_2. | tumour | .bai

Options avaliable:
-a | --auto-start		Automatically start the jobs on creation (default off)
-n | --name			The name for the job (default BWA_Align)
-d | --directory		The root directory for the project (default $PWD)
-r | --refdir			Directory in BCI-Haemato/Refs containing the reference (default GRCh37/)
-h | --help			Display this message and exit

***
## Polysolver_Array.sh

Pre-recs: See above

This will run HLA typing on your samples using Polysolver. Polysolver can be installed through conda in a new environment. This was the easiest was for me to get it working. Make sure your condarc has these:
```bash
channels:
  - defaults
  - bioconda
  - conda-forge
  - vacation
```
Then run
```bash
## Create new env called polysolver and install hla-polysolved in it.
conda create -n polysolver -c vacation hla-polysolver
```
This will create a new conda environment you can access using:

```bash
source activate polysolver
```
This is how the array builder works, so if you make a different environment name I'm going to have to write in a new argument to specific the environment and that'll be a whole thing.

Options: 
```bash
-a | --auto-start		Automatically start the jobs on creation (default off)
-n | --name			The name for the job (default BWA_Align)
-d | --directory		The root directory for the project (default $PWD)
-r | --ref			The reference used to align the bam (default hg19)
```

***
## Samtools_Index_Array.sh

Does what it says in the name, will build and submit an array script that will index all bam files in Alignment/

Options:
```bash
-n | --name			The name for the job (default BWA_Align)
-d | --directory		The root directory for the project (default $PWD)
-h | --help			Display this message and exit"
```
***
## Lumpy-VCF_Array_Build.sh

Lumpy is a structural variant caller.

DIR should be the root of the project which needs to contain a folder called Alignment.
In this folder you should have bam files for your samples with the suffix .recalib.bam. These will used to call the SVs.

You need an output folder called VCF/SV/ as this is where the VCF files will be placed.

Options

```bash
-a | --auto-start               Automatically start the jobs on creation (default on)
-n | --name                     The name for the job (default Lumpy_Array)
-d | --directory                The root directory for the project (default $PWD)"
```
***

## Fastqc_array.sh

Fastqc can be used to assess the quality of FASTQ, Sam and Bam files.

The script will expect that the fastq files are stored in a directory called FASTQ_Raw. Inside of this directory should be a directory for each sample containing the sample_R[1,2].fastq.gz files.

OR

if MODE is set to bam you'll need a directory called Alignment that contains bam files. (The script will analyse all these bam files.)

i.e.

Project root | raw | sample | .fastq.gz 
--- | --- | --- | ---
RNAseq_proj | FASTQ_Raw | Sample1 | Sample1_R1.fastq.gz
|  |  |  | Sample1_R2.fastq.gz
| |  | Sample2 | Sample2_R1.fastq.gz
|  |  |  | Sample2_R2.fastq.gz

Options

```bash
-a | --auto-start               Automatically start the jobs on creation (default on)
-n | --name                     The name for the job (default Lumpy_Array)
-m | --mode			The mode for the job (bam|fastq) (default fastq)
-d | --directory                The root directory for the project (default $PWD)"
```
