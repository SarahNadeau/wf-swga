#!/usr/bin/env nextflow


/*
==============================================================================
                              wf-swga
==============================================================================
*/

def helpMessage() {
    log.info"""
    =========================================
     wf-swga v${version}
    =========================================

    Usage:
    The minimal command for running the pipeline is:
    nextflow run main.nf
    A more typical command for running the pipeline is:
    nextflow run -profile singularity main.nf --inpath INPUT_DIR --outpath OUTPATH_DIR

    Input/output options:
      --inpath              Path to input data directory containing FastA assemblies. Recognized extensions are:  fa, fasta, fas, fna, fsa, fa.gz, fasta.gz, fas.gz, fna.gz, fsa.gz.
      --outpath             The output directory where the results will be saved.
      --target-chunk-size   Length of sequence in each chunk for down-sampling of target genome FastA.
      --target-n-chunks     The number of chunks to sample from the target genome FastA.
      --backgr-chunk-size   Length of sequence in each chunk for down-sampling of background genome FastA.
      --backgr-n-chunks     The number of chunks to sample from the background genome FastA.
    Profile options:
      -profile singularity  Use Singularity images to run the workflow. Will pull and convert Docker images from Dockerhub if not locally available.
      -profile docker       Use Docker images to run the workflow. Will pull images from Dockerhub if not locally available.
    Other options:
      -resume               Re-start a workflow using cached results. May not behave as expected with containerization profiles docker or singularity.
      -stub                 Use example output files for any process with an uncommented stub block. For debugging/testing purposes.
      -name                 Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic
    """.stripIndent()
}

version = "1.0.0"
nextflow.enable.dsl=2

if (params.help) {
    helpMessage()
    exit 0
}

if (params.version) {
    println "VERSION: $version"
    exit 0
}

// Handle command line input
File targetFileObj = new File(params.target)
File backgroundFileObj = new File(params.background)
if (!(targetFileObj.exists() && backgroundFileObj.exists())) {
    System.err.println "ERROR: $params.target or $params.background doesn't exist"
    exit 1
}

noTargetDownsampling = !params.targetChunkSize && !params.targetNChunks
noBackgrDownsampling = !params.backgrChunkSize && !params.backgrNChunks
targetDownsampling = params.targetChunkSize && params.targetNChunks
backgrDownsampling = params.backgrChunkSize && params.backgrNChunks

if (!(noTargetDownsampling || targetDownsampling)) {
    System.err.println "ERROR: Both or none of --target-chunk-size and --target-n-chunks must be specified"
    exit 1
} else if (!(noBackgrDownsampling || backgrDownsampling)) {
    System.err.println "ERROR: Both or none of --backgr-chunk-size and --backgr-n-chunks must be specified"
    exit 1
}

File outpathFileObj = new File(params.outpath)
if (outpathFileObj.exists()) {
    // Per the config file, outpath stores log & trace files so it is created before this point
    // Check that outpath only contains a trace file created this hour
    dayAndHour = new java.util.Date().format('yyyy-MM-dd HH')
    outFiles = outpathFileObj.list()
    if (!(outFiles[0] ==~ /trace.($dayAndHour):\d\d:\d\d.txt/ && outFiles.size() == 1)) {
        // If it contains an older trace file or other files, warn the user
        System.out.println "WARNING: $params.outpath already exists. Output files will be overwritten."
    }
} else {
    outpathFileObj.mkdirs()
}

File logpathFileObj = new File(params.logpath)
if (logpathFileObj.exists()) {
    System.out.println "WARNING: $params.logpath already exists. Log files will be overwritten."
} else {
    logpathFileObj.mkdirs()
}

// Print parameters used
log.info """
    =====================================
    wf-swga $version
    =====================================
    target:         ${params.target}
    background:     ${params.background}
    outpath:        ${params.outpath}
    logpath:        ${params.logpath}
    =====================================
    """
    .stripIndent()

/*
==============================================================================
                 Import local custom modules and subworkflows
==============================================================================
*/
include {
    INFILE_HANDLING;
    RUN_SWGA;
} from "./modules/swga.nf"

include {
    DOWNSAMPLE_TARGET;
    DOWNSAMPLE_BACKGR;
} from './subworkflows/downsample.nf'

/*
==============================================================================
                            Run the main workflow
==============================================================================
*/

workflow {

    target = Channel.fromPath(params.target, checkIfExists: true)
    background = Channel.fromPath(params.background, checkIfExists: true)

    // TODO: handle compressed input
    INFILE_HANDLING (
        target,
        background
    )

    targetForSwga = INFILE_HANDLING.out.target
    backgrForSwga = INFILE_HANDLING.out.background

    if (targetDownsampling) {
        DOWNSAMPLE_TARGET(
            INFILE_HANDLING.out.target
        )
        targetForSwga = DOWNSAMPLE_TARGET.out
    }
    if (backgrDownsampling) {
        DOWNSAMPLE_BACKGR(
            INFILE_HANDLING.out.background
        )
        backgrForSwga = DOWNSAMPLE_BACKGR.out
    }

    RUN_SWGA (
        targetForSwga,
        backgrForSwga
    )


}

/*
==============================================================================
                        Completion summary
==============================================================================
*/

workflow.onComplete {
    log.info """
                |=====================================
                |Pipeline Execution Summary
                |=====================================
                |Workflow Version : ${version}
                |Nextflow Version : ${nextflow.version}
                |Command Line     : ${workflow.commandLine}
                |Resumed          : ${workflow.resume}
                |Completed At     : ${workflow.complete}
                |Duration         : ${workflow.duration}
                |Success          : ${workflow.success}
                |Exit Code        : ${workflow.exitStatus}
                |Launch Dir       : ${workflow.launchDir}
                |=====================================
             """.stripMargin()
}

workflow.onError {
    def err_msg = """
                     |=====================================
                     |Error summary
                     |=====================================
                     |Completed at : ${workflow.complete}
                     |exit status  : ${workflow.exitStatus}
                     |workDir      : ${workflow.workDir}
                     |Error Report :
                     |${workflow.errorReport ?: '-'}
                     |=====================================
                  """.stripMargin()
    log.info err_msg

}