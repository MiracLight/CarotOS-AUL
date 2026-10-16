# @description CarotOS-AUL: IceWM masaustu paketlerini imaja ekler. Paketler rootfs onbellegine girmez (add_packages_to_image).

function extension_prepare_config__carotos_aul_icewm() {
	display_alert "Extension: ${EXTENSION}: IceWM paketleri ekleniyor" "CarotOS-AUL" "info"
	add_packages_to_image icewm icewm-common
	add_packages_to_image xserver-xorg-core xserver-xorg-input-libinput xinit x11-xserver-utils
	add_packages_to_image fonts-dejavu-core python3-gi gir1.2-gtk-3.0 lxterminal
	# Istek uzerine baslayan yardimcilar: dunst (bildirim, D-Bus ile), lxpolkit (yetki ajani, pkexec sarmalayicisi ile)
	add_packages_to_image dunst lxpolkit pkexec polkitd libnotify-bin gir1.2-notify-0.7 procps dbus-bin
	# Guvenlik cekirdek seti: Guvenlik Paneli ve Poligon ilk acilista calissin. nikto overlay'de (/opt/nikto, /usr/local/bin/nikto).
	# Perl'in kendisi taban imajda var; nikto icin yalnizca su iki modul paketi eksikti (XML::Writer, HTTPS icin Net::SSLeay).
	add_packages_to_image nmap tcpdump ufw libxml-writer-perl libnet-ssleay-perl
}

# Kernel kilidi (6.18 -> 6.18.56). linux-6.18.y dalinin ucu 6.18.57'ye ilerleyince Armbian'in
# rockchip vsi-iommu yamasi derlenmedi (drivers/iommu/vsi-iommu.c: attach_dev imzasi uyusmuyor).
# Framework'un kendi onerdigi yontem: mainline_kernel_decide_version__600 veya ustu kanca.
# Armbian yamayi uyarlayinca (framework guncellenince) bu kilit kaldirilip yeniden denenmeli.
function mainline_kernel_decide_version__600_carotos_aul_kernel_kilidi() {
	[[ "${KERNEL_MAJOR_MINOR}" != "6.18" ]] && return 0 # yalnizca 6.18 icin
	declare -g KERNELBRANCH="tag:v6.18.56"
	display_alert "CarotOS-AUL: kernel sabitlendi" "KERNELBRANCH='${KERNELBRANCH}' (6.18.57 vsi-iommu derleme hatasi)" "info"
}
