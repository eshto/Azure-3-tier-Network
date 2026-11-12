variable "workload" {
  description = "Short app name used in resource names (max 10)."
  type        = string
  default     = "app"
}

variable "environment" {
  description = "dev or prod."
  type        = string
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "vnet_cidr" {
  description = "VNet range. Web/app/db subnets are carved from it automatically (x.x.1.0/24, x.x.2.0/24, x.x.3.0/24)."
  type        = string
}

variable "app_port" {
  description = "Port the web tier uses to reach the compute tier."
  type        = string
  default     = "8080"
}

variable "db_port" {
  description = "Port the compute tier uses to reach the DB (1433 SQL Server, 5432 PostgreSQL, 3306 MySQL)."
  type        = string
  default     = "1433"
}

variable "flow_log_days" {
  type    = number
  default = 30
}

variable "use_existing_network_watcher" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
