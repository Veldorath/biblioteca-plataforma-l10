# Biblioteca L10 en AWS Learner Lab

Esta configuración prepara la red y la capa de datos de la E2 en `us-east-1`.
La instancia NAT es pública. Los tres nodos de mensajería, Postgres y Gestión
son privados. Se administran con Session Manager sin abrir el puerto 22.

Desde la raíz de Plataforma, con el Learner Lab activo y Git Bash:

```bash
aws sts get-caller-identity --query Arn --output text
bash deploy/aws/01-red.sh
bash deploy/aws/02-maquinas.sh
bash deploy/aws/03-subir.sh
bash deploy/aws/04-levantar.sh
set -o pipefail
bash deploy/aws/06-evidencia.sh | tee deploy/aws/evidencia.txt
```

En otra terminal, `bash deploy/aws/05-tunel.sh` abre Kafka UI en
`http://localhost:18085` mientras la sesión siga activa.

Los archivos de despliegue se copian al bucket privado. Las credenciales de
RabbitMQ y PostgreSQL se envían a Parameter Store como `SecureString`. Los
`.env` reales se guardan en `secretos/`, ignorado por Git. Para repetir solo una
parte, por ejemplo, usa `bash deploy/aws/04-levantar.sh kafka topics`.

Cuando exista la IP pública de `gw-azure`, se vuelve a ejecutar `01-red.sh`
con `IP_GW_AZURE` para agregar el origen de la regla HTTPS de AWS.
