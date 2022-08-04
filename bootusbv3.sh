#!/bin/bash
#
# I got the steps to acomplish booting Slackware from usb from
# https://www.youtube.com/watch?v=ddjw_yPvxNY
# Lost Expat  youtube.
# i just dump the script in a file, and automated a few steps
# so that typing errors won't creep in.
#
# Version 3.0.0
# Author: Lost Expat
# scripted by: Fhurqaan Hamid
# All valid partitions are presented in a menu. 
# Optional parameter "update", will search for the latest kernel
# in the /boot directory. 

#
# COPY THIS SCRIPT TO YOUR SLACKWARE BOOT USB,
# AFTER INSTALL SLACKWARE, DO NOT REBOOT THE COMPUTER;
# RUN THIS IS SCRIPT 

# Remember: 
# Money is the root of all evil....
# Send $10 for more info! ©

# FIXES:
# Now a menu of valid drives is presented
# also fixed, not so reliable version checking
# to most reliable checking :)

# Set version number
VERSION=3.0.0

# define colors. All bright colors
# for normal colors remove 1; or change to 2;
# i have problem seeing normal colors on my fading mointor
# besides bright colors pop-out :)
red=`echo -e "\e[1;31m"`
green=`echo -e "\e[1;32m"`
yellow=`echo -e "\e[1;33m"`
blue=`echo -e "\e[1;34m"`
magenta=`echo -e "\e[1;35m"`
cyan=`echo -e "\e[1;36m"`
white=`echo -e "\e[1;37m"`
normal=`echo -e "\e[0m"`

#define function find valid drive type
menuDrives () {
	drives=($(df --type=ext{2..5} | awk 'NR>1{print $1}' |  sort))
	# add abort elenment to array as last item
	drives+=("abort")
}


echo Make your Slackware boot from USB
echo Version $white$VERSION$normal
echo No copyrights, copylefts...or copywrongs

# get curent kernel version
kernel=`uname -r`

# check parameters
if [[ "$1" != "update" && "$1" != "" ]]
then
	echo "Usage:- \n$0 [update]."
	echo [update] is optional. To update to new kernel version you downloaded.
	echo Defaults current kernel $yellow$kernel$normal version.
	exit 1
fi

menuDrives
echo Select drive/partition to make bootable!
select i in ${drives[@]}
do
	case $i in
		abort)
			echo Aborting, quiting, exiting script $0
			exit
			;;
		  "")
		    echo $red\That choice is not in the menu!
		    echo Smash enter to display menu.$normal
			;;
		   *)
			echo $green$i$normal will be setup to boot from usb
			# do processing for selected drive/partition
			# $i = /dev/sda1
			wrkdrvn=${i:4}  ## returns /sda1
			wrkdrv=${i:4:4} ## returns /sda
			devdrv=${i::-1} ## returns /dev/sda
			break
			;;
	esac
done

case "$1" in
	update)
		kernel=`ls /boot/vmlinuz*[0-9]* -1v | tail -n1 | cut -d\- -f3`
		;;
	"")
		#	Use currently install kernel
		;;
	*)
		echo usage ./bootusb [update]
		exit
		;;
esac
echo Using kernel $green$kernel$normal

# set the uuid's for partition 
duuid=`blkid $i | sed 's/.*: UUID=/\l/'| cut -d\" -f2`
puuid=`blkid $i | sed 's/.*PARTUUID=/\l/'| cut -d\" -f2`
bootptype=`blkid $i | sed 's/.* TYPE=/\l/' | cut -d\" -f2`

swpduuid=""
# swppuuid=""

# set max partitions to check...
MAX_PART=5

# search for swap partition
for (( n=1; n<=$MAX_PART; n++ ))
do
	rtdrv=$devdrv$n
	# set variables
	ptype=`blkid $rtdrv | sed 's/.* TYPE=/\l/' | cut -d\" -f2`
	case $ptype in
		swap)
			swpduuid=`blkid $rtdrv | sed 's/.*: UUID=/\l/'| cut -d\" -f2`
#			swppuuid=`blkid $rtdrv | sed 's/.*TUUID=/\l/'| cut -d\" -f2`
			break
			;;
	esac
