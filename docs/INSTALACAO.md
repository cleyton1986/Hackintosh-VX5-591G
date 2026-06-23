# 📖 Instalação manual — passo a passo detalhado

Guia completo para instalar o **macOS Sequoia 15** no **Acer Aspire VX5‑591G** (OpenCore), preparando tudo a
partir de um **PC com Linux** (sem precisar de Mac). Para o caminho automático, veja o [README](../README.md).

> ⚠️ Faça por sua conta e risco. O disco de instalação será apagado.

---

## 1. Ajustar a BIOS (Insyde)

Entre na BIOS (**F2**) e ajuste:
- **Secure Boot** → **Disabled**. *(Alguns Insyde exigem definir uma "Supervisor Password" antes; depois pode remover.)*
- **Boot Mode** → **UEFI**.
- Salve (**F10**). A tecla **F12** abre o menu de boot.

---

## 2. Gerar seu próprio número de série (SMBIOS)

A EFI vem **sem serial** (por segurança). Cada instalação precisa de um **único**.

**Jeito fácil (script deste repo):**
```bash
./scripts/gen-smbios.sh --inject
```
Isso gera e grava `SystemSerialNumber`, `MLB` e `SystemUUID` em `EFI/OC/config.plist`.

**Jeito manual (GenSMBIOS):**
```bash
git clone https://github.com/corpnewt/GenSMBIOS.git
cd GenSMBIOS && ./GenSMBIOS.command   # gere para o modelo MacBookPro14,3
```
Preencha em `EFI/OC/config.plist` → `PlatformInfo → Generic`:

| Campo | Valor |
|---|---|
| `SystemSerialNumber` | Serial gerado |
| `MLB` | Board Serial gerado |
| `SystemUUID` | SmUUID gerado |
| `ROM` | MAC da sua placa de rede (12 hex, sem `:`) — ajuda no iCloud |

> Não compartilhe esses valores publicamente.

---

## 3. Baixar o macOS (no Linux)

Dois downloads: **BaseSystem** (recuperação, ~900MB) e o **instalador completo** (~15GB).

### 3a) BaseSystem — `macrecovery`
```bash
git clone https://github.com/acidanthera/OpenCorePkg.git
cd OpenCorePkg/Utilities/macrecovery
python3 ./macrecovery.py -b Mac-7BA5B2D9E42DDD94 -m 00000000000000000 download
```
Cria a pasta `com.apple.recovery.boot/`. O board `Mac-7BA5B2D9E42DDD94` fixa o **Sequoia 15**.

### 3b) Instalador completo — `gibMacOS`
```bash
git clone https://github.com/corpnewt/gibMacOS.git
cd gibMacOS
python3 gibMacOS.py -c publicrelease -v 15 --no-interactive
```
No fim você terá o **`InstallAssistant.pkg`** (~15GB) dentro de `macOS Downloads/`.

---

## 4. Criar o pendrive (no Linux)

Pendrive ≥ 32GB, com **2 partições**:

| Partição | Formato | Conteúdo |
|---|---|---|
| `OPENCORE` (3GB) | FAT32 | `EFI/` + `com.apple.recovery.boot/` |
| `INSTALL` (resto) | exFAT | `InstallAssistant.pkg` |

> 🚨 **CUIDADO:** confirme o pendrive com `lsblk` antes — o comando errado apaga o disco errado!
> Troque **`/dev/sdX`** pelo seu pendrive.

```bash
lsblk                                     # descubra o disco certo
sudo wipefs -a /dev/sdX
sudo sgdisk --zap-all /dev/sdX
sudo sgdisk -n1:0:+3GiB -t1:EF00 -c1:OPENCORE /dev/sdX
sudo sgdisk -n2:0:0     -t2:0700 -c2:INSTALL  /dev/sdX
sudo partprobe /dev/sdX
sudo mkfs.vfat -F32 -n OPENCORE /dev/sdX1
sudo mkfs.exfat        -n INSTALL  /dev/sdX2     # pacote: exfatprogs

# Copiar arquivos
sudo mkdir -p /mnt/oc /mnt/inst
sudo mount /dev/sdX1 /mnt/oc && sudo mount /dev/sdX2 /mnt/inst
sudo cp -R EFI                                /mnt/oc/
sudo cp -R /caminho/com.apple.recovery.boot   /mnt/oc/
sudo cp /caminho/InstallAssistant.pkg         /mnt/inst/
sync && sudo umount /mnt/oc /mnt/inst
```

---

## 5. Instalar o macOS

1. No Acer: **F12** → boote pelo pendrive (UEFI).
2. OpenCore → **"macOS Base System"** *(se não aparecer, aperte a barra de espaço)*.
3. **Utilitário de Disco** → *Mostrar Todos os Dispositivos* → apague o **disco interno inteiro**:
   Nome `macOS` · Formato **APFS** · Esquema **GUID Partition Map**.
