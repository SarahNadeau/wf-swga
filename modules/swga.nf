nextflow.enable.dsl = 2


process INFILE_HANDLING {

    input:
        path(target)
        path(background)

    output:
        path('.tmp/target.fasta.noblanks'), emit: target
        path('.tmp/background.fasta.noblanks'), emit: background

    script:
    """
    source bash_functions.sh

    # Decompress input
    mkdir .tmp
    if [[ "${target}" == *.gz ]]; then
        gunzip -c ${target} > .tmp/target.fasta
        msg "INFO: extracted compressed target genome ${target}"
    else
        cp ${target} .tmp/target.fasta
    fi

    if [[ "${background}" == *.gz ]]; then
        gunzip -c ${background} > .tmp/background.fasta
        msg "INFO: extracted compressed background genome ${background}"
    else
        cp ${background} .tmp/background.fasta
    fi

    # Remove blank lines for swga
    for file in .tmp/target.fasta .tmp/background.fasta; do
        awk NF \${file} >> \${file}.noblanks
    done
    msg "INFO: removed any blank lines in input"

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


process RUN_SWGA {
    publishDir "${params.outpath}", mode: "copy"
    container "snads/swga@sha256:776a2988b0ba727efe0b5c1420242c0309cd8e82bff67e9acf98215bf9f1f418"

    input:
        path(target)
        path(background)

    output:
        path("swga")

    script:
    """
    source bash_functions.sh

    # Must provide an exclusionary sequences file to again avoid interactive mode
    echo ">dummy_seq\n" > dummy.fasta

    mkdir swga
    cd swga  # swga init initializes workspace in the current directory

    msg "INFO: running swga init"
    swga init \
      -f ../${target} \
      -b ../${background} \
      -e ../dummy.fasta

    msg "INFO: running swga count"
    swga count

    msg "INFO: running swga filter"
    swga filter

    # TODO: run this
    swga find_sets

    # TODO: make limit an optional wf input
    msg "INFO: running swga export primers"
    swga export primers \
      --limit 100 \
      --order_by gini \
      --output ./primers_top_100_gini.txt

    cd ../
    cat .command.out >> ${params.logpath}/stdout.nextflow.txt
    cat .command.err >> ${params.logpath}/stderr.nextflow.txt
    """

}