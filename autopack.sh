#!/bin/bash


# check root privilege
if [[ $UID -ne 0 ]]
then
	echo "This script needs root privilege !" 
	echo "" 
	exit 1
fi

usage()
{
    echo
    echo "Usage: ${scriptname} version release driver-source utils-source [release-path]" 
    echo 
    echo "e.g. ${scriptname} 2.8 2 /home/git/liunx/drivers/block/shannon/ /home/git/shannon-utils/ /home/git/autorelease/"
    echo
}

mount_disk()
{
    case $1 in
	"u")
	umount $2 
	;;
	"m")
	if [ ! -d $3 ]
	then
	    mkdir -p $3
	fi
	mount $2 $3
	;;
    esac
}

set_params()
{

    # set parameter of boot partion and mount it 
    grubfilepath="/boot/grub2/grub.cfg"
    bootpart="/dev/sda1"
    bootmountpoint="/mnt/bootdisk"
    grubpath=${bootmountpoint}${grubfilepath}
    mount_disk m ${bootpart} ${bootmountpoint} 
    
    # get total system number by counting menuentries in grub.cfg
    # get current system number from grub.cfg
    bootnumflag="set default"
    systemflag="menuentry"
    totalsyscnt=$(grep "^${systemflag}" "${grubpath}" | wc -l)
    cursysnum=$(grep "${bootnumflag}" "${grubpath}" | awk -F ' |=' '$1~/^set/{if($3~/^[0-9]+$/) print $3;}')
    echo "total system count: ${totalsyscnt}; current system number: ${cursysnum}" >> ${logpath}


    # check if this is the first time run this script
    if [ -f "${backuppath}" ]
    then
	firstrun="no"
	workpath=$(awk 'NR==2{print $1}' ${backuppath})
	((nextsysnum = cursysnum + 1))
    else
	firstrun="yes"
	workpath=$(pwd)
	echo ${cursysnum} >> ${backuppath}
	echo ${workpath} >> ${backuppath}
	echo "This is the first time you run this script" >> ${logpath}
	((nextsysnum = 0))
    fi
    echo "work path: ${workpath}" >> ${logpath}
    echo "next system number: ${nextsysnum}" >> ${logpath}

    # check if this is the last time run this script
    if [ ${nextsysnum} -eq ${totalsyscnt} ]
    then
	lastrun="yes"
	# restore grub.cfg
	nextsysnum=$(head -1 ${backuppath})
	rm -f ${backuppath}
	echo "This is the last time you run this script" >> ${logpath}
	echo "next system number: ${nextsysnum}" >> ${logpath}
    fi
    

    #edit grub.cfg for reboot
    sed -i "/^${bootnumflag}/c ${bootnumflag}=${nextsysnum}" "${grubpath}"

    # set release path, default is the current work path
    if [ ! ${releasepath} ]
    then
	releasepath=${workpath}
    fi
    scriptpath="${workpath}/${scriptname}"
    echo "releasepath: ${releasepath}" >> ${logpath}
    
    # get some infomation of current system
    distributorid=$(lsb_release -a | grep "Distributor" | awk '{print $3}')
    sysrelease=$(lsb_release -a | grep "Release" | awk '{print $2}')
    syskernel=$(uname -r)
    #generate distribution path, rc.local path of current system and  kernel-build path accroding to distributorid and sysrelease
    case ${distributorid} in
	"CentOS"|"Fedora")
	distribution="redhat${sysrelease%%.*}"
	kernelpath="/lib/modules/${syskernel}/build"
	currcpath="/etc/rc.d/rc.local"
	;;
	"SUSE")
	distribution="sles${sysrelease%%.*}"
	kernelpath="/lib/modules/${syskernel}-default/build"
	currcpath="/etc/rc.d/rc.local"
	;;
	"Debian")
	distribution="debian${sysrelease%%.*}"
	kernelpath="/usr/src/linux-headers-${syskernel}-amd64"
	currcpath="/etc/rc.local"
	;;
	"Ubuntu")
	distribution="ubuntu${sysrelease}"
	kernelpath="/usr/src/linux-headers-${syskernel}-generic"
	currcpath="/etc/rc.local"
	;;
	"Oracle*")
	distribution="oracle${sysrelease}"
	kernelpath=""
	currcpath="/etc/rc.d/rc.local"
	;;
    esac
    ###
    echo "distribution: ${distribution}" >> ${logpath}

    # delete startup on current system
    sed -i "/${scriptname}/d" "${currcpath}"
}


