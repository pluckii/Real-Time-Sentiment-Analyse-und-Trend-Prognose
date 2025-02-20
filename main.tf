provider "aws" {
  region = "us-east-1"
}

resource "aws_kinesis_stream" "sentiment_stream" {
  name             = "sentiment-analysis-stream"
  shard_count      = 1
  retention_period = 24
}

resource "aws_s3_bucket" "sentiment_bucket" {
  bucket = "real-time-sentiment-analysis-bucket"
  acl    = "private"
}

resource "aws_iam_role" "kinesis_role" {
  name = "kinesis_execution_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "kinesis_policy" {
  name        = "kinesis_read_write_policy"
  description = "Policy for Kinesis read/write access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:DescribeStream",
        "kinesis:GetRecords",
        "kinesis:GetShardIterator",
        "kinesis:ListStreams",
        "kinesis:PutRecord",
        "kinesis:PutRecords"
      ],
      "Resource": "${aws_kinesis_stream.sentiment_stream.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "kinesis_policy_attach" {
  role       = aws_iam_role.kinesis_role.name
  policy_arn = aws_iam_policy.kinesis_policy.arn
}

resource "aws_lambda_function" "sentiment_lambda" {
  function_name    = "sentiment-analysis-lambda"
  role            = aws_iam_role.kinesis_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.8"
  s3_bucket       = aws_s3_bucket.sentiment_bucket.id
  s3_key          = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")
  
  environment {
    variables = {
      KINESIS_STREAM = aws_kinesis_stream.sentiment_stream.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "kinesis_trigger" {
  event_source_arn  = aws_kinesis_stream.sentiment_stream.arn
  function_name     = aws_lambda_function.sentiment_lambda.arn
  starting_position = "LATEST"
}

resource "aws_iam_role" "sagemaker_role" {
  name = "sagemaker-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sagemaker.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "sagemaker_s3_cloudwatch_policy" {
  name        = "SageMakerS3CloudWatchPolicy"
  description = "Allows SageMaker to access S3 and CloudWatch Logs"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-s3-bucket",
        "arn:aws:s3:::your-s3-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_s3_cloudwatch" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = aws_iam_policy.sagemaker_s3_cloudwatch_policy.arn
}
