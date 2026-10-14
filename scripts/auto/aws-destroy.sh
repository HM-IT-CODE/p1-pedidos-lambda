#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1
unset AWS_ENDPOINT_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_PROFILE=p1 AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
tofu -chdir=infra workspace select aws >/dev/null 2>&1
tofu -chdir=infra destroy -auto-approve -no-color 2>&1 | grep -E 'Destruction complete|Destroy complete|Error|error'
tofu -chdir=infra workspace select default >/dev/null 2>&1
echo "== lo que queda en AWS (debe estar todo vacio):"
aws lambda list-functions --query 'Functions[].FunctionName' --output text
aws dynamodb list-tables --query 'TableNames' --output text
aws sqs list-queues --query 'QueueUrls' --output text
aws apigateway get-rest-apis --query 'items[].name' --output text
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/p1 --query 'logGroups[].logGroupName' --output text
echo "== workspace actual: $(tofu -chdir=infra workspace show)"
