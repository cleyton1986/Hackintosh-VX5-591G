#!/usr/bin/env bash
# =============================================================================
#  gen-smbios.sh  —  Gera um número de série (SMBIOS) próprio para a EFI.
#  Cada Hackintosh precisa de um SERIAL/MLB/UUID ÚNICO. Este script gera e,
#  opcionalmente, injeta direto na EFI/OC/config.plist.
#
#  Uso:
#    ./scripts/gen-smbios.sh            # só gera e mostra (você copia manual)
#    ./scripts/gen-smbios.sh --inject   # gera E grava em EFI/OC/config.plist
# =============================================================================
set -euo pipefail

MODEL="MacBookPro14,3"
INJECT=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/EFI/OC/config.plist"
WORKDIR="$REPO_ROOT/downloads"

die() { printf "\033[31mERRO: %s\033[0m\n" "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --inject) INJECT=1; shift;;
    --model)  MODEL="$2"; shift 2;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "argumento desconhecido: $1";;
  esac
done

command -v python3 >/dev/null || die "falta python3"
command -v curl >/dev/null || die "falta curl"

# ---------- Baixar macserial (do release oficial do OpenCorePkg) ----------
command -v unzip >/dev/null || die "falta o comando 'unzip'"
mkdir -p "$WORKDIR"
MS="$WORKDIR/macserial"
case "$(uname -s)" in
  Darwin) BIN="macserial";;
  Linux)  BIN="macserial.linux";;
  *) die "SO não suportado";;
esac
if [ ! -x "$MS" ]; then
  echo "==> Baixando macserial (OpenCorePkg release)..."
  ZIP_URL="$(curl -fsSL https://api.github.com/repos/acidanthera/OpenCorePkg/releases/latest \
    | python3 -c 'import sys,json; [print(a["browser_download_url"]) for a in json.load(sys.stdin)["assets"] if a["name"].endswith("-RELEASE.zip")]' \
    | head -1)"
  [ -n "$ZIP_URL" ] || die "não achei o release do OpenCorePkg"
  curl -fsSL -o "$WORKDIR/oc-release.zip" "$ZIP_URL" || die "falha ao baixar o OpenCorePkg"
  ( cd "$WORKDIR" && unzip -o -j oc-release.zip "Utilities/macserial/$BIN" -d . >/dev/null ) || die "macserial não encontrado no zip"
  mv "$WORKDIR/$BIN" "$MS"
  chmod +x "$MS"
  rm -f "$WORKDIR/oc-release.zip"
  [ "$(uname -s)" = "Darwin" ] && xattr -dr com.apple.quarantine "$MS" 2>/dev/null || true
fi

# ---------- Gerar ----------
echo "==> Gerando SMBIOS para $MODEL ..."
PAIR="$("$MS" --model "$MODEL" --num 1 2>/dev/null | head -1)"
SERIAL="$(printf '%s' "$PAIR" | awk -F' \\| ' '{print $1}' | tr -d ' ')"
MLB="$(printf '%s' "$PAIR" | awk -F' \\| ' '{print $2}' | tr -d ' ')"
UUID="$(python3 -c 'import uuid;print(str(uuid.uuid4()).upper())')"
[ -n "$SERIAL" ] && [ -n "$MLB" ] || die "macserial não gerou um par válido"

echo
printf "  \033[1mSystemSerialNumber\033[0m = %s\n" "$SERIAL"
printf "  \033[1mMLB (Board Serial)\033[0m = %s\n" "$MLB"
printf "  \033[1mSystemUUID\033[0m         = %s\n" "$UUID"
echo
echo "  ROM = use o MAC da sua placa de rede (12 dígitos hex, sem ':')."
echo "        Linux:  ip link        |  macOS:  ifconfig en0 | grep ether"
echo

# ---------- Injetar (opcional) ----------
if [ "$INJECT" = "1" ]; then
  [ -f "$CONFIG" ] || die "config não encontrado em $CONFIG"
  cp "$CONFIG" "$CONFIG.bak-$(date +%s 2>/dev/null || echo bak)" 2>/dev/null || cp "$CONFIG" "$CONFIG.bak"
  SERIAL="$SERIAL" MLB="$MLB" UUID="$UUID" CONFIG="$CONFIG" python3 - <<'PY'
import os, plistlib
cfg=os.environ["CONFIG"]
with open(cfg,"rb") as f: p=plistlib.load(f)
g=p["PlatformInfo"]["Generic"]
g["SystemSerialNumber"]=os.environ["SERIAL"]
g["MLB"]=os.environ["MLB"]
g["SystemUUID"]=os.environ["UUID"]
with open(cfg,"wb") as f: plistlib.dump(p,f)
print("==> Injetado em EFI/OC/config.plist (backup .bak criado).")
print("    Falta só o ROM (MAC da sua placa de rede) — preencha à mão se quiser iServices.")
PY
else
  echo "Dica: rode com --inject para gravar automaticamente em EFI/OC/config.plist."
fi
