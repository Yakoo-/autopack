#!/bin/bash

####Shannon System driver release script####


check_rpmbuild()
{
    # check rpmbuild
    rpmbuild --version 2> /dev/null 1>/dev/null
    if [ $? -ne 0 ]
    then
	echo "rpmbuild not installed, please run "yum install rpm-build" to install"
	exit 1
    fi
}

usage()
{
    echo
    echo "usage: `basename $0` <all|source> version release driver-source utils-source [yestoall]"
    echo "	 or `basename $0` <rpm> version release"
    echo "	    source: prepare source tarball and setup environment for rpm build"
    echo "	    rpm:    rpmbuild, must setup environment before this step"
    echo "	    all:    source + rpm"
    echo
    echo "e.g. driver.sh all 2.2 0 /git/linux/drivers/block/shannon/ /git/shannon-utils/"
    echo
}

# prepare driver source tarball
build_source()
{
    # Remove old one
    if [ -e ${top_dir}/source ]
    then
	if [ "x${allyes}" == "xtrue" ]
	then
	    answer=Y
	else
	    read -n1 -p "WARN: ${top_dir}/source exists,  Do you want to overwrite [Y/N]? " answer
	fi
	case $answer in
	    Y|y)
		echo
		;;
	    N|n)
		echo "Canceled"
		exit 1
		;;
	    *)
		echo "Error choice"
		exit 1
		;;
	esac
	rm -rf ${top_dir}/source
    fi

    mkdir -p ${top_dir}/source


    if [ -e ${driver_source} ]
    then
	rm -rf ${driver_source}
    fi


    cp -r ${driver} ${driver_source}

    make -C ${driver_source} clean
    make -C ${driver_source}
    if [ $? -ne 0 ]
    then
	echo "make failed!!!!!!"
	exit 1
    fi

    rm -rf ${driver_source}/shannon_512.c
    rm -rf ${driver_source}/shannon_buffer.c
    rm -rf ${driver_source}/shannon_debug.c
    rm -rf ${driver_source}/shannon_dna.c
    rm -rf ${driver_source}/shannon_ftl.c
    rm -rf ${driver_source}/shannon.h
    rm -rf ${driver_source}/shannon_ioctl.c
    rm -rf ${driver_source}/shannon_ioctl.h
    rm -rf ${driver_source}/shannon_main.c
    rm -rf ${driver_source}/shannon_mbr.h
    rm -rf ${driver_source}/shannon_microcode.c
    rm -rf ${driver_source}/shannon_regs.h
    rm -rf ${driver_source}/shannon_sysfs_core.c
    rm -rf ${driver_source}/shannon_nor.c


    strip -g -S -d ${driver_source}/shannon_main.o
    strip -g -S -d ${driver_source}/shannon_ftl.o
    strip -g -S -d ${driver_source}/shannon_ioctl.o

    mv ${driver_source}/shannon_main.o ${driver_source}/shannon_main.o_shipped
    mv ${driver_source}/shannon_ftl.o ${driver_source}/shannon_ftl.o_shipped
    mv ${driver_source}/shannon_ioctl.o ${driver_source}/shannon_ioctl.o_shipped
    rm ${driver_source}/*emu*

    make -C ${driver_source} clean

    if [ -e ${driver_source}.tar.gz ]
    then
	rm ${driver_source}.tar.gz
    fi

    tar zcf ${driver_source}.tar.gz ${driver_source}/

    # prepare shannon-utils source tarball

    if [ -e ${utils_source} ]
    then
	rm -rf ${utils_source}
    fi

    cp -r ${utils} ${utils_source}

    make -C ${utils_source} purge
    make -C ${utils_source}

    if [ $? -ne 0 ]
    then
	echo "make failed!!!!!!"
	exit 1
    fi

    rm -rf ${utils_source}/*.h
    rm -rf ${utils_source}/*.c
    rm -rf ${utils_source}/.git*
    rm -rf ${utils_source}/shannon-attach
    rm -rf ${utils_source}/shannon-detach
    rm -rf ${utils_source}/shannon-status
    rm -rf ${utils_source}/shannon-format
    rm -rf ${utils_source}/shannon-beacon
    rm -rf ${utils_source}/shannon-firmwareupdate
    sed -i "s/^shannon-utils *(.*)/shannon-utils (${version}.${release})/" ${utils_source}/debian/changelog

    strip -g -S -d ${utils_source}/*.o

    sed -i "/HEADERS/d" ${utils_source}/Makefile
    sed -i "/common.h/d" ${utils_source}/Makefile

    if [ -e ${utils_source}.tar.gz ]
    then
	rm ${utils_source}.tar.gz
    fi

    tar zcf ${utils_source}.tar.gz ${utils_source}

    mv ${driver_source} ${top_dir}/source/
    mv ${utils_source} ${top_dir}/source/
    mv ${driver_source}.tar.gz ${top_dir}
    mv ${utils_source}.tar.gz ${top_dir}

    # change version number in debian/changelog debian/rules
    cp -r debian ${top_dir}/source

    sed -i "s/^shannon_version.*/shannon_version := ${version}.${release}/" ${top_dir}/source/debian/rules
    sed -i "s/^shannon *(.*)/shannon (${version}.${release})/" ${top_dir}/source/debian/changelog

    cp -r spec/shannon-driver.spec ${top_dir}/
    cp -r spec/shannon-utils.spec ${top_dir}/
    # sed version and release number in spec file
    sed -i "/%define sh_version/c\
	%define sh_version	${version}" ${top_dir}/shannon-driver.spec
    sed -i "/%define sh_release/c\
	%define sh_release	${release}" ${top_dir}/shannon-driver.spec

    sed -i "/%define sh_version/c\
	%define sh_version	${version}" ${top_dir}/shannon-utils.spec
    sed -i "/%define sh_release/c\
	%define sh_release	${release}" ${top_dir}/shannon-utils.spec

    rm -rf ${top_dir}/${source_tarball}
    cp -r ${top_dir}/source ${top_dir}/${source_tarball}

    previous=`pwd`
    cd ${top_dir}

    rm -rf ${source_tarball}.tar.gz
    tar czf ${source_tarball}.tar.gz ${source_tarball}
    rm -rf ${source_tarball}

    cd ${previous}

    echo
    echo "Prepare clean source directory...done"
    echo
}


