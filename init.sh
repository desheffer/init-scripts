#!/bin/bash

set -e

cd "$(dirname "$0")"

if [ "$USER" != "root" ]; then
    echo "$0: must be root"
    exit
fi

pacman -S --needed --noconfirm python-pip python-virtualenv
rm -rf venv
virtualenv venv
source venv/bin/activate
pip install -r requirements.txt

git submodule init
git submodule update
