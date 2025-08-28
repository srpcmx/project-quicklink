terraform {
   required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40" # o la más reciente que uses en tu entorno
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
  required_version = ">= 1.6.0"
}

provider "aws" {
  region = "us-east-1" // Or your preferred region
}