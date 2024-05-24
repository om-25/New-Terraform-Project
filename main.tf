# main.tf

provider "aws" {
  region = "us-west-2"  # specify your AWS region
}

resource "aws_s3_bucket" "mwaa_bucket" {
  bucket = "my-mwaa-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "log"
    enabled = true

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_policy" "mwaa_bucket_policy" {
  bucket = aws_s3_bucket.mwaa_bucket.bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.mwaa_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role" "mwaa_execution_role" {
  name = "mwaa_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "airflow.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "mwaa_execution_policy" {
  role = aws_iam_role.mwaa_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.mwaa_bucket.arn}",
          "${aws_s3_bucket.mwaa_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_mwaa_environment" "example" {
  name                = "example-mwaa-environment"
  airflow_version     = "2.2.2"
  environment_class   = "mw1.small"
  execution_role_arn  = aws_iam_role.mwaa_execution_role.arn
  source_bucket_arn   = aws_s3_bucket.mwaa_bucket.arn
  dag_s3_path         = "dags"
  network_configuration {
    security_group_ids = [aws_security_group.mwaa_sg.id]
    subnet_ids         = [aws_subnet.public1.id, aws_subnet.public2.id]
  }

  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }

    scheduler_logs {
      enabled   = true
      log_level = "INFO"
    }

    task_logs {
      enabled   = true
      log_level = "INFO"
    }

    webserver_logs {
      enabled   = true
      log_level = "INFO"
    }

    worker_logs {
      enabled   = true
      log_level = "INFO"
    }
  }

  weekly_maintenance_window_start = "SUN:03:00"
}

resource "aws_security_group" "mwaa_sg" {
  name        = "mwaa_security_group"
  description = "Security group for MWAA"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "public1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "public2"
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main"
  }
}
