#!/usr/bin/env bash


target=$1
background=$2
exclude=$3

source bash_functions.sh

# Decompress input
mkdir .tmp
if [[ "${target}" == *.gz ]]; then
    gunzip -c ${target} > ./.tmp/target.fasta
    msg "INFO: extracted compressed target genome ${target}"
else
    cp ${target} ./.tmp/target.fasta
fi

if [[ "${background}" == *.gz ]]; then
    gunzip -c ${background} > ./.tmp/background.fasta
    msg "INFO: extracted compressed background genome ${background}"
else
    cp ${background} ./.tmp/background.fasta
fi

if [[ "${exclude}" == *.gz ]]; then
    gunzip -c ${exclude} > ./.tmp/exclude.fasta
    msg "INFO: extracted compressed exclude sequence ${exclude}"
elif [[ ${exclude} == 'none' ]]; then
    echo ">placeholder_blank_exclude_seq" > ./.tmp/exclude.fasta
    msg "INFO: created empty exclude file as placeholder to avoid interactive mode"
else
    cp "${exclude}" ./.tmp/exclude.fasta
fi

# Remove blank lines for swga
for file in .tmp/target.fasta .tmp/background.fasta .tmp/exclude.fasta; do
    awk NF ${file} >> ./${file}.noblanks
done
msg "INFO: removed any blank lines in input"