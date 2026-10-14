# Outputs = lo que tofu te muestra al terminar (y lo que otros programas pueden leer
# con `tofu output`). Las Lambdas del paso 3 van a necesitar estos nombres/URLs.

output "tabla_pedidos" {
  value = aws_dynamodb_table.pedidos.name
}

output "cola_url" {
  value = aws_sqs_queue.pedidos.url
}

output "cola_arn" {
  description = "ARN = el 'nombre completo' de un recurso en AWS: arn:aws:sqs:region:cuenta:nombre"
  value       = aws_sqs_queue.pedidos.arn
}

output "dlq_url" {
  value = aws_sqs_queue.pedidos_dlq.url
}

output "lambda_crear_pedido" {
  value = aws_lambda_function.crear_pedido.function_name
}

output "api_id" {
  value = aws_api_gateway_rest_api.api.id
}

# La URL cambia según dónde esté desplegado:
#   AWS real:   https://<api_id>.execute-api.us-east-1.amazonaws.com/dev/pedidos  (invoke_url del stage)
#   LocalStack: una ruta especial que no necesita DNS
output "url_pedidos" {
  value = local.en_localstack ? "${var.endpoint}/restapis/${aws_api_gateway_rest_api.api.id}/${aws_api_gateway_stage.dev.stage_name}/_user_request_/pedidos" : "${aws_api_gateway_stage.dev.invoke_url}/pedidos"
}

output "destino" {
  description = "Dónde quedó desplegado esto"
  value       = local.en_localstack ? "LocalStack (${var.endpoint})" : "AWS REAL (${var.region})"
}

output "lambda_procesar_pedido" {
  value = aws_lambda_function.procesar_pedido.function_name
}
