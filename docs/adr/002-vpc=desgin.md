# ADR 002: VPC design

## Context
The platform needs a network that keeps workloads private by default and
can host a Kubernetes cluster later.

## Decision
- One VPC, `10.0.0.0/16`, built as a reusable Terraform module.
- Two availability zones, each with one public and one private `/24` subnet.
- Public subnets route to an internet gateway. Private subnets have no
  internet route.
- A free S3 gateway endpoint on the private route table.
- No NAT gateway for now.

## Consequences
- Workloads in private subnets are not reachable from the internet.
- Private subnets can reach S3 but nothing else outside the VPC. A NAT
  gateway or interface endpoints will be needed before EKS nodes can pull
  images and talk to AWS APIs.
- Costs nothing while idle.
- `/24` private subnets are small for Kubernetes, where each pod takes a
  VPC IP. We may need larger subnets when EKS is added.