4. **Utilitários → Terminal**:
   ```bash
   # Corrija a data (senão dá erro / "app danificado"). Formato MMDDhhmmAAAA:
   date 062214302026                       # ex.: 22/06/2026 14:30
   installer -pkg "/Volumes/INSTALL/InstallAssistant.pkg" -target "/Volumes/macOS"
   "/Volumes/macOS/Applications/Install macOS Sequoia.app/Contents/Resources/startosinstall" \
     --volume "/Volumes/macOS" --agreetolicense --nointeraction
   ```
5. Reinicia várias vezes → a cada vez boote pelo pendrive (F12) → **"macOS Installer"**.
6. Conclua o setup inicial. 🎉

> 💡 Usamos o instalador **offline** porque o método online da Apple costuma falhar aqui (`PKDownloadError 8`,
> por data/hora errada).

---

## 6. Pós‑instalação

### 6.1 Bootar sem o pendrive
No Terminal do macOS instalado:
```bash
diskutil list                              # ache a EFI interna (ex.: disk0s1)
sudo diskutil mount disk0s1                # monta em /Volumes/EFI
sudo mkdir -p /Volumes/EFI/EFI
sudo cp -R /Volumes/OPENCORE/EFI/OC   /Volumes/EFI/EFI/
sudo cp -R /Volumes/OPENCORE/EFI/BOOT /Volumes/EFI/EFI/
sudo /usr/libexec/PlistBuddy -c "Set :Misc:Boot:LauncherOption Full" /Volumes/EFI/EFI/OC/config.plist
```
Depois: reinicie **com o pendrive ainda plugado**, boote uma vez pelo OpenCore do **disco interno** (registra
a entrada na BIOS), então na **BIOS (F2)** ponha o disco interno/"OpenCore" como 1ª prioridade. Pronto — boota sozinho.

### 6.2 Wi‑Fi (HeliPort)
A Intel 7265 usa `itlwm`, sem menu nativo. Instale o **HeliPort**:
1. Conecte a internet **por cabo**.
2. Baixe `HeliPort.dmg`: https://github.com/OpenIntelWireless/HeliPort/releases
3. Arraste para *Aplicativos*, abra (se bloquear: *Ajustes → Privacidade e Segurança → "Abrir mesmo assim"*).
4. No ícone da barra de menu → ligue o Wi‑Fi → escolha a rede.
5. Recomendado: *Preferences → Login Item* (reconecta no boot).

### 6.3 iCloud / iMessage
Com o SMBIOS preenchido (passo 2), o **iCloud** costuma funcionar. iMessage/FaceTime podem exigir ajuste extra (não é obrigatório).

---

## ⚙️ Detalhes técnicos da EFI

- **OpenCore 1.0.6** · **SMBIOS** `MacBookPro14,3` · `SecureBootModel = Disabled`.
- **iGPU HD630** nativa Kaby Lake — `AAPL,ig-platform-id = 0x591b0000` + framebuffer patches (sem spoof CFL).
- **dGPU NVIDIA** desligada via `SSDT-DDGPU.aml` (`\_SB.PCI0.PEG0.PEGP._OFF`).
- **Áudio** AppleALC ALC255 **layout 99** (+ `hda-gfx` p/ áudio HDMI).
- **Wi‑Fi** `itlwm` (+ HeliPort) · **BT** IntelBluetoothFirmware + IntelBTPatcher + BlueToolFixup.
- **Ethernet** RealtekRTL8111 · **NVMe** NVMeFix · **Teclado** VoodooPS2 · **Trackpad** VoodooI2C + VoodooI2CHID.
- **USB** `UTBDefault.kext` (mapa genérico) · `boot-args = -igfxblt -vi2c-force-polling`.

---

## 🩹 Solução de problemas

| Sintoma | Solução |
|---|---|
| OpenCore só mostra "NO NAME" | Aperte **espaço** para revelar entradas ocultas. |
| `PKDownloadError 8` / "app danificado" | **Data errada** — `date MMDDhhmmAAAA` no Terminal e tente de novo. |
| Wi‑Fi não aparece | Normal — instale o **HeliPort**. |
| Só boota com o pendrive | Copie a EFI para o disco interno (6.1) e ajuste a BIOS. |
| Sem áudio após atualizar | Você foi pro **Tahoe**? Ele mata o áudio Intel. Volte ao **Sequoia**. |
| **HDMI externo não funciona** | Limitação do Sequoia + Kaby Lake (a saída externa não é dirigida). A tela interna funciona. Sem solução viável. |

---

## 🛠️ Como a EFI foi gerada

Gerada no Linux com **[OpCore‑Simplify](https://github.com/lzhoang2801/OpCore-Simplify)** (+ Hardware‑Sniffer),
alvo Sequoia 15, com os ajustes acima (iGPU nativa KBL, ALC255 layout 99, `SSDT-DDGPU`, Wi‑Fi `itlwm`).
Para regenerar do zero, use o OpCore‑Simplify seguindo essas escolhas.