build_rpm()
{
    # copy source tarball to the directory required by spec
    # we use /tmp/shannon-build as topdir. if not exist, create them.

    topdir=/tmp/shannon-build

    if [ -e ${topdir} ]
    then
	rm -rf ${topdir}
    fi

    echo
    echo "Workspace: ${top_dir}"
    echo

    if [ ! -e ${top_dir}/${driver_source}.tar.gz ]
    then
	echo
	echo "Cannot find ${top_dir}/${driver_source}.tar.gz"
	echo "Please run ./driver.sh source at first."
	echo
	exit 1
    fi

    if [ ! -e ${top_dir}/${utils_source}.tar.gz ]
    then
	echo
	echo "Cannot find ${top_dir}/${utils_source}.tar.gz"
	echo "Please run ./driver.sh source at first."
	echo
	exit 1
    fi

    mkdir -p ${topdir}/{BUILD,RPMS/x86_64,RPMS/i386,SOURCES,SPECS,SRPMS}

    cp ${top_dir}/${driver_source}.tar.gz ${topdir}/SOURCES/
    cp ${top_dir}/${utils_source}.tar.gz ${topdir}/SOURCES/

    # rpmbuild driver
    rpmbuild --define "_topdir /tmp/shannon-build" -ba ${top_dir}/shannon-driver.spec
    if [ $? -ne 0 ]
    then
	echo "rpmbuild failed!!!!!!"
	exit 1
    fi

    # rpmbuild utils
    rpmbuild --define "_topdir /tmp/shannon-build" -ba ${top_dir}/shannon-utils.spec
    if [ $? -ne 0 ]
    then
	echo "rpmbuild failed!!!!!!"
	exit 1
    fi

    # copy generated rpms to rpms/ directory
    cp -f ${topdir}/RPMS/x86_64/*.rpm ${top_dir}/
    #cp -f ${topdir}/RPMS/i386/*.rpm rpm/
    cp -f ${topdir}/SRPMS/*.rpm ${top_dir}/

    echo "All work done!"
}

# Retired
<<EOF
package()
{
    if [ $# -eq 2 ]
    then
	version=$1
	release=$2
    else
	usage
	exit 1
    fi

    rm -rf Shannon_Linux_Driver_${version}.${release}
    mkdir -p Shannon_Linux_Driver_${version}.${release} 

    cp -r rpm Shannon_Linux_Driver_${version}.${release} 
    cp -r deb Shannon_Linux_Driver_${version}.${release}
    cp -r source Shannon_Linux_Driver_${version}.${release} 

    tar czf Shannon_Linux_Driver_${version}.${release}.tar.gz Shannon_Linux_Driver_${version}.${release} 

    mv Shannon_Linux_Driver_${version}.${release}.tar.gz package/

    echo
    echo "Pacakge Shannon_Linux_Driver_${version}.${release}.tar.gz is packed up"
    echo
}
EOF

# Retired
<<EOF
build_deb()
{
    if [ $# -eq 2 ]
    then
	version=$1
	release=$2
    else
	usage
	exit 1
    fi

    if [ ! -e source/shannon_${version}.${release}.tar.gz ]
    then
	echo
	echo "Cannot find source/shannon_${version}.${release}.tar.gz"
	echo "Please run driver.sh source at first."
	echo
	exit 1
    fi
    # change version number in debian/changelog debian/rules
    sed -i "s/^shannon_version.*/shannon_version := ${version}.${release}/" source/debian/rules
    sed -i "s/^shannon *(.*)/shannon (${version}.${release})/" source/debian/changelog

    cd source
    dpgk-buildpackage -us -uc

    cp -f *.deb deb/

    echo
    echo "Deb build finished."
    echo
}
EOF

