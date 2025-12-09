FROM debian:trixie-slim

# Установка зависимостей для работы с образами и файловыми системами
# Добавляем bats для тестов
RUN apt-get update && apt-get install -y --no-install-recommends \
  git \
  gawk \
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
  bats \
  && rm -rf /var/lib/apt/lists/*

# Рабочая директория
WORKDIR /workspace

# По умолчанию запускаем bash
CMD ["/bin/bash"]
