
variable "aws_region" {
  default = "us-east-1"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "" # If empty, no SSH key will be assigned
}
