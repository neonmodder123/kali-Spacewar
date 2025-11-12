#!/bin/bash -e

# This script builds a Kali image for various mobile devices, integrating 
# the Mobian repository for mobile-specific packages.
# This version includes robust, host-side GPG key installation for both 
# the main Kali archive (to fix debootstrap warnings) and the Mobian 
# repository (to fix the previous fatal error).

. bin/funcs.sh

# Default Configuration
device="nothingphone1"
environment="phosh"
hostname="nethunter"
username="kali"
password="8888"
mobian_suite="trixie"
IMGSIZE=5 	# GBs
MIRROR='http://http.kali.org/kali'

# Parse command line options
while getopts "cbt:e:h:u:p:s:m:M:" opt
do
	case "$opt" in
		t ) device="$OPTARG" ;;
		e ) environment="$OPTARG" ;;
		h ) hostname="$OPTARG" ;;
		u ) username="$OPTARG" ;;
		p ) password="$OPTARG" ;;
		s ) custom_script="$OPTARG" ;;
		m ) mobian_suite="$OPTARG" ;;
		M ) MIRROR="$OPTARG" ;;
		c ) compress=1 ;;
		b ) blockmap=1 ;;
	esac
done

# Device-specific configuration
case "$device" in
	"pinephone"|"pinetab"|"sunxi" )
		arch="arm64"
		family="sunxi"
		SERVICES="eg25-manager"
		PACKAGES="megapixels"
		;;
	"pinephonepro"|"pinetab2"|"rockchip" )
		arch="arm64"
		family="rockchip"
		SERVICES="eg25-manager"
		PACKAGES="megapixels megapixels-config-pinephonepro"
		;;
	"pocof1"|"oneplus6"|"oneplus6t"|"sdm845"|"qcom" )
		arch="arm64"
		family="qcom"
		SERVICES="qrtr-ns rmtfs pd-mapper tqftpserv qcom-modem-setup droid-juicer"
		PACKAGES="pulseaudio yq qbootctl"
		PARTITIONS=1
		SPARSE=1
		;;
	"nothingphone1"|"sm7325" )
		arch="arm64"
		family="sm7325"
		SERVICES="qrtr-ns rmtfs pd-mapper tqftpserv qcom-modem-setup droid-juicer"
		PACKAGES="pulseaudio yq qbootctl"
		PARTITIONS=1
		SPARSE=1
		;;
	* )
		echo "Unsupported device ${device}"
		exit 1
		;;
esac

# Common packages
PACKAGES="${PACKAGES} kali-linux-core wget vim binutils rsync systemd-timesyncd systemd-repart"
DPACKAGES="${family}-support"

# Environment-specific packages
case "${environment}" in
	phosh)
		PACKAGES="${PACKAGES} phosh-phone phrog portfolio-filemanager"
		SERVICES="${SERVICES} greetd"
		;;
	plasma-mobile)
		PACKAGES="${PACKAGES} plasma-mobile qmlkonsole"
		SERVICES="${SERVICES} plasma-mobile"
		;;
	xfce|lxde|gnome|kde)
		PACKAGES="${PACKAGES} kali-desktop-${environment}"
		SERVICES="${SERVICES}" # Assuming greetd or display manager is included in kali-desktop-*
		;;
esac

IMG="kali_${environment}_${device}_`date +%Y%m%d`.img"
ROOTFS_TAR="kali_${environment}_${device}_`date +%Y%m%d`.tgz"
ROOTFS="kali_rootfs_tmp"

### START BUILDING ###
banner
echo '____________________BUILD_INFO____________________'
echo "Device: $device"
echo "Environment: $environment"
echo "Hostname: $hostname"
echo "Username: $username"
echo "Password: $password"
echo "Mobian Suite: $mobian_suite"
echo "Family: $family"
echo "Custom Script: $custom_script"
echo -e '--------------------------------------------------\n\n'
echo '[*]Build will start in 5 seconds...'; sleep 5

[ -e "base.tgz" ] && mkdir ${ROOTFS} && tar --strip-components=1 -xpf base.tgz -C ${ROOTFS}

echo '[+]Stage 1: Debootstrap'
[ -e ${ROOTFS}/etc ] && echo -e "[*]Debootstrap already done.\nSkipping Debootstrap..." || debootstrap --foreign --arch $arch kali-rolling ${ROOTFS} ${MIRROR}

echo '[+]Stage 2: Debootstrap second stage and adding Mobian apt repo'
if [ -e ${ROOTFS}/etc/passwd ]; then
    echo '[*]Second Stage already done'
