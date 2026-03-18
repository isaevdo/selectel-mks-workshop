# Шаг 3: Kubernetes — деплой приложения

**Время:** ~10–15 минут
**Что делаем:** Запускаем приложение Coffee Shop в кластере MKS

---

## Основные сущности Kubernetes (читайте манифесты!)

```
Pod          — минимальная единица: один или несколько контейнеров вместе
Deployment   — управляет подами: сколько, какой образ, как обновлять
Service      — стабильный сетевой адрес для группы подов
```

---

## Файлы этого шага

```
step-3-kubernetes/
├── deployment.yaml  ← описание приложения (прочитайте комментарии!)
├── service.yaml     ← сетевой доступ внутри кластера
└── pvc.yaml         ← пример постоянного диска (в воркшопе не применяется)
```

---

## Выполнение

### 0. Убедитесь, что kubectl подключён к кластеру

```bash
kubectl get nodes
# Должен быть узел в статусе Ready
```

### 1. Создайте namespace

Namespace изолирует ресурсы нашего приложения от системных компонентов кластера:

```bash
kubectl create namespace workshop
```

### 2. Создайте секрет для доступа к реестру

Kubernetes нужен токен CRaaS, чтобы скачать образ из приватного реестра.
Используйте токен, который Terraform создал автоматически на шаге 1.

```bash
# Получите токен из Terraform (из папки step-1-terraform):
CRAAS_TOKEN=$(cd ../step-1-terraform && terraform output -raw craas_token)

# Создайте секрет в Kubernetes:
kubectl create secret docker-registry craas-auth \
  --docker-server=cr.selcloud.ru \
  --docker-username=token \
  --docker-password=${CRAAS_TOKEN} \
  --namespace=workshop
```

> Секрет сохраняется в зашифрованном виде в etcd.
> Deployment ссылается на него через `imagePullSecrets: - name: craas-auth`.

### 3. Обновите адрес образа в deployment.yaml

Откройте `deployment.yaml` и замените в строке `image:`:
```
image: cr.selcloud.ru/coffee-shop-registry/coffee-shop:latest
```
На адрес вашего реестра из вывода terraform (шаг 1).

### 4. Примените манифесты

```bash
cd step-3-kubernetes

kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

> `apply` — идемпотентная команда: создаёт ресурс, если не существует,
> или обновляет, если уже есть. Можно запускать сколько угодно раз.

### 5. Следите за запуском

```bash
# Статус подов в namespace workshop (обновляется в реальном времени)
kubectl get pods -n workshop -w

# Ожидаемый итог:
# NAME                           READY   STATUS    RESTARTS   AGE
# coffee-shop-7d9f8b9c4-xk2mn   1/1     Running   0          30s
```

> Статусы пода по порядку:
> `Pending` → `ContainerCreating` → `Running`
> Если застряло в `ImagePullBackOff` — проверьте секрет и адрес образа.

---

## Проверка результата

```bash
# Посмотреть все ресурсы в namespace workshop
kubectl get deployment,pod,service -n workshop

# Логи контейнера (убедиться, что nginx запустился)
kubectl logs deployment/coffee-shop -n workshop

# Временно открыть доступ к приложению через port-forward
kubectl port-forward service/coffee-shop-svc 8080:80 -n workshop
# Откройте http://localhost:8080 в браузере
```

---

## Полезные команды для изучения

```bash
# Детали пода (события, ресурсы, volume mounts)
kubectl describe pod <имя-пода>

# Зайти внутрь контейнера (как SSH)
kubectl exec -it <имя-пода> -- sh

# Посмотреть манифест ресурса в кластере
kubectl get deployment coffee-shop -o yaml
```

---

## Что происходит после `kubectl apply`

```
kubectl apply -f deployment.yaml
        │
        ↓
  API Server (принимает манифест)
        │
        ↓
  Scheduler (выбирает узел для пода)
        │
        ↓
  kubelet на узле (скачивает образ из CRaaS, запускает контейнер)
        │
        ↓
  Pod Running ✓
```

---

## Устранение проблем

### ImagePullBackOff — образ не скачивается
```bash
kubectl describe pod <имя-пода>
# Смотрите секцию Events внизу
```
Причины и решения:
- **wrong secret** — пересоздайте секрет с правильными данными:
  ```bash
  kubectl delete secret craas-auth -n workshop
  CRAAS_TOKEN=$(cd ../step-1-terraform && terraform output -raw craas_token)
  kubectl create secret docker-registry craas-auth \
    --docker-server=cr.selcloud.ru \
    --docker-username=token \
    --docker-password=${CRAAS_TOKEN} \
    --namespace=workshop
  ```
- **неверный адрес образа** — проверьте строку `image:` в deployment.yaml, должно совпадать с `registry_endpoint` из шага 1

### Pod в статусе Pending — не запускается
```bash
kubectl describe pod <имя-пода>
# Ищите Events: "Insufficient cpu/memory" или "no nodes available"
```
- Если `Insufficient cpu/memory` — узел слишком мал, проверьте, что node_cpus=2, node_ram_mb=4096

### CrashLoopBackOff — контейнер падает сразу после старта
```bash
kubectl logs <имя-пода> --previous
# Покажет логи упавшего контейнера
```

**Переходите к шагу 4!** →
