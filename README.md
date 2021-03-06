# Selective Whole Genome Amplification workflow


## Steps in the workflow
1. Run [swga](https://github.com/eclarke/swga) on a target genome and background genome(s).

## Requirements
* Nextflow
* Docker or Singularity

## Install
```
git clone https://github.com/SarahNadeau/wf-swga.git
cd wf-swga
```

## Set-up for Aspen cluster
``` 
# Add these Singularity variables to $HOME/.bashrc
SINGULARITY_BASE=/scicomp/scratch/$USER
export SINGULARITY_TMPDIR=$SINGULARITY_BASE/singularity.tmp
export SINGULARITY_CACHEDIR=$SINGULARITY_BASE/singularity.cache
export NXF_SINGULARITY_CACHEDIR=$SINGULARITY_BASE/singularity.cache
mkdir -pv $SINGULARITY_TMPDIR $SINGULARITY_CACHEDIR

# Restart session, navigate back into wf-swga

module load nextflow/21.04.3

# Run workflow with -profile singularity
```

## Get example data 
These files are actually already included in `example_input`, but here's how they were generated:
```
# Take data used by swga tutorial
mkdir -p example_input
wget "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=15594346&rettype=fasta&retmode=text" -O example_input/target.fasta
wget "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=556503834&rettype=fasta&retmode=text" -O example_input/background.fasta
# Decrease file size to make it run faster
head -100 example_input/target.fasta > example_input/target_100.fasta
head -100 example_input/background.fasta > example_input/background_100.fasta
```

## Run workflow
Note: replace `-profile singularity` with `-profile docker` if you are using docker instead.
```
# Get help and see all options
nextflow run main.nf --help

# Get genome lengths
TARGET_LEN=$(wc -c example_input/target_100.fasta | awk '{print $1}')
BACKGR_LEN=$(wc -c example_input/background_100.fasta | awk '{print $1}')

# Run with Docker
# Primer search space reduced for example run, takes ~3m 30s on MacBook Pro laptop.
nextflow run \
    -profile singularity main.nf \
    --outpath OUTPATH_DIR \
    --target example_input/target_100.fasta \
    --background example_input/background_100.fasta \
    --target_length $TARGET_LEN \
    --backgr_length $BACKGR_LEN \
    --max_kmer_size 10 \
    --min_kmer_size 10 \
    --max_sets_search 1000
```