else
    nspawn-exec /debootstrap/debootstrap --second-stage
fi

# --- ROBUST APT KEY AND SOURCE SETUP (FINAL FIX: Host-Side for both Kali & Mobian) ---

KEYRING_DIR="${ROOTFS}/usr/share/keyrings"
KALI_KEYRING_PATH="${KEYRING_DIR}/kali-archive-keyring.gpg"
MOBIAN_KEYRING_PATH="${KEYRING_DIR}/mobian-archive-keyring.gpg"

# 1. Create the necessary directories on the host
mkdir -p ${ROOTFS}/etc/apt/sources.list.d ${KEYRING_DIR}

# 2. Install KALI Key (Fixes the debootstrap WARNING)
echo "[*] Installing Kali GPG key from host system to ${KALI_KEYRING_PATH}..."
# Use curl/gpg on the host and tee the output to guarantee correct format and permissions.
curl -fsSL https://archive.kali.org/archive-keyring.gpg | gpg --dearmor | tee ${KALI_KEYRING_PATH} > /dev/null
chmod 644 ${KALI_KEYRING_PATH}

# 3. Install MOBIAN Key (Fixes the previous FATAL ERROR)
echo "[*] Installing Mobian GPG key from host system to ${MOBIAN_KEYRING_PATH}..."
curl -fsSL http://repo.mobian.org/mobian.gpg | gpg --dearmor | tee ${MOBIAN_KEYRING_PATH} > /dev/null
chmod 644 ${MOBIAN_KEYRING_PATH}

# 4. Update the main Kali sources line to include contrib/non-free and the signed-by directive
# This ensures the first source line is correctly formatted for modern APT
sed -i 's/main/main contrib non-free non-free-firmware/g' ${ROOTFS}/etc/apt/sources.list
sed -i 's|^deb \(.*\)kali-rolling \(.*\) *|deb [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] \1kali-rolling \2|g' ${ROOTFS}/etc/apt/sources.list

# 5. Create the Mobian sources list, using the modern 'signed-by' attribute
echo "deb [signed-by=${MOBIAN_KEYRING_PATH}] http://repo.mobian.org/ ${mobian_suite} main non-free-firmware" > ${ROOTFS}/etc/apt/sources.list.d/mobian.list

# --- END ROBUST APT KEY AND SOURCE SETUP (FINAL FIX) ---


cat << EOF > ${ROOTFS}/etc/apt/preferences.d/00-mobian-priority
Package: *
Pin: release o=Mobian
Pin-Priority: 700
EOF

ROOT_UUID=`python3 -c 'from uuid import uuid4; print(uuid4())'`
BOOT_UUID=`python3 -c 'from uuid import uuid4; print(uuid4())'`

if [[ "$family" == "sunxi" || "$family" == "rockchip" ]]
then
	BOOTPART="UUID=${BOOT_UUID}	/boot	ext4	defaults,x-systemd.growfs	0	2"
fi

cat << EOF > partuuid
ROOT_UUID=${ROOT_UUID}
BOOT_UUID=${BOOT_UUID}
EOF

cat << EOF > ${ROOTFS}/etc/fstab
# <file system> <mount point> 	<type> 	<options> 	 	<dump> 	<pass>
UUID=${ROOT_UUID}	/	ext4	defaults,x-systemd.growfs	0	1
${BOOTPART}
EOF

echo '[+]Stage 3: Installing device specific and environment packages'
# This 'apt update' should now succeed for both Kali and Mobian sources.
nspawn-exec apt update 
nspawn-exec apt install -y ${PACKAGES}
nspawn-exec apt install -y ${DPACKAGES}

echo '[+]Stage 4: Adding some extra tweaks'
if [ ! -e "${ROOTFS}/etc/repart.d/50-root.conf" ]
then
	mkdir -p ${ROOTFS}/etc/kali-motd
	touch ${ROOTFS}/etc/kali-motd/disable-minimal-warning
	mkdir -p ${ROOTFS}/etc/skel/.local/share/squeekboard/keyboards/terminal
	curl https://raw.githubusercontent.com/Shubhamvis98/PinePhone_Tweaks/main/layouts/us.yaml > ${ROOTFS}/etc/skel/.local/share/squeekboard/keyboards/us.yaml
	ln -srf ${ROOTFS}/etc/skel/.local/share/squeekboard/keyboards/{us.yaml,terminal/}
	sed -i 's/-0.07/0/;s/-0.13/0/' ${ROOTFS}/usr/share/plymouth/themes/kali/kali.script
	mkdir -p ${ROOTFS}/etc/repart.d
	cat << 'EOF' > ${ROOTFS}/etc/repart.d/50-root.conf
