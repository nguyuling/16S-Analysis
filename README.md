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

Directories with suffix:
- `_a` contain table files `*.qza`
- `_v` contain visualization files `*.qzv`

All qiime zipped files can be viewed on [QIIME2 View](https://view.qiime2.org).

```
16S_Project
├── 1_Reads
│   ├── (all read files)
│   └── data.qza                        # demuxed read
│
├── 2_Feature
│   ├── denoising-stats.qza
│   ├── rep_seqs.qza                    # fasta sequences
│   └── table.qza                       # asv table
│
├── 3_taxonomy_a
│   ├── classification.qza              # taxonomy assignment of features
│   ├── search-results.qza              # blast search result
│   ├── table_lvl3.qza                  # taxa collapse to level 3 - class
│   └── table_lvl7.qza                  # taxa collapse to level 7 - species    
│   
├── 4_taxonomy_v
│   ├── feature_heatmap.qzv
│   ├── taxa_barplot.qzv                # interactive bar plot
│   └── summary.qzv                     # sample and taxa bar plot
│
├── 5_diversity_a
│   ├── (all alpha and beta diversities .qza)
│   ├── bray_curtis_pcoa_biplot.qza
│   ├── jaccard_pcoa_biplot.qza
│   └── rel_table_lvl3_.qza
│
├── 6_diversity_v
│   ├── alpha_rarefaction.qzv           # alpha: line chart
│   ├── bray_curtis_emperor.qzv         # beta: 3D scatter plot
│   ├── bray_curtis_emperor_biplot.qzv  # beta: 3D biplot
│   ├── jaccard_emperor.qzv             # beta: 3D scatter plot
│   ├── jaccard_emperor_biplot.qzv      # beta: 3D biplot
│   ├── observed_features_vector.qzv    # alpha: box plot
│   └── shannon_vector.qzv              # alpha: box plot
│
├── 7_differential
│   ├── ancom.qzv                       # ancom volcano plot
│   ├── comp_table.qza 
│   ├── da_barplot.qzv                  # da bar plot
│   ├── da_table.qzv                    # da interactive table
│   └── differentials.qza
│
├── logs
│   └── pipeline_20261020_140840.log
│
└── sample-metadata.tsv
```