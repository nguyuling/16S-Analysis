#!/bin/sh
# 16s_paired.sh: 16S amplicon pipeline with a step menu.
#   sh 16s_paired.sh            interactive menu
#   sh 16s_paired.sh 3 4 5      run these steps (outputs are regenerated)
#   sh 16s_paired.sh all        run every step, skipping finished ones
#   sh 16s_paired.sh allforce   run every step, regardless of existing outputs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/16s_lib.sh"

trap 'log "SESSION ENDED"' EXIT
log "SESSION STARTED. Log file: $log_file"

move() {                                                    # 1
    mkdir -p "$Reads" || return 1
    skip_if_done "move" "$Reads/.moved" && return 0
    for f in "$Dir"/*; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "$metadata_name" ] && continue
        mv "$f" "$Reads/" && log "Moved: $(basename "$f")"
    done
    touch "$Reads/.moved"
}

import() {                                                  # 2
    need "$Reads" 1 || return 1
    skip_if_done "import" "$Reads/data.qza" && return 0
    run qiime tools import \
        --type 'SampleData[PairedEndSequencesWithQuality]' \
        --input-path "$Reads" \
        --input-format CasavaOneEightSingleLanePerSampleDirFmt \
        --output-path "$Reads/data.qza"
    # RUN qiime tools list-types to check all --type
}

denoise() {                                                 # 3
    need "$Reads/data.qza" 2 || return 1
    skip_if_done "denoise" "$table" "$rep_seqs" && return 0
    mkdir -p "$Feature" || return 1
    run qiime dada2 denoise-paired \
        --i-demultiplexed-seqs "$Reads/data.qza" \
        --p-trunc-len-f 0 \
        --p-trunc-len-r 0 \
        --o-representative-sequences "$rep_seqs" \
        --o-table "$table" \
        --o-denoising-stats "$Feature/denoising-stats.qza"
    # SET --p-trunc-len-f and --p-trunc-len-r
}

classify() {                                                # 4
    need "$rep_seqs" 3 || return 1
    skip_if_done "classify" "$classification" && return 0
    mkdir -p "$Taxonomy_a" || return 1
    run qiime feature-classifier classify-consensus-blast \
        --i-query "$rep_seqs" \
        --i-reference-reads "$ref_seqs" \
        --i-reference-taxonomy "$ref_taxa" \
        --o-classification "$classification" \
        --o-search-results "$Taxonomy_a/search-results.qza"
}

collapse_lvl3() {                                           # 5
    need "$classification" 4 || return 1
    skip_if_done "collapse level 3" "$table_lvl3" && return 0
    run qiime taxa collapse \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --p-level 3 \
        --o-collapsed-table "$table_lvl3"
}

collapse_lvl7() {                                           # 6
    need "$classification" 4 || return 1
    skip_if_done "collapse level 7" "$table_lvl7" && return 0
    run qiime taxa collapse \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --p-level 7 \
        --o-collapsed-table "$table_lvl7"
}

summarize() {                                               # 7
    need "$table_lvl7" 6 || return 1
    skip_if_done "summarize" "$Taxonomy_v/summary.qzv" && return 0
    mkdir -p "$Taxonomy_v" || return 1
    run qiime feature-table summarize \
        --i-table "$table_lvl7" \
        --m-sample-metadata-file "$metadata" \
        --o-visualization "$Taxonomy_v/summary.qzv"
}

heatmap() {                                                 # 8
    need "$table_lvl3" 5 || return 1
    skip_if_done "heatmap" "$Taxonomy_v/feature_heatmap.qzv" && return 0
    mkdir -p "$Taxonomy_v" || return 1
    run qiime feature-table heatmap \
        --i-table "$table_lvl3" \
        --o-visualization "$Taxonomy_v/feature_heatmap.qzv"
}

taxa_barplot() {                                            # 9
    need "$classification" 4 || return 1
    skip_if_done "taxa barplot" "$Taxonomy_v/taxa_barplot.qzv" && return 0
    mkdir -p "$Taxonomy_v" || return 1
    run qiime taxa barplot \
        --i-table "$table" \
        --i-taxonomy "$classification" \
        --m-metadata-file "$metadata" \
        --o-visualization "$Taxonomy_v/taxa_barplot.qzv"
}

core_metrics() {                                            # 10
    need "$table" 3 || return 1
    skip_if_done "core metrics" "$Diversity_a/bray_curtis_pcoa_results.qza" && return 0
    mkdir -p "$Diversity_a" "$Diversity_v" || return 1
    run qiime diversity core-metrics \
        --i-table "$table" \
        --p-sampling-depth 1700 \
        --m-metadata-file "$metadata" \
        --output-dir "$Diversity_a" || return 1
    # SET --p-sampling-depth
    mv "$Diversity_a/bray_curtis_emperor.qzv" "$Diversity_a/jaccard_emperor.qzv" "$Diversity_v/" 2>/dev/null
    return 0
}

rel_freq() {                                                # 11
    need "$table_lvl3" 5 || return 1
    skip_if_done "relative frequency" "$rel_table_lvl3" && return 0
    mkdir -p "$Diversity_a" || return 1
    run qiime feature-table relative-frequency \
        --i-table "$table_lvl3" \
        --o-relative-frequency-table "$rel_table_lvl3"
}

biplot_bray() {                                             # 12
    need "$Diversity_a/bray_curtis_pcoa_results.qza" 10 || return 1
    need "$rel_table_lvl3" 11 || return 1
    skip_if_done "Bray-Curtis PCoA biplot" "$Diversity_a/bray_curtis_pcoa_biplot.qza" && return 0
    run qiime diversity pcoa-biplot \
        --i-pcoa "$Diversity_a/bray_curtis_pcoa_results.qza" \
        --i-features "$rel_table_lvl3" \
        --o-biplot "$Diversity_a/bray_curtis_pcoa_biplot.qza"
}

biplot_jaccard() {                                          # 13
    need "$Diversity_a/jaccard_pcoa_results.qza" 10 || return 1
    need "$rel_table_lvl3" 11 || return 1
    skip_if_done "Jaccard PCoA biplot" "$Diversity_a/jaccard_pcoa_biplot.qza" && return 0
    run qiime diversity pcoa-biplot \
        --i-pcoa "$Diversity_a/jaccard_pcoa_results.qza" \
        --i-features "$rel_table_lvl3" \
        --o-biplot "$Diversity_a/jaccard_pcoa_biplot.qza"
}

alpha_rarefaction() {                                       # 14
    need "$table" 3 || return 1
    skip_if_done "alpha rarefaction" "$Diversity_v/alpha_rarefaction.qzv" && return 0
    mkdir -p "$Diversity_v" || return 1
    run qiime diversity alpha-rarefaction \
        --i-table "$table" \
        --p-max-depth 1700 \
        --m-metadata-file "$metadata" \
        --o-visualization "$Diversity_v/alpha_rarefaction.qzv"
    # SET --p-max-depth
}

alpha_shannon() {                                           # 15
    need "$Diversity_a/shannon_vector.qza" 10 || return 1
    skip_if_done "alpha significance (Shannon)" "$Diversity_v/shannon_vector.qzv" && return 0
    mkdir -p "$Diversity_v" || return 1
    run qiime diversity alpha-group-significance \
        --i-alpha-diversity "$Diversity_a/shannon_vector.qza" \
        --m-metadata-file "$metadata" \
        --o-visualization "$Diversity_v/shannon_vector.qzv"
}

alpha_observed() {                                          # 16
    need "$Diversity_a/observed_features_vector.qza" 10 || return 1
    skip_if_done "alpha significance (observed)" "$Diversity_v/observed_features_vector.qzv" && return 0
    mkdir -p "$Diversity_v" || return 1
    run qiime diversity alpha-group-significance \
        --i-alpha-diversity "$Diversity_a/observed_features_vector.qza" \
        --m-metadata-file "$metadata" \
        --o-visualization "$Diversity_v/observed_features_vector.qzv"
}

emperor_bray() {                                            # 17
    need "$Diversity_a/bray_curtis_pcoa_biplot.qza" 12 || return 1
    skip_if_done "Emperor biplot (Bray-Curtis)" "$Diversity_v/bray_curtis_emperor_biplot.qzv" && return 0
    mkdir -p "$Diversity_v" || return 1
    run qiime emperor biplot \
        --i-biplot "$Diversity_a/bray_curtis_pcoa_biplot.qza" \
        --m-sample-metadata-file "$metadata" \
        --o-visualization "$Diversity_v/bray_curtis_emperor_biplot.qzv"
}

emperor_jaccard() {                                         # 18
    need "$Diversity_a/jaccard_pcoa_biplot.qza" 13 || return 1
    skip_if_done "Emperor biplot (Jaccard)" "$Diversity_v/jaccard_emperor_biplot.qzv" && return 0
    mkdir -p "$Diversity_v" || return 1
    run qiime emperor biplot \
        --i-biplot "$Diversity_a/jaccard_pcoa_biplot.qza" \
        --m-sample-metadata-file "$metadata" \
        --o-visualization "$Diversity_v/jaccard_emperor_biplot.qzv"
}

ancombc() {                                                 # 19
    need "$table_lvl3" 5 || return 1
    skip_if_done "ANCOM-BC" "$Differential_a/differentials.qza" && return 0
    mkdir -p "$Differential_a" || return 1
    run qiime composition ancombc \
        --i-table "$table_lvl3" \
        --m-metadata-file "$metadata" \
        --p-formula Habitat \
        --o-differentials "$Differential_a/differentials.qza"
    # SET --p-formula to a metadata column
}

pseudocount() {                                             # 20
    need "$table_lvl3" 5 || return 1
    skip_if_done "add pseudocount" "$Differential_a/comp_table.qza" && return 0
    mkdir -p "$Differential_a" || return 1
    run qiime composition add-pseudocount \
        --i-table "$table_lvl3" \
        --o-composition-table "$Differential_a/comp_table.qza"
}

da_table() {                                                # 21
    need "$Differential_a/differentials.qza" 19 || return 1
    skip_if_done "DA table" "$Differential_v/da_table.qzv" && return 0
    mkdir -p "$Differential_v" || return 1
    run qiime composition tabulate \
        --i-data "$Differential_a/differentials.qza" \
        --o-visualization "$Differential_v/da_table.qzv"
}

da_barplot() {                                              # 22
    need "$Differential_a/differentials.qza" 19 || return 1
    skip_if_done "DA barplot" "$Differential_v/da_barplot.qzv" && return 0
    mkdir -p "$Differential_v" || return 1
    run qiime composition da-barplot \
        --i-data "$Differential_a/differentials.qza" \
        --p-label-limit 400 \
        --o-visualization "$Differential_v/da_barplot.qzv"
    # SET --p-label-limit if labels are cut off
}

ancom() {                                                   # 23
    need "$Differential_a/comp_table.qza" 20 || return 1
    skip_if_done "ANCOM" "$Differential_v/ancom.qzv" && return 0
    mkdir -p "$Differential_v" || return 1
    run qiime composition ancom \
        --i-table "$Differential_a/comp_table.qza" \
        --m-metadata-file "$metadata" \
        --m-metadata-column Habitat \
        --o-visualization "$Differential_v/ancom.qzv"
}

# ========== dispatch and menu ==========
run_step() {
    case "$1" in
        1)  move ;;
        2)  import ;;
        3)  denoise ;;
        4)  classify ;;
        5)  collapse_lvl3 ;;
        6)  collapse_lvl7 ;;
        7)  summarize ;;
        8)  heatmap ;;
        9)  taxa_barplot ;;
        10) core_metrics ;;
        11) rel_freq ;;
        12) biplot_bray ;;
        13) biplot_jaccard ;;
        14) alpha_rarefaction ;;
        15) alpha_shannon ;;
        16) alpha_observed ;;
        17) emperor_bray ;;
        18) emperor_jaccard ;;
        19) ancombc ;;
        20) pseudocount ;;
        21) da_table ;;
        22) da_barplot ;;
        23) ancom ;;
        *)  log "Unknown step: $1"; return 1 ;;
    esac
}

# usage: run_all <FORCE value: 0 skip finished, 1 rerun everything>
run_all() {
    FORCE=$1
    for n in $(seq 1 23); do
        if ! run_step "$n"; then
            log "STOPPED at step $n. Fix the error and run again."
            return 1
        fi
    done
    log "ALL STEPS DONE"
}

show_menu() {
    cat <<'EOF'

============================ 16S pipeline ============================
 1  Move reads into 1_reads          13  PCoA biplot (Jaccard)
 2  Import reads (QIIME 2)           14  Alpha rarefaction
 3  Denoise with DADA2               15  Alpha significance (Shannon)
 4  Classify taxonomy                16  Alpha significance (observed)
 5  Collapse to level 3              17  Emperor biplot (Bray-Curtis)
 6  Collapse to level 7              18  Emperor biplot (Jaccard)
 7  Summarize level 7 table          19  ANCOM-BC
 8  Heatmap, level 3                 20  Add pseudocount
 9  Taxa barplot                     21  Differential abundance table
10  Core diversity metrics           22  Differential abundance barplot
11  Relative frequency, level 3      23  ANCOM
12  PCoA biplot (Bray-Curtis)

 a  Run all, skip finished steps
 f  Run all, rerun every step regardless
 q  Quit
======================================================================
EOF
}

menu() {
    while true; do
        show_menu
        printf 'Select step(s), separated by spaces (e.g. 3, or 4 5): '
        read -r choice || exit 0
        case "$choice" in
            q|Q) exit 0 ;;
            a|A) run_all 0 ;;
            f|F) run_all 1 ;;
            "") ;;
            *)
                FORCE=1
                for n in $choice; do
                    case "$n" in
                        ''|*[!0-9]*) echo "Invalid input: $n"; break ;;
                    esac
                    if ! run_step "$n"; then
                        echo "Step $n failed. Check $log_file, fix the problem, then select step $n again."
                        break
                    fi
                done
                ;;
        esac
    done
}

# ========== entry point ==========
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