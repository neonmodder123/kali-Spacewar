# Kali Phosh Builder for Nothing Phone (1) Spacewar

```
-----------------------------------------
 _____     _   _____         _
|   | |___| |_|  |  |_ _ ___| |_ ___ ___
| | | | -_|  _|     | | |   |  _| -_|  _|
|_|___|___|_| |__|__|___|_|_|_| |___|_|
 _____
|  _  |___ ___
|   __|  _| . | Image Generator
|__|  |_| |___| by Shubham Vishwakarma

twitter/git: shubhamvis98
-----------------------------------------
```

A huge thanks to Mobian Project and Megi's Kernel Patches.

## Build Instruction:

Normal Build with default username and password:
```
sudo ./build.sh -t nothingphone1
```
If you want to specify the username, password, and hostname, run this:
```
sudo ./build.sh -t nothingphone1 -u USER -h HOSTNAME -p PASSWORD
```

## Required packages:
    - android-sdk-libsparse-utils
    - bmap-tools
    - debootstrap
    - qemu-user-static
    - rsync
    - systemd-container
