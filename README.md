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

Connect to wifi:

    wifi-menu

Run **stage 1**:

    curl -L https://github.com/desheffer/init-scripts/raw/master/stage1/curl.sh | bash

The system will reboot into the new system when the installation is complete.

Run **stage 2**:

    git clone https://github.com/desheffer/init-scripts.git
    ./init-scripts/stage2/deploy.sh
