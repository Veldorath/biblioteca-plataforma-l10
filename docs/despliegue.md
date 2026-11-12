# Despliegue de Biblioteca L10

La red de Azure se configuró en el portal y las dos VM se crearon con Azure
CLI en Brazil South. Se usó `Standard_D2as_v4` para ambas.

## Azure · Salida de bff por gw-azure

Se ejecutó la prueba desde `bff` con Azure Run Command.

```bash
MSYS2_ARG_CONV_EXCL='*' az vm run-command invoke \
  -g biblioteca-l10 -n bff --command-id RunShellScript \
  --scripts 'set -e
hostname
ip -4 -brief address
timeout 240 cloud-init status --wait
docker compose version
printf "IPv4 de salida: "
curl -4fsS --max-time 15 https://checkip.amazonaws.com' \
  --query 'value[0].message' -o tsv
```

```text
Enable succeeded:
[stdout]
bff
lo               UNKNOWN        127.0.0.1/8
eth0             UP             10.1.2.4/24 metric 100
docker0          DOWN           172.17.0.1/16
status: done
Docker Compose version 2.40.3+ds1-0ubuntu1~24.04.1
IPv4 de salida: 20.226.129.185

[stderr]
```

La IPv4 de salida coincide con la IP pública de `gw-azure`.

## Azure · Estado final de las VM

```bash
az vm list -g biblioteca-l10 --show-details \
  --query "[?name=='bff' || name=='gw-azure'].{VM:name,Estado:powerState}" \
  -o table
```

```text
VM        Estado
--------  --------------
bff       VM deallocated
gw-azure  VM deallocated
```
