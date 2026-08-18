#!/usr/bin/env bash
set -Eeuo pipefail

###########################################################
# Level 4 iteration 2: shared state management (S3 backend)
#
# WSL example:
#   bash /mnt/c/Users/Pette/aws-devops-level4-iteration2/Level4-Iteration2.sh
###########################################################

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

resolve_existing_dir() {
  local candidate

  for candidate in "$@"; do
    [[ -n "$candidate" && -d "$candidate" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done

  return 1
}

DEFAULT_PROJECT_DIR="$(resolve_existing_dir \
  "${PROJECT_DIR:-}" \
  "$HOME/aws-devops-level3-iteration5" \
  "/mnt/c/Users/Pette/aws-devops-level3-iteration5" \
  || true)"
DEFAULT_PROJECT_DIR="${DEFAULT_PROJECT_DIR:-$HOME/aws-devops-level3-iteration5}"

DEFAULT_VERIFY_DIR="$(resolve_existing_dir \
  "${VERIFY_DIR:-}" \
  "$HOME/aws-devops-level3-iteration6" \
  "/mnt/c/Users/Pette/aws-devops-level3-iteration6" \
  || true)"
DEFAULT_VERIFY_DIR="${DEFAULT_VERIFY_DIR:-$HOME/aws-devops-level3-iteration6}"

PROJECT_DIR="${PROJECT_DIR:-$DEFAULT_PROJECT_DIR}"
VERIFY_DIR="${VERIFY_DIR:-$DEFAULT_VERIFY_DIR}"
REPO_URL="${REPO_URL:-https://github.com/Nation-devapl/aws-devops-level3-iteration5.git}"
GIT_BRANCH="${GIT_BRANCH:-Petter.Wastesson}"
AWS_REGION="${AWS_REGION:-eu-north-1}"
VERIFY_MARKER="${VERIFY_MARKER:-Hello Me!}"
MY_SSH="${MY_SSH:-}"

terraform_init() {
  terraform init -input=false -migrate-state -force-copy
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'ERROR: Required command is missing: %s\n' "$command_name" >&2
    exit 1
  fi
}

require_value() {
  local value_name="$1"
  local value="$2"

  if [[ -z "$value" || "$value" == "None" || "$value" == "null" ]]; then
    printf 'ERROR: AWS did not return a valid value for %s.\n' "$value_name" >&2
    exit 1
  fi
}

verify_website() {
  local ec2_dns="$1"
  local attempt http_body

  for attempt in $(seq 1 40); do
    if http_body="$(curl --fail --silent --show-error --location \
      --connect-timeout 5 --max-time 15 "http://${ec2_dns}/" 2>&1)"; then
      if grep -Fq "$VERIFY_MARKER" <<< "$http_body"; then
        printf 'YES\n'
        return 0
      fi
      printf 'HTTP attempt %d returned content without the expected marker.\n' \
        "$attempt" >&2
    else
      printf 'HTTP attempt %d failed: %s\n' "$attempt" "$http_body" >&2
    fi
    sleep 15
  done

  return 1
}

ami_from_state() {
  terraform state show aws_instance.devops-school-level3 2>/dev/null |
    awk '/^[[:space:]]*ami[[:space:]]*=/ { gsub(/"/, "", $3); print $3; exit }'
}

wait_for_instance() {
  local ec2_dns="$1"
  local instance_id

  instance_id="$(aws ec2 describe-instances \
    --filters "Name=dns-name,Values=${ec2_dns}" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || true)"

  if [[ -z "$instance_id" || "$instance_id" == "None" || "$instance_id" == "null" ]]; then
    printf 'Could not resolve instance ID for %s; waiting for HTTP only.\n' "$ec2_dns"
    return 0
  fi

  printf 'Waiting for instance %s to pass status checks...\n' "$instance_id"
  aws ec2 wait instance-running --instance-ids "$instance_id"
  aws ec2 wait instance-status-ok --instance-ids "$instance_id" || true
}

normalize_lf_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  python3 -c 'from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_bytes(path.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n"))' "$file"
}

plan_would_destroy_or_replace() {
  local plan_file="$1"

  terraform show -no-color "$plan_file" |
    grep -Eqi 'must be replaced|forces replacement|will be destroyed'
}

apply_without_replacing() {
  local plan_exit=0

  set +e
  terraform plan -input=false -detailed-exitcode -out=tfplan
  plan_exit=$?
  set -e

  case "$plan_exit" in
    0)
      printf 'No changes. Your infrastructure matches the configuration.\n'
      ;;
    1)
      printf 'ERROR: terraform plan failed.\n' >&2
      exit 1
      ;;
    2)
      if plan_would_destroy_or_replace tfplan; then
        printf 'ERROR: Terraform plan would destroy or replace resources. Apply aborted.\n' >&2
        terraform show -no-color tfplan |
          grep -E 'must be replaced|forces replacement|will be destroyed|Plan:' >&2 || true
        return 0
      fi
      terraform apply -input=false tfplan
      ;;
    *)
      printf 'ERROR: Unexpected terraform plan exit code: %s\n' "$plan_exit" >&2
      exit 1
      ;;
  esac
}

