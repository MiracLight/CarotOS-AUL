#!/bin/bash
# CarotOS-AUL: CarotOS uygulamalarini, etiketi (tag) sabitlenmis kaynaktan overlay'e kopyalar.
# Kullanim: ./sync-apps.sh        (depo kokunden)
# Kaynak ve surum asagida TEK yerde tutulur. Surum degistirmek icin yalnizca KAYNAK_TAG degisir.
# Not: Poligon'un v1.2.1 kopyasi, Poligon deposunun guncel hali ile birebir ayniydi (2026-10-13'te dogrulandi).
set -euo pipefail

KAYNAK_DEPO="${SYNC_KAYNAK_DEPO:-https://github.com/MiracLight/carotos.git}"
KAYNAK_TAG="v1.2.1"
# Karsilama Sihirbazi (welcome) bilerek yok: XFCE kodu IceWM icin yeniden yazilacak.
UYGULAMALAR="health security-panel usb magaza poligon"
# config/includes.chroot'a gore, uygulama disindaki dosyalar:
DOSYALAR="
usr/share/applications/carotos-health.desktop
usr/share/applications/carotos-security-panel.desktop
usr/share/applications/carotos-usb-check.desktop
usr/share/applications/carotos-magaza.desktop
usr/share/applications/carotos-poligon-ogrenci.desktop
usr/share/applications/carotos-poligon-ogretmen.desktop
usr/share/icons/carotos/security-panel-icon.png
usr/share/icons/hicolor/256x256/apps/carotos-security-panel.png
usr/share/icons/hicolor/256x256/apps/carotos-poligon-ogrenci.png
usr/share/icons/hicolor/256x256/apps/carotos-poligon-ogretmen.png
usr/share/pixmaps/carotos-magaza.png
"

KOK="$(cd "$(dirname "$0")" && pwd)"
HEDEF="$KOK/userpatches/overlay/rootfs"
[ -d "$HEDEF" ] || { echo "HATA: $HEDEF yok - betik depo kokunde mi?"; exit 1; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$KAYNAK_TAG" "$KAYNAK_DEPO" "$T/src"
GERCEK_TAG="$(git -C "$T/src" describe --tags --exact-match 2>/dev/null || true)"
[ "$GERCEK_TAG" = "$KAYNAK_TAG" ] || { echo "HATA: alinan surum '$GERCEK_TAG', beklenen '$KAYNAK_TAG'"; exit 1; }
SHA="$(git -C "$T/src" rev-parse HEAD)"
SRC="$T/src/config/includes.chroot"
[ -d "$SRC/opt/carotos" ] || { echo "HATA: kaynakta config/includes.chroot/opt/carotos yok"; exit 1; }

# --- once hepsini dogrula, sonra kopyala ---
for a in $UYGULAMALAR; do
	[ -d "$SRC/opt/carotos/$a" ] || { echo "HATA: kaynakta uygulama yok: $a"; exit 1; }
done
for f in $DOSYALAR; do
	[ -f "$SRC/$f" ] || { echo "HATA: kaynakta dosya yok: $f"; exit 1; }
done

for a in $UYGULAMALAR; do
	rm -rf "${HEDEF:?}/opt/carotos/$a"
	install -d "$HEDEF/opt/carotos"
	cp -a --no-preserve=ownership "$SRC/opt/carotos/$a" "$HEDEF/opt/carotos/$a"
	# imaja girmemesi gerekenler
	find "$HEDEF/opt/carotos/$a" \( -name '__pycache__' -o -name '*.pyc' -o -name 'test_*.py' -o -name '.gitignore' \) -prune -exec rm -rf {} +
done
for f in $DOSYALAR; do
	install -d "$HEDEF/$(dirname "$f")"
	cp -a --no-preserve=ownership "$SRC/$f" "$HEDEF/$f"
done

# kaynak kaydi (hangi surumden geldigi imajda gorunsun)
install -d "$HEDEF/usr/share/carotos-aul"
{
	echo "kaynak: $KAYNAK_DEPO"
	echo "tag: $KAYNAK_TAG"
	echo "commit: $SHA"
	echo "uygulamalar: $UYGULAMALAR"
} > "$HEDEF/usr/share/carotos-aul/uygulamalar-kaynak.txt"

# --- kontrol ---
hata=0
for a in $UYGULAMALAR; do
	n=$(find "$HEDEF/opt/carotos/$a" -name '*.py' | wc -l)
	echo "$a: $n .py dosyasi"
	while IFS= read -r p; do
		python3 -I -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$p" || { echo "SOZDIZIMI HATASI: $p"; hata=1; }
	done < <(find "$HEDEF/opt/carotos/$a" -name '*.py')
done
kalan=$(find "$HEDEF/opt/carotos" \( -name '__pycache__' -o -name '*.pyc' -o -name 'test_*' \) | wc -l)
[ "$kalan" -eq 0 ] || { echo "HATA: test/pyc kalintisi var: $kalan"; hata=1; }
# .desktop dosyalarinin Exec hedefi imajda olacak mi
for d in "$HEDEF"/usr/share/applications/carotos-*.desktop; do
	e=$(sed -n 's/^Exec=//p' "$d" | head -1)
	yol=$(echo "$e" | tr ' ' '\n' | grep '^/opt/' | head -1)
	[ -f "$HEDEF$yol" ] || { echo "HATA: $(basename "$d") Exec hedefi yok: $yol"; hata=1; }
	case "$e" in /opt/*) [ -x "$HEDEF$yol" ] || { echo "HATA: $(basename "$d") dogrudan calistirilir ama +x degil: $yol"; hata=1; } ;; esac
done
[ "$hata" -eq 0 ] || { echo "SENKRON BASARISIZ"; exit 1; }
echo "tamam: $KAYNAK_TAG ($SHA)"
