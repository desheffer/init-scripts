#!/bin/bash

set -e

cd "$(dirname "${0}")"

if [ "${USER}" = "root" ]; then
    echo "${0}: script should run as a non-privileged user"
    exit 1
fi

git submodule init
git submodule update

if [ ! -d venv ]; then
    sudo pacman -S --needed --noconfirm python python-pip python-virtualenv

    virtualenv venv

    source venv/bin/activate
    pip install -r requirements.txt
fi

become=("--ask-become-pass")
tag=()

function show_help {
    echo "Usage: ${0} [OPTION]..."
    echo "Deploy init-scripts to this computer."
    echo
    echo "  -p    use the specified SUDO password"
    echo "  -t    deploy a specific tag"
    exit 0
}

while getopts ":hp:t:" opt; do
    case ${opt} in
        h)
            show_help
            ;;
        p)
            become=("--extra-vars" "ansible_become_pass='${OPTARG}'")
            ;;
        t)
            tag=("-t" "${OPTARG}")
            ;;
        \?)
            echo "${0}: invalid option -- '${OPTARG}'" 1>&2
            echo "Try '${0} -h' for more information." 1>&2
            exit 1
            ;;
        :)
            echo "${0}: option requires an argument -- '${OPTARG}'" 1>&2
            echo "Try '${0} -h' for more information." 1>&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

if [ ! -z ${1+x} ]; then
    show_help
fi

source venv/bin/activate
ansible-playbook "${become[@]}" "${tag[@]}" deploy.yml