[Partition]
Type=root
Weight=1000
EOF
else
	echo '[*]This has been already done'
fi

echo '[+]Stage 5: Adding user and changing default shell to zsh'
if [ ! `grep ${username} ${ROOTFS}/etc/passwd` ]
then
	nspawn-exec adduser --disabled-password --gecos "" ${username}
	sed -i "s#${username}:\!:#${username}:`echo ${password} | openssl passwd -1 -stdin`:#" ${ROOTFS}/etc/shadow
	sed -i 's/bash/zsh/' ${ROOTFS}/etc/passwd
	for i in dialout sudo audio video plugdev input render bluetooth feedbackd netdev; do
		nspawn-exec usermod -aG ${i} ${username} || true
	done
else
	echo '[*]User already present'
fi

echo '[*]Enabling kali plymouth theme'
nspawn-exec plymouth-set-default-theme -R kali
#sed -i "/picture-uri/cpicture-uri='file:\/\/\/usr\/share\/backgrounds\/kali\/kali-red-sticker-16x9.jpg'" ${ROOTFS}/usr/share/glib-2.0/schemas/11_mobile.gschema.override
sed -i "/picture-uri/cpicture-uri='file:\/\/\/usr\/share\/backgrounds\/kali\/kali-metal-dark-16x9.jpg'" ${ROOTFS}/usr/share/glib-2.0/schemas/10_desktop-base.gschema.override
nspawn-exec glib-compile-schemas /usr/share/glib-20/schemas

echo '[+]Stage 6: Enable services'
for svc in `echo ${SERVICES} | tr ' ' '\n'`
do
	nspawn-exec systemctl enable $svc
done

echo '[*]Checking for custom script'
if [ -f "${custom_script}" ]
then
	mkdir -p ${ROOTFS}/ztmpz
	cp ${custom_script} ${ROOTFS}/ztmpz
	nspawn-exec bash /ztmpz/${custom_script}
	[ -d "${ROOTFS}/ztmpz" ] && rm -rf ${ROOTFS}/ztmpz
fi

echo '[*]Tweaks and cleanup'
echo ${hostname} > ${ROOTFS}/etc/hostname
grep -q ${hostname} ${ROOTFS}/etc/hosts || \
	sed -i "1s/$/\n127.0.1.1\t${hostname}/" ${ROOTFS}/etc/hosts
nspawn-exec apt clean

if [ ${SPARSE} ]
then
	#nspawn-exec sudo -u ${username} systemctl --user disable pipewire pipewire-pulse
	#nspawn-exec sudo -u ${username} systemctl --user mask pipewire pipewire-pulse
	#nspawn-exec sudo -u ${username} systemctl --user enable pulseaudio
	cp -r bin/bootloader.sh bin/configs ${ROOTFS}
	chmod +x ${ROOTFS}/bootloader.sh
	nspawn-exec /bootloader.sh ${family}
	mv -v ${ROOTFS}/boot*img .
	rm -rf ${ROOTFS}/bootloader.sh ${ROOTFS}/configs
fi

echo '[*]Deploy rootfs into EXT4 image'
tar -cpzf ${ROOTFS_TAR} ${ROOTFS} && rm -rf ${ROOTFS}
mkimg ${IMG} ${IMGSIZE} ${PARTITIONS}
tar -xpf ${ROOTFS_TAR}

if [[ "$family" == "sunxi" || "$family" == "rockchip" ]]
then
	echo '[*]Update u-boot config...'
	nspawn-exec -r '/etc/kernel/postinst.d/zz-u-boot-menu $(linux-version list | tail -1)'
fi

echo '[*]Cleanup and unmount'
cleanup

echo "[+]Stage 7: Compressing ${IMG}..."
if [ "$blockmap" ]
then
	bmaptool create ${IMG} > ${IMG}.bmap
else
	echo '[*]Skipped blockmap creation'
fi

if [ "$SPARSE" ]
then
	img2simg ${IMG} ${IMG}_SPARSE
	mv -v ${IMG}_SPARSE ${IMG}
fi

if [ "$compress" ]
then
	[ -f "${IMG}" ] && xz "${IMG}"
else
	echo '[*]Skipped compression'
fi
echo '[+]Image Generated.'


