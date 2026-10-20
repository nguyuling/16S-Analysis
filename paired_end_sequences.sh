#!/bin/sh
set -e

# directories (rename if needed)
dir="/Volumes/T7/paired_end_sequences"
Reads="$dir/1_Reads"
Feature="$dir/2_Feature"
Taxonomy_a="$dir/3_taxonomy_a"
Taxonomy_v="$dir/4_taxonomy_v"
Diversity="$dir/5_diversity"
Differential="$dir/6_differential"

# input files (rename if needed)
metadata_name="sample-metadata.tsv"
ref_seqs="/Volumes/T7/databases/moving_pictures/reference-sequences.qza"
ref_taxa="/Volumes/T7/databases/moving_pictures/reference-taxonomy.qza"

# generated files
metadata="$dir/$metadata_name"
table="$Feature/table.qza"
classification="$Taxonomy_a/classification.qza"

mkdir -p "$Reads" && cd "$Reads"
    for f in "$dir"/*; do
        [ -f "$f" ] || continue                  # skip folders and anything that isn't a file
        name=$(basename "$f")
        if [ "$name" = "$metadata_name" ]; then
            continue
        fi
        mv "$f" "$Reads/"
    done

    qiime tools import \
        --type 'SampleData[PairedEndSequencesWithQuality]' \
        --input-path "$Reads" \
        --input-format CasavaOneEightSingleLanePerSampleDirFmt \
        --output-path data.qza \
    # run `qiime tools list-types` to check all '--type'

echo "Successfully import and demux read!"


mkdir -p "$Feature" && cd "$Feature"
    qiime dada2 denoise-paired \
        --i-demultiplexed-seqs "$Reads/data.qza" \
        --p-trunc-len-f 0 \
        --p-trunc-len-r 0 \
        --o-representative-sequences rep_seqs.qza \
        --o-table "$table" \
        --o-denoising-stats denoising-stats.qza
    # set '--p-trunc-len-f' and '--p-trunc-len-r'

    qiime Feature-table summarize \
        --i-table "$table" \
        --m-sample-metadata-file "$metadata" \
        --o-visualization summary.qzv

echo "Successfully generate ASV table and its summary!"


mkdir -p "$Taxonomy_a" && cd "$Taxonomy_a"
    qiime Feature-classifier classify-consensus-blast \
        --i-query "$Feature/rep_seqs.qza" \
        --i-reference-Reads "$ref_seqs" \
        --i-reference-taxonomy "$ref_taxa" \
        --o-classification "$classification" \
        --o-search-results search-results.qza

    qiime taxa collapse \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --p-level 3 \
        --o-collapsed-table collapsed_table.qza
    # set '--p-level' (1-6) to collapse

echo "Successfully classify Feature and perform taxa collapse!"


mkdir -p "$Taxonomy_v" && cd "$Taxonomy_v"
    qiime Feature-table heatmap \
        --i-table "$Taxonomy_a/collapsed_table.qza" \
        --o-visualization Feature-heatmap.qzv

    qiime taxa barplot \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --m-metadata-file "$metadata" \
        --o-visualization taxa-barplot.qzv

echo "Successfully visualize Feature and taxonomy distribution!"


# Diversity
    qiime diversity core-metrics \
        --i-table "$table" \
        --p-sampling-depth 7800 \
        --m-metadata-file "$metadata" \
        --output-dir "$Diversity"
    # set '--p-sampling-depth'
    # alpha diversity: shannon, observed-Features, faith, evenness
    # beta diversity: jaccard, bray-curtis

    cd "$Diversity"

    qiime diversity alpha-rarefaction \
        --i-table "$table" \
        --p-max-depth 7800 \
        --m-metadata-file "$metadata" \
        --o-visualization alpha_rarefaction.qzv

echo "Successfully compute alpha and beta diversity scores!"


mkdir -p "$Differential" && cd "$Differential"
    qiime composition ancombc \
        --i-table "$table" \
        --m-metadata-file "$metadata" \
        --p-formula Group \
        --o-differentials differentials.qza
    # set '--p-formula' to a column name of the metadata

    qiime composition tabulate \
        --i-data differentials.qza \
        --o-visualization visualization.qzv

echo "Successfully compute differential abundance!"