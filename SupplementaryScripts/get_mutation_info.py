#!/bin/python

import glob, os
from natsort import natsorted
############################################
## Constants
############################################
annotFile="Annotation.out.hg19_multianno.txt"
## Variant Headers
STRELKA_HEAD="CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tNORMAL\tTUMOR"
VARSCAN_HEAD="CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tSAMPLE"

# Load unique annotated mutations
class CombineAnnotations:

	def __init__(self, dataType="varscan", annotFile="Annotation.out.hg19_multianno.txt", pattern="*.pass.*"):
		
		self.annot = self.loadAnnot(annotFile)
		self.mutations = self.loadMutation(pattern)
		self.combineMutation(dataType)

	def loadAnnot(self, file):
		print "Loading Annotations"

		rv = {}
		FILE = open( file )
		Data = FILE.readlines()
		FILE.close()
		self.header = Data[0].rstrip()
		for line in Data[1:]:
			KEY='\t'.join(line.rstrip().split('\t')[0:5])
			if not rv.has_key(KEY):
				rv[KEY]=line.rstrip()
		return rv
 
	def loadMutation(self, pattern="*.pass.*"):
		print "Loading Mutations"	
		rv ={}
		for file in glob.glob(pattern):
			print file	
			FILE = open(file)
			sampleFile = FILE.readlines()
			FILE.close()
			for mutant in sampleFile:
				sampleName = file.split(".")[0]
				KEY='\t'.join(mutant.rstrip().split('\t')[0:5])
				if not rv.has_key(KEY):
					rv[KEY] = {}
				if not rv[KEY].has_key(sampleName):			
					rv[KEY][sampleName]= mutant
		return rv

	def combineMutation(self, dataType):
		if dataType == "varscan":
			self.header += "\tSample\tCount\t" + VARSCAN_HEAD
		elif dataType == "strelka":
			self.header += "\tSample\tCount\t" + STRELKA_HEAD
		else:
			self.header += "\tSample\tCount"
		print "Writing data"
		rv = []
		for key, mutation in natsorted(self.annot.iteritems()):
			for sample, values in natsorted(self.mutations[key].iteritems()):
				rv.append('\t'.join([mutation, sample, str(len(self.mutations[key].keys())), values]))
		outfile=open("get_mutation_info.out.txt", "w")
		
		outfile.write(self.header + "\n")
		for line in rv:
			outfile.write(line)
		outfile.close()

if __name__ == "__main__":

	import sys

	if len(sys.argv) > 1:

		head=sys.argv[1]

		CombineAnnotations(dataType=head)

	else:
	
		CombineAnnotations()
