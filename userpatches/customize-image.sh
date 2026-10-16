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

	# 1b) Kimlik: userpatches/overlay/surum.json TEK kaynaktir. Armbian'in base-files paketi /etc/os-release'i
	# onbellekteki eski markayla birakabiliyor (2026-10-16'da yakalandi), bu yuzden kimlik burada yazilir
	# ve dogrulanir. ID=debian ve NAME bilerek degistirilmez (araclar Debian bekler).
	SURUM_JSON="${OVERLAY_KOK:-/tmp/overlay}/surum.json"
	[ -f "$SURUM_JSON" ] || { echo "HATA: surum.json yok: $SURUM_JSON" >&2; exit 1; }
	surum_oku() { python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1],encoding="utf-8"))[sys.argv[2]])' "$SURUM_JSON" "$1"; }
	K_AD=$(surum_oku ad); K_SURUM=$(surum_oku surum); K_URL=$(surum_oku url)
	K_DESTEK=$(surum_oku destek_url); K_HATA=$(surum_oku hata_url)
	for v in K_AD K_SURUM K_URL K_DESTEK K_HATA; do
		[ -n "${!v}" ] || { echo "HATA: surum.json: $v bos" >&2; exit 1; }
	done
	K_PRETTY="$K_AD $K_SURUM ($RELEASE)"
	OSR="${HEDEF:-}/etc/os-release"
	sed -i -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"$K_PRETTY\"|" \
		-e "s|^ARMBIAN_PRETTY_NAME=.*|ARMBIAN_PRETTY_NAME=\"$K_PRETTY\"|" \
		-e "s|^HOME_URL=.*|HOME_URL=\"$K_URL\"|" \
		-e "s|^SUPPORT_URL=.*|SUPPORT_URL=\"$K_DESTEK\"|" \
		-e "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"$K_HATA\"|" \
		-e "s|^CAROTOS_AUL_VERSION=.*|CAROTOS_AUL_VERSION=\"$K_SURUM\"|" "$OSR"
	grep -q '^CAROTOS_AUL_VERSION=' "$OSR" || printf 'CAROTOS_AUL_VERSION="%s"\n' "$K_SURUM" >> "$OSR"
	printf '%s %s \\l\n\n' "$K_AD" "$K_SURUM" > "${HEDEF:-}/etc/issue"
	printf '%s %s\n' "$K_AD" "$K_SURUM" > "${HEDEF:-}/etc/issue.net"
	printf 'version=%s\n' "$K_SURUM" >> "${HEDEF:-}/etc/carotos-aul-release"
	install -D -m 644 "$SURUM_JSON" "${HEDEF:-}/usr/share/carotos-aul/surum.json"
	grep -qx "PRETTY_NAME=\"$K_PRETTY\"" "$OSR" || { echo "HATA: os-release PRETTY_NAME yazilamadi" >&2; exit 1; }
	grep -qx "CAROTOS_AUL_VERSION=\"$K_SURUM\"" "$OSR" || { echo "HATA: os-release CAROTOS_AUL_VERSION yazilamadi" >&2; exit 1; }
	grep -qx "HOME_URL=\"$K_URL\"" "$OSR" || { echo "HATA: os-release HOME_URL yazilamadi" >&2; exit 1; }

	# 2) overlay/rootfs altindaki her sey imajin kokune kopyalanir
	if [ -d /tmp/overlay/rootfs ]; then
		overlay_kur
	fi

	# 2b) Python bayt kodu onbellegi imaja girmez (userpatches VM'de calistirilinca olusabiliyor).
	# Kalirsa build basarisiz olur.
	find "${HEDEF:-}/opt" \( -name '__pycache__' -o -name '*.pyc' \) -prune -exec rm -rf {} + 2>/dev/null || true
	n=$(find "${HEDEF:-}/opt" \( -name '__pycache__' -o -name '*.pyc' \) 2>/dev/null | wc -l)
	[ "$n" = "0" ] || { echo "HATA: /opt altinda $n bayt kodu kalintisi kaldi" >&2; exit 1; }

	# 3) Turkce locale (Karsilama Sihirbazi Turkce secimi icin). Varsayilan dil
	# en_US kalir; tr_TR yalnizca kullanici secerse ~/.xsessionrc ile devreye girer.
	# Uretilemezse build basarisiz olur (sessizce calismayan bir secenek olmasin).
	sed -i 's/^# *\(tr_TR\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
	locale-gen
	locale -a | grep -qi '^tr_TR\.utf-\?8$' || { echo "HATA: tr_TR.UTF-8 uretilemedi" >&2; exit 1; }

	# 4) Armbian'in tasidigi build ana makinesi sahipligini temizle
	sahiplik_temizle
} # Main

Main "$@"
