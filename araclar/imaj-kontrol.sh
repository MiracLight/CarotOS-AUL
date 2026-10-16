#!/bin/bash
# CarotOS-AUL imaj kontrolu (SALT OKUNUR: imaji ro baglar, hicbir sey yazmaz).
# Kullanim:  araclar/imaj-kontrol.sh [imaj.img]
#            (imaj verilmezse /srv/aul/build/output/images altindaki en yeni .img)
# AUL_KOK=/yol  ->  imaj baglanmaz, o dizin imaj koku sayilir (test icin).
set -u

S_OK=0; S_HATA=0; S_UYARI=0
ok()    { S_OK=$((S_OK+1));       printf '  [OK]    %s\n' "$*"; }
hata()  { S_HATA=$((S_HATA+1));   printf '  [HATA]  %s\n' "$*"; }
uyari() { S_UYARI=$((S_UYARI+1)); printf '  [UYARI] %s\n' "$*"; }
bilgi() { printf '  [..]    %s\n' "$*"; }
baslik() { printf '\n== %s ==\n' "$*"; }

if [ -n "${AUL_KOK:-}" ]; then
	M="$AUL_KOK"; SUDO=""
	[ -d "$M" ] || { echo "HATA: AUL_KOK dizin degil: $M"; exit 2; }
else
	SUDO="sudo"
	IMG="${1:-$(ls -t /srv/aul/build/output/images/*.img 2>/dev/null | head -1)}"
	[ -n "$IMG" ] && [ -f "$IMG" ] || { echo "HATA: imaj bulunamadi (arguman verin)"; exit 2; }
	echo "imaj: $IMG"
	BAS=$(sfdisk -d "$IMG" 2>/dev/null | sed -n 's/.*start= *\([0-9][0-9]*\),.*/\1/p' | head -1)
	if [ -z "$BAS" ]; then BAS=32768; echo "UYARI: bolum baslangici okunamadi, 32768 varsayildi"; fi
	M=$(mktemp -d /tmp/aulimg.XXXXXX)
	$SUDO mount -o ro,loop,offset=$((BAS*512)) "$IMG" "$M" || { rmdir "$M"; echo "HATA: imaj baglanamadi"; exit 2; }
	trap '$SUDO umount "$M/dev" 2>/dev/null; $SUDO umount "$M" 2>/dev/null; rmdir "$M" 2>/dev/null' EXIT
fi

var()  { [ -e "$M$1" ] && ok "var: $1" || hata "YOK: $1"; }
calis(){ if [ -f "$M$1" ] && [ -x "$M$1" ]; then ok "calistirilabilir: $1"; else hata "yok ya da +x degil: $1"; fi; }
root() { local s; s=$(stat -c %u:%g "$M$1" 2>/dev/null); [ "$s" = "0:0" ] && ok "root:root: $1" || hata "sahiplik $s (beklenen 0:0): $1"; }

baslik "Surum ve kernel"
if [ -f "$M/etc/carotos-aul-release" ]; then
	ok "/etc/carotos-aul-release"; sed 's/^/        /' "$M/etc/carotos-aul-release"
else hata "YOK: /etc/carotos-aul-release"; fi
if [ -L "$M/boot/uInitrd" ]; then
	bilgi "uInitrd -> $(readlink "$M/boot/uInitrd")"
else uyari "/boot/uInitrd bag yok"; fi
bilgi "kernel dosyalari: $(ls "$M"/boot 2>/dev/null | grep -E '^(vmlinuz|Image|uInitrd|dtb)' | tr '\n' ' ')"
for f in /boot/boot.cmd /boot/armbianEnv.txt; do var "$f"; done

baslik "Paketler (dpkg durumu)"
DQ() { dpkg-query --admindir="$M/var/lib/dpkg" "$@" 2>/dev/null; }
for p in icewm xinit xserver-xorg-core xserver-xorg-input-libinput python3-gi gir1.2-gtk-3.0 \
         lxterminal dunst lxpolkit pkexec polkitd perl \
         nmap tcpdump ufw libxml-writer-perl libnet-ssleay-perl; do
	d=$(DQ -W -f='${db:Status-Abbrev}' "$p")
	case "$d" in ii*) ok "kurulu: $p";; *) hata "kurulu degil: $p";; esac
