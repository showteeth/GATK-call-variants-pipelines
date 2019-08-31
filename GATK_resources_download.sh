#!/bin/bash
set -u
set -e
# @Date    : 2019-08-28 16:17:09
# @Author  : soyabean (songyb18@mails.tsinghua.edu.cn)

cat GATK_resources.txt |awk '$0!~/^#/'|while read line
do
	wget -b --tries=40 -o $(basename ${line}).log ${line}
done 

