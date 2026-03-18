# ==============================================================================
# ГЛАВНЫЙ ФАЙЛ TERRAFORM
# ==============================================================================
# Что создаёт этот файл:
#   1. Проект в Selectel
#   2. Сервисного пользователя для OpenStack API
#   3. Приватную сеть и подсеть
#   4. Роутер (выход узлов кластера в интернет)
#   5. Кластер Managed Kubernetes (MKS)
#   6. Группу узлов (worker nodes)
#   7. Реестр контейнеров (Container Registry / CRaaS)
# ==============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    selectel = {
      source  = "selectel/selectel"
      version = "~> 6.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "2.1.0"
    }
  }
}

# --- Провайдер Selectel ---
# auth_region — пул, в котором расположены эндпоинты. Должен совпадать с region.
provider "selectel" {
  domain_name = var.selectel_domain
  username    = var.selectel_username
  password    = var.selectel_password
  auth_url    = "https://cloud.api.selcloud.ru/identity/v3/"
  auth_region = var.region
}

# --- Провайдер OpenStack ---
provider "openstack" {
  auth_url    = "https://cloud.api.selcloud.ru/identity/v3"
  domain_name = var.selectel_domain
  tenant_id   = selectel_vpc_project_v2.workshop_project.id
  user_name   = selectel_iam_serviceuser_v1.openstack_user.name
  password    = selectel_iam_serviceuser_v1.openstack_user.password
  region      = var.region
}

# ==============================================================================
# РЕСУРС 1: Проект Selectel
# ==============================================================================

resource "selectel_vpc_project_v2" "workshop_project" {
  name = var.project_name
}

# ==============================================================================
# РЕСУРС 2: Сервисный пользователь для OpenStack
# ==============================================================================
# OpenStack API требует пользователя, привязанного к конкретному проекту.
# Terraform создаёт его автоматически и передаёт credentials в OpenStack провайдер.

resource "selectel_iam_serviceuser_v1" "openstack_user" {
  name     = var.openstack_username
  password = var.openstack_password

  # Роль member на уровне проекта — минимальные права для управления сетью и кластером
  role {
    role_name  = "member"
    scope      = "project"
    project_id = selectel_vpc_project_v2.workshop_project.id
  }
}

# ==============================================================================
# РЕСУРСЫ 3–4: Приватная сеть и подсеть
# ==============================================================================
# Узлы кластера работают в приватной сети. В интернет они выходят через роутер.

resource "openstack_networking_network_v2" "network" {
  name           = "${var.cluster_name}-network"
  admin_state_up = true
  tenant_id      = selectel_vpc_project_v2.workshop_project.id

  depends_on = [
    selectel_vpc_project_v2.workshop_project,
    selectel_iam_serviceuser_v1.openstack_user,
  ]
}

resource "openstack_networking_subnet_v2" "subnet" {
  name            = "${var.cluster_name}-subnet"
  network_id      = openstack_networking_network_v2.network.id
  tenant_id       = selectel_vpc_project_v2.workshop_project.id
  cidr            = "192.168.0.0/24"
  dns_nameservers = ["188.93.16.19", "188.93.17.19"]
  enable_dhcp     = false
}

# ==============================================================================
# РЕСУРСЫ 5–6: Роутер
# ==============================================================================
# Роутер соединяет приватную сеть с внешней (интернет).
# Без него узлы кластера не смогут скачивать образы из CRaaS и других реестров.

# Находим внешнюю сеть (публичную сеть Selectel) — она уже существует
data "openstack_networking_network_v2" "external_network" {
  external = true

  # depends_on заставляет Terraform отложить этот запрос до apply,
  # когда сервисный пользователь уже создан и OpenStack-провайдер может аутентифицироваться.
  depends_on = [
    selectel_iam_serviceuser_v1.openstack_user,
  ]
}

