dir="/Volumes/T7/16s"
asv="$dir/asv"
taxonomy_a="$dir/taxnomy_a"
taxonomy_v="$dir/taxnomy_v"
diversity="$dir/diversity"
differential="$dir/differential"

r1="$dir/A3_S22_L001_R1_001.fastq"
r2="$dir/A3_S22_L001_R2_001.fastq"
metadata="$dir/metadata.tsv"
ref_seqs="/Volumes/T7/databases/silva138_AB_V3_V4/silva138_AB_V3-V4seqs_uniq.qza"
ref_taxa="/Volumes/T7/databases/silva138_AB_V3_V4/silva138_AB_V3-V4taxa_uniq.qza"


mkdir -p "$asv" && cd "$asv"
   
    qiime tools import \
        --type 'SampleData[PairedEndSequencesWithQuality]' \
        --input-path "$r1" "$r2" \
        --output-path demux-paired.qza \
        # run `qiime tools list-types` to check all types

    # qiime2 dada2 denoise-paired
    qiime dada2 denoise-paired \
        --i-demultiplexed-seqs demux-paired.qza \
        --p-trunc-len-f 250 \
        --p-trunc-len-r 250 \
        --o-representative-sequences representative-sequences.qza \
        --o-table asv-table.qza \
        --o-denoising-stats denoising-stats.qza \

    # qiime2 feature-table summarize
    qiime feature-table summarize \
        --i-table feature-table.qza \
        --m-metadata-file "$metadata" \
        --o-visualization summary.qzv \


mkdir -p "$taxonomy_a" && cd "$taxonomy_a"
    # qiime2 feature-classifier classify-consensus blast
    qiime feature-classifier classify-consensus-blast \
        --i-query "$asv/representative-sequences.qza" \
        --i-reference-reads "$ref_seqs" \
        --i-reference-taxonomy "$ref_taxa" \
        --o-classifier taxonomy.qza

    # qiime2 taxa collapse
    qiime taxa collapse \
    --i-table "$asv/asv-table.qza" \
    --i-taxonomy taxonomy.qza \
    --p-level 3 \
    --o-collapsed-table collapsed-table-l3.qza


mkdir -p "$taxonomy_v"
    # qiime2 taxa barplot
    qiime taxa barplot \
        --i-table "$asv/asv-table.qza" \
        --i-taxonomy "$taxonomy_a/taxonomy.qza" \
        --m-metadata-file "$metadata" \
        --o-visualization taxa-bar-plots.qzv

    # qiime2 feature-table heatmap
    qiime feature-table


mkdir $diversity
    # qiime2 diversity alpha-rarefaction
    qiime diversity alpha-rarefaction \
        --i-table "$asv/asv-table.qza" \
        --p-max-depth 7800 \
        --m-metadata-file "$metadata" \
        --o-visualization alpha-rarefaction.qzv

    # qiime2 diversity core-metrics
    qiime diversity


mkdir $differential
    # qiime2 composition ancombc
    qiime composition ancombc \
        --i-table "$taxonomy_a/collapsed-table-l3.qza" \
        --m-metadata-file "$metadata" \
        --p-formula subject \
        --o-differentials ancombc.qza

    # qiime2 composition tabulate
    qiime composition tabulate \
        --i-data ancombc.qza \
        --o-visualization visualization.qzv