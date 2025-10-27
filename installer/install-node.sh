#!/bin/bash

# === VARIABLES PARAMETRIZABLES ===
NODE_VERSION="22.0.0"
NODE_DISTRO="linux-x64"
NODE_BASE_URL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-$NODE_DISTRO.tar.xz"
NODE_TAR="/tmp/node-v$NODE_VERSION-$NODE_DISTRO.tar.xz"
NODE_DIR="/opt/nodejs"
NODE_PROFILE="/etc/profile.d/node.sh"

# Colores para output usando tput (256 colores)
PINK=$(tput setaf 204)
PURPLE=$(tput setaf 141)
GREEN=$(tput setaf 114)
ORANGE=$(tput setaf 208)
BLUE=$(tput setaf 75)
YELLOW=$(tput setaf 221)
RED=$(tput setaf 196)
BOLD=$(tput bold)
NC=$(tput sgr0) # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
warn()    { echo -e "${ORANGE}[WARN]${NC} $1"; }
bold()    { echo -e "${BOLD}$1${NC}"; }

die() {
    error "$1"
    exit 1
}

install_node() {
    if command -v node >/dev/null 2>&1 && node --version | grep -q "^v${NODE_VERSION%%.*}"; then
        success "Node.js $NODE_VERSION ya está instalado."
        return 0
    fi
    if [ ! -f "$NODE_TAR" ] || [ ! -s "$NODE_TAR" ]; then
        info "Descargando Node.js $NODE_VERSION en $NODE_TAR..."
        curl -L -o "$NODE_TAR" "$NODE_BASE_URL" || die "No se pudo descargar Node.js."
    else
        info "Usando archivo Node.js ya descargado en $NODE_TAR."
    fi
    # Verificar e instalar xz-utils si es necesario
    if ! command -v xz >/dev/null 2>&1; then
        info "Instalando xz-utils para descomprimir .tar.xz..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y xz-utils || die "No se pudo instalar xz-utils."
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y xz || die "No se pudo instalar xz."
        elif command -v yum >/dev/null 2>&1; then
            yum install -y xz || die "No se pudo instalar xz."
        elif command -v pacman >/dev/null 2>&1; then
            pacman -Sy --noconfirm xz || die "No se pudo instalar xz."
        else
            die "No se pudo encontrar un gestor de paquetes compatible para instalar xz-utils."
        fi
    fi
    info "Extrayendo Node.js en $NODE_DIR..."
    rm -rf "$NODE_DIR"
    mkdir -p "$NODE_DIR"
    tar -xf "$NODE_TAR" -C "$NODE_DIR" --strip-components=1 || die "No se pudo extraer Node.js."
    info "Configurando PATH global para Node.js..."
    echo "export PATH=\"\$PATH:$NODE_DIR/bin\"" > "$NODE_PROFILE"
    chmod 644 "$NODE_PROFILE"
    success "Node.js $NODE_VERSION instalado correctamente en $NODE_DIR."
}

bold "=== Instalador de Node.js $NODE_VERSION ==="
install_node
if [ -f "$NODE_PROFILE" ]; then
    echo -e "Para usar Node.js de inmediato, ejecuta:${NC} ${YELLOW}${BOLD}source $NODE_PROFILE${NC}"
fi
success "Todo listo: Node.js $NODE_VERSION instalado."
