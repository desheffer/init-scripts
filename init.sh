#!/bin/bash

set -e

cd "$(dirname "${0}")"

if [ "${USER}" = "root" ]; then
    echo "${0}: script should run as a non-privileged user"
    exit 1
fi

if [ -d venv ] && [ "${1}" == "--needed" ]; then
    exit 0
fi

sudo pacman -S --needed --noconfirm python python-pip python-virtualenv

rm -rf venv
virtualenv venv

source venv/bin/activate
pip install -r requirements.txt

git submodule init
git submodule update
