# Восстановление и раздел `factory` (RO)

## Задача раздела `factory`

Отдельный раздел `p5` (ext4, **ro**) хранит эталонные образы rootfs и контрольные суммы.
Это повышает шансы восстановления при повреждении данных.

## Содержимое

```text
/factory/
├── rootfs_A.tar.zst
├── rootfs_A.tar.zst.sha256
└── (опц.) rootfs_B.tar.zst
```

## Восстановление

```bash
sudo restore_factory.sh        # восстановит A из /factory/rootfs_A.tar.zst
sudo restore_factory.sh B      # восстановит B
```

Скрипт монтирует целевой раздел, очищает его и распаковывает tar.zst.

## Создание factory‑образа (после стабилизации rootfs_A)

Создавайте образ с **неактивного** rootfs, чтобы избежать гонок:

```bash
# Пример: мы загружены в B и создаём образ для A (/dev/mmcblk0p2)
mount /dev/mmcblk0p2 /mnt/rootA

# Очистка мусора
rm -rf /mnt/rootA/var/log/* /mnt/rootA/var/tmp/* /mnt/rootA/tmp/*
rm -rf /mnt/rootA/var/cache/apt/archives/*.deb || true
rm -f  /mnt/rootA/etc/ssh/ssh_host_* || true
: > /mnt/rootA/etc/machine-id

# Упаковка
mkdir -p /factory
tar --xattrs --acls --numeric-owner --one-file-system -C /mnt/rootA .   | zstd -T0 -19 -o /factory/rootfs_A.tar.zst

sha256sum /factory/rootfs_A.tar.zst > /factory/rootfs_A.tar.zst.sha256
umount /mnt/rootA
```

> Раздел `factory` монтируется в `ro` через fstab. Для обновления образа временно перемонтируйте `rw`:

```bash
sudo mount -o remount,rw /factory
# ... обновление ...
sudo mount -o remount,ro /factory
```
