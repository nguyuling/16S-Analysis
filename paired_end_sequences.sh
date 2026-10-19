#!/bin/sh
set -e

# directories (rename if needed)
dir="/Volumes/T7/paired_end_sequences"
dir_reads="$dir/1_reads"
dir_feature="$dir/2_feature"
dir_taxonomy_a="$dir/3_taxonomy_a"
dir_taxonomy_v="$dir/4_taxonomy_v"
dir_diversity="$dir/5_diversity"
dir_differential="$dir/6_differential"

# input files (rename if needed)
metadata_name="sample-metadata.tsv"
ref_seqs="/Volumes/T7/databases/moving_pictures/reference-sequences.qza"
ref_taxa="/Volumes/T7/databases/moving_pictures/reference-taxonomy.qza"

# generated files
metadata="$dir/$metadata_name"
table="$dir_feature/table.qza"
classification="$dir_taxonomy_a/classification.qza"

mkdir -p "$dir_reads" && cd "$dir_reads"
    for f in "$dir"/*; do
        [ -f "$f" ] || continue                  # skip folders and anything that isn't a file
        name=$(basename "$f")
        if [ "$name" = "$metadata_name" ]; then
            continue
        fi
        mv "$f" "$dir_reads/"
    done

    qiime tools import \
        --type 'SampleData[PairedEndSequencesWithQuality]' \
        --input-path "$dir_reads" \
        --input-format CasavaOneEightSingleLanePerSampleDirFmt \
        --output-path data.qza \
    # run `qiime tools list-types` to check all '--type'

echo "Successfully import and demux read!"


mkdir -p "$dir_feature" && cd "$dir_feature"
    qiime dada2 denoise-paired \
        --i-demultiplexed-seqs "$dir_reads/data.qza" \
        --p-trunc-len-f 0 \
        --p-trunc-len-r 0 \
        --o-representative-sequences rep_seqs.qza \
        --o-table "$table" \
        --o-denoising-stats denoising-stats.qza
    # set '--p-trunc-len-f' and '--p-trunc-len-r'

    qiime feature-table summarize \
        --i-table "$table" \
        --m-sample-metadata-file "$metadata" \
        --o-visualization summary.qzv

echo "Successfully generate ASV table and its summary!"


mkdir -p "$dir_taxonomy_a" && cd "$dir_taxonomy_a"
    qiime feature-classifier classify-consensus-blast \
        --i-query "$dir_feature/rep_seqs.qza" \
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


mkdir -p "$dir_taxonomy_v" && cd "$dir_taxonomy_v"
    qiime feature-table heatmap \
        --i-table "$dir_taxonomy_a/collapsed_table.qza" \
        --o-visualization feature-heatmap.qzv

    qiime taxa barplot \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --m-metadata-file "$metadata" \
        --o-visualization taxa-barplot.qzv

echo "Successfully visualize feature and taxonomy distribution!"


# dir_diversity
    qiime diversity core-metrics \
        --i-table "$table" \
        --p-sampling-depth 7800 \
        --m-metadata-file "$metadata" \
        --output-dir "$dir_diversity"
    # set '--p-sampling-depth'
    # alpha diversity: shannon, observed-features, faith, evenness
    # beta diversity: jaccard, bray-curtis

    cd "$dir_diversity"

    qiime diversity alpha-rarefaction \
        --i-table "$table" \
        --p-max-depth 7800 \
        --m-metadata-file "$metadata" \
        --o-visualization alpha_rarefaction.qzv

echo "Successfully compute alpha and beta diversity scores!"


mkdir -p "$dir_differential" && cd "$dir_differential"
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