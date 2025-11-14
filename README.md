# Kali Phosh Builds for Nothing Phone (1) Spacewar

```
-----------------------------------------
 _____     _   _____         _
|   | |___| |_|  |  |_ _ ___| |_ ___ ___
| | | | -_|  _|     | | |   |  _| -_|  _|
|_|___|___|_| |__|__|___|_|_|_| |___|_|
 _____
|  _  |___ ___
|   __|  _| . | Updated builds by me :)
|__|  |_| |___| build.sh by Shubham Vishwakarma

twitter/git: shubhamvis98
-----------------------------------------
```
This repo has normal and dualboot (test) updated builds for the Nothing Phone 1, and a GitHub Workflow to build these images. I will not be building for other devices as I do not have them.

A huge thanks to Mobian Project, Megi's Kernel Patches and Shubham Vishwakarma (Shubhamvis98).

# STATUS:
## There is a segmentation fault while booting and since I do not have access to a linux computer at the moment and have a lot of work, I cannot build the kernel. I might try later on, but I cannot guarentee that.

## Build Instruction:
Automatic Build:

Just fork this repository and run the Build Image action.

### Manual Build:

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
