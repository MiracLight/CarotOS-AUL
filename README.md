# CarotOS-AUL

**CarotOS-AUL** (Armbian Ultra Light), CarotProject ailesinin ikinci işletim sistemidir.
Armbian altyapısı üzerine kurulu, Debian 13 "trixie" tabanlı, arm64 SBC'ler için hafif bir
siber güvenlik eğitimi dağıtımıdır. İlk hedef kart: **Orange Pi 5 (RK3588S, 8 GB)**.

CarotDeck (cyberdeck donanımı) ayrı ve daha sonraki bir projedir; AUL bu cihazla sınırlı değildir.

## Durum

| | |
|---|---|
| Derleme hattı | Çalışıyor (ilk derleme 41:38 dk, önbellekli ikinci derleme 2:36 dk) |
| Özelleştirme (`customize-image.sh` + overlay) | Doğrulandı: işaretçi ve overlay dosyası imajın içinde görüldü |
| Önyükleme testi | **Yapılmadı** (kart henüz yok) |
| Yayınlanmış imaj | **Yok.** Gerçek donanımda önyüklenmeden imaj yayınlanmaz. |

Ayrıntılar için `BUILD.md` dosyasına bakın. Lisans henüz belirlenmedi.
