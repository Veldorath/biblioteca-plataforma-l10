# Biblioteca L10 en Azure

El grupo de recursos es `biblioteca-l10`. Los recursos del lab se crean en
`northcentralus` (North Central US). La consulta de la suscripción mostró los
dos tamaños sin restricciones y sin zonas de disponibilidad, con 6 vCPU
regionales libres. Las dos VM requieren 4 vCPU en total.

| Recurso | Configuración |
| --- | --- |
| VNet `vnet-biblioteca-ncus` | `10.1.0.0/16` |
| Subred `publica` | `10.1.1.0/24`, NSG `nsg-gw-azure` |
| Subred `privada` | `10.1.2.0/24`, sin salida predeterminada, NSG `nsg-bff` y tabla `rt-privada` |
| Ruta `salida` | `0.0.0.0/0`, dispositivo virtual en `10.1.1.4` |
| IP pública `pip-gw-azure` | IPv4 Standard estática, etiqueta DNS disponible |
| `gw-azure` | Ubuntu 24.04, `Standard_B2ats_v2`, IP privada fija `10.1.1.4`, IP pública y reenvío IP en la NIC |
| `bff` | Ubuntu 24.04, `Standard_B2als_v2`, IP privada fija `10.1.2.4`, sin IP pública |

Configura los NSG como en `red.sh`. El SSH de `gw-azure` usa tu IPv4 pública
con máscara `/32`. Para las VM, usa autenticación con clave SSH, usuario
`azureuser`, discos de 30 GB Standard SSD LRS y el cloud-init de cada máquina.
Primero inicia `gw-azure` y comprueba que terminó cloud-init. Luego inicia
`bff`, que necesita ese NAT para instalar Docker.

La comprobación es que `bff` tiene Docker y reporta como salida la IP pública
de `gw-azure`. Guarda también la lista de reglas de `nsg-gw-azure` y el estado
de las dos VM después de detenerlas desde el portal. Ambas deben aparecer como
`Stopped (deallocated)` o `Detenido (desasignado)`.

Los scripts de esta carpeta son la implementación por CLI del lab.
`L` y `ETIQUETA` permiten cambiar la región y el DNS sin
editar los archivos. Si configuras en el portal, usa estos scripts como
referencia para nombres y valores. La llave privada se guarda en tu perfil.
