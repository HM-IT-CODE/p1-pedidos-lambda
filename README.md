# Proyecto 1 — Pedidos serverless: API Gateway + Lambda + DynamoDB + SQS (+ CI/CD)

[![ci](https://github.com/HM-IT-CODE/p1-pedidos-lambda/actions/workflows/ci.yml/badge.svg)](https://github.com/HM-IT-CODE/p1-pedidos-lambda/actions/workflows/ci.yml)

Laboratorio de arquitectura serverless, hecho con asistencia de IA y probado de punta a punta en
LocalStack (corriendo sobre [mini](../mini-docker), un runtime de contenedores propio) y en AWS real.
El código está comentado en español para servir como material de estudio.

## Arquitectura (a dónde vamos)

```
 curl / front
     │  POST /pedidos
     ▼
 API Gateway (HTTP) ──▶ Lambda "crear-pedido" ──▶ DynamoDB (tabla pedidos, estado=PENDIENTE)
                                 │
                                 └──▶ SQS (cola pedidos-nuevos)
                                            │  (AWS invoca la Lambda sola cuando llega un mensaje)
                                            ▼
                                 Lambda "procesar-pedido" ──▶ DynamoDB (estado=PROCESADO)

 Todo esto lo crea OpenTofu (infra/*.tf) y lo prueba un pipeline CI (GitHub Actions)
 contra LocalStack antes de tocar AWS real.
```

Diferencia con los labs 5/6: allí **nosotros** corríamos los procesos (Node, Rust) todo el tiempo.
Aquí **no hay servidor**: AWS arranca la Lambda solo cuando llega una petición o un mensaje, y cobra por milisegundo.

## Plan (paso a paso)

- [x] **Paso 1** — Estructura + LocalStack con soporte de Lambda
- [x] **Paso 2** — Infra con OpenTofu: tabla DynamoDB + cola SQS (LocalStack corriendo en **mini**, Docker apagado)
- [x] **Paso 3** — Lambda `crear-pedido` en TypeScript, compilada con esbuild, zip con tofu, **corriendo en mini** (vía `mini serve`)
- [x] **Paso 4** — API Gateway (REST v1; la v2 es Pro en LocalStack) → Lambda; probado con curl (201 y 400)
- [x] **Paso 5** — Lambda `procesar-pedido` disparada por SQS (lotes, idempotencia, batchItemFailures; `FALLA` → 3 intentos → DLQ)
- [x] **Paso 6** — Pruebas automáticas con **Jest**: 21 unitarias (mocks) + 6 de integración contra LocalStack en mini (8 oct)
- [x] **Paso 7** — Pipeline CI en GitHub Actions: `.github/workflows/ci.yml` (escrito y validado; corre de verdad cuando el repo esté en GitHub)
- [x] **Paso 8** — **AWS real (14 oct)**: usuario IAM `henry-labs` + presupuesto cero → `apply` creó 19 recursos en ~1 min → curl desde internet 201 → **las mismas 6 pruebas de integración pasaron contra AWS** (DLQ incluida) → logs en CloudWatch (REPORT: 16-160 ms, 95 MB) → `destroy` dejó la cuenta vacía

## Después: repaso con cambios hechos por Henry (yo guío, tú programas)

En este proyecto:
- [ ] Agregar un campo nuevo al pedido (ej. `cliente`) y validarlo en `crear-pedido`.
- [ ] Nueva ruta `GET /pedidos/{id}` → Lambda nueva `ver-pedido` (método + integración en `api.tf`).
- [ ] Cambiar la regla de la DLQ (`maxReceiveCount`) y ver el `plan` con `~` (modificar, no crear).
- [ ] Romper un permiso IAM a propósito y entender el error.

Con .NET (`D:\2026\LABS\DemoFacturacionWebForms` y un WinForms):
- [ ] Web Forms: botón que crea un pedido llamando a `url_pedidos` (HttpClient) y muestra el estado.
- [ ] WinForms: lista de pedidos leída desde la API.
- [ ] Ver cómo un sistema .NET viejo se conecta a servicios en la nube sin reescribirlo.

## Paso extra (al final de todo): IA detrás de una Lambda

- [ ] Lambda que lee la cola y llama a una API de IA (Claude / Gemini / Bedrock); la clave vive solo en la nube.
- [ ] Asíncrono como el paso 5: API Gateway corta a los 29 s y la IA puede tardar más → 201 al instante + cola + resultado en DynamoDB.
- [ ] Web Forms manda la tarea y luego consulta el resultado.
- [ ] Cuidar: qué datos salen de la empresa, costo por uso, que alguien revise lo que devuelve la IA.

## Paso 8 hecho (14 oct): qué se vio en AWS real

| | LocalStack en mini | AWS real |
|---|---|---|
| `tofu apply` de 19 recursos | 3-4 min | **~1 min** |
| Pedido válido → PROCESADO | 1-5 s | 1,5 s |
| Prueba de la DLQ (3 intentos × 30 s) | 95 s | 95 s (igual: lo manda la cola) |
| Logs | `mini logs` / salida.log | CloudWatch: `aws logs tail /aws/lambda/p1-crear-pedido` |
| Lo que cobra | nada | la línea `REPORT` de cada invocación: ms × MB (95 MB usados de 256) |

Mismo código, mismos `.tf`, mismas pruebas: **cero cambios** entre LocalStack y AWS. El único interruptor es el
workspace de tofu (`default` / `aws`) y las credenciales. Ciclo completo: `sh scripts/aws-real.sh quien → plan →
apply → probar → logs → destroy`. Scripts sin interacción (para correr en segundo plano): `scripts/auto/aws-*.sh`.

Pendiente de la cuenta: borrar los usuarios IAM viejos (`hmts`, `testuser`) o al menos desactivar la clave activa de `hmts`;
confirmar el correo del presupuesto (AWS manda un correo de verificación).

## Dónde quedamos (8 oct, noche) — lo que avanzó Claude solo

**Levantar todo en un comando** (mini serve ya arranca solo con WSL: quedó instalado como servicio):

```sh
wsl -d Ubuntu -u root -- sh /mnt/d/2026/LABS/p1-pedidos-lambda/scripts/levantar-todo.sh
```

Hace: mini serve → LocalStack en mini → espera que esté sano → borra el estado viejo de tofu → build → apply (~4 min).

**Paso 6, pruebas con Jest** (`jest.config.cjs`, carpeta `test/`):

| Comando | Qué prueba | Necesita | Tiempo |
|---|---|---|---|
| `npm test` | 21 pruebas unitarias: los handlers con AWS falso (`aws-sdk-client-mock`) | nada | ~45 s la 1.ª vez en /mnt/d, luego menos |
| `npm run test:integracion` | 5 pruebas del sistema desplegado: HTTP → API Gateway → Lambdas → DynamoDB/SQS | LocalStack + apply | ~30 s |
| `PRUEBA_DLQ=1 npm run test:integracion` | + FALLA → 3 intentos → DLQ | igual | +2 min |
| `npm run typecheck` | errores de tipos de TypeScript | nada | ~10 s |

(Para la integración exporta antes `AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1 AWS_ENDPOINT_URL=http://localhost:4566`.)

Resultado del 8 oct: **21/21 unitarias, 6/6 integración (con DLQ), typecheck limpio.**

Para estudiar, en este orden:
1. `test/ayudas/eventos.ts`: cómo se ve un *event* de API Gateway y uno de SQS.
2. `test/unit/crear-pedido.test.ts`: `mockClient`, `commandCalls`, `test.each`, y por qué un 400 no debe tocar AWS.
3. `test/unit/procesar-pedido.test.ts`: lote mixto → solo el malo en `batchItemFailures`, y un mensaje repetido NO es un fallo.
4. `test/ayudas/despliegue.ts` + `test/integracion/flujo-pedidos.test.ts`: `esperarHasta()`, la forma de probar lo asíncrono.

**Hallazgo para el repaso**: si SQS falla después de guardar en DynamoDB, el pedido queda PENDIENTE para
siempre. La prueba `hueco conocido` lo documenta. Se arregla con el patrón **outbox** (lo hiciste en el lab
saga-outbox-cqrs) o con **DynamoDB Streams**. Buen ejercicio para hacer tú.

**Paso 7, CI**: `.github/workflows/ci.yml`: job `unitarias` (typecheck + jest + build) → job `integracion`
(LocalStack en Docker + tofu apply + jest con DLQ). Va a correr solo cuando el repo esté en GitHub.

**Paso 8, AWS real**: lee `docs/PASO-8-AWS-REAL.md`. Cambios en `infra/`:
- `provider.tf`: workspace `default` = LocalStack, workspace `aws` = AWS real (bloque `dynamic "endpoints"`).
- `logs.tf` (nuevo): log groups con 7 días de retención (si no, AWS los guarda para siempre).
- `api.tf`: freno de 5 peticiones/s, solo en AWS real.
- `outputs.tf`: `url_pedidos` según el destino, y un output nuevo `destino`.
- `lambda.tf` / `procesar.tf`: `depends_on` para que IAM esté listo antes de crear las funciones.

**Clientes .NET** (8 oct): Web Forms (`Pedidos.aspx`) y WinForms crean pedidos en esta API → `clientes/README.md`.
`levantar-todo.sh` ahora deja la URL en `url-api.txt` para que los dos la lean solos.

**tofu sin cambios eternos**: `default_tags` (todo etiquetado `proyecto=p1`) + `ignore_changes` en el event source
mapping (LocalStack no guarda sus tags). `tofu plan` después de un apply → "No changes".

## Paso 1 — LocalStack con Lambda

```sh
wsl -d Ubuntu -u root -- sh /mnt/d/2026/LABS/p1-pedidos-lambda/scripts/levantar.sh
wsl -d Ubuntu -u root -- sh /mnt/d/2026/LABS/p1-pedidos-lambda/scripts/estado.sh
```

Lo nuevo frente al Lab 2: LocalStack necesita el **socket de Docker** (`/var/run/docker.sock`)
porque cada Lambda corre en **su propio contenedor** (igual que en AWS, donde corre en una microVM Firecracker).

## Dónde quedamos (5 oct, noche)

- Paso 2 completo: LocalStack corriendo en **mini** (Docker apagado), tabla `p1-pedidos` y colas creadas con tofu.
- Paso 3 a medias: la Lambda `crear-pedido` **funciona corriendo con Node** (`npm run probar:crear`):
  201 con pedido válido (guardado en DynamoDB + mensaje en SQS), 400 con qty mala, 400 con body roto.
- Falta del paso 3: empaquetarla con esbuild (zip). Para **desplegarla** en el servicio Lambda (paso 4)
  hay que decidir: prender Docker solo para eso, o enseñarle a mini la API de Docker.
- Pendiente revisar: la "1 moderate vulnerability" de `npm audit` (no correr `audit fix --force`).

## Cómo retomar (si se apagó la PC o se hizo `wsl --shutdown`)

```sh
wsl -d Ubuntu -u root
cd /mnt/d/2026/LABS/p1-pedidos-lambda
mini ps                                    # ¿sigue corriendo localstack?
# si no está:
mini rm localstack
# (desde el 6 oct) con Lambda: mini serve en otra terminal + LocalStack apuntando a su socket
mini run -d --name localstack --net host --memory 2g -v /run/mini:/run/mini -e DOCKER_HOST=unix:///run/mini/docker.sock -e LAMBDA_DOCKER_NETWORK=bridge -e HOSTNAME_FROM_LAMBDA=10.88.0.1 -e SERVICES=lambda,logs,dynamodb,sqs,iam,sts,apigateway -e AWS_DEFAULT_REGION=us-east-1 localstack-3.8
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_ENDPOINT_URL=http://localhost:4566
rm -f infra/terraform.tfstate*             # LocalStack no guarda datos: el estado viejo ya no sirve
tofu -chdir=infra apply -auto-approve      # recrea tabla y colas
COLA=$(tofu -chdir=infra output -raw cola_url)
TABLA_PEDIDOS=p1-pedidos COLA_URL=$COLA npm run probar:crear
```
