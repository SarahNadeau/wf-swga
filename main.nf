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
    nextflow run -profile singularity main.nf --target <dir> --background <dir> --backgr_length <length> --target_length <length>

    Mandatory parameters:
      --target              Path to target genome assembly. Recognized extensions are:  fa, fasta, fas, fna, fsa, fa.gz, fasta.gz, fas.gz, fna.gz, fsa.gz.
      --background          Path to background genome assembly. Recognized extensions are:  fa, fasta, fas, fna, fsa, fa.gz, fasta.gz, fas.gz, fna.gz, fsa.gz.
      --outpath             The output directory where the results will be saved.
      --backgr_length       Length of the background genome. Used to calculate maximum binding sites for a primer in the background genome.
      --target_length       Length of the target genome. Used to calculate minimum binding sites for a primer in the target genome.

    Optional downsampling parameters:
      --target-chunk-size   Length of sequence in each chunk for down-sampling of target genome FastA.
      --target-n-chunks     The number of chunks to sample from the target genome FastA.
      --backgr-chunk-size   Length of sequence in each chunk for down-sampling of background genome FastA.
      --backgr-n-chunks     The number of chunks to sample from the background genome FastA.

    Optional primer search parameters:
      --max_bg_bind_rate    Maximum binding sites for a primer in the background genome = ceil(backgr_length * max_bg_bind_rate). Default = 0.00001 (every 100000 bp).
      --min_fg_bind_rate    Minimum binding sites for a primer in the target (foreground) genome = ceil(target_length * min_fg_bind_rate). Default = 0.00000667 (every 150000 bp).
      --min_bg_bind_dist    Minimum average distance between primers in a set in the background genome. Default = 80000.
      --max_fg_bind_dist    Maximum distance between any two primer binding sites in a set in the foreground genome. Default = 7000.
      --min_kmer_size       Minimum primer length.
      --max_kmer_size       Maximum primer length.
      --set_find_workers    Number of workers to spawn when searching primer graph for sets. Unclear what effect this has.
      --max_sets_search     Maximum number of sets to check (if < 0, will find as many sets as possible). Seems powerful for speeding up find_sets if you don't care about an optimal optimal solution.
      --n_top_primers       Maximum number of primer results to return (once ordered by ratio in target:background, once by gini evenness metric).
      --n_top_sets          Maximum number of set results to return (once ordered by score, once by set size).

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

if (!params.target_length || !params.backgr_length) {
    System.err.println "ERROR: Must specify target and background genome lengths"
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
    target:             ${params.target}
    background:         ${params.background}
    outpath:            ${params.outpath}
    logpath:            ${params.logpath}
    backgr_length:      ${params.backgr_length}
    target_length:      ${params.target_length}
    target-chunk-size:  ${params.targetChunkSize}
    target-n-chunks:    ${params.targetNChunks}
    backgr-chunk-size:  ${params.backgrChunkSize}
    backgr-n-chunks:    ${params.backgrNChunks}
    max_bg_bind_rate:   ${params.max_bg_bind_rate}
    min_fg_bind_rate:   ${params.min_fg_bind_rate}
    min_bg_bind_dist:   ${params.min_bg_bind_dist}
    max_fg_bind_dist:   ${params.max_fg_bind_dist}
    min_kmer_size:      ${params.min_kmer_size}
    max_kmer_size:      ${params.max_kmer_size}
    set_find_workers:   ${params.set_find_workers}
    max_sets_search:    ${params.max_sets_search}
    n_top_primers:      ${params.n_top_primers}
    n_top_sets:         ${params.n_top_sets}

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
    SWGA_FILTER_PRIMERS;
    SWGA_FIND_SETS;
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

    // TODO: make these optional arguments
    max_bg_bind = java.lang.Math.ceil(params.backgr_length * params.max_bg_bind_rate).intValue() // ceiling because want >= 1
    min_fg_bind = java.lang.Math.ceil(params.target_length * params.min_fg_bind_rate).intValue()

    SWGA_FILTER_PRIMERS (
        targetForSwga,
        backgrForSwga,
        Channel.from(max_bg_bind),
        Channel.from(min_fg_bind)
    )

    SWGA_FIND_SETS (
        SWGA_FILTER_PRIMERS.out.swga_dir
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
