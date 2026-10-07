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

# Overlay'i root:root sahipligiyle kurar.
# "cp -a" KULLANILMAZ: ana makinedeki sahipligi (uid 1000) ve dizin izinlerini
# imajin / /etc /usr dizinlerine tasir (guvenlik hatasi, build 4'te yakalandi).
# HEDEF yalnizca testler icindir; imaj build'inde bos kalir.
overlay_kur() {
	local kok=/tmp/overlay/rootfs f d m
	( cd "$kok" && find . -mindepth 1 -type d -print0 ) | while IFS= read -r -d '' d; do
		[ -d "${HEDEF:-}/$d" ] || install -d -o root -g root -m 755 "${HEDEF:-}/$d"
	done
	( cd "$kok" && find . -type f -print0 ) | while IFS= read -r -d '' f; do
		if [ -x "$kok/$f" ]; then m=755; else m=644; fi
		install -D -o root -g root -m "$m" "$kok/$f" "${HEDEF:-}/$f"
	done
	( cd "$kok" && find . -type l -print0 ) | while IFS= read -r -d '' f; do
		cp -P --no-preserve=ownership "$kok/$f" "${HEDEF:-}/$f"
	done
	# Dogrulama: temel dizinler ve overlay dosyalari root:root olmali, yoksa build basarisiz olur
	for d in / /etc /usr /usr/share; do
		[ "$(stat -c %U:%G "${HEDEF:-}$d")" = "root:root" ] || { echo "HATA: $d root:root degil" >&2; exit 1; }
	done
	( cd "$kok" && find . -type f -print0 ) | while IFS= read -r -d '' f; do
		[ "$(stat -c %U:%G "${HEDEF:-}/$f")" = "root:root" ] || { echo "HATA: /$f root:root degil" >&2; exit 1; }
	done
}

# Armbian build'i bazi dosyalari "cp -p" ile kopyalar (/boot/boot.cmd, /boot/armbianEnv.txt)
# ve build ana makinesindeki sahipligi (uid 1000) tasir. Imajda build sirasinda bu uid'e ait
# bir kullanici yoktur; ilk acilista olusan ilk kullanici uid 1000 alacagi icin bu dosyalar
# o kullaniciya ait olurdu. Burada root:root yapilir ve kalan olmadigi dogrulanir.
sahiplik_temizle() {
	local d n dizinler=()
	for d in /boot /etc /usr /var /opt /root; do
		if [ -d "${HEDEF:-}$d" ]; then dizinler+=("${HEDEF:-}$d"); fi
	done
	n=$(find "${dizinler[@]}" -xdev \( -uid 1000 -o -gid 1000 \) -print | wc -l)
	echo "sahiplik_temizle: uid/gid 1000 olan $n oge root:root yapiliyor"
	find "${dizinler[@]}" -xdev \( -uid 1000 -o -gid 1000 \) -exec chown -h root:root {} +
	n=$(find "${dizinler[@]}" -xdev \( -uid 1000 -o -gid 1000 \) -print | wc -l)
	[ "$n" = "0" ] || { echo "HATA: uid/gid 1000 olan $n oge kaldi" >&2; exit 1; }
}

Main() {
	# 1) Surum isaretcisi
	printf 'CarotOS-AUL\nrelease=%s\nboard=%s\nfamily=%s\narch=%s\ndesktop=%s\n' \
		"$RELEASE" "$BOARD" "$LINUXFAMILY" "$ARCH" "$BUILD_DESKTOP" > /etc/carotos-aul-release
	chmod 644 /etc/carotos-aul-release

	# 2) overlay/rootfs altindaki her sey imajin kokune kopyalanir
	if [ -d /tmp/overlay/rootfs ]; then
		overlay_kur
	fi

	# 3) Armbian'in tasidigi build ana makinesi sahipligini temizle
	sahiplik_temizle
} # Main

Main "$@"
