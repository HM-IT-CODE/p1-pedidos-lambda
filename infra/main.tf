# ═══ Paso 2: la base de datos y la cola ══════════════════════════════════════
# Sintaxis:  resource "<tipo de recurso>" "<nombre interno en tofu>" { ... }
#   - el tipo dice QUÉ se crea en AWS (una tabla, una cola...)
#   - el nombre interno es solo para referirse a él dentro de estos archivos

# ─── Tabla DynamoDB "p1-pedidos" ──────────────────────────────────────────────
# DynamoDB NO es como Postgres/SQL Server: no defines columnas.
# Solo defines la CLAVE (por qué se busca). Cada item puede traer los campos que quiera.
resource "aws_dynamodb_table" "pedidos" {
  name         = "${var.proyecto}-pedidos" # ${...} = interpolar una variable -> "p1-pedidos"
  billing_mode = "PAY_PER_REQUEST"         # pagas por cada lectura/escritura, sin reservar capacidad
  hash_key     = "id"                      # la clave primaria (partition key)

  attribute {
    name = "id"
    type = "S" # S = string, N = number, B = binario
  }

  tags = { proyecto = var.proyecto }
}

# ─── Cola de errores (DLQ = Dead Letter Queue) ────────────────────────────────
# Si un mensaje falla 3 veces, SQS lo aparta aquí en vez de reintentarlo para siempre.
resource "aws_sqs_queue" "pedidos_dlq" {
  name                      = "${var.proyecto}-pedidos-nuevos-dlq"
  message_retention_seconds = 1209600 # 14 días guardados para revisarlos
}

# ─── Cola principal "p1-pedidos-nuevos" ───────────────────────────────────────
resource "aws_sqs_queue" "pedidos" {
  name                       = "${var.proyecto}-pedidos-nuevos"
  visibility_timeout_seconds = 30 # mientras alguien procesa un mensaje, los demás no lo ven por 30 s

  # Referencia a OTRO recurso: aws_sqs_queue.pedidos_dlq.arn
  # Por esto tofu sabe que debe crear la DLQ ANTES que esta cola (grafo de dependencias).
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.pedidos_dlq.arn
    maxReceiveCount     = 3
  })

  tags = { proyecto = var.proyecto }
}
