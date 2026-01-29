# UI Performance Guidelines (HeadUnit OS)

This document outlines the constraints and best practices for developing web-based interfaces on the CoffeeDigital Reborn HeadUnit hardware (Raspberry Pi 4/5).

## 1. Hardware Context & Challenges

### Target Resolution: 2880 x 824 (Ultrawide)

While testing is often done at 1920x1080 (2.07M pixels), the final display is 2880x824 (2.37M pixels). This is a **15% increase in pixel count**. Every frame requires more work from the GPU, especially for fill-rate heavy operations.

### Graphics Architecture

- **Compositor**: Cage (Wayland) + wlroots.
- **Renderer**: V3D (OpenGL ES 3.1 / Vulkan).
- **Driver**: Mesa.
- **Constraints**: Bandwidth is the primary bottleneck. Complex blending and filters can quickly drop the frame rate below 60 FPS.

---

## 2. CSS Optimization (The "Golden Rules")

### ❌ What to Avoid (Performance Killers)

- **`backdrop-filter` (Blur)**: This is the #1 performance killer. Avoid it entirely for the HeadUnit. It forces the GPU to read back the framebuffer, apply blur, and composite it back every frame.
- **Heavy `box-shadow`**: Large, blurry shadows (e.g., `box-shadow: 0 0 50px ...`) are expensive to paint. Use small, sharp shadows or pre-rendered images for glows.
- **`filter: drop-shadow()`**: More expensive than `box-shadow`.
- **Complex Gradients**: Deeply nested linear/radial gradients can slow down rasterization.
- **Fixed/Sticky Position during scroll**: Triggers massive repaints.

### ✅ What to Use (Hardware Accelerated)

- **`transform`**: Use for movement, scaling, and rotation. (e.g., `translate3d(0,0,0)` to force a new layer).
- **`opacity`**: Use for fades.
- **`will-change: transform, opacity`**: Only use on elements that animate frequently to help Chromium pre-allocate layers.

---

## 3. React/Frontend Best Practices

### DOM Node Count

Keep the DOM tree shallow. RPi hardware struggles with layout calculations if the DOM is too deep (e.g., > 1000 nodes). Use virtualization (like `react-window`) for lists.

### Animations

- Use **CSS Transitions/Animations** for simple UI states.
- Use **Framer Motion** or **GSAP** sparingly. Ensure they use hardware-accelerated properties only.
- Prefer `requestAnimationFrame` over `setTimeout` for JS-driven logic.

### Assets & Media

- **Icons**: Use SVGs. Avoid icon-fonts (they are treated as text and re-rendered).
- **Images**: Use WebP format. Ensure images are pre-sized to their display size (don't load a 4K image into a 200px container).
- **Video**: Use H.264/AVC for best hardware acceleration support.

---

## 4. Chromium Configuration (Kiosk Mode)

We use several flags to ensure high performance. Do not remove these unless you know what you are doing:

- `--canvas-oop-rasterization`: Rasterizes canvas 2D off the main thread.
- `--ignore-gpu-blocklist`: Force GPU usage even if Chromium thinks the driver is risky.
- `--enable-gpu-rasterization`: Essential for smooth scrolling and animations.
- `--enable-zero-copy`: Reduces memory copies between CPU and GPU.

---

## 5. Debugging Performance

When the UI feels "choppy":

1. Check `chrome://gpu` to ensure "Hardware accelerated" is visible.
2. Open DevTools (via SSH tunnel) and use the **Performance tab**.
3. Look for **Long Tasks** (red bars) and **Layout Thrashing**.
4. Check **Paint Flashing** in the Rendering tab to see what's being redrawn unnecessarily.

> [!TIP] > **Rule of Thumb**: If it doesn't run at 60 FPS on your dev machine during "Slow CPU" throttling (6x slowdown in DevTools), it will definitely lag on the RPi.
