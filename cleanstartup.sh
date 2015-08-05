#!/bin/bash
#
#
#
grubfilepath="/boot/grub2/grub.cfg"
bootdiskpath="/dev/sda1"
grubmountpoint="/mnt/bootdisk"
grubpath="$grubmountpoint$grubfilepath"
logpath="/home/cleanlog"

mountpoint="/mnt/tempmount"
nextrcpath="/etc/rc.d/rc.local"

keyword="autopack"

systemflag="menuentry"

if [[ $UID -ne 0 ]]
then
        echo "This script needs root privilege !" >> "$logpath"
        echo "" >> "$logpath"
        exit 1
fi

#mount boot partition
if [[ ! -d $grubmountpoint ]]
then
        mkdir $grubmountpoint
fi
mount "$bootdiskpath" "$grubmountpoint" >> "$logpath"

echo $(date) >> ${logpath}

#count system numbers
total=$(grep "^$systemflag" "$grubpath" | wc -l)
echo "Total system count: $total " >> "$logpath"

#delete startup on every system listed in grub.cfg
for (( current=1;current<=total;current++))
do
	echo  >> "$logpath"
	echo "$current" >> "$logpath"
	targetdisk=$(grep "^$systemflag" "$grubpath" | awk -F'[ ()]' 'NR=='$current'{for(i=1;i<=NF;i++) if($i~/dev/) print $i}')
	if [[ ! -d $mountpoint ]]
	then
	        mkdir $mountpoint
	fi
	mount $targetdisk $mountpoint >> "$logpath"

        targetsystem=$(grep "^$systemflag" "$grubpath" | awk -F'[ ()]' '{ORS=" "}NR=='$current'{for(i=2;i<=NF;i++) if($i~/on/) break; else print $i;}')
        #set path of rc.local according to the system type
        case $targetsystem in
        *Ubuntu*|*Debian*)
                nextrcpath="/etc/rc.local"
        ;;
        *)
                nextrcpath="/etc/rc.d/rc.local"
        ;;
        esac

	sed -i -c "/$keyword/d" $mountpoint$nextrcpath
	cat $mountpoint$nextrcpath >> "$logpath"
	umount $mountpoint
done

umount $grubmountpoint

exit 0
