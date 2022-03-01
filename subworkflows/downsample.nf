include {
    DOWNSAMPLE_GENOME
} from '../modules/swga.nf'


workflow DOWNSAMPLE_TARGET {
    take:
        target
    main:
        DOWNSAMPLE_GENOME (
            target,
            params.targetChunkSize,
            params.targetNChunks
        )
    emit:
        DOWNSAMPLE_GENOME.out.downsampled_genome
}

workflow DOWNSAMPLE_BACKGR {
    take:
        background
    main:
        DOWNSAMPLE_GENOME (
            background,
            params.backgrChunkSize,
            params.backgrNChunks
        )
    emit:
        DOWNSAMPLE_GENOME.out.downsampled_genome
}
