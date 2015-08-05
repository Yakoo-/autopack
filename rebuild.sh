#!/bin/bash

usage()
{
    echo
    echo "usage: `basename $0` <redhat|sles|debian|ubuntu> version release kernel-build kernel-release"
    echo
    echo "  kernel-build is a directory containing materials necessary for building kernel modules,"
    echo "  typically like /lib/modules/2.6.32-431.el6.x86_64/build/, which is a symbolic link to"
    echo "  /usr/src/kernels/2.6.32-431.el6.x86_64/. this script support both these two format."
    echo
    echo "  kernel-release is what uname -r will give, if not given, script will extract it from kernel-build."
    echo "	/lib/modules/2.6.32-431.el6.x86_64/build/  ===>  the 3rd field, i.e. 2.6.32-431.el6.x86_64"
    echo "	/usr/src/kernels/2.6.32-431.el6.x86_64/ ===> basename of kernel-build, i.e. 2.6.32-431.el6.x86_64"
    echo "	if basename of kernel-build is not equals to the real kernel-release, explicitly specify it."
    echo
    echo "  redhat5|redhat6|redhat7:(stand for Redhat, CentOS, Fedora, OEL distributions)"
    echo "	if no kernel-build directory is given, will iterate in /usr/src/kernels/"
    echo "  sles11|sles12:"
    echo "	if no kernel-build directory is given, will iterate in /lib/modules/*-default/build"
    echo "	if kernel-build is not given as /lib/modules/*-default/build, must give kernel-release,"
    echo "	since basename of kernel-build alway is not equals to the kernel-release we need on sles11."
    echo "  debian6|debian7|debian8:"
    echo "	if no kernel-build directory is given, will iterate in /usr/src/linux-headers-*-amd64/"
    echo "  ubuntu10.04|ubuntu12.04|ubuntu14.04:"
    echo "	if no kernel-build directory is given, will iterate in /usr/src/linux-headers-*-generic"
    echo "	or /usr/src/linux-headers-*-server."
    echo
}

check_rpm_build()
{
    # check rpmbuild
    rpmbuild --version 2> /dev/null 1>/dev/null
    if [ $? -ne 0 ]
    then
	echo "rpmbuild not installed, please run "yum install rpm-build" to install"
	exit 1
    fi

    # check soure rpms
    if [ ! -e ${srcrpm} ]
    then
	    echo "${srcrpm} doesnt exsit!"
	    exit 1
    fi

    if [ ! -e ${utilssrcrpm} ]
    then
	    echo "${utilssrcrpm} doesnt exsit!"
	    exit 1
    fi
}

banner_start()
{
    echo
    echo "

#######  #######  #######  #######  #######  #######

"
    echo
}

