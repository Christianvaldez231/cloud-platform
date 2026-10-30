# ADR 003: EKS cluster design

Status: Accepted
Date: 2026-10-29

## Context
The platform needs a Kubernetes cluster to run workloads on. It must work
across two availability zones, be reproducible from code, and stay cheap
because it is created and destroyed between work sessions.

## Decision
- Amazon EKS, so AWS runs and upgrades the control plane across zones.
- One managed node group in the private subnets, with nodes spread across both
  zones. Dev runs two `t3.medium` nodes. AWS handles provisioning and rolling
  updates.
- Nodes sit in private subnets only. They reach the internet through the
  per-zone NAT gateways and reach S3 through the gateway endpoint.
- The cluster's private endpoint is on, so nodes talk to the control plane
  through network interfaces inside the VPC and not through the NAT gateways.
- The cluster's public endpoint stays on, restricted to a single allowed
  address (a `/32`) supplied by the calling environment. This keeps `kubectl`
  working from outside the VPC.
- Cluster access uses the API authentication mode (access entries) with
  `bootstrap_cluster_creator_admin_permissions`, so the identity that creates
  the cluster is admin and no aws-auth ConfigMap is needed.
- Kubernetes version, instance types, and node counts are module variables
  with defaults, so other environments can override them.
- `envs/dev` applies default tags (`Environment`, `Project`, `ManagedBy`) to
  every resource and re-exports the cluster name as an output.

## Security scan results
A Trivy scan runs on every pull request. Three findings on the cluster are
accepted on purpose, using inline `trivy:ignore` comments above the cluster
resource:
- AWS-0039 (no customer-managed key for secrets): EKS already encrypts all
  Kubernetes API data by default with an AWS-owned key. Owning the key is
  deferred until the cluster holds real secrets.
- AWS-0040 and AWS-0041 (public endpoint enabled, with a public address in the
  allowlist): the endpoint is limited to one address, nodes use the private
  endpoint, and every request still needs valid credentials. Private-only access
  needs a VPN, bastion, or runner inside the VPC.

## Consequences
- Running cost is roughly $0.27 an hour with the whole environment up (cluster
  fee, two NAT gateways, two nodes), so it must be destroyed after each
  session.
- If the allowed address changes (new network, new ISP address), `kubectl` is
  locked out until the value is updated and applied. AWS console and CLI access
  is not affected.
- A cluster left on a Kubernetes version past standard support is billed at a
  much higher extended-support rate, so the version needs to stay current.
- Pods get VPC addresses, so the `/24` private subnets cap how large the
  cluster can grow.
- Cluster admin access is tied to whichever identity ran the apply. Other
  identities, such as a CI role, need their own access entries.
- Two nodes in two zones is the intended spread, but placement is not
  guaranteed. It was verified with
  `kubectl get nodes -L topology.kubernetes.io/zone`.

## Known gaps (deliberately deferred)
- The public endpoint is still on. The target is private-only access once there
  is a way into the VPC.
- Kubernetes secrets use the default AWS-owned key, not a customer-managed one.
- Control plane logging is off.
- The CNI policy is attached to the node role. AWS recommends attaching it to a
  role used by the `aws-node` service account instead.
- No OIDC provider or Pod Identity yet, which pods will need to get their own
  AWS permissions.
- Add-ons (CNI, CoreDNS, kube-proxy) use EKS defaults and are not pinned.

## Alternatives considered
- Fargate: no nodes to manage, but costs more per pod and limits what can run.
- Self-managed nodes: more control, but you own the patching and replacement.
- One node: cheaper, but one failure or upgrade takes every pod down.
- Private-only endpoint now: stronger, but needs extra infrastructure to reach
  the cluster at this stage.