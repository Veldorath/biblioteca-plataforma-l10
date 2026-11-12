# Despliegue de Biblioteca L10

## AWS · Red y capa de datos

El despliegue se ejecutó en AWS Learner Lab, en `us-east-1`, con los
scripts de `deploy/aws/`. Las máquinas estuvieron listas en 388 segundos.
Solo `nat` recibió una IP pública. Las cinco instancias privadas descargaron
Docker e imágenes a través de `nat` y se administraron con Session Manager.
La regla HTTPS de `sg-gw` quedó limitada a la IP pública de `gw-azure`.

Las siguientes salidas se recopilaron con `bash deploy/aws/06-evidencia.sh`.

### Instancias e IP

```text
---------------------------------------------
|             DescribeInstances             |
+---------+--------------+------------------+
|  gestion|  10.0.11.20  |  None            |
|  mq-3   |  10.0.21.13  |  None            |
|  mq-1   |  10.0.21.11  |  None            |
|  nat    |  10.0.1.10   |  54.196.100.222  |
|  datos  |  10.0.21.30  |  None            |
|  mq-2   |  10.0.22.12  |  None            |
+---------+--------------+------------------+
```

### Reglas del puerto 22

```text
[]
```

### Quórum, réplicas y offsets de Kafka

```text
$ $K/kafka-metadata-quorum.sh --bootstrap-server 10.0.21.11:9092 describe --status
ClusterId:              QmlibGlvdGVjYS1LYWZrYQ
LeaderId:               1
LeaderEpoch:            1
HighWatermark:          687
MaxFollowerLag:         0
MaxFollowerLagTimeMs:   0
CurrentVoters:          [{"id": 1, "endpoints": ["CONTROLLER://10.0.21.11:9093"]}, {"id": 2, "endpoints": ["CONTROLLER://10.0.22.12:9093"]}, {"id": 3, "endpoints": ["CONTROLLER://10.0.21.13:9093"]}]
CurrentObservers:       [{"id": 5, "directoryId": "TTtNns5eG7dUOKt3-PMp_Q"}, {"id": 6, "directoryId": "KnBmRm5OLMc7JrcHWmEi9g"}, {"id": 4, "directoryId": "i8-8Sva6Qy9n2tA3sY0LEA"}]
$ $K/kafka-topics.sh --bootstrap-server 10.0.21.11:9092 --describe --topic biblioteca.prestamos
Topic: biblioteca.prestamos	TopicId: IdXIlIBHTSycXBjMNWXNBg	PartitionCount: 3	ReplicationFactor: 3	Configs: min.insync.replicas=2,cleanup.policy=delete,retention.ms=604800000
	Topic: biblioteca.prestamos	Partition: 0	Leader: 4	Replicas: 4,5,6	Isr: 4,5,6	Elr: 	LastKnownElr:
	Topic: biblioteca.prestamos	Partition: 1	Leader: 5	Replicas: 5,6,4	Isr: 5,6,4	Elr: 	LastKnownElr:
	Topic: biblioteca.prestamos	Partition: 2	Leader: 6	Replicas: 6,4,5	Isr: 6,4,5	Elr: 	LastKnownElr:
$ $K/kafka-get-offsets.sh --bootstrap-server 10.0.21.11:9092 --topic biblioteca.lecturas
biblioteca.lecturas:0:492
biblioteca.lecturas:1:2279
biblioteca.lecturas:2:213
$ $K/kafka-get-offsets.sh --bootstrap-server 10.0.21.11:9092 --topic biblioteca.prestamos
biblioteca.prestamos:0:136
biblioteca.prestamos:1:145
biblioteca.prestamos:2:123
```

### Clúster de RabbitMQ

```text
Disk Nodes
rabbit@mq-1
rabbit@mq-2
Running Nodes
rabbit@mq-1
rabbit@mq-2
Versions
rabbit@mq-1: RabbitMQ 4.3.7 on Erlang 27.3.4.19
rabbit@mq-2: RabbitMQ 4.3.7 on Erlang 27.3.4.19
CPU Cores
Node: rabbit@mq-1, available CPU cores: 2
Node: rabbit@mq-2, available CPU cores: 2
Maintenance status
Node: rabbit@mq-1, status: not under maintenance
Node: rabbit@mq-2, status: not under maintenance
Alarms
(none)
Network Partitions
(none)
```

### Estado de PostgreSQL

```text
biblioteca-datos-postgres-1  postgres:18  Up 3 minutes (healthy)
PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
```

La repetición de `bash deploy/aws/04-levantar.sh simulador` detectó los
mensajes existentes y omitió la publicación.

```text
biblioteca.lecturas ya tiene 2984 mensajes: no se publica otra vez (FORZAR=1 para publicar igual).
```

Kafka UI respondió por el túnel de Session Manager y mostró los brokers
4, 5 y 6. El simulador publicó 2.984 lecturas y 404 préstamos.

## Azure · Despliegue

La red de Azure se configuró en el portal y las dos VM se crearon con Azure
CLI en Brazil South. Se usó `Standard_D2as_v4` para ambas.

### Salida de bff por gw-azure

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

### Ruta de la subred privada

```bash
az network route-table route list \
  -g biblioteca-l10 --route-table-name rt-privada -o table
```

```text
AddressPrefix    HasBgpOverride    Name    NextHopIpAddress    NextHopType       ProvisioningState    ResourceGroup
---------------  ----------------  ------  ------------------  ----------------  -------------------  ---------------
0.0.0.0/0        False             salida  10.1.1.4            VirtualAppliance  Succeeded            biblioteca-l10
```

La ruta predeterminada apunta a la IP privada de `gw-azure`.

### Estado final de las VM

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

### Reglas de entrada de nsg-gw-azure

```bash
az network nsg rule list \
  -g biblioteca-l10 --nsg-name nsg-gw-azure -o table
```

La tabla resume la salida. La IPv4 pública del cliente SSH se omite en
esta copia y se conserva la máscara `/32`.

| Regla | Prioridad | Origen | Protocolo | Puertos de destino | Acción |
| --- | --- | --- | --- | --- | --- |
| `web` | 100 | `Internet` | TCP | 80, 443 | Allow |
| `ssh-integrante` | 110 | `[IPv4 del cliente]/32` | TCP | 22 | Allow |
| `desde-privada` | 120 | `10.1.2.0/24` | `*` | `*` | Allow |
