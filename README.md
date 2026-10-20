# 16S Analysis Pipeline

### Environment / Packages Needed
(refer `env.yml`)
1. **qiime2** — `q2cli version 2024.10.1`
2. **R** — `R version 4.3.3 (2024-02-29)`

### Guide to Run the Pipeline
1. Locate all read files and metadata in a single folder, for example:

```
16S_Project
├── read_1.fastq.gz
├── read_n.fastq.qz
└── sample-metadata.tsv
```

2. Provide pathname in the RENAME block:
- directory / input files folder pathname
- metadata filename
- reference files pathname

3. Perform modification on the script where the comments locate, based on the reads file type, denoise settings, taxa level to collapse, sampling depth and metadata column name.

### Output Files Structure
```
16S_Project
├── 1_Reads
│   ├── (all read files)
│   └── data.qza                        # demuxed read
├── 2_Feature
│   ├── denoising-stats.qza
│   ├── rep_seqs.qza                    # fasta sequences
│   ├── summary.qzv                     # bar graph of sample and feature
│   └── table.qza                       # binary format
├── 3_taxonomy_a
│   ├── classification.qza              # taxonomy assignment to feature
│   ├── collapsed_table.qza             # binary format
│   └── search-results.qza              # blast search result
├── 4_taxonomy_v
│   ├── feature-heatmap.qzv
│   └── taxa-barplot.qzv                # interactive barplot
├── 5_diversity
│   └── (all alpha and beta diversities)
├── 6_differential
│   ├── differentials.qza               # differential stats of each feature
│   └── visualization.qzv
├── logs
│   └── pipeline_20261020_140840.log
└── sample-metadata.tsv
```