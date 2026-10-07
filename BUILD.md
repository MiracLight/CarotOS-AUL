# Derleme notlari

## Gereksinimler (Armbian belgesine gore)
- En az 8 GB bellek, yaklasik 50 GB bos disk. Gelistirme VM'inde 8 GB RAM ve ayri 80 GB disk (`/srv/aul`) kullanildi.
- Docker (`sudo apt install -y docker.io docker-buildx`) ve kullanicinin `docker` grubunda olmasi.

## Kurulum (dogrulandi)
```
sudo mkdir -p /srv/aul   # ayri diske bagli, sahibi derleme kullanicisi olmali
cd /srv/aul && git clone --depth=1 --branch=main https://github.com/armbian/build
cd build && sudo ./compile.sh requirements
sudo usermod -aG docker $USER   # sonra yeni oturum
```
Kullanilan armbian/build commit'i: `surum.json` icinde.

## Derleme (dogrulandi)
`userpatches/config-aul-opi5.conf` dosyasi `/srv/aul/build/userpatches/` altina konur, sonra:
```
cd /srv/aul/build && ./compile.sh aul-opi5 build
```
Cikti: `output/images/`. Bu depodaki `userpatches/` klasorunun build'e baglanma yontemi
(`USERPATCHES_PATH`) henuz **denenmedi**.

## Bilinen tuzaklar
- `compile.sh build` **sudo ile calistirilmaz** (reddedilir). Yalnizca `requirements` sudo ister.
- Yanlislikla sudo ile calistirilirsa `.tmp`, `output`, `userpatches` root sahipli kalir: `sudo chown -R $USER: /srv/aul/build`.
- Uzun parametreleri terminale yapistirmak gorunmez karakter getirebilir ("Invalid cmdline param"); ayarlar config dosyasinda tutulur.

## Dogrulama durumu
- Derleme: basarili (Orange Pi 5, trixie, current 6.18.55, minimal CLI, 1,8 GB imaj, sha256 tamam).
- Onyukleme / NVMe: **dogrulanmadi.** Kartla ilk test edilecek konu (mainline U-Boot, SPI/NVMe senaryosu).
