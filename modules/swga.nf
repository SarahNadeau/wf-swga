nextflow.enable.dsl = 2


process INFILE_HANDLING {

    input:
        path(target)
        path(background)
        val exclude

    output:
        path('.tmp/target.fasta.noblanks'), emit: target
        path('.tmp/background.fasta.noblanks'), emit: background
        path('.tmp/exclude.fasta.noblanks'), emit: exclude_seq

    script:
    """
    infile_handling.sh ${target} ${background} ${exclude}
    cat .command.out >> ${params.logpath}/stdout.nextflow.txt
    cat .command.err >> ${params.logpath}/stderr.nextflow.txt
    """

}


process DOWNSAMPLE_GENOME {
    container "snads/downsample-fasta@sha256:4f8acbc70f86972ce0446a8d3b59aac7a9f13241738fbf42adbee4e6629f38a3"

    input:
        path(genome)
        val chunk_size
        val n_chunks

    output:
        // ${genome}.downsampled is not evaluated properly somehow, need to use regex to find output
        path('*.downsampled'), emit: downsampled_genome

    script:
    """
    source bash_functions.sh

    msg "INFO: Down-sampling ${genome} to ${n_chunks} chunks of length ${chunk_size}"

    # Don't concatenate down-sampled seqs because segments aren't actually adjacent, shouldn't consider spanning kmers
    downsample_fasta.py --fasta ${genome} --chunk-size ${chunk_size} --n-chunks ${n_chunks} --no-concatenate > ${genome}.downsampled

    cat .command.out >> ${params.logpath}/stdout.nextflow.txt
    cat .command.err >> ${params.logpath}/stderr.nextflow.txt
    """
}

// TODO: implement this, remove genome lengths as required input
// process GET_GENOME_LENGTHS {
//     input:
//         path(target)
//         path(background)
//
// }


process SWGA_FILTER_PRIMERS {
    publishDir "${params.outpath}", mode: "copy"
    container "snads/swga@sha256:776a2988b0ba727efe0b5c1420242c0309cd8e82bff67e9acf98215bf9f1f418"
    label "process_medium"

    input:
        path(target)
        path(background)
        path(exclude)
        val max_bg_bind
        val min_fg_bind

    output:
        path("swga"), emit: swga_dir

    script:
    """
    source bash_functions.sh

    mkdir swga
    cd swga  # swga init initializes workspace in the current directory

    msg "INFO: running swga init"
    swga init \
      -f ../${target} \
      -b ../${background} \
      -e ../${exclude}

    msg "INFO: running swga count"
    swga count \
        --min_size ${params.min_kmer_size} \
        --max_size ${params.max_kmer_size}

    msg "INFO: running swga filter"
    swga filter \
      --max_bg_bind ${max_bg_bind} \
      --min_fg_bind ${min_fg_bind} \
      --min_tm ${params.min_tm} \
      --max_tm ${params.max_tm}

    msg "INFO: running swga export primers"
    swga export primers \
      --limit ${params.n_top_primers} \
      --order_by ratio \
      --descending \
      --output ./primers_top_${params.n_top_primers}_ratio.txt

    # Exports all primers, with active primers at the top
    swga export primers \
      --order_by active \
      --descending \
      --output ./primers_all.txt

    cd ../
    touch swga_filter_success.txt
    cat .command.out >> ${params.logpath}/stdout.nextflow.txt
    cat .command.err >> ${params.logpath}/stderr.nextflow.txt
    """

}

process SWGA_FIND_SETS {
    cpus "${params.set_find_workers}"
    publishDir "${params.outpath}", mode: "copy"
    container "snads/swga@sha256:776a2988b0ba727efe0b5c1420242c0309cd8e82bff67e9acf98215bf9f1f418"

    input:
        path(swga_dir)

    output:
        path("swga")

    script:
    """
    source bash_functions.sh

    cd swga

    msg "INFO: running swga find sets"
    swga find_sets \
        --workers ${params.set_find_workers} \
        --max_sets ${params.max_sets_search} \
        --min_bg_bind_dist ${params.min_bg_bind_dist} \
        --max_fg_bind_dist ${params.max_fg_bind_dist} \
        --min_size ${params.find_sets_min_size} \
        --max_size ${params.find_sets_max_size} \
        --max_dimer_bp ${params.max_dimer_bp}

    msg "INFO: running swga export sets"
    swga export sets \
      --limit ${params.n_top_sets} \
      --order_by score \
      --output ./sets_top_${params.n_top_sets}_score.txt

    swga export sets \
      --limit ${params.n_top_sets} \
      --order_by set_size \
      --output ./sets_top_${params.n_top_sets}_size.txt

    swga export bedfile \
      --limit ${params.n_top_sets}

    cd ../
    cat .command.out >> ${params.logpath}/stdout.nextflow.txt
    cat .command.err >> ${params.logpath}/stderr.nextflow.txt
    """

}