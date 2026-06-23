# 🍎 Hackintosh — Acer Aspire VX5‑591G (macOS Sequoia)

EFI do **OpenCore** + scripts para instalar o **macOS Sequoia 15** no notebook **Acer Aspire VX5‑591G** —
preparando tudo a partir de um **PC com Linux** (ou do próprio macOS), **sem precisar de um Mac**.

> ⚠️ Hackintosh é para **estudo/teste**. Faça por sua conta e risco.

---

## 💻 Hardware testado

| Componente | Detalhe | macOS |
|---|---|---|
| Modelo | Acer Aspire VX5‑591G | ✅ |
| CPU | Intel Core **i7‑7700HQ** (Kaby Lake) | ✅ |
| iGPU | **Intel HD Graphics 630** | ✅ acelerada (Metal 3) |
| GPU dedicada | NVIDIA GTX 1050Ti | ⛔ desligada (sem driver macOS) |
| Áudio | Realtek **ALC255** | ✅ |
| Wi‑Fi | Intel **7265** | ✅ via `itlwm` + app HeliPort |
| Bluetooth / Ethernet | Intel / Realtek RTL8111 | ✅ |
| Tela 15.6" 1080p, teclado, trackpad, brilho | | ✅ |
| **HDMI externo** | ligado à iGPU | ❌ não funciona no Sequoia (limitação Kaby Lake) |

---

## ✅ O que funciona

Gráficos acelerados, áudio, Wi‑Fi (com **HeliPort**), Bluetooth, Ethernet, USB, teclado, trackpad, brilho, iCloud.

⛔ **NÃO atualize para o macOS Tahoe (26)** — ele remove o áudio das placas Intel (ALC255 para de funcionar). **Fique no Sequoia 15.**

---

## 📂 Estrutura do projeto

```
.
├── README.md                ← este arquivo (visão geral + início rápido)
├── EFI/                      ← EFI do OpenCore pronta (gere seu próprio serial — passo 1)
├── scripts/
│   ├── create-usb.sh         ← baixa o macOS + cria o pendrive de instalação (automático)
│   └── gen-smbios.sh         ← gera seu número de série (SMBIOS) próprio
├── docs/
│   └── INSTALACAO.md         ← guia manual detalhado + solução de problemas
└── .gitignore
```

---

## 🚀 Início rápido (scripts)

> Requisitos: **Linux** ou **macOS**, com `git`, `python3`, `curl`, `unzip`.
> No Linux ainda: `sgdisk`, `mkfs.vfat`, `mkfs.exfat`, `wipefs`.

### 1) Gere seu número de série (obrigatório)
A EFI vem **sem serial** (cada Hackintosh precisa de um único):
```bash
./scripts/gen-smbios.sh --inject
```
> Grava `Serial`, `MLB` e `UUID` em `EFI/OC/config.plist`. (O `ROM` = MAC da sua rede é opcional — veja o guia.)

### 2) Crie o pendrive de instalação (apaga o pendrive!)
Descubra o disco do pendrive com `lsblk` (Linux) ou `diskutil list` (macOS) e rode:
```bash
# Linux
sudo ./scripts/create-usb.sh --disk /dev/sdX

# macOS
sudo ./scripts/create-usb.sh --disk /dev/diskN
```
O script **baixa o macOS Sequoia** (BaseSystem + instalador completo), **particiona** o pendrive e **copia** a EFI + instalador. 🪄

Opções úteis:
- `--mode online` → usa só a recuperação (pendrive menor, ≥8GB; instala pela internet)
- `--skip-download` → reaproveita o que já foi baixado em `downloads/`
- `--help` → todas as opções

### 3) Instale
Plugue no Acer → **F2** (BIOS: Secure Boot **OFF**, UEFI) → **F12** → boote pelo pendrive → siga o `LEIA‑PRIMEIRO.txt` que o script deixou no pendrive (ou o **[guia detalhado](docs/INSTALACAO.md)**).

---

## 📖 Guia completo

Passo a passo detalhado (BIOS, download manual, criação do pendrive na mão, instalação, pós‑instalação,
Wi‑Fi, e **solução de problemas**) em **[docs/INSTALACAO.md](docs/INSTALACAO.md)**.

---

## ⚙️ Resumo técnico da EFI

OpenCore **1.0.6** · SMBIOS `MacBookPro14,3` · iGPU HD630 nativa KBL `0x591b0000` · ALC255 layout 99 ·
dGPU desligada (`SSDT-DDGPU`) · Wi‑Fi `itlwm` · Ethernet RTL8111 · `SecureBootModel = Disabled`.
Detalhes completos no [guia](docs/INSTALACAO.md#️-detalhes-técnicos-da-efi).

---

## 🙏 Créditos

- [Acidanthera](https://github.com/acidanthera) — OpenCore, Lilu, WhateverGreen, VirtualSMC
- [OpenIntelWireless](https://github.com/OpenIntelWireless) — `itlwm` + HeliPort
- [OpCore‑Simplify](https://github.com/lzhoang2801/OpCore-Simplify) — geração da EFI
- [corpnewt](https://github.com/corpnewt) — gibMacOS, GenSMBIOS
- [Dortania](https://dortania.github.io/OpenCore-Install-Guide/) — guia de referência

---

## ☕ Support the Project

If this project was useful to you and you'd like to support its development, consider buying me a coffee:

<p align="center">
  <a href="https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=cleyton1986%40gmail.com&currency_code=BRL&item_name=Hackintosh+VX5-591G">
    <img src="https://img.shields.io/badge/PayPal-Donate-00457C?logo=paypal&logoColor=white&style=for-the-badge" alt="Donate via PayPal">
  </a>
</p>

<p align="center">
  <b>PIX (Brazil):</b> <code>cleyton1986@gmail.com</code>
</p>

Any contribution is voluntary and greatly appreciated! It helps keep the project alive and motivates new features.

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.

> Os componentes de terceiros incluídos (OpenCore, Lilu, WhateverGreen e demais kexts) mantêm as suas próprias licenças.

**This software is provided "as is", without warranty of any kind.** Hackintosh é para fins de estudo/teste — use por sua conta e risco.

---

<p align="center">
  <b>Desenvolvido por OctalDev — Cleyton Alves</b> | Senior Software Engineer
</p>

> Feito para o **Acer Aspire VX5‑591G**. Se ajudou, deixe uma ⭐. Hackintosh é para estudo/testes. 🚀
