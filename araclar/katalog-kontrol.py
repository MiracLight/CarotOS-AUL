#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CarotOS-AUL: Magaza katalogundaki paketlerin Debian trixie arm64'te var olup
olmadigini denetler. SALT OKUNUR: yalnizca indeks indirir (onbellek:
~/.cache/carotos-aul/) ve rapor yazar.

Kullanim:
    araclar/katalog-kontrol.py                  indeksi indirir (main contrib non-free)
    araclar/katalog-kontrol.py --indeks DOSYA   hazir bir Packages dosyasi kullanir
    araclar/katalog-kontrol.py --katalog YOL    baska bir katalog.json
"""
import argparse
import json
import lzma
import os
import sys
import urllib.request

VARSAYILAN_KATALOG = os.path.expanduser(
    "~/carotos-aul/userpatches/overlay/rootfs/opt/carotos/magaza/katalog.json")
ONBELLEK = os.path.expanduser("~/.cache/carotos-aul")
TABAN = "https://deb.debian.org/debian/dists/trixie"
BILESENLER = ("main", "contrib", "non-free")
# Katalog disinda, imajin ve uygulamalarin ihtiyac duydugu paketler.
# nikto burada YOK: AUL'da apt'tan degil, overlay'den (/opt/nikto, 2.6.1) gelir;
# onun icin istedigi Perl modulleri (libxml-writer-perl, libnet-ssleay-perl) listede.
EKSTRA = ["nmap", "tcpdump", "tshark", "aircrack-ng", "sqlmap",
          "john", "hydra", "ufw", "fail2ban", "lxterminal", "pcmanfm",
          "libxml-writer-perl", "libnet-ssleay-perl",
          "pkexec", "polkitd", "libnotify-bin", "gir1.2-notify-0.7",
          "python3-gi", "gir1.2-gtk-3.0", "icewm", "dunst", "lxpolkit"]


def indir(bilesen):
    os.makedirs(ONBELLEK, exist_ok=True)
    yol = os.path.join(ONBELLEK, f"Packages-trixie-{bilesen}-arm64.xz")
    url = f"{TABAN}/{bilesen}/binary-arm64/Packages.xz"
    if not os.path.isfile(yol):
        print(f"indiriliyor: {url}", file=sys.stderr)
        with urllib.request.urlopen(url, timeout=120) as r, open(yol, "wb") as f:
            f.write(r.read())
    with lzma.open(yol, "rt", encoding="utf-8", errors="replace") as f:
        return f.read()


def ayristir(metin, bilesen, tablo):
    for blok in metin.split("\n\n"):
        alan = {}
        son = None
        for satir in blok.splitlines():
            if satir[:1] in (" ", "\t") and son:
                alan[son] += " " + satir.strip()
            elif ":" in satir:
                son, _, deger = satir.partition(":")
                alan[son] = deger.strip()
        ad = alan.get("Package")
        if not ad:
            continue
        kayit = {"surum": alan.get("Version", "?"),
                 "boyut_kib": int(alan.get("Installed-Size", "0") or 0),
                 "bilesen": bilesen}
        tablo.setdefault(ad, kayit)
        for p in alan.get("Provides", "").split(","):
            p = p.split("(")[0].strip()
            if p:
                tablo.setdefault(p, dict(kayit, sanal=ad))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--katalog", default=VARSAYILAN_KATALOG)
    ap.add_argument("--indeks", help="hazir Packages (duz metin) dosyasi")
    a = ap.parse_args()

    tablo = {}
    if a.indeks:
        with open(a.indeks, encoding="utf-8", errors="replace") as f:
            ayristir(f.read(), "main", tablo)
    else:
        for b in BILESENLER:
            try:
                ayristir(indir(b), b, tablo)
            except Exception as e:
                print(f"UYARI: {b} indirilemedi: {e}", file=sys.stderr)
    if not tablo:
        print("HATA: hic paket okunamadi (ag erisimi var mi?)")
        return 1
    print(f"indeks: {len(tablo)} paket/sanal ad okundu\n")

    with open(a.katalog, encoding="utf-8") as f:
        kat = json.load(f)
    yok = []
    print("== KATALOG ==")
    for u in kat["uygulamalar"]:
        p = u["paket"]
        k = tablo.get(p)
        if k:
            ek = f" (sanal: {k['sanal']})" if k.get("sanal") else ""
            print(f"OK    {p:20} {k['surum']:24} {k['bilesen']:9} {k['boyut_kib']//1024:5} MB  [{u['kategori']}]{ek}")
        else:
            print(f"YOK   {p:20} [{u['kategori']}]")
            yok.append(p)
    print("\n== EKSTRA (imaj/uygulama gereksinimleri) ==")
    yok2 = []
    for p in EKSTRA:
        k = tablo.get(p)
        if k:
            print(f"OK    {p:20} {k['surum']:24} {k['bilesen']:9} {k['boyut_kib']//1024:5} MB")
        else:
            print(f"YOK   {p}")
            yok2.append(p)
    print(f"\nOZET: katalog {len(kat['uygulamalar'])} paket, yok: {len(yok)} {yok}")
    print(f"      ekstra {len(EKSTRA)} paket, yok: {len(yok2)} {yok2}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
