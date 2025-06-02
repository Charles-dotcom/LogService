terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}


provider "sops" {}

data "aws_caller_identity" "current" {}
output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

data "sops_file" "secrets" {
  source_file = "secrets.json"
}


# DynamoDB Table
resource "aws_dynamodb_table" "logs" {
  name           = "Logs-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ID"
  range_key      = "DateTime"

  attribute {
    name = "ID"
    type = "S"
  }

  attribute {
    name = "PK_GSI"
    type = "S"
  }

  attribute {
    name = "DateTime"
    type = "S"
  }

  global_secondary_index {
    name               = "LogsByTime"
    hash_key           = "PK_GSI"
    range_key          = "DateTime"
    projection_type    = "ALL"
  }

  server_side_encryption {
    enabled = true
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda-policy-${var.environment}"
  role   = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.logs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Function for Receiving Logs
resource "aws_lambda_function" "log_receiver" {
  function_name = "log-receiver-${var.environment}"
  handler       = "handler.log_receiver"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_role.arn
  filename      = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.logs.name
    }
  }
}

# Lambda Function for Retrieving Logs
resource "aws_lambda_function" "get_logs" {
  function_name = "get-logs-${var.environment}"
  handler       = "handler.get_logs"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_role.arn
  filename      = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.logs.name
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "log_service" {
  name        = "log-service-${var.environment}"
  description = "REST API for log service"
}

resource "aws_api_gateway_resource" "logs_resource" {
  rest_api_id = aws_api_gateway_rest_api.log_service.id
  parent_id   = aws_api_gateway_rest_api.log_service.root_resource_id
  path_part   = "logs"
}

# POST Method
resource "aws_api_gateway_method" "post_logs" {
  rest_api_id   = aws_api_gateway_rest_api.log_service.id
  resource_id   = aws_api_gateway_resource.logs_resource.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "post_logs_integration" {
  rest_api_id             = aws_api_gateway_rest_api.log_service.id
  resource_id             = aws_api_gateway_resource.logs_resource.id
  http_method             = aws_api_gateway_method.post_logs.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.log_receiver.invoke_arn
}

# GET Method
resource "aws_api_gateway_method" "get_logs" {
  rest_api_id   = aws_api_gateway_rest_api.log_service.id
  resource_id   = aws_api_gateway_resource.logs_resource.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "get_logs_integration" {
  rest_api_id             = aws_api_gateway_rest_api.log_service.id
  resource_id             = aws_api_gateway_resource.logs_resource.id
  http_method             = aws_api_gateway_method.get_logs.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_logs.invoke_arn
}

# API Key and Usage Plan
resource "aws_api_gateway_api_key" "log_service_key" {
  name  = "log-service-key-${var.environment}"
  value = data.sops_file.secrets.data["api_key"]
}

resource "aws_api_gateway_usage_plan" "log_service_usage_plan" {
  name        = "log-service-usage-plan-${var.environment}"
  api_stages {
    api_id = aws_api_gateway_rest_api.log_service.id
    stage  = aws_api_gateway_stage.log_service_stage.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "log_service_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.log_service_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.log_service_usage_plan.id
}

# API Gateway Deployment and Stage
resource "aws_api_gateway_deployment" "log_service_deployment" {
  rest_api_id = aws_api_gateway_rest_api.log_service.id
  depends_on  = [
    aws_api_gateway_integration.post_logs_integration,
    aws_api_gateway_integration.get_logs_integration
  ]
}

resource "aws_api_gateway_stage" "log_service_stage" {
  deployment_id = aws_api_gateway_deployment.log_service_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.log_service.id
  stage_name    = var.environment
}

# Lambda Permissions for API Gateway
resource "aws_lambda_permission" "api_gateway_log_receiver" {
  statement_id  = "AllowAPIGatewayInvokeLogReceiver"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_receiver.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.log_service.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_get_logs" {
  statement_id  = "AllowAPIGatewayInvokeGetLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_logs.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.log_service.execution_arn}/*/*"
}
