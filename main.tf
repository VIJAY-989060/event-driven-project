# main.tf
provider "aws" {
  region = "ap-south-1"
}

# Create S3 bucket for uploading CSVs
resource "aws_s3_bucket" "data_bucket" {
  bucket = "event-driven-data-pipeline-bucket-vijay"
  force_destroy = true
  tags = {
    Name = "Data Upload Bucket"
  }
}

# iam.tf
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "sns_publish_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_access_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# lambda.tf
resource "aws_lambda_function" "ingest_lambda" {
  function_name = "ingest_lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "ingest_lambda.handler"
  runtime       = "python3.9"
  filename      = "./lambda_zips/ingest_lambda.zip"
  source_code_hash = filebase64sha256("./lambda_zips/ingest_lambda.zip")
  timeout       = 30
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.report_topic.arn
    }
  }
}

resource "aws_lambda_function" "report_lambda" {
  function_name = "report_lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "report_lambda.handler"
  runtime       = "python3.9"
  filename      = "./lambda_zips/report_lambda.zip"
  source_code_hash = filebase64sha256("./lambda_zips/report_lambda.zip")
  timeout       = 60
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.report_topic.arn
    }
  }
}

# sns.tf
resource "aws_sns_topic" "report_topic" {
  name = "daily-report-topic"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.report_topic.arn
  protocol  = "email"
  endpoint  = "vjjaiwal@gmail.com"
}

# eventbridge.tf
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "daily-report-trigger"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "reportLambda"
  arn       = aws_lambda_function.report_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

# s3 trigger permission
data "aws_iam_policy_document" "s3_lambda_trigger" {
  statement {
    effect = "Allow"
    actions = ["lambda:InvokeFunction"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    resources = [aws_lambda_function.ingest_lambda.arn]
    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = [aws_s3_bucket.data_bucket.arn]
    }
  }
}

resource "aws_lambda_permission" "s3_invoke_lambda" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_bucket.arn
}

resource "aws_s3_bucket_notification" "s3_lambda_notification" {
  bucket = aws_s3_bucket.data_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.ingest_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.s3_invoke_lambda]
}

