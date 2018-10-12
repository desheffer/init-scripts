#!/bin/bash

cd "$(dirname "$0")"

source ./init.sh --needed
source venv/bin/activate

FLAGS=""
if [ ! -z "$1" ]; then
    FLAGS="-t $1"
fi

ansible-playbook --ask-become-pass $FLAGS deploy.yml