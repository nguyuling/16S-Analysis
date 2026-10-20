#!/bin/sh
set -e

# RENAME
Dir="/Volumes/T7/16s_project"                                               # path of read files and metadata
metadata_name="sample-metadata.tsv"                                         # metadata filename only
ref_seqs="/Volumes/T7/databases/moving_pictures/reference-sequences.qza"    # path of reference sequence
ref_taxa="/Volumes/T7/databases/moving_pictures/reference-taxonomy.qza"     # path of reference taxa

# directories
Reads="$Dir/1_reads"
Feature="$Dir/2_feature"
Taxonomy_a="$Dir/3_taxonomy_a"
Taxonomy_v="$Dir/4_taxonomy_v"
Diversity_a="$Dir/5_diversity_a"
Diversity_v="$Dir/6_diversity_v"
Differential="$Dir/7_differential"

# files
metadata="$Dir/$metadata_name"
table="$Feature/table.qza"
classification="$Taxonomy_a/classification.qza"
table_lvl6="$Taxonomy_a/table_lvl6.qza"
rel_table_lvl6="$Diversity_a/rel_table_lvl6.qza"

# logging
Log="$Dir/logs"
mkdir -p "$Log"
log_file="$Log/pipeline_$(date '+%Y%m%d_%H%M%S').log"
start_time=$(date +%s)

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
    msg="[$(timestamp)] $*"
    echo "$msg"                 # console
    echo "$msg" >> "$log_file"  # log file
}

# run a command, log it, send its stdout/stderr to the log file, and record the result
run() {
    log "START: $*"
    step_start=$(date +%s)
    if "$@" >> "$log_file" 2>&1; then
        log "OK ($(( $(date +%s) - step_start ))s)"
    else
        rc=$?
        log "FAILED with exit code $rc: $*"
        log "See $log_file for the full error output."
        exit "$rc"
    fi
}

finish() {
    rc=$?
    total=$(( $(date +%s) - start_time ))
    if [ "$rc" -eq 0 ]; then
        log "PIPELINE COMPLETED SUCCESSFULLY in ${total}s"
    else
        log "PIPELINE STOPPED with exit code $rc after ${total}s"
    fi
}
trap finish EXIT

log "PIPELINE STARTED"
log "Data directory: $Dir"
log "Log file: $log_file"

