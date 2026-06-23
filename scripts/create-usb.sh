#!/usr/bin/env bash
# =============================================================================
#  create-usb.sh  —  Cria o pendrive de instalação do Hackintosh Acer VX5-591G
#  (macOS Sequoia 15 + OpenCore).  Funciona em Linux e macOS.
#
#  O que faz automaticamente:
#    1) Baixa o BaseSystem (recuperação) via macrecovery
#    2) (modo offline) Baixa o instalador completo (InstallAssistant.pkg) via gibMacOS
#    3) Particiona o pendrive (apaga tudo!)
#    4) Copia a EFI + instalador para o pendrive
#
#  Uso:
#    sudo ./scripts/create-usb.sh --disk <DISCO> [opções]
#
#  Exemplos:
#    Linux:  sudo ./scripts/create-usb.sh --disk /dev/sdb
#    macOS:  sudo ./scripts/create-usb.sh --disk /dev/disk4
#
#  Descubra o disco com:  lsblk   (Linux)   ou   diskutil list   (macOS)
#  ⚠️  ATENÇÃO: o disco informado será TOTALMENTE APAGADO. Confira 3x!
# =============================================================================
set -euo pipefail

# ---------- Configuração padrão ----------
MACOS_VERSION="15"                         # série do Sequoia (NÃO use 26/Tahoe)
RECOVERY_BOARD="Mac-7BA5B2D9E42DDD94"      # board-id que fixa o Sequoia no macrecovery
MODE="offline"                             # offline (≥32GB) | online (recuperação, ≥8GB)
ASSUME_YES=0
SKIP_DOWNLOAD=0
DISK=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EFI_SRC="$REPO_ROOT/EFI"
WORKDIR="$REPO_ROOT/downloads"

# ---------- Cores ----------
c_red()  { printf "\033[31m%s\033[0m\n" "$*"; }
c_grn()  { printf "\033[32m%s\033[0m\n" "$*"; }
c_yel()  { printf "\033[33m%s\033[0m\n" "$*"; }
c_bld()  { printf "\033[1m%s\033[0m\n" "$*"; }
die()    { c_red "ERRO: $*"; exit 1; }

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

# ---------- Parse de argumentos ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --disk)          DISK="$2"; shift 2;;
    --mode)          MODE="$2"; shift 2;;
    --macos-version) MACOS_VERSION="$2"; shift 2;;
    --skip-download) SKIP_DOWNLOAD=1; shift;;
    -y|--yes)        ASSUME_YES=1; shift;;
    -h|--help)       usage;;
    *) die "argumento desconhecido: $1 (use --help)";;
  esac
done

[ "$MODE" = "offline" ] || [ "$MODE" = "online" ] || die "--mode deve ser 'offline' ou 'online'"
[ -n "$DISK" ] || die "informe o disco com --disk (ex.: --disk /dev/sdb).  Veja com 'lsblk' / 'diskutil list'."
[ -d "$EFI_SRC/OC" ] || die "pasta EFI/ não encontrada em $EFI_SRC. Rode a partir da raiz do projeto."

# ---------- Detectar SO ----------
OS="$(uname -s)"
case "$OS" in
  Linux)  PLATFORM="linux";;
  Darwin) PLATFORM="macos";;
  *) die "SO não suportado: $OS (apenas Linux e macOS)";;
esac
c_bld "==> Plataforma: $PLATFORM | Modo: $MODE | macOS alvo: $MACOS_VERSION"

# ---------- Checar dependências ----------
need() { command -v "$1" >/dev/null 2>&1 || die "falta o comando '$1'. Instale antes de continuar."; }
need git; need python3; need curl
if [ "$PLATFORM" = "linux" ]; then
  need sgdisk; need partprobe; need mkfs.vfat
  [ "$MODE" = "offline" ] && need mkfs.exfat
  need wipefs
fi
[ "$(id -u)" = "0" ] || die "rode com sudo (precisa de root para particionar)."

# =============================================================================
#  1) DOWNLOAD do macOS
# =============================================================================
mkdir -p "$WORKDIR"
RECOVERY_DIR="$WORKDIR/com.apple.recovery.boot"
INSTALLER_PKG=""

