# ADR 003: EKS cluster design

Status: Accepted
Date: 2026-10-27

## Context
The platform needs a Kubernetes cluster to run workloads on. It must work
across two availability zones, be reproducible from code, and stay cheap
because it is created and destroyed between work sessions.

## Decision
- Amazon EKS, so AWS runs and upgrades the control plane across zones.
- One managed node group (two `t3.medium` nodes) in the private subnets,
  one node per zone. AWS handles node provisioning and rolling updates.
- Nodes sit in private subnets only. They reach the internet through the
  per-zone NAT gateways and reach S3 through the gateway endpoint.
- Cluster access uses the API authentication mode (access entries) with
  `bootstrap_cluster_creator_admin_permissions`, so the identity that
  creates the cluster is admin and no aws-auth ConfigMap is needed.
- Kubernetes version, instance types, and node counts are module variables
  with defaults, so other environments can override them.
- The module is called from `envs/dev`, which also applies default tags
  (`Environment`, `Project`, `ManagedBy`) to every resource.

## Consequences
- Running cost is roughly $0.27 an hour with the whole environment up (cluster
  fee, two NAT gateways, two nodes), so it must be destroyed after each
  session.
- A cluster left on a Kubernetes version past standard support is billed at a
  much higher extended-support rate, so the version needs to stay current.
- Pods get VPC addresses, so the `/24` private subnets cap how large the
  cluster can grow.
- Access is tied to whichever identity ran the apply. Other identities (for
  example a CI role) need their own access entries.

## Known gaps (deliberately deferred)
- The API endpoint is public (authentication is still required). It should be
  restricted to known IP ranges or made private-only.
- Control plane logging is off.
- Kubernetes secrets are not encrypted with a customer-managed KMS key.
- The CNI policy is attached to the node role. AWS recommends attaching it to
  a role used by the `aws-node` service account instead.
- No OIDC provider or Pod Identity yet, which pods will need to get their
  own AWS permissions.
- Add-ons (CNI, CoreDNS, kube-proxy) use EKS defaults and are not pinned.

## Alternatives considered
- Fargate: no nodes to manage, but costs more per pod and limits what can run.
- Self-managed nodes: more control, but you own the patching and replacement.
- One node: cheaper, but one failure or upgrade takes every pod down.