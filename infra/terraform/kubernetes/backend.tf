terraform {
  backend "s3" {
    bucket                      = "terraform-state" # Name of the MinIO bucket
    key                         = "kubernetes/terraform.tfstate" # Path to the state file in the bucket
    endpoint                    = var.minio_endpoint # MinIO API endpoint
    access_key                  = var.minio_access_key # MinIO access key
    secret_key                  = var.minio_secret_key # MinIO secret key
    region                      = "us-east-1" # Arbitrary region (MinIO ignores this)
    skip_credentials_validation = true # Skip AWS-specific credential checks
    skip_metadata_api_check     = true # Skip AWS metadata API checks
    skip_region_validation      = true # Skip AWS region validation
    use_path_style              = true # Use path-style URLs[](http://<host>/<bucket>)
  }
}