# Paso 8 — El mismo proyecto en AWS real

Todo el código ya está listo: `infra/` sirve para LocalStack **y** para AWS real. Lo que cambia es el
**workspace** de tofu (`default` = LocalStack, `aws` = AWS real) y las credenciales. El script
`scripts/aws-real.sh` hace los cambios por ti y se niega a seguir si detecta LocalStack.

> Las claves de AWS las escribes **tú**, en tu terminal. No van en ningún archivo del proyecto,
> ni en el chat, ni en GitHub.

## 0. Antes de tocar nada: el freno de la billetera (5 min, en la consola web)

1. **MFA en la cuenta root**: arriba a la derecha → *Security credentials* → *Assign MFA device*
   (app autenticadora en el teléfono). La cuenta root no se usa para nada más.
2. **Alerta de presupuesto**: *Billing and Cost Management* → *Budgets* → *Create budget* →
   plantilla **Zero spend budget** (o *Monthly cost budget* con $1). Pon tu correo. Si algo empieza a cobrar, te llega un correo.
3. Región: usa **us-east-1** (N. Virginia) en la consola. El proyecto está configurado para esa región.

## 1. Un usuario para trabajar (no root)

En la consola: **IAM** → *Users* → *Create user*
- Nombre: `henry-labs`. No le des acceso a la consola web; solo lo vas a usar desde la terminal.
- Permisos (*Attach policies directly*): para este laboratorio, `AdministratorAccess`.
  Es amplio a propósito, porque tofu crea roles IAM, Lambdas, colas y tablas. Para un cliente real se
  usa el **mínimo privilegio**: una política solo con lo que el proyecto usa. Es un buen ejercicio para después.
- Entra al usuario → *Security credentials* → *Create access key* → caso de uso **CLI**.
  Copia el *Access key ID* y el *Secret*. El secret solo se muestra esa vez.

En WSL (`wsl -d Ubuntu -u root`):

```sh
aws configure --profile p1
#   AWS Access Key ID:      (pega el tuyo)
#   AWS Secret Access Key:  (pega el tuyo)
#   Default region name:    us-east-1
#   Default output format:  json
```

Esto guarda las claves en `/root/.aws/credentials`, fuera del proyecto.

## 2. Desplegar

```sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda
sh scripts/aws-real.sh quien     # debe salir TU número de cuenta (12 dígitos), no 000000000000
sh scripts/aws-real.sh plan      # lee qué va a crear: ~20 recursos, todos con "+"
sh scripts/aws-real.sh apply     # escribe "yes". Tarda 1-3 min (en AWS real es más rápido que en LocalStack)
```

Al final verás `url_pedidos = "https://xxxx.execute-api.us-east-1.amazonaws.com/dev/pedidos"`.
Esa URL **es pública en internet**. Por eso `api.tf` le pone un freno de 5 peticiones por segundo.

Si la primera vez sale un error como *"The role defined for the function cannot be assumed by Lambda"*,
es IAM tardando en propagarse. Repite `apply` y listo.

## 3. Probar

```sh
sh scripts/aws-real.sh probar    # curl → 201, y las MISMAS pruebas de integración de Jest, ahora contra AWS
sh scripts/aws-real.sh logs      # los console.log de las Lambdas (CloudWatch Logs)
```

Las pruebas de integración no saben si hablan con LocalStack o con AWS: leen la URL de `tofu output`.
Para incluir la prueba de la DLQ: `PRUEBA_DLQ=1 sh scripts/aws-real.sh probar` (unos 2 minutos).

Mira también la consola web: **Lambda** → `p1-crear-pedido` → *Monitor*; **DynamoDB** → *Tables* →
`p1-pedidos` → *Explore items*; **SQS** → las dos colas. Es lo mismo que veías con `aws ... --endpoint`.

## 4. Borrar (el mismo día)

```sh
sh scripts/aws-real.sh destroy   # escribe "yes"
```

Queda todo como estaba. Los log groups también se borran, porque los crea `logs.tf` con retención de 7 días.

## Cuánto cuesta

Con unas decenas de pruebas, centavos o cero. Lambda, SQS y DynamoDB *on-demand* cobran por uso,
y aquí el uso es mínimo. API Gateway REST cobra por millón de peticiones. Lo que puede salir caro es
**dejar la API pública encendida** y que alguien la descubra. Para eso están el freno de 5/s, la alerta de
presupuesto y `destroy` al terminar.

## Siguiente nivel (CD): que GitHub despliegue solo

En `.github/workflows/ci.yml` está el CI (pruebas contra LocalStack). El "CD" sería un tercer job
que, si todo pasa en `main`, corre `tofu apply` contra AWS. La forma correcta de hacerlo **no usa
claves guardadas en GitHub**, sino **OIDC**: AWS confía en GitHub y le da un rol temporal por cada
ejecución. Se hace cuando el repo esté publicado en GitHub (está en la hoja de ruta).