if [ "$SKIP_DOWNLOAD" = "0" ]; then
  c_bld "==> [1/4] Baixando o BaseSystem (recuperação) via macrecovery..."
  if [ ! -f "$RECOVERY_DIR/BaseSystem.dmg" ]; then
    [ -f "$WORKDIR/macrecovery.py" ] || curl -fsSL -o "$WORKDIR/macrecovery.py" \
      "https://raw.githubusercontent.com/acidanthera/OpenCorePkg/master/Utilities/macrecovery/macrecovery.py"
    [ -f "$WORKDIR/boards.json" ] || curl -fsSL -o "$WORKDIR/boards.json" \
      "https://raw.githubusercontent.com/acidanthera/OpenCorePkg/master/Utilities/macrecovery/boards.json"
    ( cd "$WORKDIR" && python3 ./macrecovery.py -b "$RECOVERY_BOARD" -m 00000000000000000 download )
    [ -f "$RECOVERY_DIR/BaseSystem.dmg" ] || die "macrecovery não gerou o BaseSystem.dmg"
  else
    c_grn "    BaseSystem já existe, pulando."
  fi

  if [ "$MODE" = "offline" ]; then
    c_bld "==> [1/4] Baixando o instalador completo (InstallAssistant.pkg ~15GB) via gibMacOS..."
    INSTALLER_PKG="$(find "$WORKDIR" -name 'InstallAssistant.pkg' 2>/dev/null | head -1 || true)"
    if [ -z "$INSTALLER_PKG" ]; then
      [ -d "$WORKDIR/gibMacOS" ] || git clone --depth 1 https://github.com/corpnewt/gibMacOS.git "$WORKDIR/gibMacOS"
      ( cd "$WORKDIR/gibMacOS" && python3 gibMacOS.py -c publicrelease -v "$MACOS_VERSION" --no-interactive -o "$WORKDIR/installer-dl" )
      INSTALLER_PKG="$(find "$WORKDIR/installer-dl" -name 'InstallAssistant.pkg' 2>/dev/null | head -1 || true)"
    fi
    [ -n "$INSTALLER_PKG" ] || die "InstallAssistant.pkg não foi baixado. Rode 'python3 gibMacOS.py' manualmente e escolha o Sequoia."
    c_grn "    Instalador: $INSTALLER_PKG"
  fi
else
  c_yel "==> Download PULADO (--skip-download). Usando o que já está em $WORKDIR."
  INSTALLER_PKG="$(find "$WORKDIR" -name 'InstallAssistant.pkg' 2>/dev/null | head -1 || true)"
fi

# =============================================================================
#  2) Validar o disco alvo (travas de segurança)
# =============================================================================
c_bld "==> [2/4] Validando o disco alvo: $DISK"
[ -e "$DISK" ] || die "disco $DISK não existe."

if [ "$PLATFORM" = "linux" ]; then
  base="$(basename "$DISK")"
  rm_flag="$(cat /sys/block/$base/removable 2>/dev/null || echo 0)"
  sectors="$(cat /sys/block/$base/size 2>/dev/null || echo 0)"
  model="$(cat /sys/block/$base/device/model 2>/dev/null || echo '?')"
  echo "    removível=$rm_flag | setores=$sectors | modelo=$model"
  [ "$rm_flag" = "1" ] || die "$DISK NÃO é removível. Abortando para proteger discos internos."
  # recusa > 256GB (proteção contra apagar HD/SSD por engano)
  [ "$sectors" -gt 0 ] && [ "$sectors" -lt 536870912 ] || die "tamanho suspeito ($sectors setores). Use um pendrive."
else
  internal="$(diskutil info "$DISK" 2>/dev/null | awk -F': *' '/Internal/{print $2; exit}')"
  removable="$(diskutil info "$DISK" 2>/dev/null | awk -F': *' '/Removable Media|Ejectable/{print $2}' | tr '\n' ' ')"
  size="$(diskutil info "$DISK" 2>/dev/null | awk -F': *' '/Disk Size/{print $2; exit}')"
  echo "    Internal=$internal | $removable | Tamanho=$size"
  echo "$internal" | grep -qi "No" || die "$DISK parece INTERNO. Abortando para proteger seu sistema."
fi

# ---------- Confirmação ----------
c_red   "================================================================"
c_red   "  TODO O CONTEÚDO DE  $DISK  SERÁ APAGADO PERMANENTEMENTE!"
c_red   "================================================================"
if [ "$ASSUME_YES" = "0" ]; then
  printf "Para confirmar, digite exatamente o disco (%s): " "$DISK"
  read -r ans
  [ "$ans" = "$DISK" ] || die "confirmação não bateu. Abortado."
fi

