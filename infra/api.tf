# ═══ Paso 4: API Gateway → Lambda ════════════════════════════════════════════
# API Gateway es la "puerta HTTP" de AWS: recibe POST /pedidos de internet y se lo
# pasa a la Lambda como `event`. La Lambda no abre ningún puerto: API Gateway la invoca.
#
#   curl ── POST /dev/pedidos ──▶ API Gateway (REST API) ──invoca──▶ Lambda p1-crear-pedido
#
# Ojo: AWS tiene dos versiones. v2 ("HTTP API") es la más nueva y barata, pero en LocalStack
# gratis solo existe la v1 ("REST API"). La idea es la misma; cambian los nombres de recursos.

# ─── 1. La API ────────────────────────────────────────────────────────────────
resource "aws_api_gateway_rest_api" "api" {
  name = "${var.proyecto}-api"
}

# ─── 2. La ruta /pedidos (cuelga de la raíz "/") ──────────────────────────────
resource "aws_api_gateway_resource" "pedidos" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "pedidos"
}

# ─── 3. El método POST en /pedidos (sin autenticación por ahora; el Lab 9 era Keycloak/JWT) ─
resource "aws_api_gateway_method" "post_pedidos" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.pedidos.id
  http_method   = "POST"
  authorization = "NONE"
}

# ─── 4. La integración: "lo que llegue aquí, pásaselo entero a la Lambda" ─────
# AWS_PROXY = API Gateway no transforma nada: manda la petición completa como `event`
# y devuelve tal cual lo que responda la Lambda ({statusCode, headers, body}).
resource "aws_api_gateway_integration" "post_pedidos" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.pedidos.id
  http_method             = aws_api_gateway_method.post_pedidos.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST" # API Gateway SIEMPRE invoca Lambdas con POST
  uri                     = aws_lambda_function.crear_pedido.invoke_arn
}

# ─── 5. Publicar: un "deployment" es una foto de la API; el "stage" le pone nombre (dev) ─
resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  # Si cambian la ruta, el método o la integración, se crea una foto nueva.
  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.pedidos.id,
      aws_api_gateway_method.post_pedidos.id,
      aws_api_gateway_integration.post_pedidos.id,
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api.id
  stage_name    = "dev"
}

# ─── 6. Permiso: que API Gateway PUEDA invocar la Lambda ──────────────────────
# Sin esto, en AWS real la API respondería 500 "Internal server error".
# Es el permiso "al revés" del rol: el rol dice qué puede hacer la Lambda;
# esto dice quién puede llamar a la Lambda.
resource "aws_lambda_permission" "api" {
  statement_id  = "PermitirApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crear_pedido.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# ─── 7. (Paso 8) Freno de mano en AWS real: máximo de peticiones por segundo ──
# La API no tiene login: cualquiera con la URL puede llamarla. En AWS real eso es plata.
# Con esto, API Gateway responde 429 "Too Many Requests" si pasan de 5/s (ráfagas de 10),
# y la Lambda ni se entera. `count = 0` en LocalStack: ahí no hace falta.
resource "aws_api_gateway_method_settings" "freno" {
  count       = local.en_localstack ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.dev.stage_name
  method_path = "*/*" # todas las rutas y métodos

  settings {
    throttling_rate_limit  = 5
    throttling_burst_limit = 10
  }
}