done

# check working dir
if [[ ! -d $wrkdrvn ]]
then
	echo $wrkdrvn...not found, creating.
	mkdir $wrkdrvn
fi

# mount drive
mount $i $wrkdrvn

# Save UUID for boot and swap partition to fstab.new file

echo Creating $PWD/fstab.new file 
if [[ $swapduuid == "" ]]
then
	echo "# swap partition not found" > fstab.tmp
else
	echo "UUID=$swpduuid	swap	swap	defaults	0	0" > fstab.tmp
fi
echo "UUID=$duuid	/	$bootptype	defaults	1	1" >> fstab.tmp

# join the fstab.new file to the fstab file
cat fstab.tmp $wrkdrvn/etc/fstab > fstab.new

# comment out the original mount point, 
# now line 3 and 4, from the /etc/fstab file
sed -i '3,4s/^\/dev/#\/dev/g' fstab.new

# remove temp file
rm fstab.tmp
echo
echo
echo Double check the new fstab file in your $green$PWD$normal directory
echo If all ok, then overwrite the $wrkdrvn/etc/fstab file. 
echo 
echo Example:
echo cp mydir/fstab.new $wrkdrvn/etc/fstab
echo
echo Lines 3 and 4 are commented by default.
echo These are the default mountpoint for swap and sda partition.
sleep 3

# set paths for mkinitrd and lilo.conf
initfile=$wrkdrvn/etc/mkinitrd.conf
lilofile=$wrkdrvn/etc/lilo.conf

# housekeeping
echo removing /proc /sys /dev
rm -rf $wrkdrvn/proc/*
rm -rf $wrkdrvn/sys/*
rm -rf $wrkdrvn/dev/*

echo remounting /proc /sys /dev
mount --bind /proc $wrkdrvn/proc
mount --bind /sys  $wrkdrvn/sys
mount --bind /dev  $wrkdrvn/dev
rm -rf $wrkdrvn/tmp/initrd-tree
rm -f $wrkdrvn/boot/initrd.gz

# create mkinitrd.conf
# edit to suit your needs
echo "Creating $initfile"
echo "KERNEL_VERSION=\"$kernel\""			 > $initfile
echo "SOURCE_TREE=\"/tmp/initrd-tree\"" 	>> $initfile
echo "OUTPUT_IMAGE=\"/boot/initrd.gz\"" 	>> $initfile
echo "CLEAR_TREE=\"1\""						>> $initfile
echo "MODULE_LIST=\"ochi-hdc:ochi-pci:\
uhci-hcd:ehci-pci:\
xhci-hcd:xhci-pci:\
usb-storage:uas\""							>> $initfile
echo "ROOTDEV=\"UUID=$duuid\""				>> $initfile
echo "ROOTFS=\"ext4\""						>> $initfile
echo "KEYMAP=\"us\""						>> $initfile
echo "UDEV=\"1\""							>> $initfile
echo "WAIT=\"2\""							>> $initfile
echo "MODCONF=\"0\""						>> $initfile
echo "RAID=\"0\""							>> $initfile
echo "LVM=\"0\""							>> $initfile

chroot $wrkdrvn mkinitrd -F
lilo -v

# create lilo.conf
echo Generating $lilofile
echo "prompt"								>  $lilofile
echo "compact"								>> $lilofile
echo "timeout=60"							>> $lilofile
echo "boot=$i"								>> $lilofile
echo "image=/boot/vmlinuz"					>> $lilofile
echo "initrd=/boot/initrd.gz"				>> $lilofile
echo "append=\" root=PARTUUID=$puuid\""		>> $lilofile
echo "label=usbLinux"						>> $lilofile
echo "read-only"							>> $lilofile

rm -f $wrkdrvn/boot/boot.*
rm -f $wrkdrvn/boot/map
chroot $wrkdrvn lilo

# unmount
umount $wrkdrvn /proc
umount $wrkdrvn /sys
umount $wrkdrvn /dev
umount $wrkdrvn

# delete working dir
rm -r $wrkdrvn
echo All doneded....
echo When all in one and one is all
echo You\'ll be a rock and not roll...
