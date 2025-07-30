variable "aws_region" {
  description = "The aws region to use"
  type        = string
  default     = "us-west-2"
}

variable "bucket_name" {
  description = "The name of the bucket to use for static hosting"
  type        = string
  default     = "merapar-challenge-s3"
}

variable "initial_string" {
  description = "The initial value of the dynamic string"
  type        = string
  default     = "initial value"
}

variable "ssm_parameter_name" {
  default = "/dynamic-html/value"
}