rebuild_redhat()
{
    check_rpm_build

    mkdir -p ${top_dir}/$command

    if [ -d ${top_dir}/$command ]
    then
	echo "work directory: ${top_dir}/$command"
    else
	echo
	echo "failed to create work directory: ${top_dir}/$command"
	exit 1
    fi


    if [ "x$kerneldir" == "x" ]
    then
	# This only works under redhat/centos.
	for kerneldir in /usr/src/kernels/*
	do
	    kernelname=`basename ${kerneldir}`
	    kernelname=${kernelname%-x86_64*}

	    banner_start
	    echo "Now rebuild for $kernelname"
	    echo "kernel build: ${kerneldir}"
	    echo
	    rpmbuild --rebuild --define "rpm_kernel_version ${kernelname}" --define "kdir ${kerneldir}" ${srcrpm} | tee tmp

	    if [ $? -ne 0 ]
	    then
		echo "rpmbuild --rebuild failed!!!!!!"
		exit 1
	    fi
	    cmdline=`cat tmp | grep Wrote`
	    binrpm=${cmdline#Wrote: }
	    #echo ${binrpm}
	    cp -f ${binrpm} ${top_dir}/$command/
	    echo
	    echo "####### Success: rebuild a binary rpm package `basename ${binrpm}` #######"
	done
    else
	if [ "x$kernelname" == "x" ]
	then
	    if [ `basename ${kerneldir}` == "build" ]
	    then
		kernelname=`echo ${kerneldir} | awk -F/ '{print $4}'`
	    else
		kernelname=`basename ${kerneldir}`
		kernelname=${kernelname#linux-headers-}
	    fi
	fi
	banner_start
	echo "Now rebuild for $kernelname"
	echo "kernel build: ${kerneldir}"
	echo
	rpmbuild --rebuild --define "rpm_kernel_version ${kernelname}" --define "kdir ${kerneldir}" ${srcrpm} | tee tmp

	if [ $? -ne 0 ]
	then
	    echo "rpmbuild --rebuild failed!!!!!!"
	    exit 1
	fi
	cmdline=`cat tmp | grep Wrote`
	binrpm=${cmdline#Wrote: }
	#echo ${binrpm}
	cp -f ${binrpm} ${top_dir}/$command/
	echo "####### Success: rebuild a binary rpm package `basename ${binrpm}` #######"
    fi

    # copy source rpm and utils bin rpm to directory
    cp -f ${srcrpm} ${top_dir}/$command/
    cp -f ${utilsrpm} ${top_dir}/$command/

    if [[ -e tmp ]]
    then
	rm -rf tmp
    fi
}

rebuild_sles()
{
    check_rpm_build

    mkdir -p ${top_dir}/$command

    if [ -d ${top_dir}/$command ]
    then
	echo "work directory: ${top_dir}/$command"
    else
	echo
	echo "failed to create work directory: ${top_dir}/$command"
	exit 1
    fi


    if [ "x$kerneldir" == "x" ]
    then
	# This works under sles11.
	for kerneldir in /lib/modules/*-default/build/
	do
	    kernelname=`echo ${kerneldir} | awk -F/ '{print $4}'`

	    banner_start
	    echo "Now rebuild for $kernelname"
	    echo "kernel build: ${kerneldir}"
	    echo
	    rpmbuild --rebuild --define "rpm_kernel_version ${kernelname}" --define "kdir ${kerneldir}" ${srcrpm} | tee tmp

	    if [ $? -ne 0 ]
	    then
		echo "rpmbuild --rebuild failed!!!!!!"
		exit 1
	    fi
	    cmdline=`cat tmp | grep Wrote`
	    binrpm=${cmdline#Wrote: }
	    #echo ${binrpm}
	    cp -f ${binrpm} ${top_dir}/$command/
	    echo "####### Success: rebuild a binary rpm package `basename ${binrpm}` #######"

	done
    else
	if [ "x$kernelname" == "x" ]
	then
	    if [ `basename ${kerneldir}` == "build" ]
	    then
		kernelname=`echo ${kerneldir} | awk -F/ '{print $4}'`
	    else
		kernelname=`basename ${kerneldir}`
		kernelname=${kernelname#linux-headers-}
	    fi
	fi
	banner_start
	echo "Now rebuild for $kernelname"
	echo "kernel build: ${kerneldir}"
	echo
	rpmbuild --rebuild --define "rpm_kernel_version ${kernelname}" --define "kdir ${kerneldir}" ${srcrpm} | tee tmp

	if [ $? -ne 0 ]
	then
	    echo "rpmbuild --rebuild failed!!!!!!"
	    exit 1
	fi
	cmdline=`cat tmp | grep Wrote`
	binrpm=${cmdline#Wrote: }
	#echo ${binrpm}
	cp -f ${binrpm} ${top_dir}/$command/
	echo "####### Success: rebuild a binary rpm package `basename ${binrpm}` #######"
    fi

    # copy source rpm and utils bin rpm to directory
    cp -f ${srcrpm} ${top_dir}/$command/
    cp -f ${utilsrpm} ${top_dir}/$command/

    if [[ -e tmp ]]
    then
	rm -rf tmp
    fi

    echo "All Done!"
}

check_deb_build()
{
    dpkg-buildpackage --version 2> /dev/null 1>/dev/null
    if [ $? -ne 0 ]
    then
	echo "dpkg-buildpackage not installed, please run "apt-get install dpkg-dev" to install"
	exit 1
    fi

    if [ ! -d ${sourcedir} ]
    then
	echo "could not find ${sourcedir}!"
	exit 1
    fi


    if [ ! -d ${modulesrc} ]
    then
	echo "could not find ${modulesrc}!"
	exit 1
    fi

    if [ ! -d ${utilssrc} ]
    then
	echo "could not find ${utilssrc}!"
	exit 1
    fi
}

rebuild_deb()
{
    check_deb_build

    mkdir -p ${top_dir}/$command

    if [ -d ${top_dir}/$command ]
    then
	echo "work directory: ${top_dir}/$command"
    else
	echo
	echo "failed to create work directory: ${top_dir}/$command"
	exit 1
    fi


    if [ "x$kerneldir" == "x" ]
    then
	# This only works under ubuntu/debian.
	for kerneldir in /usr/src/linux-headers-*
	do
	    if [[ "x$(echo $kerneldir | grep "server")" == "x" && "x$(echo $kerneldir | grep "generic")" == "x"  && "x$(echo $kerneldir | grep "amd64")" == "x" ]]
	    then
		echo
		echo "skipping $kerneldir"
		echo
		continue
	    fi
	    kernelname=`basename ${kerneldir}`
	    kernelname=${kernelname#linux-headers-}

	    banner_start
	    echo "Now rebuild for $kernelname"
	    echo "kernel build: ${kerneldir}"
	    echo

	    previous=`pwd`
	    cd $sourcedir

	    sed -i "s/^deb_kernel_version ?=.*/deb_kernel_version ?= ${kernelname}/" debian/rules
	    sed -i "s#^deb_kernel_src :=.*#deb_kernel_src := ${kerneldir}#" debian/rules 
	    dpkg-buildpackage -us -uc

	    if [ $? -ne 0 ]
	    then
		echo "dpkg-buildpackage failed!!!"
		exit 1
	    fi

	    cd ..

	    deb_target=$(ls shannon-module-${kernelname}*.deb)
	    mv -f $deb_target $command

	    echo "####### Success: rebuild a binary deb package $deb_target #######"

	    cd $previous
	done
    else
	if [ "x$kernelname" == "x" ]
	then
	    if [ `basename ${kerneldir}` == "build" ]
	    then
		kernelname=`echo ${kerneldir} | awk -F/ '{print $4}'`
	    else
		kernelname=`basename ${kerneldir}`
		kernelname=${kernelname#linux-headers-}
	    fi
	fi

	banner_start
	echo "Now rebuild for $kernelname"
	echo "kernel build: ${kerneldir}"
	echo

	previous=`pwd`
	cd $sourcedir
	sed -i "s/^deb_kernel_version ?=.*/deb_kernel_version ?= ${kernelname}/" debian/rules
	sed -i "s#^deb_kernel_src :=.*#deb_kernel_src := ${kerneldir}#" debian/rules 
	dpkg-buildpackage -us -uc

	if [ $? -ne 0 ]
	then
	    echo "dpkg-buildpackage failed!!!"
	    exit 1
	fi

	cd ..

	deb_target=$(ls shannon-module-${kernelname}*.deb)
	mv -f $deb_target $command

	echo "####### Success: rebuild a binary deb package $deb_target #######"

	cd $previous
    fi

    # build shannon-utils deb
    echo
    echo "generating shannon-utils deb..."
    echo
    cd $previous

    cd $utilssrc
    dpkg-buildpackage -us -uc

    if [ $? -ne 0 ]
    then
	echo "dpkg-buildpackage failed!!!"
	exit 1
    fi

    cd ..

    utils_deb_target=$(ls shannon-utils*.deb)
    mv -f $utils_deb_target ../$command

    echo "####### Success: shannon-utils deb package $utils_deb_target #######"

    cd $previous

    echo "All Done!"

}

check_args()
{
	version=$1
	shift
	release=$1
	shift

	top_dir=Shannon_Linux_Driver_${version}.${release}
	srcrpm=${top_dir}/shannon-module-${version}-${release}.src.rpm
	utilssrcrpm=${top_dir}/shannon-utilities-${version}-${release}.src.rpm
	utilsrpm=${top_dir}/shannon-utils-${version}-${release}.x86_64.rpm
	sourcedir=${top_dir}/source/
	modulesrc=${top_dir}/source/shannon-module_${version}.${release}
	utilssrc=${top_dir}/source/shannon-utils_${version}.${release}

	if [ ! -e ${top_dir} ]
	then
		echo
		echo "${top_dir} doesnt exsit!"
		exit 1
	fi

	echo
	echo "Checking arguments:"
	echo "command: $command"
	echo "version: $version"
	echo "release: $release"
	if [ $# -eq 1 ]
	then
		kerneldir=$1
		echo "kernel-build: ${kerneldir}"
	elif [ $# -eq 2 ]
	then
		kerneldir=$1
		kernelname=$2
		echo "kernel-build: ${kerneldir}"
		echo "kernel-release: $kernelname"
	fi
	echo
}



#Start from here!
  ####    #####    ##    #####    #####
 #          #     #  #   #    #     #
  ####      #    #    #  #    #     #
      #     #    ######  #####      #
 #    #     #    #    #  #   #      #
  ####      #    #    #  #    #     #

command=$1

shift

case $command in
    "redhat5" | "redhat6" | "redhat7")
	check_args $*
	rebuild_redhat
	;;
    "sles11" | "sles12")
	check_args $*
	rebuild_sles
	;;
    "debian6" | "debian7" | "debian8")
	check_args $*
	rebuild_deb
	;;
    "ubuntu10.04" | "ubuntu12.04" | "ubuntu14.04")
	check_args $*
	rebuild_deb
	;;
    *)
	usage
	exit 1
	;;
esac
