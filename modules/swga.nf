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
    # Must provide an exclusionary sequences file to again avoid interactive mode
    echo ">dummy_seq\n" > dummy.fasta

    mkdir swga
    cd swga  # swga init initializes workspace in the current directory

    swga init \
      -f ../${target} \
      -b ../${background} \
      -e ../dummy.fasta

    swga count
    swga filter

    # TODO: run this
    #swga find_sets

    # TODO: make limit an optional wf input
    swga export primers \
      --limit 100 \
      --order_by gini \
      --output ./primers_top_100_gini.txt

    cd ../
    cat .command.out >> ${params.logpath}/stdout.nextflow.txt
    cat .command.err >> ${params.logpath}/stderr.nextflow.txt
    """

}