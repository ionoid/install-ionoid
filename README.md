# Ionoid SealOS Manager Installation tools

This repo contains tools to install Ionoid SealOS Manager sdk. It
support any Linux system with systemd installed.


## Install Ionoid IoT Manager

To install Ionoid SealOS Manager, simply run the following command
on your termainl:

```bash
curl https://sdk.services.ionoid.net/install.bash | MACHINE=arm7 IMAGE=raspbian-stretch-lite.zip CONFIG=config.json bash
```

Follow the progress, and when prompted for `root` password, enter it.
It is used for `sudo` command to install programs if necessary.

This command downloads the installation script and execute it with
`bash` making sure to pass the right envrionment variables.

* MACHINE: is the target machine architecture, valid values are: `arm6`,
        `arm7`, `amd64`.
Example Raspberry PI 3: `arm7`
Example Raspberry PI Zero: 'arm6`


* IMAGE: is the final Operating System image where the tools will be
installed. Example for `Raspbian` downloaded from Rasperry Pi foundation website `IMAGE=raspbian-stretch-lite.zip`.


* CONFIG: is the project's `config.json`, you can obtain it from the
correspondig Ionoid Project, by selecting `Add Devices`.
