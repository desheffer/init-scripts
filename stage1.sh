#!/bin/bash

cd "$(dirname "$0")"

source ./init.sh --needed

ansible-playbook stage1.yml