first_existing_value() {
  local candidate

  for candidate in "$@"; do
    if [[ -n "$candidate" && "$candidate" != "None" && "$candidate" != "null" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

lookup_security_group_id() {
  local group_name="$1"

  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${group_name}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true
}

lookup_key_pair() {
  local key_name="$1"

  if aws ec2 describe-key-pairs --key-names "$key_name" >/dev/null 2>&1; then
    printf '%s\n' "$key_name"
    return 0
  fi

  return 1
}

collect_aws_context() {
  export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"

  MY_USER="$(aws sts get-caller-identity --query Arn --output text | awk -F/ '{print $NF}')"
  require_value "MY_USER" "$MY_USER"

  MY_SG="$(first_existing_value \
    "$(lookup_security_group_id "level3.${MY_USER}")" \
    "$(lookup_security_group_id "devops-school-level3")" \
    "$(lookup_security_group_id "aws-devops-level3-sg")" \
    || true)"
  require_value "MY_SG" "$MY_SG"

  MY_VPC="$(aws ec2 describe-security-groups \
    --group-ids "$MY_SG" \
    --query 'SecurityGroups[0].VpcId' \
    --output text)"
  require_value "MY_VPC" "$MY_VPC"

  MY_KEYNAME="$(first_existing_value \
    "$(lookup_key_pair "devops.school.level3.${MY_USER}" || true)" \
    "$(lookup_key_pair "petter-ec2-key" || true)" \
    || true)"
  require_value "MY_KEYNAME" "$MY_KEYNAME"

  if [[ -z "$MY_SSH" ]]; then
    for ssh_candidate in "$HOME/.ssh/id_rsa_level3" "$HOME/.ssh/petter-ec2-key.pem"; do
      if [[ -r "$ssh_candidate" ]]; then
        MY_SSH="$ssh_candidate"
        break
      fi
    done
  fi

  MY_SUBNET="$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${MY_VPC}" "Name=state,Values=available" \
    --query 'sort_by(Subnets,&AvailabilityZone)[0].SubnetId' \
    --output text)"
  MY_AMI="$(aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64 \
    --query Parameter.Value \
    --output text)"

  require_value "MY_SUBNET" "$MY_SUBNET"
  require_value "MY_AMI" "$MY_AMI"

  MY_STATE_BUCKET="$(printf '%s' "$MY_USER" | tr '[:upper:]' '[:lower:]')-apl-devops-terraform-state"

  printf 'Using security group %s in VPC %s\n' "$MY_SG" "$MY_VPC"
  printf 'Using key pair %s\n' "$MY_KEYNAME"
  printf 'Using state bucket %s\n' "$MY_STATE_BUCKET"
}

write_tfvars() {
  cat > terraform.tfvars <<EOF
aws_owner = "${MY_USER}"
ami_id = "${MY_AMI}"
subnet_id = "${MY_SUBNET}"
main_sg_id = "${MY_SG}"
ec2_type = "t3.micro"
ec2_name = "devops-school-level3.${MY_USER}"
keypair = "${MY_KEYNAME}"
EOF
}

ensure_s3_tf() {
  if [[ -f s3.tf ]]; then
    return 0
  fi

  cat > s3.tf <<EOF
resource "aws_s3_bucket" "terraform-state" {
  bucket = "${MY_STATE_BUCKET}"

  tags = {
    Team        = "APL"
    ManagedBy   = "terraform"
    Environment = var.ec2_name
  }
}

resource "aws_s3_bucket_versioning" "devops-terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  versioning_configuration {
    status = "Enabled"
  }
}
EOF
}

