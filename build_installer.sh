#!/bin/sh

. common.subr
. common_start.subr

DFF_VERSION=$(readlink ${VERITAWALL_REPO}/FreeBSD:13:amd64/latest)

IMAGE_TARGET=disc1.iso
IMAGE_NAME=disc1.iso
IMAGE_EXT=.iso

VERITAWALL_PKG_REPODIR="`realpath ${VERITAWALLWRKDIR}`/poudriere-base/data/packages/${FBSD_BRANCH}-${PORT_BRANCH}"

RELEASE_DIR=${MAKEOBJDIRPREFIX}/${FBSD_TREE}/amd64.amd64/release/

create_ports_list() {
	sudo -E poudriere bulk -c -n ${PORT_BULK} -j ${FBSD_BRANCH} -p ${PORT_BRANCH} -O ${OVERLAY_PORTS} VERITAWALL/VERITAWALL lang/python3 | \
		grep 'Ports to build: ' | sed 's/.* Ports to build: //g' | tr ' ' '\n' | grep -v "^$" | \
		sort | while read line; do
			tar -xOf ${VERITAWALL_PKG_REPODIR}/packagesite.txz packagesite.yaml | jq -r "select(.origin | (sub(\"/overlays/${OVERLAY_PORTS}/\"; \"\")) == \"${line}\") | .path"
	done
}

image_name()
{

    echo "VERITAWALL_installer_${1}_${DFF_VERSION}-${date}${IMAGE_SUFFIX}${IMAGE_EXT}"
}

build_installer()
{
    name=`image_name ${1}`
    shift
    opts="$@"

    sudo chflags -R noschg ${RELEASE_DIR}
    sudo rm -rf ${RELEASE_DIR}
    cd ${FBSD_TREE}/release && sudo -E make ${IMAGE_TARGET} WITH_PKGBASE=y REPODIR=${VERITAWALL_REPO} \
				    VERITAWALL_REPODIR=${VERITAWALL_PKG_REPODIR} \
				    PORTSDIR=${PORTSDIR} \
				    NODOC= ${opts}
    mkdir -p ${IMAGE_DIR}/
    cp ${MAKEOBJDIRPREFIX}/${FBSD_TREE}/amd64.amd64/release/${IMAGE_NAME} ${IMAGE_DIR}/${name}

    bzip2 -v -9 ${IMAGE_DIR}/${name}

    cat ${IMAGE_DIR}/${name}.bz2 | sha256 > ${IMAGE_DIR}/${name}.bz2.sha256
}

mkdir -p ${LOGS_DIR}

export VERITAWALL_PORTS_LIST=`create_ports_list`
if [ $? -ne 0 -o -z "${VERITAWALL_PORTS_LIST}" ]; then
	echo "The ports list is empty."
	exit 1
fi

build_installer serial "WITH_SERIAL=yes" 2>&1 | tee -a ${LOGS_DIR}/build_installer.log || exit 1
build_installer vga 2>&1 | tee -a ${LOGS_DIR}/build_installer.log || exit 1

echo "========== BUILD FINISHED ==========="
echo "Serial image:  `image_name serial`.bz2"
echo "Serial sha256: `image_name serial`.bz2.sha256"
echo "VGA image:     `image_name vga`.bz2"
echo "VGA sha256:    `image_name vga`.bz2.sha256"
echo "====================================="
