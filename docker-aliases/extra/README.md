# docker-aliases / extra

Módulos opcionales que no se cargan por defecto. Actívalos manualmente desde `~/.bashrc` o `~/.zshrc`.

## Opt-in: git-properties (`dcpr`)

`dcpr` muestra el archivo `git.properties` de contenedores compose (útil para stacks Spring Boot / nginx con metadatos de build).

No se carga por defecto porque es de nicho y agrega tiempo de source innecesario para la mayoría de usuarios.

### Activar

Agrega la siguiente línea en `~/.bashrc` o `~/.zshrc`, **después** del loader principal:

```bash
source ~/.marckv.dots/docker-aliases/extra/git-properties.sh
```

### Uso

```bash
dcpr <service>       # Muestra git.properties de un servicio
dcpr -a              # Muestra git.properties de todos los servicios
dcpr -a -s           # Tabla resumen de todos los servicios
```
