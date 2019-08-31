#!/bin/bash
# @Date    : 2019-08-26 16:38:54

################################################################
############## GATK call variant from RNA-seq ##################
################### function needed t run ######################
################################################################

##### step0: initial #####
GATK_RNA_seq=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${GATK_RNA_seq}/comman_func.sh
source ${GATK_RNA_seq}/pipe_config.sh

##### step1: QC #####
qc(){
	local raw_fastqc_folder=$1
	local raw_read_array
	echo "step1: evaluate ${fastq_folder} data quality to ${raw_fastqc_folder}"
	mkdir -p ${raw_fastqc_folder}
	# config file
	raw_read_array=($(distinguish_read))
	fastqc -o ${raw_fastqc_folder} -f fastq --threads ${NumThreads} ${raw_read_array[0]} ${raw_read_array[1]}
}

##### step2: trim #####
trim_paired(){
	local trim_fastq_folder=$1
	local final_fastqc_folder=$2
	local raw_read_array
	echo "step2: trim、remove adapter、length selection and rerun fastqc in ${fastq_folder} to ${trim_fastq_folder}"
	raw_read_array=($(distinguish_read))
	mkdir -p ${final_fastqc_folder} ${trim_fastq_folder}
	mkdir -p ${trim_fastq_folder}/unpaired
	trim_galore -q 20 --phred33 --fastqc_args "--threads ${NumThreads} --outdir ${final_fastqc_folder}" \
		--length 50 --paired --retain_unpaired ${raw_read_array[0]} ${raw_read_array[1]} \
		--dont_gzip -o ${trim_fastq_folder}
	mv ${trim_fastq_folder}/*_unpaired_* ${trim_fastq_folder}/unpaired
}

# mapping with star for RNA-seq
## build 1pass index
generate_star_1pass_index(){
    local index_1pass_folder=$1
    echo "step3: build star 1pass mapping index to ${index_1pass_folder}"
    mkdir -p ${index_1pass_folder}
    STAR --runMode genomeGenerate --genomeDir ${index_1pass_folder} --genomeFastaFiles ${GenomeFastaFile} \
        --runThreadN ${NumThreads} --sjdbGTFfile ${GenomeAnnoFile} --sjdbOverhang $(get_STAROverhang ${fastq_folder})  
}

## build 2pass index
generate_star_2pass_index(){
    local index_2pass_folder=$1
    local mapping_1pass_folder=$2
    echo "step3: build star 2pass mapping index to ${index_2pass_folder}"
    mkdir -p ${index_2pass_folder}
    STAR --runMode genomeGenerate --genomeDir ${index_2pass_folder} --genomeFastaFiles ${GenomeFastaFile} \
        --runThreadN ${NumThreads} --sjdbGTFfile ${GenomeAnnoFile} --sjdbOverhang $(get_STAROverhang ${fastq_folder})  \
        --sjdbFileChrStartEnd ${mapping_1pass_folder}/SJ.out.tab
}

## mapping 1pass and 2pass func 
satr_mapping(){
	local index_folder=$1
	local trim_fastq_folder=$2
	local mapping_folder=$3
	local trim_read_array
	echo "step3: star mapping with ${index_folder} index to ${mapping_folder}"
	mkdir -p ${mapping_folder}
	trim_read_array=($(distinguish_read ${trim_fastq_folder}))
	STAR --genomeDir ${index_folder} --runThreadN ${NumThreads}  \
		--readFilesIn ${trim_read_array[0]} ${trim_read_array[1]} \
		--outFileNamePrefix ${mapping_folder}/  --outSAMtype BAM SortedByCoordinate \
		--outBAMsortingThreadN ${NumThreads}
	# build bam index
	picard BuildBamIndex I=${mapping_folder}/Aligned.sortedByCoord.out.bam
}


gatk_generate_dict(){
	echo "creat genome fai and dict file"
	if [[ ! -f  "${GenomeFastaFile}.fai" ]]
	then
		samtools faidx ${GenomeFastaFile}
	fi

	if [[ ! -f "$(dirname ${GenomeFastaFile})/$(basename $(basename ${GenomeFastaFile} ".fasta") ".fa").dict" ]]
	then
		picard CreateSequenceDictionary \
			REFERENCE=${GenomeFastaFile} \
			OUTPUT=$(dirname ${GenomeFastaFile})/$(basename $(basename ${GenomeFastaFile} ".fasta") ".fa").dict
	fi
}

# home-made group bam name 
gatk_add_group(){
	local mapping_2pass_folder=$1
	local add_group_bam=$2
	echo "step4: GATK AddOrReplaceReadGroups to ${add_group_bam}"
	picard AddOrReplaceReadGroups I=${mapping_2pass_folder}/Aligned.sortedByCoord.out.bam \
		O=${add_group_bam} SO=coordinate \
		RGID=$(get_read_group) \
		RGLB=${RGLB} \
		RGPL=${RGPL} \
		RGSM=${RGSM} \
		RGPU=$(get_read_group)_${RGSM}
}

gatk_markdup(){
	local add_group_bam=$1
	local mark_dup_bam=$2
	local metrics_file=$3
	echo "step5: GATK MarkDuplicates to ${mark_dup_bam}"
	picard MarkDuplicates \
		I=${add_group_bam} O=${mark_dup_bam} M=${metrics_file} \
		CREATE_INDEX=true VALIDATION_STRINGENCY=SILENT 
}


gatk_splitntrim(){
	local mark_dup_bam=$1
	local split_bam=$2

    if [[ ! -f "$(echo ${mark_dup_bam} | sed 's/.bam$/.bai/')" ]]
    then
        picard BuildBamIndex I=${mark_dup_bam}
    fi
    echo "step6: GATK SplitNCigarReads to ${split_bam}"
	GATK -T SplitNCigarReads -R ${GenomeFastaFile} \
		-I ${mark_dup_bam} -o ${split_bam} \
		-rf ReassignOneMappingQuality -RMQF 255 -RMQT 60 \
		-U ALLOW_N_CIGAR_READS
}

gatk_indel_realign(){
	local in_bam=$1
	local realign_bam=$2
	local intervals_file=$3

	local known_indels_arg;local f
    for f in $KnownIndelsFile
    do
        known_indels_arg="$known_indels_arg -known $f"
    done
    echo "step7: GATK IndelRealigner to ${realign_bam}"
    GATK -T RealignerTargetCreator -R ${GenomeFastaFile} \
    	-I ${in_bam} \
    	$known_indels_arg \
    	-o ${intervals_file}

    GATK -T IndelRealigner -R ${GenomeFastaFile} \
    	-I ${in_bam} \
    	$known_indels_arg \
    	-targetIntervals ${intervals_file} \
    	-o ${realign_bam}
}

gatk_base_recall(){
    local realign_bam=$1
    local recal_table_file=$2
    local after_recal_table_file=$3
    local recal_plot_file=$4
    local racal_bam_file=$5
   
    local known_indels_arg;local f
    for f in ${KnownIndelsFile}
    do
        known_indels_arg="${known_indels_arg} -knownSites $f"
    done
    echo "step8: GATK BaseRecalibrator to ${racal_bam_file}"
    GATK -T BaseRecalibrator -R ${GenomeFastaFile} \
        -I ${realign_bam} \
        -knownSites ${KnownSnpsFile} ${known_indels_arg} \
        -o ${recal_table_file}

    GATK -T PrintReads -R ${GenomeFastaFile} \
        -I ${realign_bam} -BQSR ${recal_table_file} \
        -o ${racal_bam_file}

    GATK -T BaseRecalibrator -R ${GenomeFastaFile} \
        -I ${realign_bam} \
        -knownSites ${KnownSnpsFile} ${known_indels_arg} \
        -BQSR ${recal_table_file} \
        -o ${after_recal_table_file}

    GATK -T AnalyzeCovariates -R ${GenomeFastaFile} \
        -before ${recal_table_file} \
        -after ${after_recal_table_file} \
        -plots ${recal_plot_file}
}

gatk_variant_call_HaplotypeCaller(){
	local in_bam_file=$1
	local raw_vcf_file=$2
	echo "step9: GATK HaplotypeCaller to ${raw_vcf_file}"
	GATK -T HaplotypeCaller -R ${GenomeFastaFile} \
		-I ${in_bam_file} \
		-dontUseSoftClippedBases -stand_call_conf ${StandCallConf} \
		-o ${raw_vcf_file}
}

gatk_variant_call_UnifiedGenotyper(){
	local in_bam_file=$1
	local raw_vcf_file=$2
	echo "step9: UnifiedGenotyper to ${raw_vcf_file}"
	GATK -T UnifiedGenotyper -R ${GenomeFastaFile} \
		-I ${in_bam_file} \
		-stand_call_conf ${StandCallConf} \
		-nt ${NumThreads} \
		-o ${raw_vcf_file}
}

gatk_variant_filter(){
	local raw_vcf_file=$1
	local filter_vcf_file=$2
	echo "step10: VariantFiltration to ${filter_vcf_file}"
	GATK -T VariantFiltration -R ${GenomeFastaFile} \
		-V ${raw_vcf_file} -window ${Window} -cluster ${Cluster} \
		-filterName FS -filter "FS>${FSFilter}" \
		-filterName QD -filter "QD<${QDFilter}" \
		-o ${filter_vcf_file}
}


gatk_variant_select(){
	local filter_vcf_file=$1
	local selected_vcf_file=$2
	echo "step11: SelectVariants snp to ${selected_vcf_file}"
	GATK -T SelectVariants -R $GenomeFastaFile \
		-V ${filter_vcf_file} \
		-selectType SNP \
		-o ${selected_vcf_file}
}












