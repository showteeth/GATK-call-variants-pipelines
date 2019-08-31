#!/bin/bash
# @Date    : 2019-08-27 21:04:40

GATK_RNA_seq=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${GATK_RNA_seq}/pipe_config.sh

for i in `ls -1 -d ${data_folder}/*`
do
	sample_name=$(basename ${i})
	fastq_folder=${i}
	if [[ -f ${scripts_folder}/${sample_name}.run ]]
	then
		rm ${scripts_folder}/${sample_name}.run
	fi

	if [[ "${RunPlatform}" == "workstation" ]]
	then
		cat ${GATK_RNA_seq}/workstation_header.sh >>${scripts_folder}/${sample_name}.run
	elif [[ "${RunPlatform}" == "tsinghua" ]]
	then
		cat ${GATK_RNA_seq}/bsub_header.sh >>${scripts_folder}/${sample_name}.run
		sed -i "s/thread_tmp/${NumThreads}/" ${scripts_folder}/${sample_name}.run
	elif [[ "${RunPlatform}" == "peking" ]]
	then
		cat ${GATK_RNA_seq}/sge_header.sh >>${scripts_folder}/${sample_name}.run
		sed -i "s/node_tmp/${Node}/" ${scripts_folder}/${sample_name}.run
		sed -i "s/cpu_tmp/${Cpu}/" ${scripts_folder}/${sample_name}.run
	fi

	echo -e "source ${GATK_RNA_seq}/comman_func.sh \nsource ${GATK_RNA_seq}/pipe_func.sh \nsource ${GATK_RNA_seq}/pipe_config.sh" >>${scripts_folder}/${sample_name}.run
	
	echo "fastq_folder=${fastq_folder}" >>${scripts_folder}/${sample_name}.run
	echo "gunzip_reads" >>${scripts_folder}/${sample_name}.run
	qc_folder=${results_folder}/${sample_name}/qc
	echo "qc ${qc_folder}" >>${scripts_folder}/${sample_name}.run

	trim_folder=${results_folder}/${sample_name}/trim
	echo "trim_paired ${trim_folder} ${trim_folder}" >>${scripts_folder}/${sample_name}.run

	index_1pass_folder=$(dirname ${GenomeFastaFile})/index_1pass
	echo "generate_star_1pass_index ${index_1pass_folder}" >>${scripts_folder}/${sample_name}.run

	mapping_1pass_folder=${results_folder}/${sample_name}/mapping_1pass
	echo "satr_mapping ${index_1pass_folder} ${trim_folder} ${mapping_1pass_folder}" >>${scripts_folder}/${sample_name}.run

	index_2pass_folder=$(dirname ${GenomeFastaFile})/index_2pass
	echo "generate_star_2pass_index ${index_2pass_folder} ${mapping_1pass_folder}" >>${scripts_folder}/${sample_name}.run

	mapping_2pass_folder=${results_folder}/${sample_name}/mapping_2pass
	echo "satr_mapping ${index_2pass_folder} ${trim_folder} ${mapping_2pass_folder}" >>${scripts_folder}/${sample_name}.run

	echo "gatk_generate_dict" >>${scripts_folder}/${sample_name}.run

	process_bam_folder=${results_folder}/${sample_name}/process_bam
	mkdir -p ${process_bam_folder}
	process_bam_header=${process_bam_folder}/${sample_name}
	echo -e "RGLB=${sample_name}_${DataType} \nRGPL=${SequencingPlatform} \nRGSM=${sample_name}">>${scripts_folder}/${sample_name}.run
	echo "gatk_add_group ${mapping_2pass_folder} ${process_bam_header}_group.bam" >>${scripts_folder}/${sample_name}.run

	echo "gatk_markdup ${process_bam_header}_group.bam ${process_bam_header}_markdup.bam  ${process_bam_header}_dupmetrics" >>${scripts_folder}/${sample_name}.run

	echo "gatk_splitntrim ${process_bam_header}_markdup.bam ${process_bam_header}_split.bam" >>${scripts_folder}/${sample_name}.run
	echo "gatk_indel_realign ${process_bam_header}_split.bam ${process_bam_header}_realign.bam ${process_bam_header}.intervals" >>${scripts_folder}/${sample_name}.run

	echo "gatk_base_recall ${process_bam_header}_realign.bam ${process_bam_header}_recal_table ${process_bam_header}_after_recal_table ${process_bam_header}_recal_plot.pdf ${process_bam_header}_racal.bam" >>${scripts_folder}/${sample_name}.run

	vcf_folder=${results_folder}/${sample_name}/vcf
	mkdir -p ${vcf_folder}
	echo "gatk_variant_call_HaplotypeCaller ${process_bam_header}_racal.bam ${vcf_folder}/${sample_name}_raw.vcf" >>${scripts_folder}/${sample_name}.run

	echo "gatk_variant_filter ${vcf_folder}/${sample_name}_raw.vcf ${vcf_folder}/${sample_name}_filter.vcf" >>${scripts_folder}/${sample_name}.run

	echo "gatk_variant_select ${vcf_folder}/${sample_name}_filter.vcf ${vcf_folder}/${sample_name}_snp.vcf" >>${scripts_folder}/${sample_name}.run

done


if [[ "${RunPlatform}" == "workstation" ]]
then
	for i in `ls -1 -d ${scripts_folder}/*.run`
	do
		nohup bash ${i} >${i}.log 2>&1 &
	done
elif [[ "${RunPlatform}" == "tsinghua" ]]
then
	for i in `ls -1 -d ${scripts_folder}/*.run`
	do
		bsub < ${i}
	done
elif [[ "${RunPlatform}" == "peking" ]]
then
	for i in `ls -1 -d ${scripts_folder}/*.run`
	do
		qsub ${i}
	done
fi

