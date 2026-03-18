# ==============================================================================
# ПЕРЕМЕННЫЕ TERRAFORM
# ==============================================================================
# Значения задаются в файле terraform.tfvars (скопируйте из .example)
# ==============================================================================

# --- Аутентификация сервисного пользователя Selectel ---

variable "selectel_domain" {
  description = "ID аккаунта Selectel (только цифры, без суффикса, например: 123456)"
  type        = string
}

variable "selectel_username" {
  description = "Имя сервисного пользователя Selectel (IAM → Сервисные пользователи)"
  type        = string
}

variable "selectel_password" {
  description = "Пароль сервисного пользователя Selectel"
  type        = string
  sensitive   = true
}

# --- Сервисный пользователь для OpenStack API ---
# Terraform создаёт этого пользователя автоматически и использует его для
# управления сетью и другими OpenStack-ресурсами внутри проекта.

variable "openstack_username" {
  description = "Имя сервисного пользователя для OpenStack (будет создан Terraform'ом)"
  type        = string
  default     = "workshop-openstack-user"
}

variable "openstack_password" {
  description = "Пароль сервисного пользователя для OpenStack"
  type        = string
  sensitive   = true
}

# --- Настройки проекта ---

variable "project_name" {
  description = "Название проекта, который будет создан в Selectel"
  type        = string
  default     = "workshop-coffee-shop"
}

# --- Настройки кластера MKS ---

variable "cluster_name" {
  description = "Название кластера Kubernetes"
  type        = string
  default     = "coffee-shop-cluster"
}

variable "region" {
  description = "Регион Selectel (ru-9 = Москва, ru-1 = Санкт-Петербург)"
  type        = string
  default     = "ru-9"
}

# --- Настройки узлов (нод) кластера ---

variable "node_count" {
  description = "Количество рабочих узлов. Для воркшопа достаточно 1."
  type        = number
  default     = 1
}

variable "node_flavor_id" {
  description = <<-EOT
    ID типа виртуальной машины для узла кластера.
    Список доступных flavor: панель Selectel → Kubernetes → Создать группу узлов.
    Пример для ru-9: "1013" (проверьте актуальные значения в панели).
  EOT
  type        = string
  default     = "1013"
}

# --- Настройки Container Registry (CRaaS) ---

variable "registry_name" {
  description = "Название реестра. Станет частью адреса: cr.selcloud.ru/<name>"
  type        = string
  default     = "coffee-shop-registry"
}
