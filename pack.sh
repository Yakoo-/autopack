#!/bin/bash

usage()
{
    echo
    echo "usage: `basename $0` version release"
    echo
}

if [ $# -eq 2 ]
then
    version=$1
    release=$2
else
    usage
    exit 1
fi


top_dir=Shannon_Linux_Driver_${version}.${release}

package=Shannon_Linux_Driver_Package_${version}.${release}

if [ ! -e ${top_dir} ]
then
    echo "${top_dir} doesnt exist!"
    exit 1
fi

rm -rf ${package}
rm -rf ${package}.tar.gz

mkdir -p ${package}

cp -r ${top_dir}/redhat5 ${package}
cp -r ${top_dir}/redhat6 ${package}
cp -r ${top_dir}/redhat7 ${package}
cp -r ${top_dir}/debian6 ${package}
cp -r ${top_dir}/debian7 ${package}
cp -r ${top_dir}/debian8 ${package}
cp -r ${top_dir}/sles11  ${package}
cp -r ${top_dir}/sles12  ${package}
cp -r ${top_dir}/ubuntu10.04  ${package}
cp -r ${top_dir}/ubuntu12.04  ${package}
cp -r ${top_dir}/ubuntu14.04  ${package}
cp ${top_dir}/shannon-source_${version}.${release}.tar.gz ${package}

tar czf ${package}.tar.gz ${package}

rm -rf ${package}

echo
echo "Package: ${package}.tar.gz"
echo

echo "ALL DONE!"
