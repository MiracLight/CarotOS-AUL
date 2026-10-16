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
Kullanılan armbian/build commit'i: `userpatches/overlay/surum.json` içinde (sürüm, ad ve adresler de oradan okunur; imajda `/usr/share/carotos-aul/surum.json` olarak durur).

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
- Kimlik (adım 1b): `userpatches/overlay/surum.json` tek kaynaktır. Betik buradan `/etc/os-release` (PRETTY_NAME, HOME_URL, SUPPORT_URL, BUG_REPORT_URL, CAROTOS_AUL_VERSION), `/etc/issue`, `/etc/issue.net`, `/etc/carotos-aul-release` (`version=`) ve `/usr/share/carotos-aul/surum.json` dosyalarını yazar ve yazılanı doğrular; tutmazsa build `HATA:` ile durur. Armbian'ın `armbian-base-files` paketi `os-release`'i önbellekteki eski markayla bırakabildiği için bu doğrulama şarttır. `ID=debian` ve `NAME` bilerek değiştirilmez (araçlar Debian bekler). Marka değişkenleri (`VENDOR*`, `MAINTAINER*`) `config-aul-opi5.conf` içindedir.
- Temizlik (adım 2b): betik `/opt` altındaki `__pycache__` ve `*.pyc` kalıntılarını siler; kalırsa `imaj-kontrol.sh` HATA verir.

## Çekirdek kilidi
Çekirdek `6.18.56`'ya sabitlenmiştir: 6.18.57, Armbian'ın `vsi-iommu` yamasını uygulayamıyor ve derleme düşüyor. Kilit, `userpatches/extensions/carotos-aul-icewm.sh` içindeki `mainline_kernel_decide_version__600_*` kancasıdır ve `KERNELBRANCH`'i `tag:v6.18.56` yapar. Sürümü değiştirmek için kancadaki etiketi değiştirin; yeni sürümde yama uyumu önce denenmelidir.

## Güvenlik araçları ve Mağaza kataloğu
- İmaja giren temel güvenlik seti: `nmap tcpdump ufw libxml-writer-perl libnet-ssleay-perl` (extension içinde `add_packages_to_image`; bağımlılıklar hariç yaklaşık 16 MB).
- `nikto` 2.6.1 apt'tan değil overlay'den gelir (`overlay/rootfs/opt/nikto`, `usr/local/bin/nikto`, `etc/nikto.conf`). İstediği Perl modülleri için son iki paket gereklidir.
- Mağaza kataloğu (`overlay/rootfs/opt/carotos/magaza/katalog.json`) AUL'a özeldir: nikto yok; tshark, ufw, fail2ban var. `sync-apps.sh` uygulamaları `MiracLight/carotos` deposundan (v1.2.1 etiketi) çekerken bu dosyayı `KORUNAN` değişkeniyle ezmeden korur. tshark, ufw ve fail2ban için `boyut` değerleri tahmindir.
- `araclar/katalog-kontrol.py`, katalogdaki ve imajın ihtiyaç duyduğu (EKSTRA) paketlerin trixie arm64 deposunda bulunduğunu doğrular.

## İmaj kontrolü
`araclar/imaj-kontrol.sh` en yeni imajı salt okunur bağlar; kimlik, kernel, paketler, overlay, katalog, nikto, locale, sahiplik/kalıntı ve boyutu denetler, qemu varsa chroot içinde nikto'yu gerçekten çalıştırır. Kullanım: `araclar/imaj-kontrol.sh 2>&1 | tee /tmp/imaj-kontrol.txt` (sudo parolası sorar). `AUL_KOK=/yol` verilirse imaj yerine açılmış bir dizini denetler. HATA varsa çıkış kodu sıfırdan farklıdır.
İmaj düzeni: GPT, ext4 kök bölümü 32768. sektörde, ayrı `/boot` yok. Elle bağlamak için: `sudo mount -o ro,loop,offset=$((32768*512)) "$IMG" /mnt/aulimg`.

## Süreler
- İlk derleme (önbellek boş): 41:38 dk. İkinci derleme (önbellek dolu): 2:36 dk. Son derleme (6.18.56, kimlik bloğu dahil): 5:19 dk.

## Bilinen tuzaklar
- `compile.sh build` **sudo ile çalıştırılmaz** (reddedilir). Yalnızca `requirements` sudo ister.
- Yanlışlıkla sudo ile çalıştırılırsa `.tmp`, `output`, `userpatches` root sahipli kalır: `sudo chown -R $USER: /srv/aul/build`.
- Uzun parametreleri terminale yapıştırmak görünmez karakter getirebilir ("Invalid cmdline param"); ayarlar config dosyasında tutulur.
- **Derleme çıktısını `| tail -N` ile süzmeyin.** Rootfs önbelleğini açan `pv` terminalden imleç konumu sorar;
  `tail` çıktıyı tuttuğu için cevap gelmez ve derleme sonsuza kadar takılır. Yalnızca `| tee dosya.log` kullanın.

## Doğrulama durumu
- Derleme: başarılı (Orange Pi 5, trixie, current 6.18.56, minimal CLI, yaklaşık 2,4 GiB imaj; `imaj-kontrol.sh`: 77 OK, 0 HATA, 0 UYARI).
- Özelleştirme ve kimlik: imajda doğrulandı (dosya içi ve qemu chroot).
- Önyükleme: **doğrulanmadı** (kart bekleniyor). Önyükleme doğrulanmadan imaj yayına alınmaz.
- NVMe: **doğrulanmadı.** İmajda `armbian-install` (armbian-config'e yönlendiren sarmalayıcı), `armbian-config` ve `/usr/lib/linux-u-boot-current-orangepi5/` altında iki SPI bootloader görüntüsü bulundu: `u-boot-rockchip-spi.bin` ve `u-boot-rockchip-spi-sata.bin` (NVMe için SATA olmayanı). İlk açılış SD ile yapılacak; SPI'ya yazma ancak SD açılışı doğrulandıktan sonra ve kaynak okunarak yapılacak (yanlış ya da bozuk SPI bootloader kartın açılmasını engelleyebilir; kaynaktan doğrulanacak).
- Açık işler: imaj adındaki `26.11.0-trunk` (Armbian çatısının sürümü); Armbian marka/ToS metninin yayın öncesi yeniden okunması; `apt upgrade` sonrası os-release'in korunup korunmadığı.
