#!/bin/python

import glob, os
import sys
import gzip
from natsort import natsorted
############################################
## Constants
############################################
#if len(sys.argv) > 1:
#	annotFile = sys.argv[1]
#else:
#	print "no file specified, using default"
Constants = { 
		"annotFile":"Annotation.out.hg19_multianno.txt",
		"dataType":"varscan",
		"pattern":"*.pass.*"
}
Options={
		"-f":"annotFile",
		"-t":"dataType",
		"-p":"pattern"
}

## Variant Headers
MUTECT_HEAD="CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tTUMOR\tNORMAL"
STRELKA_HEAD="CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tNORMAL\tTUMOR"
VARSCAN_HEAD="CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tSAMPLE"

## Arg Parser
def argParse(arguments):
	"""takes a list of arguments and adjusts the Contants dictionary"""
	## Make sure we're using the gloabal Contants 
	global Constants
	## Until only the script name remains
	while len(arguments) > 1:
		## Remove the next argument
		arg=arguments.pop(1)
		## if it's in the Options dictionary
		if arg in Options.keys():
		        ## change the corresponding Constant to the next argument
			Constants[Options[arg]]=arguments.pop(1)



# Load unique annotated mutations
class CombineAnnotations:

	def __init__(self, dataType, annotFile, pattern):
		"""dataType is a string of either:
			"varscan" OR "strelka" """
		self.annot = self.loadAnnot(annotFile)
		self.mutations = self.loadMutation(pattern)
		self.combineMutation(dataType)

	def loadAnnot(self, file):
		print("Loading Annotations")

		rv = {}
		FILE = open( file )
		Data = FILE.readlines()
		FILE.close()
		self.header = Data[0].rstrip()
		for line in Data[1:]:
			KEY='\t'.join(line.rstrip().split('\t')[0:5])
			if not KEY in rv:
				rv[KEY]=line.rstrip()
		return rv
 
	def loadMutation(self, pattern):
		print("Loading Mutations")
		rv ={}
		for file in glob.glob(pattern):
			print(file)
			if file.split(".")[-1] == "gz":
				FILE = gzip.open(file)
			else:
				FILE = open(file)
			sampleFile = FILE.readlines()
			FILE.close()
			for mutant in sampleFile:
				sampleName = file.split(".")[0]
				KEY='\t'.join(mutant.rstrip().split('\t')[0:5])
				if not KEY in rv:
					rv[KEY] = {}
				if not sampleName in rv[KEY]:			
					rv[KEY][sampleName]= mutant
		return rv

	def combineMutation(self, dataType):
		if dataType == "varscan":
			self.header += "\tSample\tCount\t" + VARSCAN_HEAD
		elif dataType == "strelka":
			self.header += "\tSample\tCount\t" + STRELKA_HEAD
		elif dataType == "mutect":
			self.header += "\tSample\tCount\t" + MUTECT_HEAD
		else:
			self.header += "\tSample\tCount"
		print("Writing data")
		rv = []
		for key, mutation in natsorted(self.annot.items()):
			if key in self.mutations:
				for sample, values in natsorted(self.mutations[key].items()):
					rv.append('\t'.join([mutation, sample, str(len(self.mutations[key].keys())), values]))
		outfile=open("get_mutation_info.out.txt", "w")
		
		outfile.write(self.header + "\n")
		for line in rv:
			outfile.write(line)
		outfile.close()


if __name__ == "__main__":

	import sys

	if len(sys.argv) > 1:
		
		argParse(sys.argv)

	CombineAnnotations(Constants["dataType"], Constants["annotFile"], Constants["pattern"])
