library(data.table)

filterVariants <- function(data, type="exon", vafFilt=0.001, basespace=FALSE) {
#Header for VarScan Data
VarInfHead = c("Genotype","Genotype_quality","Samtools_depth","Depth",
	       "Ref_depth","Alt_depth","Frequency","P.val","Ref_qual",
	       "Alt_qual","Ref_depth_forward","Ref_depth_reverse",
	       "Alt_depth_forward","Alt_depth_reverse")

if (basespace) {
VarInfHead = c("GT","GQ","AD","DP","Frequency","NL","SB","NC")
}

# split the variant information into seperate columns
varInf <- strsplit(as.character(data$Raw[,26]),":")
varInf <- do.call(rbind,varInf)
colnames(varInf) <- VarInfHead
data$Processed <- cbind(data$Raw, varInf)
# remove old varinf and the numerical genotype indicator 
data$Processed <- data$Processed[-c(26,27)]
# filter variants with Frequency < vafFilt 
if (basespace) {
data$Processed$Frequency <- as.numeric(as.character(data$Processed$Frequency))
} else {
data$Processed$Frequency<-as.numeric(sub("%","", data$Processed$Frequency))/100
}

data$Filter <- data$Processed[which(data$Processed$Frequency>=vafFilt),]
# remove non synonymous mutations
data$Filter <- data$Filter[which(as.character(data$Filter$ExonicFunc.ensGene) != "synonymous SNV"),]

write.table(data$Filter,paste("Variants.",type,".R.txt", sep=""), row.names = FALSE, sep="\t", quote=FALSE)
# filter out variants that occur with
data$StrandFilter <- data$Filter[which(as.numeric(as.character(data$Filter$Alt_depth_reverse)) > 0),]
data$StrandFilter <- data$StrandFilter[which(as.numeric(as.character(data$StrandFilter$Alt_depth_forward)) > 0),]

write.table(data$StrandFilter,paste("Variants.",type,".R.strandfilter.txt", sep=""), row.names = FALSE, sep="\t", quote=FALSE)

return(data)
}

correctVafByTumourContent <- function (Variants, contentFile="TumourContent.csv", type="Exon", filter="") {

tumourContent<-read.delim(contentFile, header=FALSE)

Variants <- setkey(as.data.table(Variants), Sample)[tumourContent, Frequency := Frequency / V2 ][order(Chr,Start,Ref,Alt)]
write.table(Variants,"Variants.exon.strandfilter.AdjustVAF.R.txt", row.names = FALSE, sep="\t", quote=FALSE)

return(Variants)

}

Variants <- list()
Variants$ExonVars <- list()
Variants$IntronVars <- list()

Variants$ExonVars$Raw <- read.delim("Variants.exon.filter.cut.txt")
Variants$IntVars$Raw <- read.delim("Variants.intron.filter.cut.txt")

Variants$ExonVars <- filterVariants(Variants$ExonVars)
Variants$IntVars <- filterVariants(Variants$IntVars, type="intron")


