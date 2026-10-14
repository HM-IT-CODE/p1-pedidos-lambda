#!/bin/sh
# Qué pasó con la última invocación: respuesta, contenedor de la Lambda, su log y la tabla.
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_ENDPOINT_URL=http://localhost:4566
echo "== respuesta:"; cat /tmp/respuesta.json 2>/dev/null || echo "(todavía no hay /tmp/respuesta.json)"; echo
echo "== contenedores en mini"; mini ps
L=$(ls /var/lib/mini/contenedores | grep 'lambda-p1-crear-pedido' | tail -1)
[ -n "$L" ] && { echo "== log del contenedor $L"; tail -15 /var/lib/mini/contenedores/$L/salida.log; }
echo "== tabla p1-pedidos"
aws dynamodb scan --table-name p1-pedidos --query 'Items[].{id:id.S,sku:sku.S,qty:qty.N,estado:estado.S}' --output table
echo "== mensajes en la cola"
aws sqs get-queue-attributes --queue-url $(tofu -chdir=/mnt/d/2026/LABS/p1-pedidos-lambda/infra output -raw cola_url) --attribute-names ApproximateNumberOfMessages --query Attributes --output text
