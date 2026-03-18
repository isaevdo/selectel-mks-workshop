# Воркшоп: Managed Kubernetes в Selectel

**Для кого:** Отдел продаж Selectel
**Цель:** Руками пройти полный путь клиента — от создания кластера до публикации приложения в интернет.
**Время:** ~60–70 минут

---

## Что мы строим

Кофейное веб-приложение **Coffee Shop** — простая HTML-страница, обслуживаемая nginx.
Весь путь: Terraform → Docker → Kubernetes → Интернет.

```
[Terraform]         [Docker]           [Kubernetes]        [Envoy Gateway]
создать кластер  →  собрать образ  →  задеплоить  →  опубликовать в интернет
MKS + CRaaS         coffee-shop:latest  Deployment+Service   HTTPRoute + LoadBalancer
```

---

## Предварительные требования

Установите на локальную машину:
- [VS Code](https://code.visualstudio.com/) или любой текстовый редактор — для чтения файлов с комментариями и редактирования `terraform.tfvars`
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 3.0

Нужен аккаунт Selectel с доступом к:
- Managed Kubernetes (MKS)
- Container Registry (CRaaS)
- Баланс на облачной платформе — не менее **10 000 ₽** (кластер и реестр тарифицируются с момента создания)

---

## Шаги воркшопа

| Шаг | Папка | Что делаем | Время |
|-----|-------|-----------|-------|
| 1 | `step-1-terraform/` | Создаём кластер MKS и реестр CRaaS через Terraform | ~15–20 мин |
| 2 | `step-2-docker/` | Собираем Docker-образ и пушим в CRaaS | ~10–15 мин |
| 3 | `step-3-kubernetes/` | Деплоим приложение в кластер | ~10–15 мин |
| 4 | `step-4-gateway/` | Публикуем приложение в интернет через Envoy Gateway | ~15–20 мин |

---

## Переменные, которые понадобятся

В ходе воркшопа вам будут нужны эти значения. Заполните сейчас:

```
SELECTEL_ACCOUNT_NAME=___________   # имя аккаунта (например, 123456_ivanov)
SELECTEL_PASSWORD=___________       # пароль от панели управления
PROJECT_ID=___________              # ID проекта (будет создан в шаге 1)
REGISTRY_ENDPOINT=___________       # адрес реестра (будет создан в шаге 1)
CLUSTER_NAME=coffee-shop-cluster
REGISTRY_NAME=coffee-shop-registry
```

---

## Что вы увидите в панели Selectel после воркшопа

- **Облачная платформа → Kubernetes** — работающий кластер `coffee-shop-cluster`
- **Облачная платформа → Container Registry** — реестр с образом `coffee-shop:latest`
- Приложение, доступное по публичному IP в браузере

---

> Не пишем код — читаем готовые файлы с комментариями и выполняем команды.
> На каждом шаге есть проверка результата.
