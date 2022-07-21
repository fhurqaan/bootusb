#/bin/bash
#
# I got the steps to acomplish booting Slackware from usb from
# https://www.youtube.com/watch?v=ddjw_yPvxNY 
# Lost Expat  youtube.
# i just dump the script in a file, and automated a few steps
# so that typing errors won't creep in.
#
# Version 2.0
# Author: Lost Expat 
# scripted by: Fhurqaan Hamid
# email: yeah i have one
# added support for updating kernel 
# the second optional parameter "update" will search for the latest kernel
# in the /boot directory. No checking is done. I assume that the new version 
# has been downloaded. You can change the default version to the version you 
# have installed.
#
# Rememner: money is the root of all evil....send $10 for more info!

# check parameters
echo Boot Slackware from USB drive
echo Version 2.0.0
[[ $1 == "" ]] && echo -e "\nUsage:-\n./bootusb.sh /dev/sdX [update]\nWhere X is drive partition to boot.\n[update] is optional to update to new kernel version you downloaded, defaults to 5.15.27\n" && exit 
blkid $1 2>&1 > /dev/null
if [ $? -gt 0 ] 
then
	echo $1 not found..Please enter valid drive
	exit
fi

case "$2" in
	update)
		kernel=`ls /boot -1 | tail -n1 | cut -d\- -f3`
		;;
	"")
		kernel=5.15.27
		;;
	*)
		echo usage ./bootusb /dev/sdX [update]
		exit
		;;
esac
for n in 1 2
do
	# set variables
	ptype=`blkid $1$n | sed 's/.* TYPE=/\l/' | cut -d\" -f2`
	if [[ $ptype == "ext4" ]]
	then
		rtdrv=$1$n
		duuid=`blkid $rtdrv | sed 's/.*: UUID=/\l/'| cut -d\" -f2` 
		puuid=`blkid $rtdrv | sed 's/.*PARTUUID=/\l/'| cut -d\" -f2` 
		wrkdv=${1:4}$n
	else
		swpuuid=`blkid $rtdrv | sed 's/.*: UUID=/\l/'| cut -d\" -f2` 
		swppuuid=`blkid $rtdrv | sed 's/.*PARTUUID=/\l/'| cut -d\" -f2` 
	fi
done

echo Making /dev$wrkdv bootable using kernel $kernel
#
# check working dir
if [[ ! -d $wrkdv ]] 
then
	echo $wrkdv...not found, creating.
	mkdir $wrkdv
fi

# mount drive
mount /$rtdrv /$wrkdv

# Save UUID for boot and swap partition to file
echo "UUID=$swpuuid	swap	swap	defaults	0	0" > fstabentry 
echo "UUID=$duuid	/	ext4	defaults	1	1" >> fstabentry 
echo Creating fstab.new file in $wrkdv/etc directory  
# join the file to the fstab file
#cat fstabentry /etc/fstab > fstab.new

cat fstabentry $wrkdv/etc/fstab > fstab.new
# comment out line 3 and 4 
sed -i '3,4s/^\/dev/#\/dev/g' fstab.new
#mv $wrkdv/etc/fstab $wrkdv/etc/fstab.org
#mv fstab.new $wrkdv/etc/fstab
rm fstabentry
echo Go thru the new fstab file in your current directory....then copy to the /etc/fstab directory.
echo Lines 3 and 4 are commented by default.
echo These are the default mountpoint for swap and sda partition.
initfile=$wrkdv/etc/mkinitrd.conf
lilofile=$wrkdv/etc/lilo.conf
#
echo removing /proc /sys /dev
# housekeeping
rm -rf $wrkdv/proc/*
rm -rf $wrkdv/sys/*
rm -rf $wrkdv/dev/*
##
echo remounting /proc /sys /dev
mount --bind /proc $wrkdv/proc
mount --bind /sys  $wrkdv/sys
mount --bind /dev  $wrkdv/dev

# run script

rm -rf $wrkdv/tmp/initrd-tree
rm -f $wrkdv/boot/initrd.gz

# create mkinitrd.conf
echo "Creating $initfile"
#echo "KERNEL_VERSION=\"5.15.19\""			 > $initfile
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

chroot $wrkdv mkinitrd -F
lilo -v

# create lilo.conf
echo Generating $lilofile
echo "prompt"								>  $lilofile
echo "compact"								>> $lilofile
echo "timeout=60"							>> $lilofile
echo "boot=$1"								>> $lilofile
echo "image=/boot/vmlinuz"					>> $lilofile
echo "initrd=/boot/initrd.gz"				>> $lilofile
echo "append=\" root=PARTUUID=$puuid\""		>> $lilofile
echo "label=usbLinux"						>> $lilofile
echo "read-only"							>> $lilofile

rm -f $wrkdv/boot/boot.*
rm -f $wrkdv/boot/map
chroot $wrkdv lilo

# unmount 
umount $wrkdv/proc
umount $wrkdv/sys
umount $wrkdv/dev
umount $wrkdv

# delete working dir
rm -r $wrkdv
echo All doneded....
echo When all in one and one is all
echo You\'ll be a rock and not roll...
