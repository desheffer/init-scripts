#!/bin/bash

cd "$(dirname "$0")"

source ./init.sh --needed

FLAGS=""
if [ ! -z "$1" ]; then
    FLAGS="-t $1"
fi

ansible-playbook $FLAGS stage2.yml
