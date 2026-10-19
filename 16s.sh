#!/bin/sh
set -e

# directories
dir="/Volumes/T7/16s"
reads="$dir/0_sequences"
features="$dir/1_features"
taxonomy_a="$dir/2_taxonomy_a"
taxonomy_v="$dir/3_taxonomy_v"
diversity="$dir/4_diversity"
differential="$dir/5_differential"

# files
read="sequences.fastq.gz"
barcode="barcodes.fastq.gz"
metadata="$dir/sample-metadata.tsv"
ref_seqs="/Volumes/T7/databases/silva138_AB_V3_V4/silva138_AB_V3-V4seqs_uniq.qza"
ref_taxa="/Volumes/T7/databases/silva138_AB_V3_V4/silva138_AB_V3-V4taxa_uniq.qza"
table="$features/table.qza"
classification="$taxonomy_a/classification.qza"

# mkdir -p "$reads" && cd "$reads"
#     mv "$dir/$read" "$dir/$barcode" "$reads"
# 
#     qiime tools import \
#         --type 'EMPSingleEndSequences' \
#         --input-path "$reads" \
#         --output-path emp-single-end-sequences.qza \
#         #! run `qiime tools list-types` to check all '--type'
# 
#     qiime demux emp-single \
#         --i-seqs emp-single-end-sequences.qza \
#         --m-barcodes-file "$metadata" \
#         --m-barcodes-column barcode-sequence \
#         --o-per-sample-sequences demux.qza \
#         --o-error-correction-details demux-details.qza
# 
# mkdir -p "$features" && cd "$features"
#     qiime dada2 denoise-single \
#         --i-demultiplexed-seqs "$reads/demux.qza" \
#         --p-trim-left 0 \
#         --p-trunc-len 120 \
#         --o-representative-sequences representative-sequences.qza \
#         --o-table "$table" \
#         --o-denoising-stats denoising-stats.qza \
#         #! set '--p-trunc-len'
# 
#     qiime feature-table summarize \
#         --i-table "$table" \
#         --m-sample-metadata-file "$metadata" \
#         --o-visualization summary.qzv \


mkdir -p "$taxonomy_a" && cd "$taxonomy_a"
    qiime feature-classifier classify-consensus-blast \
        --i-query "$features/representative-sequences.qza" \
        --i-reference-reads "$ref_seqs" \
        --i-reference-taxonomy "$ref_taxa" \
        --o-classification "$classification"

    qiime taxa collapse \
    --i-table "$table" \
    --i-taxonomy "$classification" \
    --p-level 3 \
    --o-collapsed-table collapsed_table.qza
    #! choose taxonomy level (1-7) to collapse


mkdir -p "$taxonomy_v" && cd "$taxonomy_v"
    qiime feature-table heatmap \
        --i-table "$taxonomy_a/collapsed_table.qza" \
        --o-visualization feature-heatmap.qzv

    qiime taxa barplot \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --m-metadata-file "$metadata" \
        --o-visualization taxa-barplot.qzv


mkdir $diversity
    qiime diversity alpha-rarefaction \
        --i-table "$table" \
        --p-max-depth 7800 \
        --m-metadata-file "$metadata" \
        --o-visualization alpha_rarefaction.qzv

    qiime diversity core-metrics \
        --i-table "$table" \
        --p-sampling-depth 7800 \
        --m-metadata-file "$metadata" \
        --o-rarefied-table rarefied-table.qza \
        --o-observed-features-vector observed-features-vector.qza \
        --o-shannon-vector shannon-vector.qza \
        --o-evenness-vector evenness-vector.qza \
        --o-jaccard-distance-matrix jaccard-distance-matrix.qza \
        --o-bray-curtis-distance-matrix bray-curtis-distance-matrix.qza \
        --o-jaccard-pcoa-results jaccard-pcoa-results.qza \
        --o-bray-curtis-pcoa-results bray-curtis-pcoa-results.qza \
        --o-jaccard-emperor jaccard-emperor.qzv \
        --o-bray-curtis-emperor bray-curtis-emperor.qzv

mkdir $differential
    qiime composition ancombc \
        --i-table "$table" \
        --m-metadata-file "$metadata" \
        --p-formula bodysite \
        --o-differentials differentials.qza

    qiime composition tabulate \
        --i-data differentials.qza \
        --o-visualization visualization.qzv