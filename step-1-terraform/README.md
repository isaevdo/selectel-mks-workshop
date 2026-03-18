# Шаг 1: Terraform — кластер и реестр

**Время:** ~15–20 минут
**Что создаём:** Кластер MKS + реестр CRaaS в облаке Selectel

---

## Что такое Terraform?

Terraform позволяет описать инфраструктуру в виде кода и создать её одной командой.
Вместо ручных кликов в панели управления — текстовые файлы, которые можно версионировать в git,
передавать коллегам, воспроизводить на другом аккаунте.

**Клиенты Selectel используют Terraform**, чтобы автоматизировать создание кластеров,
управлять множеством сред (dev/staging/prod) и встраивать инфраструктуру в CI/CD.

---

## Файлы этого шага

```
step-1-terraform/
├── main.tf                   ← главный файл: описывает что создать
├── variables.tf              ← объявления переменных
└── terraform.tfvars.example  ← шаблон для ваших значений (скопируйте!)
```

---

## Выполнение

### 0. Создайте сервисного пользователя (делается один раз)

Terraform v6 работает через **сервисного пользователя** (IAM), а не через логин от панели.

**В панели Selectel:**
1. Перейдите: **Управление доступами → Сервисные пользователи → Создать сервисного пользователя**
2. Имя: `terraform-user` (или любое)
3. Назначьте две роли на уровне **аккаунта**:
   - `Member` — для создания проекта и управления ресурсами
   - `iam.admin` — для создания сервисных пользователей через Terraform
4. Сохраните логин и пароль — они нужны для `selectel_username` и `selectel_password`

Второй сервисный пользователь (для OpenStack API) Terraform создаст **автоматически** — просто придумайте пароль для `openstack_password` в `terraform.tfvars`.

> `selectel_domain` — ID аккаунта (только цифры, без суффикса). Найти в правом верхнем углу панели.

### 1. Подготовьте переменные

```bash
# Перейдите в папку шага
cd step-1-terraform

# Создайте файл с вашими данными
cp terraform.tfvars.example terraform.tfvars

# Откройте и заполните: selectel_domain, selectel_username, selectel_password
nano terraform.tfvars
```

> **Важно:** `openstack_password` — минимум **20 символов**, заглавные/строчные буквы, цифры, спецсимволы.
> Пример: `W0rksh0p#S3cur3!2024xy`
> Несоответствие требованиям вызовет ошибку `insecure_password` или `invalid_length_password` при `terraform apply`.

### 2. Инициализируйте Terraform

```bash
terraform init
```

> Terraform скачает провайдер Selectel v6 и OpenStack (~нескольких секунд).
> Вы увидите: `Terraform has been successfully initialized!`
>
> Если ранее запускали `init` и видите ошибку версии провайдера — удалите кеш и повторите:
> ```bash
> rm -rf .terraform .terraform.lock.hcl
> terraform init
> ```

### 3. Посмотрите план изменений

```bash
terraform plan
```

> `plan` показывает, что Terraform **собирается** сделать, ничего не трогая.
> Прочитайте вывод: `+ create` — значит ресурс будет создан.
> Итог внизу: `Plan: 9 to add, 0 to change, 0 to destroy.`

### 4. Примените план

```bash
terraform apply
```

> Terraform снова покажет план и спросит подтверждение.
> Введите `yes` и нажмите Enter.
> Создание кластера занимает **8–12 минут** — это нормально.

---

## Проверка результата

После завершения Terraform выведет:

```
Outputs:
project_id        = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
cluster_id        = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
registry_endpoint = "cr.selcloud.ru/coffee-shop-registry"
craas_token       = <sensitive>
```

**Сохраните `registry_endpoint` и токен** — они нужны на шаге 2!

```bash
# Получить токен (выведет значение в терминал):
terraform output -raw craas_token
```

Проверьте в панели Selectel:
- **Облачная платформа → Kubernetes** — виден кластер `coffee-shop-cluster`
- **Облачная платформа → Container Registry** — виден реестр `coffee-shop-registry`

---

## Подключение kubectl к кластеру

После создания кластера нужно получить kubeconfig — файл с ключами доступа:

```bash
# Через панель управления: Kubernetes → ваш кластер → "Получить kubeconfig"
# Скачайте файл и выполните:

export KUBECONFIG=~/Downloads/kubeconfig.yaml

# Проверьте подключение:
kubectl get nodes
```

> Ожидаемый вывод:
> ```
> NAME          STATUS   ROLES    AGE   VERSION
> worker-xxxx   Ready    <none>   5m    v1.30.x
> ```

---

## Что происходит "под капотом"

```
terraform apply
     │
     ├── Создаёт проект в Selectel (2–3 сек)
     ├── Создаёт мастер-узлы Kubernetes (4–6 мин) ← Selectel управляет ими
     ├── Создаёт рабочий узел (2–4 мин)
     └── Создаёт реестр контейнеров (10–20 сек)
```

**Переходите к шагу 2!** →
