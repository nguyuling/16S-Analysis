#!/bin/sh
# Loaded by 16s.sh. Do not run this file directly.

# ———————————————————————————— SET your paths ————————————————————————————

Dir="/Volumes/T7/16s_project"
metadata_name="sample-metadata.tsv"
ref_seqs="/Volumes/T7/databases/moving_pictures/reference-sequences.qza"
ref_taxa="/Volumes/T7/databases/moving_pictures/reference-taxonomy.qza"

# ————————————————————————— directories & files ———————————————————————————

Reads="$Dir/1_reads"
Feature="$Dir/2_feature"
Taxonomy_a="$Dir/3_taxonomy_a"
Taxonomy_v="$Dir/4_taxonomy_v"
Diversity_a="$Dir/5_diversity_a"
Diversity_v="$Dir/6_diversity_v"
Differential_a="$Dir/7_differential_a"
Differential_v="$Dir/8_differential_v"

metadata="$Dir/$metadata_name"
table="$Feature/table.qza"
rep_seqs="$Feature/rep_seqs.qza"
classification="$Taxonomy_a/classification.qza"
taxa_collapsed="$Taxonomy_a/taxa_collapsed.qza"
taxa_species="$Taxonomy_a/taxa_species.qza"
taxa_collapsed_relfreq="$Diversity_a/taxa_collapsed_relfreq.qza"

# ———————————————————————————————— logging —————————————————————————————————

Log="$Dir/logs"
mkdir -p "$Log"
[ -n "$log_file" ] || log_file="$Log/pipeline_$(date '+%Y%m%d_%H%M%S').log"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
    msg="[$(timestamp)] $*"
    echo "$msg"
    echo "$msg" >> "$log_file"
}

# ———————————————————————————— helper functions —————————————————————————————

run() {                                     # run a command, send output to log, return exit code
    log "START: $*"
    s=$(date +%s)
    if "$@" >> "$log_file" 2>&1; then
        log "OK ($(( $(date +%s) - s ))s)"
    else
        rc=$?
        log "FAILED (exit $rc): $*"
        return "$rc"
    fi
}

need() {                                    # usage: need <file or dir> <step number that creates it>
    if [ ! -e "$1" ]; then
        log "ERROR: missing $1. Run step $2 first."
        return 1
    fi
}

skip_if_done() {                            # usage: skip_if_done <step name> <output>...
    name=$1; shift
    [ "${FORCE:-0}" = 1 ] && return 1
    for f in "$@"; do
        [ -e "$f" ] || return 1
    done
    log "SKIPPED $name: outputs already exist"
    return 0
}

clear_outputs() {                           # usage: clear_outputs <file or dir>...
    for f in "$@"; do
        if [ -e "$f" ]; then
            rm -rf "$f" && log "Removed old output: $f"
        fi
    done
    return 0
}

produce() {                                 # usage: produce <label> <output> <command...>
    label=$1; out=$2; shift 2
    skip_if_done "$label" "$out" && return 0
    mkdir -p "$(dirname "$out")" || return 1
    clear_outputs "$out"
    run "$@"
}

# —————————————————————————————— dispatch ——————————————————————————————————

dispatch_step() {
    case "$1" in
        1)  import ;;
        2)  denoise ;;
        3)  classify ;;
        4)  collapse_lvl3 ;;
        5)  summarize ;;
        6)  heatmap ;;
        7)  taxa_barplot ;;
        8)  core_metrics ;;
        9)  rel_freq ;;
        10) biplot_bray ;;
        11) biplot_jaccard ;;
        12) alpha_rarefaction ;;
        13) alpha_shannon ;;
        14) alpha_observed ;;
        15) emperor_bray ;;
        16) emperor_jaccard ;;
        17) ancombc ;;
        18) ancom ;;
        19) da_table ;;
        20) da_barplot ;;
        *)  log "Unknown step: $1"; return 1 ;;
    esac
}

run_step() {
    dispatch_step "$1"
}

run_all() {                                 # usage: run_all <FORCE value: 0 skip finished, 1 rerun everything>
    FORCE=$1
    for n in $(seq 1 20); do
        if ! run_step "$n"; then
            log "STOPPED at step $n. Fix the error and run again."
            return 1
        fi
    done
    log "ALL STEPS DONE"
}

show_menu() {
    cat <<'EOF'
———————————————————————————— 16S pipeline ————————————————————————————
 1  Move reads and import (QIIME 2)  11  PCoA biplot (Jaccard)
 2  Denoise with DADA2               12  Alpha rarefaction
 3  Classify taxonomy                13  Alpha significance (Shannon)
 4  Collapse to taxa level 3         14  Alpha significance (observed)
 5  Summarize level 7 table          15  Emperor biplot (Bray-Curtis)
 6  Heatmap, level 3                 16  Emperor biplot (Jaccard)
 7  Taxa barplot                     17  ANCOM-BC
 8  Core diversity metrics           18  ANCOM (with pseudocount)
 9  Relative frequency, level 3      19  Differential abundance table
10  PCoA biplot (Bray-Curtis)        20  Differential abundance barplot

 a  Run all, skip finished steps
 f  Run all, rerun every step regardless
 q  Quit
——————————————————————————————————————————————————————————————————————
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