# AWS DevOps Level 4 Iteration 2 – Roadmap

**Author:** Petter Wastesson
**Project type:** School and APL project
**Status:** Completed and verified
**Last updated:** 2026-08-18

## Status legend

- ✅ Completed
- 🔄 In progress
- ⏳ Planned

## Milestone 1 – Shared Terraform state ✅

- [x] S3 bucket for remote state in `eu-north-1`
- [x] bucket versioning enabled
- [x] `backend.tf` with key `devops.school`, encryption and `use_lockfile`
- [x] bucket name derived from IAM user and forced to lowercase
- [x] local state migrated into S3
- [x] backend files committed to the course branch
- [x] fresh clone reads the same state (`No changes`)

## Milestone 2 – Defect management cycle ✅

- [x] record incidents DMC-L4I2-001 through DMC-L4I2-009
- [x] document symptom, cause and fix for each case
- [x] preserve verification evidence under `DMC/03-evidence/`
- [x] keep scripts and docs on Unix LF

## Milestone 3 – Live verification ✅

- [x] Terraform plan reports no remaining changes
- [x] HTTP check returns `YES` and `Hello Me!`
- [x] verification exit code 0
- [x] runner published to the dedicated GitHub repository

## Milestone 4 – Later Level 4 iterations ⏳

- [ ] continue with later Level 4 course iterations
- [ ] HTTPS and certificate management
- [ ] least-privilege IAM for the state bucket
- [ ] optional CI checks for Terraform and Bash

## Current result

Shared remote state is in place and a fresh clone reuses it without replacing
infrastructure.

- State bucket: `petter.wastesson-apl-devops-terraform-state` (`eu-north-1`, versioning on)
- Backend key: `devops.school`
- Live instance: `i-0099a2a470a02b105`
- Public DNS: `ec2-51-20-81-254.eu-north-1.compute.amazonaws.com`
- Course branch: https://github.com/Nation-devapl/aws-devops-level3-iteration5/tree/Petter.Wastesson
- Dedicated repo: https://github.com/Peppe2236/aws-devops-level4-iteration2
- Defect log: [`DMC/DMC.md`](DMC/DMC.md)
