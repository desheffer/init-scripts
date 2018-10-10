#!/bin/bash

set -e

cd "$(dirname "$0")"

if [ "$USER" = "root" ]; then
    echo "$0: should not run as root"
    exit 1
fi

if [ -d venv ] && [ "$1" == "--needed" ]; then
    return
fi

rm -rf venv
virtualenv venv

source venv/bin/activate
pip install -r requirements.txt

git submodule init
git submodule update
