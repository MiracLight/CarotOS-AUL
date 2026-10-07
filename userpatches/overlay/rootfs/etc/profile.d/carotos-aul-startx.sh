# CarotOS-AUL: tty1'de root olmayan bir kullanıcı giriş yapınca IceWM oturumunu başlat.
# - root'a dokunmaz (Armbian ilk açılış sihirbazı root ile çalışır)
# - SSH ve diğer konsollarda (tty2...) çalışmaz: tty2'de her zaman X'siz kabuk vardır
# - X çökerse exec kullanılmadığı için kabuğa düşülür (hata ayıklama için)
case $- in
    *i*)
        if [ -z "$DISPLAY" ] && [ "$(id -u)" != "0" ] && [ "$(tty 2>/dev/null)" = "/dev/tty1" ] \
            && [ -x /usr/bin/startx ] && [ -x /usr/bin/icewm-session ]; then
            /usr/bin/startx /usr/bin/icewm-session -- -nolisten tcp vt1
        fi
        ;;
esac
