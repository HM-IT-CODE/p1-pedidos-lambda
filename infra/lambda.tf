# ═══ Paso 3: la Lambda "crear-pedido" ════════════════════════════════════════

# ─── 1. El .zip con el código ─────────────────────────────────────────────────
# `data` = algo que tofu LEE o CALCULA (no crea nada en AWS).
# archive_file comprime dist/crear-pedido/ (lo que generó `npm run build`) en un .zip.
data "archive_file" "crear_pedido" {
  type        = "zip"
  source_dir  = "${path.module}/../dist/crear-pedido"
  output_path = "${path.module}/../dist/crear-pedido.zip"
}

# ─── 2. El "rol" de la Lambda: QUIÉN es cuando corre ─────────────────────────
# En AWS nada puede tocar nada por defecto. La Lambda "asume" este rol, y el rol
# dice qué puede hacer. assume_role_policy = quién puede ponerse este rol (el servicio Lambda).
resource "aws_iam_role" "lambda" {
  name = "${var.proyecto}-lambda-rol"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ─── 3. Permisos MÍNIMOS: solo lo que el código usa ──────────────────────────
# LocalStack (gratis) no hace cumplir IAM, pero AWS real sí: si falta un permiso,
# la Lambda falla con AccessDenied. Mejor escribirlo bien desde el principio.
resource "aws_iam_role_policy" "lambda" {
  name = "${var.proyecto}-lambda-permisos"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"], Resource = aws_dynamodb_table.pedidos.arn },
      { Effect = "Allow", Action = ["sqs:SendMessage"], Resource = aws_sqs_queue.pedidos.arn },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
    ]
  })
}

# ─── 4. La función ────────────────────────────────────────────────────────────
resource "aws_lambda_function" "crear_pedido" {
  function_name = "${var.proyecto}-crear-pedido"
  role          = aws_iam_role.lambda.arn
  runtime       = "nodejs20.x"
  handler       = "index.handler" # archivo index.js, función exportada `handler`
  filename      = data.archive_file.crear_pedido.output_path
  # Huella del zip: si cambias el código y recompilas, cambia la huella y tofu sube la versión nueva.
  source_code_hash = data.archive_file.crear_pedido.output_base64sha256
  timeout          = 10  # segundos máximos por invocación
  memory_size      = 256 # MB (en AWS real también define cuánta CPU te dan, y el precio)

  # Las mismas variables que le pasabas a mano con TABLA_PEDIDOS=... COLA_URL=... npm run
  environment {
    variables = {
      TABLA_PEDIDOS = aws_dynamodb_table.pedidos.name
      COLA_URL      = aws_sqs_queue.pedidos.url
    }
  }

  # Paso 8: en AWS real IAM tarda unos segundos en "propagar" los permisos. Crear la
  # función DESPUÉS de la política y del log group evita errores de la primera corrida.
  depends_on = [aws_iam_role_policy.lambda, aws_cloudwatch_log_group.crear_pedido]
}
