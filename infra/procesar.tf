# ═══ Paso 5: Lambda "procesar-pedido" disparada por la cola ═══════════════════

data "archive_file" "procesar_pedido" {
  type        = "zip"
  source_dir  = "${path.module}/../dist/procesar-pedido"
  output_path = "${path.module}/../dist/procesar-pedido.zip"
}

# Comparte el rol con crear-pedido; le sumamos los permisos para LEER la cola.
resource "aws_iam_role_policy" "lambda_leer_cola" {
  name = "${var.proyecto}-lambda-leer-cola"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
      Resource = aws_sqs_queue.pedidos.arn
    }]
  })
}

resource "aws_lambda_function" "procesar_pedido" {
  function_name    = "${var.proyecto}-procesar-pedido"
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.procesar_pedido.output_path
  source_code_hash = data.archive_file.procesar_pedido.output_base64sha256
  # Regla de AWS: el visibility_timeout de la cola (30 s) debe ser >= que el timeout de la Lambda.
  # Si no, un mensaje "reaparecería" mientras la Lambda todavía lo está procesando.
  timeout     = 10
  memory_size = 256
  environment {
    variables = {
      TABLA_PEDIDOS = aws_dynamodb_table.pedidos.name
    }
  }
  depends_on = [aws_iam_role_policy.lambda, aws_cloudwatch_log_group.procesar_pedido]
}

# ─── El "cable" cola → Lambda ─────────────────────────────────────────────────
# AWS (aquí LocalStack) consulta la cola por ti, junta mensajes en lotes y llama a la Lambda.
# Tú no escribes ningún while(true) ni receive-message: eso es lo "serverless".
resource "aws_lambda_event_source_mapping" "cola_a_procesar" {
  event_source_arn = aws_sqs_queue.pedidos.arn
  function_name    = aws_lambda_function.procesar_pedido.arn
  batch_size       = 5 # hasta 5 mensajes por invocación
  # Permite responder "fallaron SOLO estos" (batchItemFailures) en vez de reintentar el lote entero.
  function_response_types = ["ReportBatchItemFailures"]
  depends_on              = [aws_iam_role_policy.lambda_leer_cola]

  # LocalStack gratis no guarda los tags de este recurso: sin esto, CADA plan diría
  # "1 to change" (agregar los default_tags) aunque ya se aplicó. En AWS real no pasa.
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}
