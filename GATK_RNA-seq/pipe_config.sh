#!/bin/bash
# @Date    : 2019-08-26 17:10:50


#################################################################################
################################# data & results ################################
#################################################################################
data_folder=/home/songyabing/projects_data/crispr/data
results_folder=/home/songyabing/projects_data/crispr/results
scripts_folder=/home/songyabing/projects_data/crispr/scripts

#################################################################################
################################## run platform #################################
#################################################################################
## peking、tsinghua、workstation
RunPlatform=workstation
NumThreads=4
Node=node05
Cpu=16

##################################################################################
################################## library info ##################################
##################################################################################
## used for read group
SequencingPlatform=illumina
DataType=RNA

##################################################################################
############################### reference genome #################################
##################################################################################
## reference genome for mapping and gatk
GenomeFastaFile=/home/songyabing/projects_data/crispr/genome/Mus_musculus.GRCm38.fa
## gtf file for star mapping
GenomeAnnoFile=/home/songyabing/projects_data/crispr/genome/Mus_musculus.GRCm38.gtf

##################################################################################
################################## GATK needed ###################################
##################################################################################
KnownIndelsFile=/home/songyabing/projects_data/crispr/genome/mus_musculus_indel.vcf
KnownSnpsFile=/home/songyabing/projects_data/crispr/genome/mus_musculus_snp.vcf
## GATK filter-recommand by GATK
## Only variant sites with QUAL equal or greater than this threshold will be called
StandCallConf=20.0
FSFilter=30.0
QDFilter=2.0
Window=35 
Cluster=3

##################################################################################
################################ software needed #################################
##################################################################################
# warning: GATK is suitable for java 1.8
# (.bed, .list, .picard, .interval_list, or .intervals)
GATK(){
    /home/songyabing/software/jre1.8.0_77/bin/java -Xms128m -Xmx16g -jar /home/songyabing/software/GATK/gatk_3.5/GenomeAnalysisTK.jar $@
}

picard(){
    /home/songyabing/software/jre1.8.0_77/bin/java -jar /home/songyabing/software/GATK/picard-tools-2.1.0/picard.jar $@
}



