# @description CarotOS-AUL: IceWM masaustu paketlerini imaja ekler. Paketler rootfs onbellegine girmez (add_packages_to_image).

function extension_prepare_config__carotos_aul_icewm() {
	display_alert "Extension: ${EXTENSION}: IceWM paketleri ekleniyor" "CarotOS-AUL" "info"
	add_packages_to_image icewm icewm-common
	add_packages_to_image xserver-xorg-core xserver-xorg-input-libinput xinit x11-xserver-utils
	add_packages_to_image fonts-dejavu-core python3-gi gir1.2-gtk-3.0 lxterminal
	# Istek uzerine baslayan yardimcilar: dunst (bildirim, D-Bus ile), lxpolkit (yetki ajani, pkexec sarmalayicisi ile)
	add_packages_to_image dunst lxpolkit pkexec polkitd libnotify-bin gir1.2-notify-0.7 procps dbus-bin
}
