#!/bin/bash

set -e

cd "$(dirname "${0}")"

./init.sh --needed

FLAGS=""
if [ ! -z "${1}" ]; then
    FLAGS="-t ${1}"
fi

source venv/bin/activate
ansible-playbook --ask-become-pass ${FLAGS} deploy.yml
