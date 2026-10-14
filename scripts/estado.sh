#!/bin/sh
# Muestra qué servicios de "AWS" están disponibles en LocalStack y si hay contenedores de Lambda vivos.
echo "== Servicios de LocalStack (available = listo para usar, running = ya se usó)"
curl -s localhost:4566/_localstack/health | tr ',' '\n' | grep -E 'lambda|dynamodb|sqs|apigateway|iam|logs|version' | tr -d '{}"'
echo
echo "== Contenedores de Lambda (aparecen cuando una Lambda se invoca)"
# Las Lambdas usan imágenes oficiales de AWS: public.ecr.aws/lambda/nodejs:...
docker ps --format '{{.Names}}  {{.Image}}  {{.Status}}' | grep 'public.ecr.aws/lambda' || echo "(ninguno todavía)"
