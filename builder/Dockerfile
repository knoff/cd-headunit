FROM debian:trixie-slim

# Установка зависимостей для работы с образами и файловыми системами
# Добавляем --no-install-recommends для минимизации размера
RUN apt-get update && apt-get install -y --no-install-recommends \
  git \
  parted \
  dosfstools \
  e2fsprogs \
  fdisk \
  mount \
  udev \
  rsync \
  ca-certificates \
  curl \
  xz-utils \
  sudo \
  qemu-user-static \
  binfmt-support \
  libarchive-tools \
  && rm -rf /var/lib/apt/lists/*

# Рабочая директория внутри контейнера
WORKDIR /workspace

# Скрипт сборки будет точкой входа
ENTRYPOINT ["/bin/bash", "builder/build.sh"]