done
bilgi "guvenlik seti kurulum boyutu (KB, bagimliliklar dahil degil):"
for p in nmap tcpdump ufw iptables libxml-writer-perl libnet-ssleay-perl; do
	printf '        %-22s %s\n' "$p" "$(DQ -W -f='${Installed-Size}' "$p")"
done

baslik "Overlay dosyalari"
for f in /opt/carotos/welcome/carotos-welcome.py /opt/carotos/health /opt/carotos/security-panel \
         /opt/carotos/usb /opt/carotos/magaza /opt/carotos/poligon; do var "$f"; done
calis /opt/carotos/welcome/carotos-welcome.py
for n in 1 2 3; do var "/usr/share/carotos-aul/wallpaper/carotos-wallpaper-$n.jpg"; done
for n in logo magaza panel poligon usb; do var "/usr/share/carotos/welcome/$n.png"; done
for f in menu toolbar prefoverride startup; do var "/etc/X11/icewm/$f"; done
var /etc/gtk-3.0/settings.ini
var /etc/profile.d/carotos-aul-startx.sh
var /usr/share/applications/carotos-welcome.desktop
var /usr/local/bin/pkexec
if grep -q 'carotos-welcome.py --autostart' "$M/etc/X11/icewm/startup" 2>/dev/null; then ok "startup: sihirbaz --autostart blogu var"; else hata "startup: sihirbaz blogu yok"; fi
if grep -q 'prefer-dark-theme=1' "$M/etc/gtk-3.0/settings.ini" 2>/dev/null; then ok "gtk koyu tema ayari"; else hata "gtk koyu tema ayari yok"; fi

baslik "Magaza katalogu"
KAT="$M/opt/carotos/magaza/katalog.json"
if [ -f "$KAT" ]; then
	python3 -I - "$KAT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
liste = d["uygulamalar"] if isinstance(d, dict) and "uygulamalar" in d else d
if isinstance(liste, dict):
    liste = next(v for v in liste.values() if isinstance(v, list))
paketler = [u["paket"] for u in liste]
def s(durum, m): print("  [%s] %s" % (durum, m))
s("OK" if len(paketler) == len(set(paketler)) else "HATA", "%d paket, tekrar yok" % len(paketler) if len(paketler) == len(set(paketler)) else "tekrar eden paket var")
s("OK" if "nikto" not in paketler else "HATA", "nikto katalogda degil (imajda gomulu)" if "nikto" not in paketler else "nikto hala katalogda")
for p in ("tshark", "ufw", "fail2ban"):
    s("OK" if p in paketler else "HATA", ("katalogda: " + p) if p in paketler else ("katalogda YOK: " + p))
PY
else hata "YOK: katalog.json"; fi

baslik "nikto (imaja gomulu, 2.6.1)"
calis /opt/nikto/program/nikto.pl
calis /usr/local/bin/nikto
var /etc/nikto.conf
for f in /opt/nikto /usr/local/bin/nikto /etc/nikto.conf /opt/nikto/program/nikto.pl; do root "$f"; done
for k in EXECDIR PLUGINDIR DBDIR TEMPLATEDIR; do
	if grep -q "^$k=/opt/nikto/program" "$M/etc/nikto.conf" 2>/dev/null; then ok "nikto.conf: $k"; else hata "nikto.conf: $k yok ya da yolu yanlis"; fi
done
bilgi "nikto'nun istedigi Perl modulleri dosya olarak:"
modul() {  # $1=gorunen ad, $2=Yol/Dosya.pm
	if find "$M/usr/share/perl" "$M/usr/share/perl5" "$M/usr/lib" -path "*/$2" 2>/dev/null | grep -q .; then ok "perl modulu: $1"; else hata "perl modulu YOK: $1"; fi
}
modul "Time::Piece"   "Time/Piece.pm"
modul "Time::Seconds" "Time/Seconds.pm"
modul "JSON::PP"      "JSON/PP.pm"
modul "Net::hostent"  "Net/hostent.pm"
modul "XML::Writer"   "XML/Writer.pm"
modul "Net::SSLeay"   "Net/SSLeay.pm"