# =============================================================================
#  3) Particionar o pendrive
# =============================================================================
c_bld "==> [3/4] Particionando $DISK ..."
if [ "$PLATFORM" = "macos" ]; then
  diskutil unmountDisk force "$DISK" || true
  if [ "$MODE" = "offline" ]; then
    diskutil partitionDisk "$DISK" GPT "MS-DOS FAT32" OPENCORE 3G ExFAT INSTALL R
  else
    diskutil partitionDisk "$DISK" GPT "MS-DOS FAT32" OPENCORE R
  fi
  OC_MNT="/Volumes/OPENCORE"
  INSTALL_MNT="/Volumes/INSTALL"
else
  wipefs -a "$DISK"
  sgdisk --zap-all "$DISK"
  sgdisk -n1:0:+3GiB -t1:EF00 -c1:OPENCORE "$DISK"
  [ "$MODE" = "offline" ] && sgdisk -n2:0:0 -t2:0700 -c2:INSTALL "$DISK"
  partprobe "$DISK"; sleep 2
  # nome das partições: /dev/sdb1 ou /dev/nvme0n1p1
  case "$DISK" in *[0-9]) P1="${DISK}p1"; P2="${DISK}p2";; *) P1="${DISK}1"; P2="${DISK}2";; esac
  mkfs.vfat -F32 -n OPENCORE "$P1"
  [ "$MODE" = "offline" ] && mkfs.exfat -n INSTALL "$P2"
  OC_MNT="$(mktemp -d)"; INSTALL_MNT="$(mktemp -d)"
  mount "$P1" "$OC_MNT"
  [ "$MODE" = "offline" ] && mount "$P2" "$INSTALL_MNT"
fi
[ -d "$OC_MNT" ] || die "partição OPENCORE não montou."

# =============================================================================
#  4) Copiar EFI + instalador
# =============================================================================
c_bld "==> [4/4] Copiando arquivos ..."
cp -R "$EFI_SRC" "$OC_MNT/"                         # EFI do OpenCore
cp -R "$RECOVERY_DIR" "$OC_MNT/"                    # BaseSystem (recuperação)

cat > "$OC_MNT/LEIA-PRIMEIRO.txt" <<'TXT'
INSTALAÇÃO macOS Sequoia — Acer VX5-591G

1) BIOS (F2): Secure Boot OFF, Boot Mode UEFI.
2) F12 -> bootar por este pendrive -> OpenCore -> "macOS Base System".
3) Utilitário de Disco -> Mostrar Todos os Dispositivos -> apagar o disco
   interno INTEIRO como APFS (nome: macOS, esquema: GUID Partition Map).
4) Utilitários -> Terminal. CORRIJA A DATA (senão dá erro de download / "app danificado"):
      date MMDDhhmmAAAA      (ex.: 22/06/2026 14:30 ->  date 062214302026)
5) MODO OFFLINE (pendrive com partição INSTALL):
      installer -pkg "/Volumes/INSTALL/InstallAssistant.pkg" -target "/Volumes/macOS"
      "/Volumes/macOS/Applications/Install macOS Sequoia.app/Contents/Resources/startosinstall" \
         --volume "/Volumes/macOS" --agreetolicense --nointeraction
   MODO ONLINE (só recuperação): escolha "Reinstalar macOS" e siga (precisa de internet).
6) A cada reinício, bootar pelo pendrive (F12) -> "macOS Installer".

IMPORTANTE: gere seu PRÓPRIO número de série (SMBIOS) antes de usar a EFI — veja o README.
TXT

if [ "$MODE" = "offline" ]; then
  [ -d "$INSTALL_MNT" ] || die "partição INSTALL não montou."
  c_yel "    Copiando InstallAssistant.pkg (~15GB, demora)..."
  cp "$INSTALLER_PKG" "$INSTALL_MNT/"
fi

# ---------- Finalizar ----------
sync
if [ "$PLATFORM" = "macos" ]; then
  diskutil eject "$DISK" || true
else
  umount "$OC_MNT" || true
  [ "$MODE" = "offline" ] && { umount "$INSTALL_MNT" || true; }
fi

c_grn "================================================================"
c_grn "  PRONTO! Pendrive de instalação criado em $DISK"
c_grn "================================================================"
c_yel "LEMBRE: gere seu próprio SERIAL/SMBIOS e preencha em EFI/OC/config.plist"
c_yel "        (PlatformInfo > Generic). Veja a seção 'SMBIOS' no README."
echo  "Próximo: plugue no Acer, F2 (BIOS: Secure Boot OFF), F12 -> bootar pelo pendrive."
