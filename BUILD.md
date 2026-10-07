# Derleme notları

## Gereksinimler (Armbian belgesine göre)
- En az 8 GB bellek, yaklaşık 50 GB boş disk. Geliştirme VM'inde 8 GB RAM ve ayrı 80 GB disk (`/srv/aul`) kullanıldı.
- Docker (`sudo apt install -y docker.io docker-buildx`) ve kullanıcının `docker` grubunda olması.

## Kurulum (doğrulandı)
```
sudo mkdir -p /srv/aul   # ayrı diske bağlı, sahibi derleme kullanıcısı olmalı
cd /srv/aul && git clone --depth=1 --branch=main https://github.com/armbian/build
cd build && sudo ./compile.sh requirements
sudo usermod -aG docker $USER   # sonra yeni oturum
```
Kullanılan armbian/build commit'i: `surum.json` içinde.

## Derleme (doğrulandı)
`userpatches/` altındaki dosyalar `/srv/aul/build/userpatches/` altına kopyalanır
(`config-aul-opi5.conf`, `customize-image.sh`, `overlay/`), sonra:
```
cd /srv/aul/build && ./compile.sh aul-opi5 build 2>&1 | tee /srv/aul/derleme.log
```
Çıktı: `output/images/`. Bu depodaki `userpatches/` klasörünün doğrudan build'e bağlanması
(`USERPATCHES_PATH`) henüz **denenmedi**; şimdilik dosyalar elle kopyalanıyor.

## Özelleştirme mekanizması (doğrulandı)
- `customize-image.sh` imajın içinde chroot olarak çalışır; argümanlar: `RELEASE LINUXFAMILY BOARD BUILD_DESKTOP ARCH`.
- `userpatches/overlay/` imaj içinde `/tmp/overlay` olarak salt okunur bağlanır; kopyalamayı betik yapar.
- Betik `/etc/carotos-aul-release` işaretçisini yazar ve `overlay/rootfs/` içeriğini imajın köküne kopyalar.
- İşaretçideki `family` değeri `rockchip64` çıktı (board dosyasındaki `BOARDFAMILY` değeri değil).

## Süreler
- İlk derleme (önbellek boş): 41:38 dk. İkinci derleme (önbellek dolu): 2:36 dk.

## Bilinen tuzaklar
- `compile.sh build` **sudo ile çalıştırılmaz** (reddedilir). Yalnızca `requirements` sudo ister.
- Yanlışlıkla sudo ile çalıştırılırsa `.tmp`, `output`, `userpatches` root sahipli kalır: `sudo chown -R $USER: /srv/aul/build`.
- Uzun parametreleri terminale yapıştırmak görünmez karakter getirebilir ("Invalid cmdline param"); ayarlar config dosyasında tutulur.
- **Derleme çıktısını `| tail -N` ile süzmeyin.** Rootfs önbelleğini açan `pv` terminalden imleç konumu sorar;
  `tail` çıktıyı tuttuğu için cevap gelmez ve derleme sonsuza kadar takılır. Yalnızca `| tee dosya.log` kullanın.

## Doğrulama durumu
- Derleme: başarılı (Orange Pi 5, trixie, current 6.18.55, minimal CLI, 1,8 GB imaj, sha256 tamam).
- Özelleştirme: başarılı (işaretçi ve overlay dosyası imajda görüldü).
- Önyükleme / NVMe: **doğrulanmadı.** Kartla ilk test edilecek konu (mainline U-Boot, SPI/NVMe senaryosu).
