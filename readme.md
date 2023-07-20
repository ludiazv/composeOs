# ComposeOs - A container only linux for SBCs


**ComposeOs** is a small image for ARM SBCs that intended to run containers in single boards computers (like raspberry Pi). **composeOs** is minimal and features simple configuration in a **yaml** format to 

**WARNING: composeOs is alpha version and some features are not fully tested. Please consider if you want to use in production**


## Documentation

Please check (the doc)[docs/composeos.md].

## Boards

Currently only this boards are built:

- Raspberry Pi 4
- Raspberry Pi 3
- Orange Pi Zero 2
- Banana PI M2 Zero

Only 64bit images are provided for 64bit capable SoCs.


## Contribute

At this phase of development the most appreciable contribution are:

- Testing the software and report the issues in the issues page.
- Improve the documentation.
- Provide examples of composeos.yml and software stacks.
- Contribute with additional stack templates.
- Add and test other boards.


If you want to contribute to the code base please note the following comments:

- composeOs is based on yocto/oe, you need to be familiar with yocto concepts to understand the structure of the project.
- All custom code is implemented in POSIX shell. No bashims are allowed, bash is not even installed.
- Most linux core utils are provided by Busybox that does not provide full funtionality.
- The init system is openRC.
- The _composeos.py_ in the root folder is a custom bulider using containers and is not part of the software deployed in the SBC.
- The container engine is podman and the composer is podman-compose.
- libc is musl to reduce system footprint.

## TODO

- Implement populate for tarballs.
- Include additonal images: RPI ZERO W ,  RPI ZERO 2, Orange PI 3 LTS , Orange PI Zero 3.
- Rockchip family integration.





















