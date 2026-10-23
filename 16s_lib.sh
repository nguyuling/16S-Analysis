#!/bin/sh
# Loaded by 16s.sh. Do not run this file directly.

# ———————————————————————————— SET your paths ————————————————————————————

Outdir="/Volumes/T7/16s_project"         # SET output files directory
metadata_name="sample-metadata.tsv"         # SET metadata filename only
ref_seqs="/Volumes/T7/databases/moving_pictures/reference-sequences.qza"    # SET ref seqs pathname
ref_taxa="/Volumes/T7/databases/moving_pictures/reference-taxonomy.qza"     # SET ref taxa pathname

# ————————————————————————— directories & files ———————————————————————————

Reads="$Outdir/1_reads"
Feature="$Outdir/2_feature"
Taxonomy_a="$Outdir/3_taxonomy_a"
Taxonomy_v="$Outdir/4_taxonomy_v"
Diversity_a="$Outdir/5_diversity_a"
Diversity_v="$Outdir/6_diversity_v"
Differential_a="$Outdir/7_differential_a"
Differential_v="$Outdir/8_differential_v"
Log="$Outdir/logs"

metadata="$Outdir/$metadata_name"
table="$Feature/table.qza"
rep_seqs="$Feature/rep_seqs.qza"
classification="$Taxonomy_a/classification.qza"
taxa_collapsed="$Taxonomy_a/taxa_collapsed.qza"
taxa_species="$Taxonomy_a/taxa_species.qza"
taxa_collapsed_relfreq="$Diversity_a/taxa_collapsed_relfreq.qza"

mkdir -p "$Log"
log_file="$Log/pipeline_$(date '+%Y%m%d_%H%M%S').log"

# ———————————————————————————— helper functions —————————————————————————————

log() {                                     # log datetime and message to terminal and log file
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$log_file"
}

run() {                                     # usage: run <command> <parameter>
    log "START: $*"                         # log the starting step
    start=$(date +%s)                       # start time
    if "$@" >> "$log_file" 2>&1; then       # run the command, write stdout / stderr to log file
        log "OK ($(( $(date +%s) - start ))s)"  # exit 0 : log run time (current time - start time)
    else
        rc=$?                               # exit != 0 : create variable of the latest exit code
        log "FAILED (exit $rc): $*"         # log the exit code and failed command
        return "$rc"
    fi
}

need() {                                    # usage: need <file or dir> <step number that creates it>
    if [ ! -e "$1" ]; then                  # if the prerequisite file is absent
        log "ERROR: missing $1. Run step $2 first."     # log reminder message about running the upstream step first
        return 1
    fi
}

skip_if_done() {                            # usage: skip_if_done <step name> <output>...
    name=$1; shift                          # remove first arguments (step name), leaving only the output files
    [ "${FORCE:-0}" = 1 ] && return 1       # if all force, then don't skip the step / rerun
    for f in "$@"; do                       # for all output files
        [ -e "$f" ] || return 1             # if any output file is absent, don't skip the step / rerun
    done
    log "SKIPPED $name: outputs already exist"          # if all output files exist, log message about skipping the step
    return 0
}

clear_outputs() {                           # usage: clear_outputs <file(s) or dir(s)>
    for f in "$@"; do                       # for all output files 
        if [ -e "$f" ]; then                # if the output file exist
            rm -rf "$f" && log "Removed old output: $f" # remove it 
        fi
    done
    return 0
}

produce() {                                 # usage: produce <step name> <output>
    name=$1; output=$2; shift 2             #  
    skip_if_done "$name" "$output" && return 0          # call skip_if_done, if the step is skipped / no rerun, don't produce output dir
    mkdir -p "$(dirname "$output")" || return 1         # else produce an output dir
    clear_outputs "$output"                             # call clear_outputs to remove the existing output files
    run "$@"                                            # call run to run command
}

# —————————————–——————————— entry point functions ———————————————————————————

run_step() {                                # usage: run_step <step_number>
    STEPS_RUN=$(( ${STEPS_RUN:-0} + 1 ))    # add 1 to counter each time a step is started
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
        *)  log "Unknown step: $1"; STEP_FAILED=1; return 1 ;;  # when irrelevant step number is selected, log error message
    esac || { STEP_FAILED=1; return 1; }
}

run_all() {                                 # usage: run_all <FORCE value: 0 skip finished, 1 rerun everything>
    FORCE=$1                                # create variable for first argument (force value)
    start=$(date +%s)                       # start time
    for n in $(seq 1 20); do                # for all steps
        if ! run_step "$n"; then            # run each step, if fail
            log "STOPPED at step $n. Fix the error and run again."  # log the error message and the failed step number
            return 1
        fi
    done
    total=$(( $(date +%s) - start ))        # if successfully run, calculate the total run time (current time - start time)
    log "ALL STEPS DONE. Total time: $(( total / 60 )) min $(( total % 60 )) sec"   # log the total run time 
}

menu() {                               # usage menu
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

    - Run selected step(s), separated by spaces (e.g. 6 7)
    - a  Run all steps, skipping finished ones
    - f  Run all steps, rerun every step regardless
    - q  Quit

EOF
}

show_menu() {                                    # usage: show_menu
    while true; do
        menu                           # show menu
        printf 'Run: '                      # prompt user choice
        read -r choice || exit 0            # read user choice
        case "$choice" in                   # option for choice
            q|Q) exit 0 ;;
            a|A) run_all 0 ;;               # if run all (skipping finished one), set force value to 0
            f|F) run_all 1 ;;               # if run all regardlessly, set force value to 1
            "") ;;                          # if empty line, show menu again
            *)                              # if any step number(s) are selected
                FORCE=1                     # rerun selected step(s)
                for n in $choice; do        # for all characters in the choice string
                    case "$n" in            # for each char 
                        ''|*[!0-9]*) echo "Invalid input: $n"           # if empty value or non-digit
                        break ;;
                    esac
                    if ! run_step "$n"; then                            # if fail to run the step
                        echo "Step $n failed. Check $log_file, fix the problem, then select step $n again."
                        break
                    fi
                done
                ;;
        esac
    done
}