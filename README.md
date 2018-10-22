# init-scripts

This is a set of scripts to provision my machine using Arch Linux. It consists
of multiple stages:

* **stage1** - This stage formats the hard drive, installs the base system,
  and configures basic functionality.
* **stage2** - This stage further customizes the system, installs the GUI, and
  adds other useful applications.

:warning: Please be advised these scripts are designed around **my specific
machine** and my own particular use cases. If you would like to use these
scripts, then I recommend forking this repository and modifying it to suit your
needs.

## Provisioning a machine

All of the scripts below are based on the Arch Linux [Installation
guide](https://wiki.archlinux.org/index.php/Installation_guide).

Connect to wifi, if necessary:

    wifi-menu

Start the installation script:

    bash -e <(curl -L https://github.com/desheffer/init-scripts/raw/master/stage1/curl.sh)

The script will prompt for information and run stages 1 and 2. It will reboot
into the fully installed system once complete.

## Keeping a machine in sync

Due to the idempotent nature of Ansible, you can run stage 2 again at any time.
This can be used to keep the system in sync with changes from this repository.

Run stage 2 using the following command:

    ~/init-scripts/deploy.sh
