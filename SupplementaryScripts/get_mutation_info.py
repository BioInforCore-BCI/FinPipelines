#!/bin/python

import glob, os

############################################
## Constants
############################################

MutFile="Annotation.out.hg19_multianno.txt"

# Load unique annotated mutations

def loadMutations(file):
	
	rv = {}
	FILE = open( file )
	Data = FILE.readlines()
	FILE.close()
	
	for line in Data[1:]:
		KEY='\t'.join(line.rstrip().split('\t')[0:5])
		if not rv.has_key(KEY):
			rv[KEY]=line.rstrip()

	return rv

Mutations = loadMutations(MutFile)


SampleDict = {}

# Load in all mutations 

for file in glob.glob("*.pass.*"):
	print file	
	FILE = open(file)
	sampleFile = FILE.readlines()
	
	FILE.close()
	for mutant in sampleFile:
		sampleName = file.split(".")[0]
		KEY='\t'.join(mutant.rstrip().split('\t')[0:5])
		if not SampleDict.has_key(KEY):
			SampleDict[KEY] = {}
		if not SampleDict[KEY].has_key(sampleName):			
			SampleDict[KEY][sampleName]= mutant	
outlist = []

for key, mutation in Mutations.iteritems():
	#print key
	for sample, values in SampleDict[key].iteritems():
		outlist.append('\t'.join([mutation, sample, str(len(SampleDict[key].keys())), values]))


outfile=open("get_mutation_info.out.txt", "w")

for line in outlist:
	outfile.write(line)

outfile.close()

