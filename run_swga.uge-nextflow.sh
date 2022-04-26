#!/bin/bash -l

# This script is to run the workflow on the UGE cluster
# Run as: qsub run_swga.uge-nextflow.sh

##################################################
# SET THESE VARIABLES
##################################################

TARGET=./example_input/target_100.fasta
BACKGROUND=./example_input/background_100.fasta
EXCLUDE=./example_input/exclude.fasta
OUTPATH=./example_results
PRIMER_SET_SIZE=10

##################################################
# DONT EDIT BELOW HERE
##################################################

# Load nextflow module
module load nextflow/21.04.3

# Set up tmp and cache directories for Singularity
mkdir -p $HOME/tmp && \
    export TMPDIR=$HOME/tmp
mkdir -p /scicomp/scratch/$USER/singularity.cache && \
    export NXF_SINGULARITY_CACHEDIR=/scicomp/scratch/$USER/singularity.cache

# Get LAB_HOME or custom tmp/cache variables from .bashrc
source $HOME/.bashrc

# Get approximate target and background genome lengths
TARGET_LEN=$(wc -c $TARGET | awk '{print $1}')
BACKGR_LEN=$(wc -c $BACKGROUND | awk '{print $1}')

# Run the nextflow workflow
if [[ -z "$EXCLUDE" ]]; then
  nextflow -log /scicomp/scratch/$USER/nextflow_log.txt run -profile singularity,sge main.nf \
    --outpath $OUTPATH \
    --target $TARGET \
    --background $BACKGROUND \
    --target_length $TARGET_LEN \
    --backgr_length $BACKGR_LEN \
    --find_sets_min_size $PRIMER_SET_SIZE \
    --find_sets_max_size $PRIMER_SET_SIZE \
    --max_sets_search 10000
else 
  nextflow -log /scicomp/scratch/$USER/nextflow_log.txt run -profile singularity,sge main.nf \
    --outpath $OUTPATH \
    --target $TARGET \
    --background $BACKGROUND \
    --exclude $EXCLUDE \
    --target_length $TARGET_LEN \
    --backgr_length $BACKGR_LEN \
    --find_sets_min_size $PRIMER_SET_SIZE \
    --find_sets_max_size $PRIMER_SET_SIZE \
    --max_sets_search 10000
fi
