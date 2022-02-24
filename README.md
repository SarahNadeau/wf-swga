# Selective Whole Genome Amplification workflow


## Steps in the workflow
1. Run [swga](https://github.com/eclarke/swga) on a target genome and background genome(s).

## Requirements
* Nextflow
* Docker or Singularity

## Install
```
git clone git@github.com:sarahnadeau/wf-swga.git
cd wf-swga
```

## Set-up for Aspen cluster
``` 
# Add these Singularity variables to $HOME/.bashrc
SINGULARITY_BASE=/scicomp/scratch/$USER
export SINGULARITY_TMPDIR=$SINGULARITY_BASE/singularity.tmp
export SINGULARITY_CACHEDIR=$SINGULARITY_BASE/singularity.cache
mkdir -pv $SINGULARITY_TMPDIR $SINGULARITY_CACHEDIR

# Restart session

module load nextflow/21.04.3

# Run workflow with -profile singularity
```

## Run workflow
```
# Get help
nextflow run main.nf --help
# With Docker
nextflow run -profile docker main.nf --outpath OUTPATH_DIR --inpath INPUT_DIR
# With Singularity
nextflow run -profile singularity main.nf --outpath OUTPATH_DIR --inpath INPUT_DIR
```
