# Azure-3-tier-Network
Azure/Terrafrom project. Creates a 3 tier network with separate NSG for each. 


# Azure 3-Tier Network (East US 2)

Creates its own resource group, VNet, 3 subnets (web / compute / db), one NSG per tier, and a
Network Watcher with VNet flow logs.

## Run
Prereqs: Terraform + Azure CLI, then `az login`.

    run-dev.cmd plan        run-prod.cmd plan
    run-dev.cmd apply       run-prod.cmd apply
    run-dev.cmd destroy     run-prod.cmd destroy

(Or: `.\run.ps1 -Environment dev -Action apply`)

## Ports
| Tier | Allowed in |
|---|---|
| Web | 443, 80 from the internet |
| Compute | 8080 from the web subnet only |
| DB | 1433 from the compute subnet only |

Everything else inbound is denied. Change ports in `variables.tf` defaults or in the tfvars files.

## Files
- `main.tf` everything that gets built
- `variables.tf` / `outputs.tf`
- `dev.tfvars` / `prod.tfvars` Dev / Prod
- `run.ps1`, `run-dev.cmd`, `run-prod.cmd` runners (state is kept per env: `dev.tfstate`, `prod.tfstate`)