get_args()
{
    if [ $# -eq 4 -o $# -eq 5 ]
    then
	version=$1
	release=$2
	driverpath=$3
	utilspath=$4
        if [ $# -eq 5 ]
        then
	    releasepath=$5
	    if [ ! -d ${releasepath} ]
	    then
		echo
		echo "ERROR: ${releasepath} is not exist!"
		echo
		exit 1
	    fi
        fi
    else	    
	usage
	exit 1
    fi

    if [ ! -d ${driverpath} ]
    then
	echo
	echo "ERROR: ${driverpath} is not exist!"
	echo
	exit 1
    fi
 
    if [ ! -d ${utilspath} ]
    then
	echo
	echo "ERROR: ${utilspath} is not exist!"
	echo
	exit 1
    fi

    echo >> ${logpath}
    echo "$(date)" >> ${logpath}
}

add_startup()
{
    if [ ! "x${lastrun}" == "xyes" ]
    then
	fsmountpoint="/mnt/tempmount"
	((sysnuminawk = ${nextsysnum} + 1))
	nextbootdisk=$(grep "^$systemflag" "${grubpath}" | awk -F'[ ()]' 'NR=='${sysnuminawk}'{for(i=1;i<=NF;i++) if($i~/dev/) print $i}')
	mount_disk m ${nextbootdisk} ${fsmountpoint} 

	nextsystem=$(grep "^$systemflag" "${grubpath}" | awk -F'[ ()]' '{ORS=" "}NR=='${sysnuminawk}'{for(i=2;i<=NF;i++) if($i~/on/) break; else print $i;}')

	echo "next boot disk: ${nextbootdisk}; next system: ${nextsystem}" >> ${logpath}
	#set path of rc.local according to the system type and edit it
	case ${nextsystem} in 
	*Ubuntu*|*Debian*)
		nextrcpath="/etc/rc.local"
		sed -i "/^exit/i ${scriptpath} ${version} ${release} ${driverpath} ${utilspath} ${releasepath}" "$fsmountpoint$nextrcpath"
	;;
	*CentOS*|*SUSE*|*Oracle*)
		nextrcpath="/etc/rc.d/rc.local"
		echo "${scriptpath} ${version} ${release} ${driverpath} ${utilspath} ${releasepath}" >> "$fsmountpoint$nextrcpath"
	;;
	esac
	echo "nextrcpath: ${nextrcpath}" >> ${logpath}
	chmod 755 "$fsmountpoint$nextrcpath"
    else
	# delete startup on all systems
        ${workpath}/cleanstartup.sh
	echo "pack.sh ${version} ${release}" >> ${logpath}
	${releasepath}/pack.sh ${version} ${release}
    fi
}

do_pack()
{
    cd ${releasepath}
    if [ "x${firstrun}" == "xyes" ] 
    then
	echo "./driver.sh all ${version} ${release} ${driverpath} ${utilspath} yes" >> ${logpath}
	./driver.sh all ${version} ${release} ${driverpath} ${utilspath} yes
	echo "Finished driver.sh on ${distribution}" >> ${logpath}
    else
	echo "./rebuild.sh ${distribution} ${version} ${release}" >> ${logpath}
	./rebuild.sh ${distribution} ${version} ${release}
	echo "Finished rebuild.sh on ${distribution}" >> ${logpath}
    fi
}

##########################################################################################
# start point
##########################################################################################
scriptname=$(basename $0)
logpath="/home/packlog"
backuppath="/home/backup_for_autopack"
get_args $*
set_params 
do_pack
add_startup 

mount_disk u ${fsmountpoint}
mount_disk u ${bootmountpoint}

echo "Ready to reboot" >> ${logpath}
reboot

exit 0
