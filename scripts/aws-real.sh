#!/bin/sh
# ═══ Paso 8: el MISMO proyecto contra AWS REAL ════════════════════════════════
# Uso (dentro de WSL, después de `aws configure --profile p1`, ver docs/PASO-8-AWS-REAL.md):
#   sh scripts/aws-real.sh quien      ¿con qué cuenta estoy conectado?
#   sh scripts/aws-real.sh plan       qué se va a crear (no crea nada)
#   sh scripts/aws-real.sh apply      crear todo en AWS (pide confirmar "yes")
#   sh scripts/aws-real.sh probar     curl + pruebas de integración contra AWS
#   sh scripts/aws-real.sh logs       últimos logs de las dos Lambdas
#   sh scripts/aws-real.sh destroy    BORRAR todo de AWS (hazlo al terminar)
#
# Lo importante que hace este script: QUITA las variables de LocalStack. El provider
# de AWS y el SDK respetan AWS_ENDPOINT_URL: si quedara puesta, "AWS real" sería LocalStack.
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1
unset AWS_ENDPOINT_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_PROFILE=${AWS_PROFILE:-p1} AWS_REGION=${AWS_REGION:-us-east-1} AWS_DEFAULT_REGION=${AWS_REGION:-us-east-1}

CUENTA=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$CUENTA" ]; then
  echo "✘ No hay credenciales para el perfil '$AWS_PROFILE'. Corre: aws configure --profile $AWS_PROFILE"; exit 1
fi
if [ "$CUENTA" = "000000000000" ]; then
  echo "✘ Eso es LocalStack (cuenta 000000000000), no AWS real. Revisa tus variables."; exit 1
fi

# Workspace "aws" = estado separado del de LocalStack (ver infra/provider.tf).
# Al salir SIEMPRE se vuelve a "default" (LocalStack): así un `tofu apply` suelto
# nunca toca AWS real por accidente.
tofu -chdir=infra workspace select aws >/dev/null 2>&1 || tofu -chdir=infra workspace new aws >/dev/null
trap 'tofu -chdir=infra workspace select default >/dev/null 2>&1' EXIT

case "$1" in
  quien)   aws sts get-caller-identity --output table; echo "workspace: $(tofu -chdir=infra workspace show)" ;;
  plan)    npm run build --silent && tofu -chdir=infra plan ;;
  apply)   npm run build --silent && tofu -chdir=infra apply && tofu -chdir=infra output ;;
  probar)
    URL=$(tofu -chdir=infra output -raw url_pedidos)
    echo "== POST $URL"
    curl -s -w '\nHTTP %{http_code}\n' -X POST "$URL" -H 'content-type: application/json' -d '{"sku":"AWS-01","qty":2}'
    echo "== pruebas de integración contra AWS real"
    PRUEBA_DLQ=${PRUEBA_DLQ:-} npx jest --selectProjects integracion --runInBand ;;
  logs)
    aws logs tail /aws/lambda/p1-crear-pedido --since 30m
    aws logs tail /aws/lambda/p1-procesar-pedido --since 30m ;;
  destroy) tofu -chdir=infra destroy && echo "✔ Todo borrado de AWS." ;;
  *) sed -n '2,10p' "$0" ;;
esac
