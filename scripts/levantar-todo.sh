#!/bin/sh
# Levanta TODO lo del Proyecto 1 en un solo comando (después de prender la PC):
#   1) mini serve (la "API de Docker" de mini) en segundo plano, si no está
#   2) LocalStack dentro de mini, si no está corriendo
#   3) espera a que LocalStack esté sano
#   4) borra el estado viejo de tofu (LocalStack no guarda datos) y hace build + apply
#
#   wsl -d Ubuntu -u root -- sh /mnt/d/2026/LABS/p1-pedidos-lambda/scripts/levantar-todo.sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_ENDPOINT_URL=http://localhost:4566

# 1) mini serve: si existe el servicio systemd lo usa; si no, lo lanza suelto
if curl -s --unix-socket /run/mini/docker.sock http://x/_ping 2>/dev/null | grep -q OK; then
  echo "✔ mini serve ya responde"
elif systemctl list-unit-files mini-serve.service >/dev/null 2>&1 && systemctl cat mini-serve >/dev/null 2>&1; then
  systemctl start mini-serve && sleep 1 && echo "✔ mini serve arrancado (systemd)"
else
  setsid mini serve > /var/log/mini-serve.log 2>&1 < /dev/null &
  sleep 1; echo "✔ mini serve arrancado (log: /var/log/mini-serve.log)"
fi

# 2) LocalStack
if mini ps | grep -q '^localstack .*corriendo'; then
  echo "✔ localstack ya corre"
else
  mini rm localstack >/dev/null 2>&1
  mini run -d --name localstack --net host --memory 2g -v /run/mini:/run/mini \
    -e DOCKER_HOST=unix:///run/mini/docker.sock -e LAMBDA_DOCKER_NETWORK=bridge -e HOSTNAME_FROM_LAMBDA=10.88.0.1 \
    -e SERVICES=lambda,logs,dynamodb,sqs,iam,sts,apigateway -e AWS_DEFAULT_REGION=us-east-1 localstack-3.8 >/dev/null
  echo "… localstack arrancando"
fi

# 3) salud
for i in $(seq 1 60); do
  curl -sf localhost:4566/_localstack/health >/dev/null && { echo "✔ LocalStack sano"; break; }
  sleep 2
  [ "$i" = 60 ] && { echo "✘ LocalStack no respondió en 2 min (mini logs localstack)"; exit 1; }
done

# 4) infra: si la tabla no existe, el estado de tofu es viejo → empezar de cero
tofu -chdir=infra workspace select default >/dev/null 2>&1
if ! aws dynamodb describe-table --table-name p1-pedidos >/dev/null 2>&1; then
  rm -f infra/terraform.tfstate infra/terraform.tfstate.backup
  echo "… estado viejo borrado (LocalStack arrancó vacío)"
fi
npm run build --silent || exit 1
tofu -chdir=infra apply -auto-approve -no-color | grep -E 'Apply complete|Error|error' 
# La URL de la API cambia en cada apply (LocalStack le da un id nuevo). Se guarda en un
# archivo para que el Web Forms y el WinForms la lean solos (PedidosApiUrl = "auto").
tofu -chdir=infra output -raw url_pedidos > url-api.txt
echo "✔ API: $(cat url-api.txt)   (guardada en url-api.txt para los clientes .NET)"
