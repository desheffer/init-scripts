#!/bin/bash

set -euo pipefail

# Resize partition:

mount -o remount,size=1G /run/archiso/cowspace

# Clone init-scripts repository:

pacman -Syu --needed --noconfirm git

rm -rf ~/init-scripts
git clone https://github.com/desheffer/init-scripts.git ~/init-scripts

~/init-scripts/stage1/install.sh
