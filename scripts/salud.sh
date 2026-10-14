#!/bin/sh
# Estado de los servicios que usa el proyecto en LocalStack (puerto 4566).
curl -s localhost:4566/_localstack/health | tr ',' '\n' | grep -E '"(lambda|dynamodb|sqs|apigateway|logs|iam)"|version' | tr -d '{}"' | sed 's/services://'
