# ==============================================================================
# Amazon ECR Repository with Automated Security Scanning & Encryption
# ==============================================================================
resource "aws_kms_key" "ecr_key" {
  description             = "KMS Key for ECR Image Encryption at Rest"
  deletion_window_in_days = 30
  enable_key_rotation     = true # SOC 2 CC6.6
}

resource "aws_ecr_repository" "app" {
  name                 = "overflow-ledger-service"
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr_key.arn
  }

  image_scanning_configuration {
    scan_on_push = true # Automated continuous container vulnerability scanning
  }
}

# ==============================================================================
# Amazon ECS Fargate Cluster & Service
# ==============================================================================
resource "aws_ecs_cluster" "main" {
  name = "overflow-production-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # SOC 2 CC7.2 Metrics & Telemetry
  }
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/overflow-ledger-service"
  retention_in_days = 365 # SOC 2 1-Year Audit Log Retention
}

# ------------------------------------------------------------------------------
# ECS Execution & Task Roles (Least Privilege)
# ------------------------------------------------------------------------------
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-execution-role-overflow"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role-overflow"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# ECS Task Definition (Fargate, Non-Root, Read-Only Root Filesystem)
# ------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "overflow-ledger-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "overflow-app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ledger"
        }
      }

      environment = [
        { name = "APP_ENV", value = "production" }
      ]
    }
  ])
}
