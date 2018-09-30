#!/bin/bash

set -e

cd "$(dirname "$0")"

if [ "$USER" != "root" ]; then
    echo "$0: must be root"
    exit
fi

FLAGS=""
if [ ! -z "$1" ]; then
    FLAGS="-t $1"
fi

source venv/bin/activate
ansible-playbook $FLAGS deploy.yml
