#!/bin/sh
set -e

# directories (rename if needed)
dir="/Volumes/T7/single_end_sequences"
Read="$dir/1_reads"
Feature="$dir/2_feature"
Taxonomy_a="$dir/3_taxonomy_a"
Taxonomy_v="$dir/4_taxonomy_v"
Diversity="$dir/5_diversity"
Differential="$dir/6_differential"

# input files (rename if needed)
r1="sequences.fastq.gz"
barcode="barcodes.fastq.gz"
metadata="$dir/sample-metadata.tsv"
ref_seqs="/Volumes/T7/databases/moving_pictures/reference-sequences.qza"
ref_taxa="/Volumes/T7/databases/moving_pictures/reference-taxonomy.qza"

# generated files
table="$Feature/table.qza"
classification="$Taxonomy_a/classification.qza"

mkdir -p "$Read" && cd "$Read"
    for f in "$r1" "$barcode"; do       # append read file if needed 
        if [ -f "$dir/$f" ];
            then mv "$dir/$f" "$Read/"
        fi
    done

    qiime tools import \
        --type 'EMPSingleEndSequences' \
        --input-path "$Read" \
        --output-path emp-single-end-sequences.qza \
    # run `qiime tools list-types` to check all '--type'

    qiime demux emp-single \
        --i-seqs emp-single-end-sequences.qza \
        --m-barcodes-file "$metadata" \
        --m-barcodes-column barcode-sequence \
        --o-per-sample-sequences demux.qza \
        --o-error-correction-details demux-details.qza

echo "Successfully import and demux read!"

mkdir -p "$Feature" && cd "$Feature"
    qiime dada2 denoise-single \
        --i-demultiplexed-seqs "$Read/demux.qza" \
        --p-trim-left 0 \
        --p-trunc-len 120 \
        --o-representative-sequences rep_seqs.qza \
        --o-table "$table" \
        --o-denoising-stats denoising-stats.qza \
    # set '--p-trunc-len'

    qiime feature-table summarize \
        --i-table "$table" \
        --m-sample-metadata-file "$metadata" \
        --o-visualization summary.qzv

echo "Successfully generate ASV table and its summary!"

mkdir -p "$Taxonomy_a" && cd "$Taxonomy_a"
    qiime feature-classifier classify-consensus-blast \
        --i-query "$Feature/rep_seqs.qza" \
        --i-reference-reads "$ref_seqs" \
        --i-reference-taxonomy "$ref_taxa" \
        --o-classification "$classification" \
        --o-search-results search-results.qza

    qiime taxa collapse \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --p-level 3 \
        --o-collapsed-table collapsed_table.qza
    # set '--p-level' (1-6) to collapse

echo "Successfully classify feature and perform taxa collapse!"

mkdir -p "$Taxonomy_v" && cd "$Taxonomy_v"
    qiime feature-table heatmap \
        --i-table "$Taxonomy_a/collapsed_table.qza" \
        --o-visualization feature-heatmap.qzv

    qiime taxa barplot \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --m-metadata-file "$metadata" \
        --o-visualization taxa-barplot.qzv

echo "Successfully visualize feature and taxonomy distribution!"

# Diversity
    qiime diversity core-metrics \
        --i-table "$table" \
        --p-sampling-depth 1103 \
        --m-metadata-file "$metadata" \
        --output-dir "$Diversity"
    # set '--p-sampling-depth'
    # alpha diversity: shannon, observed-features, faith, evenness
    # beta diversity: jaccard, bray-curtis

    cd "$Diversity"

    qiime diversity alpha-rarefaction \
        --i-table "$table" \
        --p-max-depth 1103 \
        --m-metadata-file "$metadata" \
        --o-visualization alpha_rarefaction.qzv

echo "Successfully compute alpha and beta diversity scores!"

mkdir -p "$Differential" && cd "$Differential"
    qiime composition ancombc \
        --i-table "$table" \
        --m-metadata-file "$metadata" \
        --p-formula bodysite \
        --o-differentials differentials.qza
    # set '--p-formula' to a column name of the metadata

    qiime composition tabulate \
        --i-data differentials.qza \
        --o-visualization visualization.qzv

echo "Successfully compute differential abundance!"