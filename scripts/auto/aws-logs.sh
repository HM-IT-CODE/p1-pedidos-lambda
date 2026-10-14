#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1
unset AWS_ENDPOINT_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_PROFILE=p1 AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
echo "== procesar-pedido (ultimos 10 min)"
aws logs tail /aws/lambda/p1-procesar-pedido --since 10m --format short 2>&1 | grep -vE 'START|END|INIT_START' | tail -14
echo "== REPORT de crear-pedido: duracion y memoria real"
aws logs tail /aws/lambda/p1-crear-pedido --since 10m --format short 2>&1 | grep REPORT | tail -3
echo "== cuantos pedidos quedaron en la tabla"
aws dynamodb scan --table-name p1-pedidos --select COUNT --query Count
