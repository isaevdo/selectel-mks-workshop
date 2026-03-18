# Шаг 4: Envoy Gateway — публикация в интернет

**Время:** ~15–20 минут
**Что делаем:** Устанавливаем Envoy Gateway и открываем приложение по публичному IP

---

## Зачем нужен Gateway?

После шага 3 приложение работает, но доступно только внутри кластера.
Чтобы пользователи попали на него из интернета, нужен входной узел (Ingress/Gateway).

```
Пользователь
    │
    ↓ http://1.2.3.4 (публичный IP)
[Load Balancer Selectel]
    │
    ↓
[Envoy Gateway] ← читает Gateway + HTTPRoute манифесты
    │
    ↓ (по правилам HTTPRoute)
[Service coffee-shop-svc]
    │
    ↓
[Pod coffee-shop]
```

---

## Файлы этого шага

```
step-4-gateway/
├── envoy-class.yaml  ← EnvoyProxy + GatewayClass (применить первым!)
├── gateway.yaml      ← точка входа (порт 80, протокол HTTP)
└── httproute.yaml    ← правило: весь трафик → coffee-shop-svc
```

---

## Выполнение

### 1. Установите Envoy Gateway через Helm

```bash
# Устанавливаем Envoy Gateway из OCI-реестра DockerHub
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.1 \
  --namespace envoy-gateway-system \
  --create-namespace

# Дожидаемся готовности
kubectl wait --timeout=5m \
  -n envoy-gateway-system \
  deployment/envoy-gateway \
  --for=condition=Available
```

> Helm — менеджер пакетов для Kubernetes. Как apt/brew, но для Kubernetes-приложений.
> "Chart" — пакет с манифестами и настройками.
> Envoy Gateway распространяется через OCI-реестр (`oci://`), поэтому `helm repo add` не нужен.

### 2. Проверьте установку

```bash
# Поды Envoy Gateway должны быть Running
kubectl get pods -n envoy-gateway-system
# NAME                             READY   STATUS    RESTARTS   AGE
# envoy-gateway-xxxxxxxxx-xxxxx    1/1     Running   0          1m
```

> Если поды не Running — проверьте логи:
> `kubectl logs -n envoy-gateway-system deployment/envoy-gateway`

### 3. Создайте EnvoyProxy и GatewayClass

Helm-установка **не создаёт** GatewayClass автоматически. Нужно применить вручную:

```bash
cd step-4-gateway

kubectl apply -f envoy-class.yaml
```

Проверьте, что GatewayClass принят:

```bash
kubectl get gatewayclass
# NAME   CONTROLLER                        ACCEPTED   AGE
# eg     gateway.envoyproxy.io/gatewaycon  True       30s
```

> Если `ACCEPTED` не `True` — подождите 30 секунд и повторите.

### 4. Примените Gateway и HTTPRoute

```bash
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
```

### 4. Дождитесь публичного IP

```bash
# Проверяем статус Gateway — ждём появления EXTERNAL-IP
kubectl get gateway coffee-shop-gateway -n workshop -w

# Или смотрим на Service, который создал Envoy Gateway
kubectl get service -n envoy-gateway-system -w
```

> Selectel автоматически создаёт Load Balancer и выдаёт публичный IP.
> Обычно занимает **1–2 минуты**.
>
> Ожидаемый вывод:
> ```
> NAME                    TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)
> envoy-default-eg-xxxx   LoadBalancer   10.96.x.x     213.x.x.x      80:xxxxx/TCP
> ```

### 5. Откройте приложение в браузере!

```bash
# Получите IP
EXTERNAL_IP=$(kubectl get svc -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-name=coffee-shop-gateway \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

echo "Открывайте: http://${EXTERNAL_IP}"
```

---

## Проверка результата

```bash
# Проверить через curl
curl http://${EXTERNAL_IP}
# Должен вернуть HTML нашей страницы Coffee Shop

# Посмотреть статус HTTPRoute
kubectl describe httproute coffee-shop-route
# В секции Status должно быть: Accepted / ResolvedRefs
```

Откройте `http://<EXTERNAL_IP>` в браузере — должна появиться страница Coffee Shop!

---

## Что мы построили

```
[Terraform]       →    MKS кластер + CRaaS реестр
[Docker]          →    Образ coffee-shop в реестре
[Kubernetes]      →    Deployment + Service (3 реплики)
[Envoy Gateway]   →    Публичный доступ через Load Balancer
```

Именно этот стек продаём клиентам как единую экосистему Selectel.

---

## Cleanup — удалить всё после воркшопа

```bash
# Удалить ресурсы Kubernetes
kubectl delete -f step-4-gateway/
kubectl delete -f step-3-kubernetes/
helm uninstall eg -n envoy-gateway-system

# Удалить инфраструктуру (MKS + CRaaS) через Terraform
cd step-1-terraform
terraform destroy
```

> `terraform destroy` удалит всё, что создал `terraform apply`.
> Подтвердите командой `yes`.
