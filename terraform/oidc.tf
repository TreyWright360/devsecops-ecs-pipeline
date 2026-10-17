# ==============================================================================
# AWS IAM OpenID Connect (OIDC) Identity Provider for GitHub Actions
# SOC 2 CC6.1 / CC6.2: Eliminates permanent static IAM access keys in CI/CD
# ==============================================================================

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# ------------------------------------------------------------------------------
# IAM Role Assumed by GitHub Actions Runners via Short-Lived STS Tokens
# ------------------------------------------------------------------------------
resource "aws_iam_role" "github_actions_ecs_deployer" {
  name        = "github-actions-ecs-deployer"
  description = "Scoped role for GitHub Actions to authenticate via OIDC and deploy to ECS"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Strictly restrict deployment rights to this repository's main branch & PRs
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# Least-Privilege IAM Policy for ECR Push & ECS Fargate Task Updates
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "github_actions_permissions" {
  name        = "github-actions-ecs-deploy-policy"
  description = "Allows pushing signed containers to ECR and updating ECS task definitions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRImagePushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "ECSDeployment"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMPassRoleToECS"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_deployer" {
  role       = aws_iam_role.github_actions_ecs_deployer.name
  policy_arn = aws_iam_policy.github_actions_permissions.arn
}

output "github_actions_role_arn" {
  description = "Configure this ARN as AWS_ROLE_ARN secret in your GitHub repository"
  value       = aws_iam_role.github_actions_ecs_deployer.arn
}
