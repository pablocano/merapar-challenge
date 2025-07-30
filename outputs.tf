output "website_url" {
  description = "The endpoint where the web page is going to be hosted"
  value       = aws_s3_bucket_website_configuration.web_configuration.website_endpoint
}

output "ssm_parameter_name" {
  description = "The location of the dynamic string in ssm"
  value       = aws_ssm_parameter.dynamic_string.name
}