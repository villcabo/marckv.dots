# Docker Compose para Testing Multi-OS

Este docker-compose levanta contenedores con diferentes versiones de Debian y Ubuntu para probar el bashrc personalizado.

## Versiones Incluidas

### Debian (desde versión 11):
- **debian-11**: Debian 11 (Bullseye)
- **debian-12**: Debian 12 (Bookworm)

### Ubuntu (desde versión 20):
- **ubuntu-20**: Ubuntu 20.04 LTS (Focal)
- **ubuntu-22**: Ubuntu 22.04 LTS (Jammy) 
- **ubuntu-24**: Ubuntu 24.04 LTS (Noble)

## Uso

### Levantar todos los contenedores:
```bash
docker-compose up -d
```

### Conectarse a un contenedor específico:
```bash
# Debian
docker-compose exec debian-11 bash
docker-compose exec debian-12 bash

# Ubuntu  
docker-compose exec ubuntu-20 bash
docker-compose exec ubuntu-22 bash
docker-compose exec ubuntu-24 bash
```

### Instalar el bashrc personalizado dentro del contenedor:
```bash
# Una vez dentro del contenedor
~/.marckv.dots/bash/install.sh

# O directamente
source ~/.marckv.dots/bash/.bashrc
```

### Verificar estado:
```bash
~/.marckv.dots/bash/install.sh status
```

### Detener todos los contenedores:
```bash
docker-compose down
```

## Características

- **Volumen montado**: El directorio actual se monta en `~/.marckv.dots` (solo lectura)
- **Herramientas básicas**: Cada contenedor instala `curl` y `git` automáticamente
- **Network aislada**: Todos los contenedores están en la misma red `marckv-net`
- **Hostnames únicos**: Cada contenedor tiene un hostname descriptivo

## Script de Instalación

El script `bash/install.sh` permite:
- **Instalar**: Agrega la línea de carga al `~/.bashrc` del sistema
- **Desinstalar**: Remueve la configuración y crea backup
- **Estado**: Muestra información sobre la instalación

La línea que se agrega es:
```bash
[[ -s "$HOME/.marckv.dots/bash/.bashrc" ]] && source "$HOME/.marckv.dots/bash/.bashrc"
```