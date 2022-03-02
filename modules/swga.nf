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


process SWGA_FILTER_PRIMERS {
    publishDir "${params.outpath}", mode: "copy"
    container "snads/swga@sha256:776a2988b0ba727efe0b5c1420242c0309cd8e82bff67e9acf98215bf9f1f418"

    input:
        path(target)
        path(background)

    output:
        path("swga"), emit: swga_dir

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

    # overwrite some default count and filter configuration options
    sed -i '/min_size/s/.*/min_size = ${params.min_size}/' parameters.cfg
    sed -i '/max_size/s/.*/max_size = ${params.max_size}/' parameters.cfg

    msg "INFO: running swga count"
    swga count

    msg "INFO: running swga filter"
    swga filter

    msg "INFO: running swga export primers"
    swga export primers \
      --limit ${params.n_top_primers} \
      --order_by ratio \
      --output ./primers_top_${params.n_top_primers}_ratio.txt

    swga export primers \
      --limit ${params.n_top_primers} \
      --order_by gini \
      --output ./primers_top_${params.n_top_primers}_gini.txt

    cd ../
    touch swga_filter_success.txt
    cat .command.out >> ${params.logpath}/stdout.nextflow.txt
    cat .command.err >> ${params.logpath}/stderr.nextflow.txt
    """

}

process SWGA_FIND_SETS {
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

    # overwrite some default find sets configuration options
    sed -i '/min_bg_bind_dist/s/.*/min_bg_bind_dist = ${params.min_bg_bind_dist}/' parameters.cfg
    sed -i '/max_fg_bind_dist/s/.*/max_fg_bind_dist = ${params.max_fg_bind_dist}/' parameters.cfg
    sed -i '/max_sets/s/.*/max_sets = ${params.max_sets_search}/' parameters.cfg
    sed -i '/workers/s/.*/workers = ${params.set_find_workers}/' parameters.cfg

    msg "INFO: running swga find sets"
    swga find_sets

    msg "INFO: running swga export sets"
    swga export sets \
      --limit ${params.n_top_sets} \
      --order_by score \
      --output ./sets_top_${params.n_top_sets}_score.txt

    swga export sets \
      --limit ${params.n_top_sets} \
      --order_by set_size \
      --output ./sets_top_${params.n_top_sets}_size.txt

    cd ../
    cat .command.out >> ${params.logpath}/stdout.nextflow.txt
    cat .command.err >> ${params.logpath}/stderr.nextflow.txt
    """

}