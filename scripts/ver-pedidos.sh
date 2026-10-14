#!/bin/sh
# Estado de todos los pedidos + mensajes en las colas + log de procesar-pedido.
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_ENDPOINT_URL=http://localhost:4566
cd /mnt/d/2026/LABS/p1-pedidos-lambda
echo "== pedidos"
aws dynamodb scan --table-name p1-pedidos --query 'Items[].[sku.S,qty.N,estado.S,id.S]' --output text | sort
for c in cola_url dlq_url; do
  U=$(tofu -chdir=infra output -raw $c)
  echo "== $c: $(aws sqs get-queue-attributes --queue-url $U --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --query 'Attributes' --output text)"
done
L=$(ls -t /var/lib/mini/contenedores | grep 'procesar-pedido' | head -1)
[ -n "$L" ] && { echo "== log de $L"; grep -vE 'NodeVersionSupportWarning' /var/lib/mini/contenedores/$L/salida.log | tail -12; }
