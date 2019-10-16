# Ionoid SealOS Manager Installation tools

This repo contains tools to install Ionoid SealOS Manager sdk. It
support any Linux system with systemd installed.


## Install Ionoid IoT Manager

To install Ionoid SealOS Manager, simply run the install command
on your terminal.

Follow the progress, and when prompted for `root` password, enter it.
It is uses for `sudo` command to install programs if necessary.

This command downloads the installation script and execute it with
`bash` making sure to pass the right envrionment variables. The new
generated image will be stored in the `output` directory where the
original image is located.


Supported environment variables are:

* MACHINE: is the target machine architecture, valid values are: `arm6`,
        `arm7`, `amd64`.
Example Raspberry PI 3: `arm7`, Raspberry PI Zero: `arm6`


* IMAGE: is the final Operating System image where the tools will be
installed. Example for [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) downloaded from Rasperry Pi foundation website `IMAGE=raspbian-stretch-lite.zip`.


* CONFIG: is the project's `config.json`. You can obtain it from the
correspondig Ionoid Project, by selecting `Add Devices`.

Create a working directory into your home:
```bash
mkdir -p ionoid-build
```

Copy your `config.json` and `raspbian` zipped image to `ionoid-build`
directory.


Install command:

```bash
cd ionoid-build
curl https://github.install-ionoid.sdk.ionoid.net/install-tools.bash | IMAGE=raspbian-stretch-lite.zip CONFIG=config.json bash
```

or

```bash
cd ionoid-build
curl -O https://github.install-ionoid.sdk.ionoid.net/install-tools.bash
chmod 755 install-tools.bash
IMAGE=raspbian-stretch-lite.zip CONFIG=config.json ./install-tools.bash
```