# Создаём роутер с подключением к внешней сети
resource "openstack_networking_router_v2" "router" {
  name                = "${var.cluster_name}-router"
  external_network_id = data.openstack_networking_network_v2.external_network.id
  tenant_id           = selectel_vpc_project_v2.workshop_project.id
}

# Подключаем подсеть к роутеру
resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

# ==============================================================================
# DATA SOURCE: Актуальные версии Kubernetes
# ==============================================================================
# Автоматически получаем последнюю поддерживаемую версию — не нужно следить вручную.

data "selectel_mks_kube_versions_v1" "versions" {
  project_id = selectel_vpc_project_v2.workshop_project.id
  region     = var.region
}

# ==============================================================================
# РЕСУРС 7: Кластер Managed Kubernetes (MKS)
# ==============================================================================
# Selectel управляет control plane. Мы управляем только worker nodes.

resource "selectel_mks_cluster_v1" "cluster" {
  name       = var.cluster_name
  project_id = selectel_vpc_project_v2.workshop_project.id
  region     = var.region

  kube_version = data.selectel_mks_kube_versions_v1.versions.latest_version

  network_id = openstack_networking_network_v2.network.id
  subnet_id  = openstack_networking_subnet_v2.subnet.id

  # Окно обслуживания: время в UTC, когда Selectel может применять обновления
  maintenance_window_start = "00:00:00"

  enable_autorepair                 = true
  enable_patch_version_auto_upgrade = true
}

# ==============================================================================
# РЕСУРС 8: Группа узлов (Node Group)
# ==============================================================================

resource "selectel_mks_nodegroup_v1" "nodegroup" {
  cluster_id        = selectel_mks_cluster_v1.cluster.id
  project_id        = selectel_mks_cluster_v1.cluster.project_id
  region            = selectel_mks_cluster_v1.cluster.region
  availability_zone = "${var.region}a"

  nodes_count = var.node_count

  # flavor_id — тип виртуальной машины для узла.
  # Список доступных flavor: панель Selectel → Kubernetes → Создать группу узлов
  flavor_id = var.node_flavor_id

  volume_gb   = 32
  volume_type = "fast.${var.region}a"

  install_nvidia_device_plugin = false
}

# ==============================================================================
# РЕСУРС 9: Реестр контейнеров (Container Registry / CRaaS)
# ==============================================================================

resource "selectel_craas_registry_v1" "registry" {
  name       = var.registry_name
  project_id = selectel_vpc_project_v2.workshop_project.id
}

# ==============================================================================
# РЕСУРС 10: Токен для доступа к реестру
# ==============================================================================
# Токен нужен для docker login и для imagePullSecret в Kubernetes.
# mode_rw = true — токен с правами чтения и записи (push + pull).
# all_registries = true — действует для всех реестров проекта.

resource "selectel_craas_token_v2" "registry_token" {
  project_id     = selectel_vpc_project_v2.workshop_project.id
  name           = "${var.registry_name}-token"
  mode_rw        = true
  all_registries = true
  registry_ids   = []
  is_set         = true
  expires_at     = "2029-01-01T00:00:00Z"
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "project_id" {
  description = "ID созданного проекта"
  value       = selectel_vpc_project_v2.workshop_project.id
}

output "cluster_id" {
  description = "ID кластера MKS"
  value       = selectel_mks_cluster_v1.cluster.id
}

output "kube_version" {
  description = "Версия Kubernetes в кластере"
  value       = data.selectel_mks_kube_versions_v1.versions.latest_version
}

output "registry_endpoint" {
  description = "Адрес реестра контейнеров (для docker push/pull)"
  value       = selectel_craas_registry_v1.registry.endpoint
}

output "craas_token" {
  description = "Токен для docker login и imagePullSecret в Kubernetes"
  value       = selectel_craas_token_v2.registry_token.token
  sensitive   = true
}

output "next_step_hint" {
  description = "Подсказка для следующего шага"
  value       = "Запустите: terraform output -raw craas_token — и сохраните токен для шага 2!"
}
