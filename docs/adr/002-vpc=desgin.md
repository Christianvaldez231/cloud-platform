# ADR 002: VPC design

Status: Accepted
Date: 2026-10-27

## Context
The platform needs a network that keeps workloads private by default,
survives the loss of one availability zone, and can host a Kubernetes
cluster (EKS). It is also a learning environment that is torn down between
sessions, so cost while idle matters.

## Decision
- One VPC, `10.0.0.0/16`, built as a reusable Terraform module. Environments
  pass in their own ranges, so dev and prod can differ.
- Two availability zones, each with one public and one private `/24` subnet.
- Public subnets route to an internet gateway. Private subnets have no
  internet route unless the NAT gateways are enabled.
- One NAT gateway per zone. Each zone has its own private route table that
  points at the NAT gateway in the same zone.
- NAT gateways are behind an `enable_nat_gateway` variable that defaults to
  `false`, so the VPC costs nothing until a cluster needs outbound access.
- A free S3 gateway endpoint on the private route tables, so S3 traffic
  skips the NAT gateways.
- Subnets are tagged for Kubernetes load balancer discovery
  (`kubernetes.io/role/elb` and `kubernetes.io/role/internal-elb`).

## Consequences
- Losing one zone does not remove the other zone's path to the internet.
- Two NAT gateways cost roughly double one, and they bill hourly while they
  exist, so the environment should be destroyed between sessions.
- With the NAT switch off, nothing in the private subnets can reach the
  internet. EKS nodes cannot join the cluster until it is on.
- `/24` private subnets hold about 250 addresses each. EKS gives every pod a
  VPC address, so a larger cluster will need bigger private subnets.

## Alternatives considered
- Single NAT gateway: cheaper, but zone b depends on zone a for outbound
  traffic. Reasonable for a throwaway environment, not for prod.
- No NAT, with VPC interface endpoints only: avoids NAT cost, but needs an
  endpoint per AWS service and still cannot reach the public internet.