#!/bin/sh
# sh 16s.sh                 interactive menu
# sh 16s.sh 3 4 5           run these steps only
# sh 16s.sh all             run every step, skipping finished ones
# sh 16s.sh allforce        run every step, regardless of existing outputs

ScriptDir="$(cd "$(dirname "$0")" && pwd)"
. "$ScriptDir/16s_lib.sh"

trap 'log "SESSION ENDED"' EXIT
log "SESSION STARTED. Log file: $log_file"

# —————————————————————————————————————— reads ——————————————————————————————————————————

import() {                                                  # 1
    mkdir -p "$Reads" || return 1
    if [ ! -f "$Reads/data.qza" ] && [ ! -f "$Reads/.moved" ]; then
        for f in "$Outdir"/*; do
            [ -f "$f" ] || continue
            [ "$(basename "$f")" = "$metadata_name" ] && continue
            mv "$f" "$Reads/" && log "Moved: $(basename "$f")"
        done
        touch "$Reads/.moved"
    fi
    skip_if_done "import" "$Reads/data.qza" && return 0
    clear_outputs "$Reads/data.qza"
    run qiime tools import \
        --type 'SampleData[PairedEndSequencesWithQuality]' \
        --input-path "$Reads" \
        --input-format CasavaOneEightSingleLanePerSampleDirFmt \
        --output-path "$Reads/data.qza"
    # RUN qiime tools list-types to check all type
}

# —————————————————————————————————————— feature ————————————————————————————————————————

denoise() {                                                 # 2
    need "$Reads/data.qza" 1 || return 1
    skip_if_done "denoise" "$table" "$rep_seqs" && return 0
    mkdir -p "$Feature" || return 1
    clear_outputs "$table" "$rep_seqs" "$Feature/denoising-stats.qza"
    run qiime dada2 denoise-paired \
        --i-demultiplexed-seqs "$Reads/data.qza" \
        --p-trunc-len-f 0 \
        --p-trunc-len-r 0 \
        --o-representative-sequences "$rep_seqs" \
        --o-table "$table" \
        --o-denoising-stats "$Feature/denoising-stats.qza"
    # SET p-trunc-len-f and --p-trunc-len-r
}

# ————————————————————————————————————— taxonomy_a ——————————————————————————————————————

classify() {                                                # 3
    need "$rep_seqs" 2 || return 1
    produce "classify" "$classification" \
        qiime feature-classifier classify-consensus-blast \
        --i-query "$rep_seqs" \
        --i-reference-reads "$ref_seqs" \
        --i-reference-taxonomy "$ref_taxa" \
        --o-classification "$classification" \
        --o-search-results "$Taxonomy_a/search-results.qza"
}

collapse_lvl3() {                                           # 4
    need "$classification" 3 || return 1
    produce "collapse level 3" "$taxa_collapsed" \
        qiime taxa collapse \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --p-level 3 \
        --o-collapsed-table "$taxa_collapsed"
}

# ———————————————————————————————————— taxonomy_v ———————————————————————————————————————

summarize() {                                               # 5
    need "$classification" 3 || return 1
    skip_if_done "summarize" "$Taxonomy_v/summary.qzv" && return 0
    mkdir -p "$Taxonomy_v" || return 1
    clear_outputs "$taxa_species" "$Taxonomy_v/summary.qzv"
    run qiime taxa collapse \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --p-level 7 \
        --o-collapsed-table "$taxa_species" || return 1
    run qiime feature-table summarize \
        --i-table "$taxa_species" \
        --m-sample-metadata-file "$metadata" \
        --o-visualization "$Taxonomy_v/summary.qzv"
}

heatmap() {                                                 # 6
    need "$taxa_collapsed" 4 || return 1
    produce "heatmap" "$Taxonomy_v/feature_heatmap.qzv" \
        qiime feature-table heatmap \
        --i-table "$taxa_collapsed" \
        --o-visualization "$Taxonomy_v/feature_heatmap.qzv"
}

taxa_barplot() {                                            # 7
    need "$classification" 3 || return 1
    produce "taxa barplot" "$Taxonomy_v/taxa_barplot.qzv" \
        qiime taxa barplot \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --m-metadata-file "$metadata" \
        --o-visualization "$Taxonomy_v/taxa_barplot.qzv"
}

# ———————————————————————————————————— diversity_a ——————————————————————————————————————

core_metrics() {                                            # 8
    need "$table" 2 || return 1
    skip_if_done "core metrics" "$Diversity_a/bray_curtis_pcoa_results.qza" && return 0
    clear_outputs "$Diversity_a"            # core-metrics fails if its output dir exists
    mkdir -p "$Diversity_v" || return 1
    run qiime diversity core-metrics \
        --i-table "$table" \
        --p-sampling-depth 1700 \
        --m-metadata-file "$metadata" \
        --output-dir "$Diversity_a" || return 1
    # SET p-sampling-depth
    mv "$Diversity_a/bray_curtis_emperor.qzv" "$Diversity_a/jaccard_emperor.qzv" "$Diversity_v/" 2>/dev/null
    return 0
}

rel_freq() {                                                # 9
    need "$taxa_collapsed" 4 || return 1
    produce "relative frequency" "$taxa_collapsed_relfreq" \
        qiime feature-table relative-frequency \
        --i-table "$taxa_collapsed" \
        --o-relative-frequency-table "$taxa_collapsed_relfreq"
}

biplot_bray() {                                             # 10
    need "$Diversity_a/bray_curtis_pcoa_results.qza" 8 || return 1
    need "$taxa_collapsed_relfreq" 9 || return 1
    produce "Bray-Curtis PCoA biplot" "$Diversity_a/bray_curtis_pcoa_biplot.qza" \
        qiime diversity pcoa-biplot \
        --i-pcoa "$Diversity_a/bray_curtis_pcoa_results.qza" \
        --i-features "$taxa_collapsed_relfreq" \
        --o-biplot "$Diversity_a/bray_curtis_pcoa_biplot.qza"
}

biplot_jaccard() {                                          # 11
    need "$Diversity_a/jaccard_pcoa_results.qza" 8 || return 1
    need "$taxa_collapsed_relfreq" 9 || return 1
    produce "Jaccard PCoA biplot" "$Diversity_a/jaccard_pcoa_biplot.qza" \
        qiime diversity pcoa-biplot \
        --i-pcoa "$Diversity_a/jaccard_pcoa_results.qza" \
        --i-features "$taxa_collapsed_relfreq" \
        --o-biplot "$Diversity_a/jaccard_pcoa_biplot.qza"
}

# ———————————————————————————————————— diversity_v ——————————————————————————————————————

alpha_rarefaction() {                                       # 12
    need "$table" 2 || return 1
    produce "alpha rarefaction" "$Diversity_v/alpha_rarefaction.qzv" \
        qiime diversity alpha-rarefaction \
        --i-table "$table" \
        --p-max-depth 1700 \
        --m-metadata-file "$metadata" \
        --o-visualization "$Diversity_v/alpha_rarefaction.qzv"
    # SET p-max-depth
}

alpha_shannon() {                                           # 13
    need "$Diversity_a/shannon_vector.qza" 8 || return 1
    produce "alpha significance (Shannon)" "$Diversity_v/shannon_vector.qzv" \
        qiime diversity alpha-group-significance \
        --i-alpha-diversity "$Diversity_a/shannon_vector.qza" \
        --m-metadata-file "$metadata" \
        --o-visualization "$Diversity_v/shannon_vector.qzv"
}

alpha_observed() {                                          # 14
    need "$Diversity_a/observed_features_vector.qza" 8 || return 1
    produce "alpha significance (observed)" "$Diversity_v/observed_features_vector.qzv" \
        qiime diversity alpha-group-significance \
        --i-alpha-diversity "$Diversity_a/observed_features_vector.qza" \
        --m-metadata-file "$metadata" \
        --o-visualization "$Diversity_v/observed_features_vector.qzv"
}

emperor_bray() {                                            # 15
    need "$Diversity_a/bray_curtis_pcoa_biplot.qza" 10 || return 1
    produce "Emperor biplot (Bray-Curtis)" "$Diversity_v/bray_curtis_emperor_biplot.qzv" \
        qiime emperor biplot \
        --i-biplot "$Diversity_a/bray_curtis_pcoa_biplot.qza" \
        --m-sample-metadata-file "$metadata" \
        --o-visualization "$Diversity_v/bray_curtis_emperor_biplot.qzv"
}

emperor_jaccard() {                                         # 16
    need "$Diversity_a/jaccard_pcoa_biplot.qza" 11 || return 1
    produce "Emperor biplot (Jaccard)" "$Diversity_v/jaccard_emperor_biplot.qzv" \
        qiime emperor biplot \
        --i-biplot "$Diversity_a/jaccard_pcoa_biplot.qza" \
        --m-sample-metadata-file "$metadata" \
        --o-visualization "$Diversity_v/jaccard_emperor_biplot.qzv"
}

# —————————————————————————————————— differential_a —————————————————————————————————————

ancombc() {                                                 # 17
    need "$taxa_collapsed" 4 || return 1
    produce "ANCOM-BC" "$Differential_a/differentials.qza" \
        qiime composition ancombc \
        --i-table "$taxa_collapsed" \
        --m-metadata-file "$metadata" \
        --p-formula Habitat \
        --o-differentials "$Differential_a/differentials.qza"
    # SET --p-formula to a metadata column
}

ancom() {                                                   # 18
    need "$taxa_collapsed" 4 || return 1
    skip_if_done "ANCOM" "$Differential_v/ancom.qzv" && return 0
    mkdir -p "$Differential_a" "$Differential_v" || return 1
    clear_outputs "$Differential_a/comp_table.qza" "$Differential_v/ancom.qzv"
    run qiime composition add-pseudocount \
        --i-table "$taxa_collapsed" \
        --o-composition-table "$Differential_a/comp_table.qza" || return 1
    run qiime composition ancom \
        --i-table "$Differential_a/comp_table.qza" \
        --m-metadata-file "$metadata" \
        --m-metadata-column Habitat \
        --o-visualization "$Differential_v/ancom.qzv"
}

# —————————————————————————————————— differential_v —————————————————————————————————————

da_table() {                                                # 19
    need "$Differential_a/differentials.qza" 17 || return 1
    produce "DA table" "$Differential_v/da_table.qzv" \
        qiime composition tabulate \
        --i-data "$Differential_a/differentials.qza" \
        --o-visualization "$Differential_v/da_table.qzv"
}

da_barplot() {                                              # 20
    need "$Differential_a/differentials.qza" 17 || return 1
    produce "DA barplot" "$Differential_v/da_barplot.qzv" \
        qiime composition da-barplot \
        --i-data "$Differential_a/differentials.qza" \
        --p-label-limit 400 \
        --o-visualization "$Differential_v/da_barplot.qzv"
    # SET p-label-limit if labels are cut off
}

# ———————————————————————————————————— entry point ——————————————————————————————————————

if [ $# -eq 0 ]; then
    menu
elif [ "$1" = "all" ]; then
    run_all 0
elif [ "$1" = "allforce" ]; then
    run_all 1
else
    FORCE=1
    for n in "$@"; do
        run_step "$n" || exit 1
    done
fi