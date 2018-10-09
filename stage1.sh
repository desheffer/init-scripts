#!/bin/bash

cd "$(dirname "$0")"

source ./init.sh --needed
source venv/bin/activate

ansible-playbook stage1.yml
