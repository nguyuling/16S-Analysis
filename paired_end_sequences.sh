#!/bin/sh
set -e

# directories (rename if needed)
Dir="/Volumes/T7/paired_end_sequences"
Reads="$Dir/1_Reads"
Feature="$Dir/2_Feature"
Taxonomy_a="$Dir/3_taxonomy_a"
Taxonomy_v="$Dir/4_taxonomy_v"
Diversity="$Dir/5_diversity"
Differential="$Dir/6_differential"

# input files (rename if needed)
metadata_name="sample-metadata.tsv"
ref_seqs="/Volumes/T7/databases/moving_pictures/reference-sequences.qza"
ref_taxa="/Volumes/T7/databases/moving_pictures/reference-taxonomy.qza"

# generated files
metadata="$Dir/$metadata_name"
table="$Feature/table.qza"
classification="$Taxonomy_a/classification.qza"

# logging
Log="$Dir/logs"
mkdir -p "$Log"
log_file="$Log/pipeline_$(date '+%Y%m%d_%H%M%S').log"
start_time=$(date +%s)

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
    msg="[$(timestamp)] $*"
    echo "$msg"                # console
    echo "$msg" >> "$log_file" # log file
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
    [ -f "$f" ] || continue                  # move all read files except the metadata
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
    --p-level 6 \
    --o-collapsed-table collapsed_table.qza
# set --p-level (1-6) to collapse

mkdir -p "$Taxonomy_v" && cd "$Taxonomy_v"

run qiime feature-table heatmap \
    --i-table "$Taxonomy_a/collapsed_table.qza" \
    --o-visualization feature-heatmap.qzv

run qiime taxa barplot \
    --i-table "$table" \
    --i-taxonomy "$classification" \
    --m-metadata-file "$metadata" \
    --o-visualization taxa-barplot.qzv

# $Diveristy
run qiime diversity core-metrics \
    --i-table "$table" \
    --p-sampling-depth 1700 \
    --m-metadata-file "$metadata" \
    --output-dir "$Diversity"
# set --p-sampling-depth
# alpha diversity: shannon, observed-features, evenness
# beta diversity: jaccard, bray-curtis

cd "$Diversity"

run qiime diversity alpha-rarefaction \
    --i-table "$table" \
    --p-max-depth 1700 \
    --m-metadata-file "$metadata" \
    --o-visualization alpha_rarefaction.qzv

mkdir -p "$Differential" && cd "$Differential"

run qiime composition ancombc \
    --i-table "$table" \
    --m-metadata-file "$metadata" \
    --p-formula Group \
    --o-differentials differentials.qza
# set --p-formula to a column name of the metadata

run qiime composition tabulate \
    --i-data differentials.qza \
    --o-visualization visualization.qzv