# Ionoid SealOS Manager Installation tools

This repo contains tools to install Ionoid SealOS Manager sdk. It
support any Linux system with systemd installed.


## Install Ionoid IoT sdk

To install Ionoid sdk, simply run the following command on your
termainl:

```bash
curl https://raw.githubusercontent.com/ionoid/install-ionoid/master/sdk-ionoid-sealos-iot.bash | MACHINE=arm7 IMAGE=raspbian-stretch-lite.zip CONFIG=config.json bash
```

Follow the progress, and enter `root` password for `sudo` command to
install programs if necessary.

This commands, downloads the installation script and execute it with
`bash` making sure to pass the right envrionment variables.

* MACHINE: is the target machine architecture, valid values are: `arm6`,
        `arm7`, `amd64`

* IMAGE: is the final Operating System image where the tools will be
installed. Example for `Raspbian` downloaded from Rasperry Pi foundation website `IMAGE=raspbian-stretch-lite.zip`.

* CONFIG: is the project's `config.json`, you can obtain it from the
correspondig Ionoid Project, by selecting `Add Devices`.
