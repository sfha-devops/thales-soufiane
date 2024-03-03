
provider "aws" {
  region     = var.aws_region
  access_key = var.access_key
  secret_key = var.secret_key
  default_tags {
    tags = {
      "tf:stackid" = "kubeadm-cluster"
    }
  }
}
