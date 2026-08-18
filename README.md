# AWS DevOps Level 4 Iteration 2

Standalone repo for Petter Wastesson's completed **Level 4 Iteration 2** work: **shared Terraform state** in S3.

The Terraform project itself still lives in the course clone (`aws-devops-level3-iteration5` on branch `Petter.Wastesson`). This repository is the Ubuntu/WSL runner that creates the S3 backend, migrates state, and verifies a fresh clone can reuse that state without replacing infrastructure.

## Shared S3 state

The script:

1. Looks up your AWS user, security group, VPC, subnet, AMI, and key pair
2. Creates an S3 bucket named `{iam-user}-apl-devops-terraform-state` (lowercased)
3. Enables versioning and writes `backend.tf` with native S3 locking (`use_lockfile = true`)
4. Runs `terraform init -migrate-state` so local state moves into S3
5. Commits `s3.tf` / `backend.tf` to the course branch (Nation-devapl)
6. Clones the repo again into a clean directory and confirms Terraform reuses the same state

No AWS credentials, `terraform.tfstate`, or `.terraform/` directories are stored in this GitHub repo.

## Run from Ubuntu / WSL

Clone and run:

```bash
git clone https://github.com/Peppe2236/aws-devops-level4-iteration2.git
cd aws-devops-level4-iteration2
bash Level4-Iteration2.sh
```

Verify only (fresh clone against existing shared state):

```bash
bash Level4-Iteration2.sh verify
```

Other phases: `create`, `commit`, `all` (default).

### WSL path note

If you keep the files on the Windows drive, the Ubuntu path is:

```bash
bash /mnt/c/Users/Pette/aws-devops-level4-iteration2/Level4-Iteration2.sh
```

The runner looks for the Terraform project in:

- `~/aws-devops-level3-iteration5`
- `/mnt/c/Users/Pette/aws-devops-level3-iteration5`

Override with `PROJECT_DIR` / `VERIFY_DIR` if needed. Requires `aws`, `terraform`, `curl`, `git`, `awk`, and `python3`, plus an AWS session for `eu-north-1`.
