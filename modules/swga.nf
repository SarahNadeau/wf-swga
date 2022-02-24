nextflow.enable.dsl = 2


process INFILE_HANDLING {

    input:
        path(target)
        path(background)

    output:
        path("find_infiles.success.txt"), emit: find_infiles_success

    script:
    """
    source bin/bash_functions.sh

    for file in "${target}" "${background}"; do
      if [ "${file: -3}" == '.gz' ]; then
        base="$(basename "${file}" .gz)"
        # Store decompressed assemblies in outpath area to avoid write
        #  permission issues in the inpath. Also remove file extensions.
        gunzip -c "${file}" > ./.tmp/"${base}"
        msg "INFO: extracted compressed input ${file}"
      fi
      # TODO: pass back out the location of the inputs
    done

    cat .command.out >> ${params.logpath}/stdout.nextflow.txt
    cat .command.err >> ${params.logpath}/stderr.nextflow.txt
    """

}

process RUN_SWGA {
    publishDir "${params.outpath}", mode: "copy"
    container "snads/swga@sha256:776a2988b0ba727efe0b5c1420242c0309cd8e82bff67e9acf98215bf9f1f418"

    input:
        // TODO: path(find_infiles_success)
        path(target)
        path(background)

    output:
        path("swga"), emit: find_infiles_success

    script:
    """
    # Must provide an exclusionary sequences file to again avoid interactive mode
    echo ">dummy_seq\n" > .tmp/dummy.fasta

    mkdir swga
    cd swga  # swga init initializes workspace in the current directory

    swga init \
      -f ${target} \
      -b ${background} \
      -e .tmp/dummy.fasta

    swga count
    swga filter

    # TODO: run this
    #swga find_sets

    N_PRIMERS_TO_EXPORT=100  # TODO: make an optional wf input
    swga export primers \
      --limit ${N_PRIMERS_TO_EXPORT} \
      --order_by gini \
      --output ./swga/primers_top_100_gini.txt

    cat .command.out >> ${params.logpath}/stdout.nextflow.txt
    cat .command.err >> ${params.logpath}/stderr.nextflow.txt
    """

}