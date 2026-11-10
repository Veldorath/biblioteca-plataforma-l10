#!/usr/bin/env bash
# 03-subir.sh · Los archivos llegan a las máquinas por S3 y los secretos por Parameter Store, porque las
# privadas no tienen SSH y el repositorio es privado.
#
#   S3               s3://biblioteca-l10-<cuenta>/deploy/aws/ = copia de deploy/aws/ sin secretos
#   Parameter Store  /biblioteca/<máquina>/env, SecureString, uno por máquina que tiene secretos:
#                    /biblioteca/mq-1/env y /biblioteca/mq-2/env   RABBITMQ_USER, RABBITMQ_PASSWORD, RABBITMQ_COOKIE
#                    /biblioteca/datos/env                         POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD
#
# Los valores reales viven en deploy/aws/secretos/<máquina>.env, que no se versiona (.gitignore) y va en
# el .zip de la entrega. Si falta alguno, este script lo crea desde su .env.example con claves aleatorias.
# Los dos nodos de RabbitMQ necesitan la misma cookie y la misma clave: mq-2.env es copia de mq-1.env.
#
# Uso, desde la raíz de biblioteca-plataforma (cada vez que cambia algo de deploy/aws/):
#   bash deploy/aws/03-subir.sh
set -euo pipefail
source "$(dirname "$0")/comun.sh"
comprobar_cuenta
B=$(bucket)

# 1 · El bucket, una vez. Queda privado: S3 bloquea el acceso público por defecto.
if aws s3api head-bucket --bucket "$B" --expected-bucket-owner "$(cuenta)" > /dev/null 2>&1; then
  log "bucket s3://$B ya existe"
else
  aws s3 mb "s3://$B"
  aws s3api put-bucket-tagging --bucket "$B" \
    --tagging "TagSet=[{Key=Name,Value=$B},{Key=Proyecto,Value=$PROYECTO}]"
fi

# 2 · Solo los archivos de AWS que necesitan las máquinas, sin secretos.
sin_crlf .
aws s3 sync . "s3://$B/deploy/aws/" --only-show-errors --exclude "secretos/*" --exclude "evidencia.txt" --exclude "*.DS_Store"
log "deploy/aws/ sincronizado en s3://$B/deploy/aws/"
aws_ s3 ls "s3://$B/deploy/aws/" --recursive | awk '{print "  " $3 "\t" $4}'

# 3 · Los secretos: uno por máquina, como SecureString
umask 077
clave() { openssl rand -hex "$1"; }
if [ ! -f secretos/mq-1.env ]; then
  sed -e "s/^RABBITMQ_PASSWORD=.*/RABBITMQ_PASSWORD=$(clave 12)/" \
      -e "s/^RABBITMQ_COOKIE=.*/RABBITMQ_COOKIE=$(clave 24)/" secretos/mq.env.example > secretos/mq-1.env
  log "secretos/mq-1.env creado con claves aleatorias"
fi
cmp -s secretos/mq-1.env secretos/mq-2.env 2>/dev/null || cp secretos/mq-1.env secretos/mq-2.env
if [ ! -f secretos/datos.env ]; then
  sed -e "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(clave 12)/" secretos/datos.env.example > secretos/datos.env
  log "secretos/datos.env creado con una clave aleatoria"
fi
for m in mq-1 mq-2 datos; do
  aws ssm put-parameter --type SecureString --overwrite --name "/biblioteca/$m/env" \
    --value "file://secretos/$m.env" > /dev/null
  log "parámetro /biblioteca/$m/env actualizado ($(grep -c '^[A-Z]' "secretos/$m.env") variables)"
done
aws_ ssm describe-parameters --parameter-filters "Key=Name,Option=BeginsWith,Values=/biblioteca/" \
  --output table --query 'Parameters[].[Name,Type,Version,LastModifiedDate]'
