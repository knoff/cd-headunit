# System Diagnostic Report: 2026-01-29

## Context

Kiosk mode is active using Cage compositor and Chromium. Testing on a physical monitor (1920px wide).

## Resource Usage

### Disk Space

| Filesystem       | Size | Used | Avail | Use% | Mounted on     |
| :--------------- | :--- | :--- | :---- | :--- | :------------- |
| `/dev/mmcblk0p5` | 2.9G | 2.3G | 486M  | 83%  | `/mnt/root-ro` |
| `/dev/mmcblk0p8` | 56G  | 86M  | 53G   | 1%   | `/data`        |
| `tmpfs` (RAM)    | 1.9G | 8.6M | 1.9G  | 1%   | `/tmp`         |

> [!WARNING]
> The root partition (`root-ro`) is at 83% capacity. Adding heavy packages (like additional GUI tools or libraries) may trigger "out of space" errors during build or runtime updates.

### Memory & ZRAM (Swap)

- **Total RAM**: 3.7Gi
- **Free RAM**: 2.5Gi
- **Used RAM**: ~563Mi
- **ZRAM**: Active (1.9G disk size), but currently unused (0B used).

### Load & CPU

- **Load Average**: 0.00, 0.14, 0.10 (Very low).
- **CPU Idle**: 95.8%.
- **Observation**: Despite low CPU/RAM usage, "performance issues" were reported in the UI. This suggests potential GPU/Rendering bottlenecks rather than raw resource exhaustion.

## Network & Connectivity

- **Backend**: Listening on `0.0.0.0:8000` (OK).
- **Chromium Debugger**: Listening on `127.0.0.1:9222` (Localhost only).

### GPU Status (RPi 4)

| Component            | Status                              |
| :------------------- | :---------------------------------- |
| **Canvas**           | Hardware accelerated                |
| **Compositing**      | Hardware accelerated                |
| **Rasterization**    | Hardware accelerated                |
| **WebGL / WebGL2**   | Hardware accelerated                |
| **Direct Rendering** | Disabled (Expected on Wayland/Cage) |

## Potential Optimization Areas

1. **Partition Size**: Increased `PART_ROOT_A/B_SIZE` to 4096MB in `headunit.conf`.
2. **Chromium Flags**: Added `--canvas-oop-rasterization` and `--remote-allow-origins=*` for better performance and remote access.
3. **Environment**: Enforced `WLR_RENDERER=gles2` for Cage to ensure stable V3D usage.
4. **CSS Analysis**: Investigate if high resolution (2880x824) combined with heavy CSS (shadows/blurs) is causing the perceived lag.