baslik "Locale"
if grep -qE '^tr_TR\.UTF-8 UTF-8' "$M/etc/locale.gen" 2>/dev/null; then ok "locale.gen: tr_TR.UTF-8 acik"; else hata "locale.gen: tr_TR.UTF-8 kapali"; fi
if [ -f "$M/usr/lib/locale/locale-archive" ] && grep -a -q 'tr_TR' "$M/usr/lib/locale/locale-archive"; then ok "locale-archive icinde tr_TR var"
elif ls -d "$M"/usr/lib/locale/tr_TR* >/dev/null 2>&1; then ok "tr_TR locale dizini var"
else hata "tr_TR locale uretilmemis"; fi

baslik "Sahiplik ve kalintilar"
D=""; for d in /boot /etc /usr /var /opt /root; do [ -d "$M$d" ] && D="$D $M$d"; done
n=$($SUDO find $D -xdev \( -uid 1000 -o -gid 1000 \) 2>/dev/null | wc -l)
[ "$n" = "0" ] && ok "uid/gid 1000 olan oge yok" || hata "uid/gid 1000 olan $n oge var"
n=$(find "$M/opt/carotos" "$M/opt/nikto" \( -name '__pycache__' -o -name '*.pyc' -o -name 'test_*' \) 2>/dev/null | wc -l)
if [ "$n" = "0" ]; then ok "pycache/test kalintisi yok"
else
	hata "pycache/test kalintisi: $n (ilk 10):"
	find "$M/opt/carotos" "$M/opt/nikto" \( -name '__pycache__' -o -name '*.pyc' -o -name 'test_*' \) 2>/dev/null | head -10 | sed "s|^$M|        |"
fi

baslik "Boyut"
bilgi "kok dosya sistemi: $(df -h --output=used,size,pcent "$M" 2>/dev/null | tail -1)"
bilgi "/usr/share/locale: $(du -sh "$M/usr/share/locale" 2>/dev/null | cut -f1)    /opt/nikto: $(du -sh "$M/opt/nikto" 2>/dev/null | cut -f1)"

baslik "Gercek calistirma (en iyi gayret: qemu-aarch64 gerekir)"
if [ -n "${AUL_KOK:-}" ]; then
	bilgi "AUL_KOK modunda atlandi"
elif [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
	# chroot'ta /dev yok; perl /dev/null'a ihtiyac duyar. Salt okunur imajin /dev dizinine host /dev baglanir.
	if $SUDO mount --bind /dev "$M/dev"; then
		cikti=$(timeout 180 $SUDO chroot "$M" /usr/bin/perl -e 'use Time::Piece; use Time::Seconds; use JSON::PP; use Net::hostent; use XML::Writer; use POSIX; use Time::HiRes; use IO::Socket; print "MODULLER_OK\n"' 2>&1)
		case "$cikti" in *MODULLER_OK*) ok "chroot: nikto'nun perl modulleri yuklenebiliyor";; *) hata "chroot: modul yuklenemedi: $cikti";; esac
		cikti=$(timeout 180 $SUDO chroot "$M" /usr/local/bin/nikto -Version 2>&1 | head -5)
		case "$cikti" in *"Nikto 2.6.1"*) ok "chroot: nikto -Version: $(echo "$cikti" | head -1)";; *) hata "chroot: nikto -Version beklenen ciktiyi vermedi: $cikti";; esac
		$SUDO umount "$M/dev" 2>/dev/null
	else
		uyari "/dev baglanamadi, gercek calistirma atlandi"
	fi
else
	uyari "qemu-aarch64 binfmt yok, gercek calistirma atlandi"
fi

printf '\nOZET: %d OK, %d HATA, %d UYARI\n' "$S_OK" "$S_HATA" "$S_UYARI"
[ "$S_HATA" -eq 0 ]
