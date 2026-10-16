#!/bin/bash
# CarotOS-AUL: IceWM onizlemesi (dev VM, Xephyr). Depodaki overlay'i kullanir.
# Oturum IZOLE calisir: sahte HOME + sahte IceWM ayar dizini kullanilir; sihirbazin ve uygulamalarin
# yazdigi hicbir sey gercek ~/.config, ~/.xsessionrc ya da sistem ayarlarina gitmez. Cikista hepsi silinir.
R="${AUL_R:-$HOME/carotos-aul/userpatches/overlay/rootfs}"
[ -d "$R/etc/X11/icewm" ] || { echo "HATA: $R/etc/X11/icewm yok"; exit 1; }
T=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/cfg" "$T/share/applications" "$T/home/.config/gtk-3.0"
for f in theme preferences prefoverride toolbar menu; do
	[ -f "$R/etc/X11/icewm/$f" ] || continue
	sed "s#/usr/share/icons/#$R/usr/share/icons/#g; s#/usr/share/carotos-aul/#$R/usr/share/carotos-aul/#g; s#/opt/carotos/#$R/opt/carotos/#g" "$R/etc/X11/icewm/$f" > "$T/cfg/$f"
done
# Gercek startup dosyasindan YALNIZCA sihirbaz blogu alinir (dbus/USB satirlari gercek oturumu etkilerdi).
if [ -f "$R/etc/X11/icewm/startup" ]; then
	{ echo '#!/bin/sh'; sed -n '/^# Karsilama Sihirbazi/,$p' "$R/etc/X11/icewm/startup" | sed "s#/opt/carotos/#$R/opt/carotos/#g"; } > "$T/cfg/startup"
	chmod +x "$T/cfg/startup"
fi
[ -f "$R/etc/gtk-3.0/settings.ini" ] && cp "$R/etc/gtk-3.0/settings.ini" "$T/home/.config/gtk-3.0/settings.ini"
for d in "$R"/usr/share/applications/carotos-*.desktop; do
	sed "s#/opt/carotos/#$R/opt/carotos/#g" "$d" > "$T/share/applications/$(basename "$d")"
done
ln -s "$R/usr/share/icons" "$T/share/icons"
if [ -n "${AUL_DRY:-}" ]; then
	echo "== cfg"; ls "$T/cfg"; echo "== startup"; cat "$T/cfg/startup" 2>/dev/null; echo "== home"; find "$T/home" -type f; echo "== prefoverride"; cat "$T/cfg/prefoverride"; echo "== menu (CarotOS)"; grep -c carotos "$T/cfg/menu"
	exit 0
fi
command -v Xephyr >/dev/null && command -v icewm-session >/dev/null || { echo "HATA: Xephyr veya icewm kurulu degil"; exit 1; }
n=20; while [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n+1)); done
Xephyr ":$n" -screen 1280x720 >/dev/null 2>&1 &
XP=$!
sleep 2
export DISPLAY=":$n"
export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" XDG_DATA_HOME="$T/home/.local/share"
export CAROTOS_WP_DIR="$R/usr/share/carotos-aul/wallpaper" CAROTOS_IMG_DIR="$R/usr/share/carotos/welcome"
XDG_DATA_DIRS="$T/share:/usr/share" ICEWM_PRIVCFG="$T/cfg" icewm-session >/dev/null 2>&1 &
echo "Xephyr :$n acildi. Baslat menusu > CarotOS > Welcome Wizard ile sihirbazi ac."
echo "Bitirince Xephyr penceresini kapat; betik kendiliginden biter ve gecici dosyalar silinir."
wait "$XP"
