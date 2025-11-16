terraform {
  backend "gcs" {
    bucket  = "gcloud-and-terraform-tfstate"
    prefix  = "terraform/state"
  }
}

