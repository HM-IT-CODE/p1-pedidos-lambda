# ─── 1. ¿Qué herramienta y qué "plugin" usamos? ───────────────────────────────
# OpenTofu (o Terraform: es el mismo lenguaje) lee TODOS los .tf de esta carpeta
# como si fueran un solo archivo. El orden de los archivos da igual.
terraform {
  required_version = ">= 1.6"
  required_providers {
    # El "provider" es el plugin que sabe hablar con la API de AWS.
    # `tofu init` lo descarga dentro de .terraform/
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Paso 3: para armar el .zip de la Lambda (data "archive_file").
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# ─── 2. ¿A qué AWS nos conectamos? (paso 8) ───────────────────────────────────
# El MISMO código despliega en dos lugares. Lo decide el "workspace" de tofu:
#
#   workspace "default" → LocalStack (en mini o en el CI)      ← lo de siempre
#   workspace "aws"     → AWS real con tus credenciales
#
# Cada workspace tiene su PROPIO estado (terraform.tfstate.d/aws/...), así que lo de
# LocalStack y lo de AWS real nunca se mezclan. Para cambiar:
#   tofu -chdir=infra workspace select aws       (o: workspace new aws, la 1.ª vez)
#   tofu -chdir=infra workspace select default
locals {
  en_localstack = terraform.workspace != "aws"
}

provider "aws" {
  region = var.region

  # LocalStack acepta cualquier clave. En AWS real se dejan en null y el SDK usa
  # tus credenciales de ~/.aws (aws configure) — NUNCA se escriben en este archivo.
  access_key = local.en_localstack ? "test" : null
  secret_key = local.en_localstack ? "test" : null

  # Con LocalStack no se validan las claves contra AWS ni se pregunta el n.º de cuenta.
  skip_credentials_validation = local.en_localstack
  skip_metadata_api_check     = local.en_localstack
  skip_requesting_account_id  = local.en_localstack

  # `dynamic` = este bloque existe solo si la lista tiene algo.
  # En LocalStack: un bloque endpoints apuntando al 4566. En AWS real: ninguno
  # (el provider usa las URLs oficiales: dynamodb.us-east-1.amazonaws.com, etc.).
  dynamic "endpoints" {
    for_each = local.en_localstack ? [1] : []
    content {
      dynamodb   = var.endpoint
      sqs        = var.endpoint
      iam        = var.endpoint
      sts        = var.endpoint
      lambda     = var.endpoint # paso 3
      logs       = var.endpoint # paso 3: logs de la Lambda (CloudWatch Logs)
      apigateway = var.endpoint # paso 4 (REST API, v1)
    }
  }

  # Todo lo creado queda etiquetado: en AWS real así lo encuentras en la consola
  # y en la factura (Billing → Cost Explorer → filtrar por tag proyecto = p1).
  default_tags {
    tags = {
      proyecto   = var.proyecto
      creado_por = "opentofu"
    }
  }
}