# read command line arguments and parse them
get_args_rpm()
{
    if [ $# -eq 2 ]
    then
	version=$1
	release=$2
    else
	usage
	exit 1
    fi

    # echo arguments read
    echo
    echo "Shannon System driver release script"
    echo
    echo "Version Number: ${version} Release Number: ${release}"
    echo "Command: $command"
    echo

    # continue or abort
    if [ "x${allyes}" == "xtrue" ]
    then
	answer=Y
    else
	read -n1 -p "Do you want to continue [Y/N]? " answer
    fi
    case $answer in
	Y|y)
	echo
	;;
	N|n)
	echo "Canceled"
	exit 1
	;;
	*)
	echo "Error choice"
	exit 1
	;;
    esac

    top_dir=Shannon_Linux_Driver_${version}.${release}
    driver_source=shannon-module_${version}.${release}
    utils_source=shannon-utils_${version}.${release}
    source_tarball=shannon-source_${version}.${release}

}

get_args()
{
    if [ $# -eq 4 -o $# -eq 5 ]
    then
	version=$1
	release=$2
	driver=$3
	utils=$4
        if [ $# -eq 5 ]
        then
	    case $5 in
	    Y|y|Yes|yes)
            allyes=true
	    ;;
	    *)
	    allyes=false
	    ;;
	    esac
        fi
    else	    
	usage
	exit 1
    fi

    # echo arguments read
    echo
    echo "Shannon System driver release script"
    echo
    echo "Version Number: ${version} Release Number: ${release}"
    echo "Command: $command Source: ${driver} ${utils}"
    echo

    # continue or abort
    if [ "x${allyes}" == "xtrue" ]
    then
	answer=Y
    else
	read -n1 -p "Do you want to continue [Y/N]? " answer
    fi
    case $answer in
	Y|y)
	echo
	;;
	N|n)
	echo "Canceled"
	exit 1
	;;
	*)
	echo "Error choice"
	exit 1
	;;
    esac

    top_dir=Shannon_Linux_Driver_${version}.${release}
    driver_source=shannon-module_${version}.${release}
    utils_source=shannon-utils_${version}.${release}
    source_tarball=shannon-source_${version}.${release}

}

# Start from here!
  ####    #####    ##    #####    #####
 #          #     #  #   #    #     #
  ####      #    #    #  #    #     #
      #     #    ######  #####      #
 #    #     #    #    #  #   #      #
  ####      #    #    #  #    #     #

command=$1
shift

case $command in
    "source")
	get_args $*
	build_source
	;;
    "rpm")
	get_args_rpm $*
	check_rpmbuild
#	build_source
	build_rpm
	;;
    "all")
	get_args $*
	check_rpmbuild
	build_source
	build_rpm
	;;
#    "pack")
#	package $*
#	;;
#    "deb")
#	build_deb $*
#	;;
    *)
	echo "Error choice"
	usage
	exit 1
	;;
esac
