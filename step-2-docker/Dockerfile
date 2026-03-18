# ==============================================================================
# DOCKERFILE — инструкция по сборке образа контейнера
# ==============================================================================
# Простая однослойная сборка: берём HTML-шаблон из локальной папки
# web-templates/ и кладём его в nginx-образ.
#
# Команда сборки запускается из КОРНЯ репозитория:
#   docker build -f step-2-docker/Dockerfile ...
# ==============================================================================

# --platform linux/amd64 — серверы Selectel работают на x86-64.
# Ноутбуки Apple M1/M2/M3 — на ARM. Без этого флага образ не запустится в кластере.
FROM --platform=linux/amd64 nginx:1.23

# ARG — переменная, доступная только во время сборки (не в runtime).
# Здесь — название папки шаблона из web-templates/.
# Можно переопределить при сборке: --build-arg TEMPLATE_NAME=limelight-html
ARG TEMPLATE_NAME="coffee-shop-html-template"

# Копируем HTML-шаблон из локальной папки репозитория в nginx.
# nginx раздаёт файлы из /usr/share/nginx/html.
COPY web-templates/${TEMPLATE_NAME} /usr/share/nginx/html

# Документируем порт — nginx слушает 80
EXPOSE 80

# Запускаем nginx в foreground (контейнер живёт, пока жив процесс)
CMD ["nginx", "-g", "daemon off;"]
