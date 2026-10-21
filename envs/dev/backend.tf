terraform {
    backend "s3" {
        bucket = "platform-tfstate-495759894456"
        key = "dev/terraform.tfstate"
        region = "us-east-1"
        use_lockfile = true
        profile = "dev"
    }
}