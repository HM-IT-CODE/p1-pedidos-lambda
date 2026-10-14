#!/bin/sh
# Paso 1: levanta LocalStack del Proyecto 1 y espera a que esté sano.
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1

# El Lab 2 usa el mismo puerto 4566: si está corriendo, lo paramos
docker ps --format '{{.Names}}' | grep -q '^nest-aws-events-localstack-1$' && docker stop nest-aws-events-localstack-1 >/dev/null && echo "(paré el LocalStack del Lab 2)"

docker compose up -d
echo "esperando a LocalStack..."
for i in $(seq 1 40); do
  docker compose ps localstack | grep -q healthy && { echo "LocalStack listo"; exit 0; }
  sleep 2
done
echo "No quedó sano en 80 s: mira 'docker compose logs localstack'"; exit 1
