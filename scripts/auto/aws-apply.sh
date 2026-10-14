#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1
unset AWS_ENDPOINT_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_PROFILE=p1 AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
tofu -chdir=infra workspace select aws >/dev/null 2>&1
npm run build --silent
tofu -chdir=infra apply -auto-approve -no-color 2>&1 | grep -E 'Creating|Creation complete|Apply complete|Error|error' 
tofu -chdir=infra output -no-color
tofu -chdir=infra workspace select default >/dev/null 2>&1
