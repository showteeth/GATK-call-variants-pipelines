#!/bin/bash
set -e

#BSUB -J gatk
#BSUB -o gatk_out.%J
#BSUB -e gatk_err.%J
#BSUB -n thread_tmp
#BSUB -R "select [mem>42000]" 
#BSUB -q TEST-A

