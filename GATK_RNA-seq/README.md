## call variant from RNA-seq
this is a pipeline for call snp from RNA-Seq, following [GATK Best Practices workflow for SNP and indel calling on RNAseq data](https://software.broadinstitute.org/gatk/documentation/article.php?id=3891).

### software dependence
* java:1.8
* fastqc
* cutadapt
* trim_galore
* GATK:3.5
* picard:2.1.0
* STAR
* R(for AnalyzeCovariates plot): ggplot2、reshape、gsalib、gplots...

<hr />

### run step
#### download pipeline
```bash
git clone 
```

<hr />

#### modify config
* modify config file `pipe_config.sh`

<hr />

#### run pipeline
```bash
# get sample run scripts
./pipe_run.sh
```


### todo list
- [ ] Snakemake pipeline
- [ ] results stat, eg: Q20/Q30、MultiQC、qualimap
- [ ] add VariantQC

### possible problems
* RScript exited with 1： maybe R packages not install and load correctly, packages includes ggplot2、reshape、gsalib、gplots...  Run command again with -l DEBUG for detailed info.
