#!/bin/bash
# @Date    : 2019-08-26 23:12:17

################################################################
############## storage comman used functions ###################
################################################################

gunzip_reads(){
	if ls ${fastq_folder}/*.gz >/dev/null 2>&1
	then
		gunzip ${fastq_folder}/*.gz
	fi
}

distinguish_read(){
	local flag;local read1;local read2
	for i in $(ls -1 -d ${fastq_folder}/*|grep -P "\.(fq|fastq)$")
	do
		flag=$(awk 'NR==1 && $2~/^1:N/' ${i})
		if  [[ -n ${flag} ]]
		then
			read1=${i}
		else
			read2=${i}
		fi
	done
	echo ${read1}
	echo ${read2}
}

get_read_group(){
	local fq_array;local group_string;local rgID
	fq_array=($(ls -1 -d ${fastq_folder}/*|grep -P "\.(fq|fastq)$"))
	group_string=($(head -n 1 ${fq_array[0]}|awk '{print $1}'|awk '{len=split($0,words,":");for (i=1;i<=len;i++){print words[i]}}'))
	rgID=${group_string[1]}_${group_string[3]}
	echo ${rgID}
}

get_STAROverhang(){
	local fq_array;local STAROverhang
	fq_array=($(ls -1 -d ${fastq_folder}/*|grep -P "\.(fq|fastq)$"))
	STAROverhang=$(head -n 2 ${fq_array[0]}|awk 'NR==2 {print length($0)-1}')
	echo ${STAROverhang}
}