write_backend_tf() {
  cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket       = "${MY_STATE_BUCKET}"
    key          = "devops.school"
    region       = "${AWS_REGION}"
    encrypt      = true
    use_lockfile = true
  }
}
EOF
}

ensure_repo() {
  if [[ ! -d "$PROJECT_DIR/.git" ]]; then
    printf 'Cloning %s into %s\n' "$REPO_URL" "$PROJECT_DIR"
    git clone "$REPO_URL" "$PROJECT_DIR"
  fi

  cd "$PROJECT_DIR"

  if git show-ref --verify --quiet "refs/heads/${GIT_BRANCH}"; then
    git checkout "$GIT_BRANCH"
  elif git show-ref --verify --quiet "refs/remotes/origin/${GIT_BRANCH}"; then
    git checkout -B "$GIT_BRANCH" "origin/${GIT_BRANCH}"
  else
    git checkout -B "$GIT_BRANCH"
  fi
}

phase_create_state_backend() {
  printf '\n=== Phase 1: create S3 state bucket and migrate local state ===\n'

  ensure_repo
  collect_aws_context
  write_tfvars
  ensure_s3_tf
  normalize_lf_file "user-data.web.sh"

  terraform_init
  terraform plan -out=tfplan
  terraform apply "tfplan"

  write_backend_tf
  terraform_init

  MY_EC2="$(terraform output -raw ec2_public_dns_name)"
  require_value "MY_EC2" "$MY_EC2"
  wait_for_instance "$MY_EC2"

  if verify_website "$MY_EC2"; then
    printf 'Deploy verification exit code: 0\n'
  else
    printf 'Deploy verification exit code: 1\n' >&2
    exit 1
  fi
}

phase_commit_and_push() {
  printf '\n=== Phase 2: commit shared-state files to branch %s ===\n' "$GIT_BRANCH"

  cd "$PROJECT_DIR"
  git add s3.tf user-data.web.sh .gitattributes
  git add -f backend.tf

  if git diff --cached --quiet; then
    printf 'No staged changes to commit.\n'
  else
    git -c "user.name=${GIT_AUTHOR_NAME:-Petter Wastesson}" \
      -c "user.email=${GIT_AUTHOR_EMAIL:-Petterwastesson@gmail.com}" \
      commit -m "level 4 - iteration 2 - shared state"
    git push -u origin "$GIT_BRANCH"
  fi
}

phase_verify_fresh_clone() {
  printf '\n=== Phase 3: verify shared state from a fresh clone ===\n'

  rm -rf "$VERIFY_DIR"
  mkdir -p "$VERIFY_DIR"
  git clone "$REPO_URL" "$VERIFY_DIR/aws-devops-level3-iteration5"
  cd "$VERIFY_DIR/aws-devops-level3-iteration5"
  git checkout "$GIT_BRANCH"

  collect_aws_context
  write_backend_tf
  terraform_init
  normalize_lf_file "user-data.web.sh"

  STATE_AMI="$(ami_from_state || true)"
  if [[ -n "$STATE_AMI" ]]; then
    MY_AMI="$STATE_AMI"
    printf 'Reusing AMI from Terraform state: %s\n' "$MY_AMI"
  fi

  write_tfvars
  apply_without_replacing

  MY_EC2="$(terraform output -raw ec2_public_dns_name)"
  require_value "MY_EC2" "$MY_EC2"
  wait_for_instance "$MY_EC2"

  if verify_website "$MY_EC2"; then
    printf 'Fresh-clone verification exit code: 0\n'
  else
    printf 'Fresh-clone verification exit code: 1\n' >&2
    exit 1
  fi
}

main() {
  require_command aws
  require_command terraform
  require_command curl
  require_command git
  require_command awk
  require_command python3

  case "${1:-all}" in
    create)
      phase_create_state_backend
      ;;
    commit)
      phase_commit_and_push
      ;;
    verify)
      phase_verify_fresh_clone
      ;;
    all)
      phase_create_state_backend
      phase_commit_and_push
      phase_verify_fresh_clone
      ;;
    *)
      printf 'Usage: %s [create|commit|verify|all]\n' "$0" >&2
      exit 1
      ;;
  esac
}

main "$@"