mkdir -p "$Reads" && cd "$Reads"
log "Moving input files into $Reads"
for f in "$Dir"/*; do
    [ -f "$f" ] || continue     # move all read files except the metadata
    name=$(basename "$f")
    if [ "$name" = "$metadata_name" ]; then
        continue
    fi
    mv "$f" "$Reads/"
    log "Moved: $name"
done

run qiime tools import \
    --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path "$Reads" \
    --input-format CasavaOneEightSingleLanePerSampleDirFmt \
    --output-path data.qza
# run qiime tools list-types to check all --type
# --input-format (optional)

mkdir -p "$Feature" && cd "$Feature"

run qiime dada2 denoise-paired \
    --i-demultiplexed-seqs "$Reads/data.qza" \
    --p-trunc-len-f 0 \
    --p-trunc-len-r 0 \
    --o-representative-sequences rep_seqs.qza \
    --o-table "$table" \
    --o-denoising-stats denoising-stats.qza
# set --p-trunc-len-f and --p-trunc-len-r

run qiime feature-table summarize \
    --i-table "$table" \
    --m-sample-metadata-file "$metadata" \
    --o-visualization summary.qzv

mkdir -p "$Taxonomy_a" && cd "$Taxonomy_a"

run qiime feature-classifier classify-consensus-blast \
    --i-query "$Feature/rep_seqs.qza" \
    --i-reference-reads "$ref_seqs" \
    --i-reference-taxonomy "$ref_taxa" \
    --o-classification "$classification" \
    --o-search-results search-results.qza

run qiime taxa collapse \
    --i-table "$table" \
    --i-taxonomy "$classification" \
    --p-level 3 \
    --o-collapsed-table table_lvl3.qza
# set --p-level (1-6) to collapse - for heatmap

run qiime taxa collapse \
    --i-table "$table" \
    --i-taxonomy "$classification" \
    --p-level 6 \
    --o-collapsed-table "$table_lvl6"
# set --p-level (1-6) to collapse - for differentials stats

mkdir -p "$Taxonomy_v" && cd "$Taxonomy_v"

run qiime feature-table heatmap \
    --i-table "$Taxonomy_a/table_lvl3.qza" \
    --o-visualization feature_heatmap.qzv

run qiime taxa barplot \
    --i-table "$table" \
    --i-taxonomy "$classification" \
    --m-metadata-file "$metadata" \
    --o-visualization taxa_barplot.qzv

run qiime diversity core-metrics \
    --i-table "$table" \
    --p-sampling-depth 1700 \
    --m-metadata-file "$metadata" \
    --output-dir "$Diversity_a"
# set --p-sampling-depth

cd "$Diversity_a"

run qiime feature-table relative-frequency \
    --i-table "$table_lvl6" \
    --o-relative-frequency-table "$rel_table_lvl6"

run qiime diversity pcoa-biplot \
    --i-pcoa bray_curtis_pcoa_results.qza \
    --i-features "$rel_table_lvl6" \
    --o-biplot bray_curtis_pcoa_biplot.qza

run qiime diversity pcoa-biplot \
    --i-pcoa jaccard_pcoa_results.qza \
    --i-features "$rel_table_lvl6" \
    --o-biplot jaccard_pcoa_biplot.qza

mkdir -p "$Diversity_v" && cd "$Diversity_v"

run qiime diversity alpha-rarefaction \
    --i-table "$table" \
    --p-max-depth 1700 \
    --m-metadata-file "$metadata" \
    --o-visualization alpha_rarefaction.qzv
# set --p-max-depth

run qiime diversity alpha-group-significance \
    --i-alpha-diversity "$Diversity_a/shannon_vector.qza" \
    --m-metadata-file "$metadata" \
    --o-visualization shannon_vector.qzv

run qiime diversity alpha-group-significance \
    --i-alpha-diversity "$Diversity_a/observed_features_vector.qza" \
    --m-metadata-file "$metadata" \
    --o-visualization observed_features_vector.qzv

run qiime emperor biplot \
    --i-biplot "$Diversity_a/bray_curtis_pcoa_biplot.qza" \
    --m-sample-metadata-file "$metadata" \
    --o-visualization bray_curtis_emperor_biplot.qzv

run qiime emperor biplot \
    --i-biplot "$Diversity_a/jaccard_pcoa_biplot.qza" \
    --m-sample-metadata-file "$metadata" \
    --o-visualization jaccard_emperor_biplot.qzv

mkdir -p "$Differential" && cd "$Differential"

run qiime composition ancombc \
    --i-table "$table_lvl6" \
    --m-metadata-file "$metadata" \
    --p-formula Habitat \
    --o-differentials differentials.qza
# set --p-formula to a column name of the metadata

run qiime composition tabulate \
    --i-data differentials.qza \
    --o-visualization da_table.qzv

run qiime composition da-barplot \
    --i-data differentials.qza \
    --o-visualization da_barplot.qzv

run qiime composition add-pseudocount \
    --i-table "$table_lvl6" \
    --o-composition-table comp_table.qza

run qiime composition ancom \
    --i-table comp_table.qza \
    --m-metadata-file "$metadata" \
    --m-metadata-column Habitat \
    --o-visualization ancom.qzv

# plot using R
# 6_diversity_v
    # bray_curtis_emperor_biplot.qzv
    # jaccard_emperor_biplot.qzv
# 7_differential
    # da_table.qzv
    # da_barplot.qzv
    # ancom.qzv