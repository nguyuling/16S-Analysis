# 16S Analysis Pipeline

### Packages Needed
(refer `env.yml`)
1. **qiime2** — `q2cli version 2024.10.1`
2. **R** — `R version 4.3.3 (2024-02-29)`

### Guide to Run the Pipeline
1. Locate all read files and metadata in a single folder, for example:

```bash
Dir/
├── read_1.fastq.gz
├── read_n.fastq.qz
├── sample-metadata.tsv
```

2. Provide pathname in the RENAME block:
- directory / input files folder pathname
- metadata filename
- reference files pathname

3. Perform modification on the script where the comments locate, based on the reads file type, denoise settings, taxa level to collapse, sampling depth and metadata column name.

### Output Files Structure
```bash
Dir/
├── 1_Reads/
|      ├── (all read files)
|      └── data.qza              # demuxed read
├── 2_Feature/
|      ├── denoise_stats.qza
|      ├── rep_seqs.qza          # fasta sequences
|      ├── summary.qzv           # bar graph of sample and feature
|      └── table.qza             # binary format
├── 3_Taxonomy_a/
|      ├── classification.qza    # taxonomy assignment to feature
|      ├── collapsed_table.qza   # binary format
|      └── search_results.qza    # blast search result
├── 4_Taxonomy_v/
|      ├── feature_heatmap.qzv
|      └── taxa_barplot.qzv      # interactive barplot
├── 5_Diversity/
|      └── (all alpha and beta diversities files)
├── 6_Differential/
|      ├── differentials.qza     # differential stats of each feature
|      └── visualizaton.qzv
└── sample-metadata.tsv
```