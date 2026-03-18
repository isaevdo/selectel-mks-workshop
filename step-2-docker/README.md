# Шаг 2: Docker — сборка и пуш образа

**Время:** ~10–15 минут
**Что делаем:** Собираем Docker-образ приложения и загружаем его в Container Registry Selectel

---

## Что такое Docker-образ?

Образ — это упакованное приложение со всеми зависимостями.
Запустите его на любом сервере с Docker/Kubernetes — получите одно и то же приложение.

```
Dockerfile  →  docker build  →  Образ (image)  →  docker push  →  Container Registry
                                                                         ↓
                                                               Kubernetes тянет отсюда
```

---

## Файлы этого шага

```
step-2-docker/
└── Dockerfile  ← инструкция по сборке образа (прочитайте!)
```

Приложение не хранится локально — Dockerfile скачивает готовый HTML-шаблон
**KOPPEE Coffee Shop** из публичного репозитория во время сборки.
Это реальный паттерн: исходники и конфигурация деплоя хранятся раздельно.

---

## Переменные

Подставьте свои значения из шага 1:

```bash
# Адрес реестра из вывода terraform apply
REGISTRY=cr.selcloud.ru/coffee-shop-registry

# Название и тег образа
IMAGE_NAME=coffee-shop
IMAGE_TAG=latest
```

---

## Выполнение

### 1. Получите токен CRaaS и войдите в реестр

CRaaS использует отдельный токен — Terraform создал его автоматически на шаге 1.

```bash
# Перейдите в папку шага 1 и получите токен
cd ../step-1-terraform
CRAAS_TOKEN=$(terraform output -raw craas_token)

# Вернитесь в папку шага 2
cd ../step-2-docker

# Логин: имя пользователя — буквально слово "token", пароль — значение токена
docker login ${REGISTRY} -u token -p ${CRAAS_TOKEN}
```

> Такой формат (`-u token`) — стандарт для реестров с token-аутентификацией.
> Docker сохранит credentials — повторный логин не нужен.

### 2. Перейдите в папку шага

```bash
cd step-2-docker
```

### 3. Соберите образ

```bash
docker build -t ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} .
```

> Разберём команду:
> - `docker build` — собрать образ
> - `-t` — тег (имя) образа: `реестр/имя:версия`
> - `.` — искать Dockerfile в текущей папке
>
> Архитектура `linux/amd64` уже указана в Dockerfile через `FROM --platform=linux/amd64`.
> Сборка выполняется в два этапа: сначала клонируется шаблон, потом собирается nginx-образ.
> Займёт **30–60 секунд** (включая скачивание репозитория).

### 4. Посмотрите собранный образ

```bash
docker images | grep coffee-shop
```

> Вы увидите образ размером ~10–15 MB (nginx + наш HTML).

### 5. Загрузите образ в реестр Selectel

```bash
docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
```

> Docker загружает слои образа в реестр.
> Займёт **30–60 секунд** в зависимости от скорости интернета.

---

## Проверка результата

Откройте панель Selectel:
**Облачная платформа → Container Registry → coffee-shop-registry**

Вы увидите репозиторий `coffee-shop` с тегом `latest`.

Также можно проверить командой:
```bash
docker pull ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
```

---

## Зачем CRaaS, а не Docker Hub?

| | Docker Hub | Selectel CRaaS |
|--|--|--|
| Расположение | Внешний сервис | Датацентр Selectel |
| Скорость pull из MKS | Медленно (через интернет) | Быстро (в одной сети) |
| Лимиты | 100 pull/6ч (free tier) | Без лимитов |
| Конфиденциальность | Данные уходят наружу | Остаются у клиента |

**Переходите к шагу 3!** →
