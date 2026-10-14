# ═══ Paso 8: los logs de las Lambdas (CloudWatch Logs) ═══════════════════════
# Cada console.log de una Lambda va a un "log group" llamado /aws/lambda/<función>.
# Si no lo creamos nosotros, la Lambda lo crea sola la primera vez... con retención
# INFINITA (los logs se guardan y se cobran para siempre, y `tofu destroy` no lo borra).
# Creándolo aquí: retención de 7 días y se borra con destroy.
resource "aws_cloudwatch_log_group" "crear_pedido" {
  name              = "/aws/lambda/${var.proyecto}-crear-pedido"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "procesar_pedido" {
  name              = "/aws/lambda/${var.proyecto}-procesar-pedido"
  retention_in_days = 7
}
