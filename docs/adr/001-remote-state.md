# ADR 001: Remote Terraform state

Status: Accepted
Date: 2026-10-27

## Context
Terraform records every resource it creates in a state file. By default that
file sits on one laptop, so losing the laptop means losing track of the
infrastructure, and two people (or a laptop and a pipeline) cannot safely run
Terraform against the same environment. The project is worked on from more
than one computer and will later be applied from CI.

## Decision
- Store state in an S3 bucket, with one state file per environment
  (`dev/terraform.tfstate`, and later `prod/terraform.tfstate`).
- Turn on versioning, server-side encryption, and a full public access block
  on the bucket. State can contain sensitive values.
- Use native S3 state locking (`use_lockfile`, Terraform 1.10 or newer), so
  two runs cannot write the same state at once. No DynamoDB table is needed.
- Create the bucket in a separate `bootstrap` project. A bucket cannot hold
  the state of the project that creates it, so `bootstrap` keeps its own
  state locally.
- Environments connect to the bucket with a backend block in `envs/<env>`.

## Consequences
- The state survives the loss of any one computer, and old versions can be
  restored if a state file is damaged.
- `bootstrap` state lives on one machine. It is small and rarely changes, but
  it must not be deleted, and the bucket must never be destroyed.
- The bucket name must be globally unique, so it includes the account ID.
- Anyone who can read the bucket can read the state, so access to it needs to
  stay restricted.
- Every new environment needs its own backend block with a different key.


## Known gaps (deliberately deferred)
- The `bootstrap` state is not in the bucket. It could be migrated once
  everything else is stable.
- The bucket uses S3-managed encryption keys, not a customer-managed KMS key.
- No access logging and no replication to a second region.
- State and infrastructure share one AWS account. Larger setups keep state in
  a separate account.
- The bucket's encryption finding (AWS-0132, no customer-managed key) is
  accepted, with an inline `trivy:ignore` comment in `bootstrap/main.tf`.

## Alternatives considered
- Local state: simplest, but not shared and easy to lose.
- S3 with a DynamoDB lock table: the older approach to locking. It works, but
  adds a resource that native locking makes unnecessary.
- Terraform Cloud or another hosted backend: removes the bucket setup, but adds
  an outside service, and managing the bucket is itself worth showing.
- Creating the bucket by hand in the console: quick, but then the most
  important piece of the setup is not in code and cannot be reproduced.