#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_REGION=us-east-1 AWS_ENDPOINT_URL=http://localhost:4566
PRUEBA_DLQ=${PRUEBA_DLQ:-1} npx jest --selectProjects integracion --runInBand 2>&1
