# ADR 002: VPC design

Status: Accepted
Date: 2026-10-29

## Context
The platform needs a network that keeps workloads private by default,
survives the loss of one availability zone, and can host an EKS cluster. It is
also a learning environment that is destroyed between sessions, so cost while
idle matters.

## Decision
- One VPC, `10.0.0.0/16`, built as a reusable Terraform module
  (`modules/vpc`). The VPC range and subnet ranges are inputs, so dev and prod
  can differ. In dev, the public subnets are `10.0.1.0/24` and `10.0.2.0/24`,
  and the private subnets are `10.0.11.0/24` and `10.0.12.0/24`.
- Two availability zones (`us-east-1a` and `us-east-1b`), each with one public
  and one private subnet.
- Public subnets route to an internet gateway. They do not hand out public IP
  addresses automatically (`map_public_ip_on_launch = false`), so anything that
  needs a public address has to ask for one.
- Private subnets have no internet route unless the NAT gateways are enabled.
- One NAT gateway per zone, each with its own Elastic IP and placed in that
  zone's public subnet. Each zone has its own private route table that points
  at the NAT gateway in the same zone.
- The NAT gateways are behind an `enable_nat_gateway` variable. The module
  default is `false`, so the VPC costs nothing until something needs outbound
  access. Dev sets it to `true` because EKS nodes need it.
- A free S3 gateway endpoint on both private route tables, so S3 traffic does
  not use the NAT gateways.
- Subnets are tagged for Kubernetes load balancer discovery
  (`kubernetes.io/role/elb` on public, `kubernetes.io/role/internal-elb` on
  private).
- DNS support and DNS hostnames are enabled, which EKS requires.

## Consequences
- Losing one zone does not remove the other zone's path to the internet.
- Two NAT gateways cost roughly double one and bill hourly while they exist, so
  the environment should be destroyed between sessions.
- With the NAT switch off, nothing in the private subnets can reach the
  internet, and EKS nodes cannot join a cluster.
- A security scan flagged automatic public IPs on the public subnets. They were
  turned off, which makes public exposure an explicit choice.
- Private `/24` subnets hold about 250 addresses each. EKS gives every pod a VPC
  address, so a larger cluster will need bigger private subnets.

## Known gaps (deliberately deferred)
- No VPC flow logs.
- No interface endpoints (for example ECR or STS), so image pulls and AWS API
  calls from the nodes go through the NAT gateways and incur data charges.
- Private subnets share the default network ACL rules.

## Alternatives considered
- Single NAT gateway: cheaper, but zone b depends on zone a for outbound
  traffic. Reasonable for a throwaway environment, not for prod.
- No NAT, with interface endpoints only: avoids NAT cost, but needs an endpoint
  per AWS service and cannot reach the public internet.
- Larger private subnets (`/20`): better for Kubernetes growth, but more to
  explain and plan. Deferred until the cluster needs it.