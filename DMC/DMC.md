# DMC – Level 4 Iteration 2

**Projekt:** AWS DevOps Level 4 Iteration 2 (delad Terraform-state)
**Författare:** Petter Wastesson
**Datum:** 2026-08-18
**Status:** Avslutad och verifierad

Arbetslogg för iterationen. Källskriptet ligger i repots rot som
`Level4-Iteration2.sh`. Terraform-projektet körs från kursklonens branch
`Petter.Wastesson`.

## Resultat

- S3-bucket: `petter.wastesson-apl-devops-terraform-state` (eu-north-1, versionering på)
- `backend.tf`: key `devops.school`, `encrypt`, `use_lockfile`
- Ny klon läser samma state: `No changes`
- HTTP: `YES`, `Hello Me!`, exitkod 0
- Instans efter replacement: `i-0099a2a470a02b105`
- DNS: `ec2-51-20-81-254.eu-north-1.compute.amazonaws.com`
- Kursbranch: https://github.com/Nation-devapl/aws-devops-level3-iteration5/tree/Petter.Wastesson
- Detta repo: https://github.com/Peppe2236/aws-devops-level4-iteration2

## Defekter och incidenter

### DMC-L4I2-001 – WSL-sökväg saknas

**Symptom:** Skriptet hittade inte projektet under `~/aws-devops-level3-iteration5`.

**Orsak:** Filerna ligger på Windows-disken, inte i Ubuntus hemkatalog. WSL
ser dem under `/mnt/c/Users/Pette/...`.

**Åtgärd:** Runnern söker både `$HOME/aws-devops-level3-iteration5` och
`/mnt/c/Users/Pette/aws-devops-level3-iteration5`. Sökvägen kan också sättas
med `PROJECT_DIR` / `VERIFY_DIR`.

### DMC-L4I2-002 – CRLF i Bash-skript

**Symptom:** `set: pipefail` och ogiltiga optionsnamn när Bash körde skriptet.

**Orsak:** Windows radbrytningar (CRLF). Bash tolkar `\r` som en del av
optionsnamnet.

**Åtgärd:** Unix LF i skript och dokument. `.gitattributes` sätter `eol=lf`
för `.sh` och `.md`. `user-data.web.sh` normaliseras före plan/apply.

### DMC-L4I2-003 – AWS-session utgången

**Symptom:** AWS-anrop misslyckades med utgången session.

**Orsak:** Ingen giltig inloggning i Ubuntu/WSL.

**Åtgärd:** `aws login` i Ubuntu innan runnern körs. Region `eu-north-1`.

### DMC-L4I2-004 – InvalidGroup.NotFound

**Symptom:** Terraform/AWS hittade inte security group
`level3.Petter.Wastesson`.

**Orsak:** Skolans namnmönster matchar inte den SG som faktiskt finns.

**Åtgärd:** Lookup faller tillbaka till befintlig grupp
`devops-school-level3` (`sg-09cf45c3a28bba35f`) och nyckelpar
`petter-ec2-key`.

### DMC-L4I2-005 – Ogiltigt S3-bucketnamn

**Symptom:** Bucketnamnet `Petter.Wastesson-apl-devops-terraform-state`
avvisades.

**Orsak:** S3-bucketnamn får inte innehålla versaler.

**Åtgärd:** IAM-användarnamnet lowercasas innan suffixet
`-apl-devops-terraform-state` läggs på. Rätt namn:
`petter.wastesson-apl-devops-terraform-state`.

### DMC-L4I2-006 – migrate-state kan inte fråga ja

**Symptom:** `terraform init -migrate-state -input=false` stannade för att den
inte fick bekräfta kopiering av state.

**Orsak:** `-input=false` blockerar interaktiv fråga, men init behöver ändå
ett ja för att flytta state.

**Åtgärd:** `terraform init -input=false -migrate-state -force-copy`.

### DMC-L4I2-007 – Tom Git-identitet i Ubuntu

**Symptom:** `git commit` i Ubuntu misslyckades med tom user.name / user.email.

**Orsak:** Windows `gitconfig` används inte av Git i WSL.

**Åtgärd:** Commit med `git -c user.name="Petter Wastesson" -c
user.email="Petterwastesson@gmail.com"` för just den committen.

### DMC-L4I2-008 – Phase 3 ersatte EC2 och HTTP vägrade anslutning

**Symptom:** `terraform apply -auto-approve` i verify-fasen ersatte instansen.
`i-0597a85128b85c3ed` förstördes och `i-0099a2a470a02b105` skapades. Curl
misslyckades 12 gånger med connection refused mot port 80.

**Orsak:** `user_data` hade CRLF/whitespace-skillnad mot state, och
`user_data_replace_on_change` tvingade replacement. Den nya instansen var
inte klar med yum/Ansible/nginx när HTTP-kollen kördes.

**Åtgärd:** Se DMC-L4I2-009. Den nya instansen
`i-0099a2a470a02b105` /
`ec2-51-20-81-254.eu-north-1.compute.amazonaws.com` är den som sedan
verifierades.

### DMC-L4I2-009 – Skydd mot oönskad replacement och för kort HTTP-väntan

**Symptom:** Verify-fasen kunde stilla ersätta EC2 och ge connection refused
innan nginx lyssnade.

**Orsak:** Ny AMI från SSM, CRLF i user-data, apply utan replace-guard, och
för få HTTP-försök.

**Åtgärd:**

- återanvänd AMI från Terraform state
- normalisera `user-data.web.sh` till LF
- `apply_without_replacing` avbryter apply om planen skulle destroy/replace
- vänta på instance status checks
- HTTP-retry i ungefär 10 minuter (40 försök à 15 s)

### DMC-L4I2-010 – Slutverifiering

**Symptom:** Inte en defekt. Ny körning av verify behövdes efter åtgärd 008/009.

**Orsak:** Replacement och HTTP-timeout i första verify-försöket.

**Åtgärd:** `bash .../Level4-Iteration2.sh verify` lyckades: `No changes`,
`YES`, `Hello Me!`, exitkod 0.

## Evidence

Korta verifieringsanteckningar ligger i `03-evidence/`.
