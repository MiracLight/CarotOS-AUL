#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP $ARCH
# CarotOS-AUL imaj ozellestirme betigi. Imajin icinde, chroot ortaminda calisir.
# userpatches/overlay ana makinede /tmp/overlay olarak (salt okunur) baglanir.

set -e

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4
ARCH=$5

Main() {
	# 1) Surum isaretcisi
	printf 'CarotOS-AUL\nrelease=%s\nboard=%s\nfamily=%s\narch=%s\ndesktop=%s\n' \
		"$RELEASE" "$BOARD" "$LINUXFAMILY" "$ARCH" "$BUILD_DESKTOP" > /etc/carotos-aul-release
	chmod 644 /etc/carotos-aul-release

	# 2) overlay/rootfs altindaki her sey imajin kokune kopyalanir
	if [ -d /tmp/overlay/rootfs ]; then
		cp -a /tmp/overlay/rootfs/. /
	fi
} # Main

Main "$@"
