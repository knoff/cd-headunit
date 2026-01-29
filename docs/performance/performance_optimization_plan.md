# Performance Optimization Plan (INP/CLS)

To reduce INP from 880ms to <200ms and CLS from 0.15 to <0.1 on Raspberry Pi 4.

## 1. Interaction to Next Paint (INP) Fixes

### State Isolation (Main Thread)

- **Problem**: `App.jsx` updates its state every 100ms, re-rendering the entire app tree.
- **Fix**: Move `useRealTimeData` and its simulation logic from `App.jsx` into a dedicated context or local state within the `ExtractionMonitor` / `CoffeeGroup`. Only update components that actually change.
- **Fix**: Wrap `CoffeeGroup`, `MetricRow`, `IconButton`, and `DetailedGraph` in `React.memo` to prevent unnecessary re-renders.

### Transition & Rendering Optimization

- **Problem**: `transition-all` on metrics and progress bars is 300ms, while data arrives every 100ms.
- **Fix**: Disable CSS transitions for properties that update faster than 250ms.
- **Fix**: Update the progress bar using `transform: scaleX(...)` instead of `width` to stay on the compositor thread.
- **Fix**: Remove `backdrop-blur` from `App.jsx` and `SettingsView`. Use solid or simple translucent backgrounds.

### Grid Animation

- **Problem**: Animating `grid-template-columns` in `DashboardGrid.jsx` triggers full layout recalculation for the whole screen (2880px).
- **Fix**: Disable smooth grid transitions on RPi 4. Use immediate layout changes or switch to a lighter animation (e.g., opacity fade-out -> layout change -> fade-in).

---

## 2. Cumulative Layout Shift (CLS) Fixes

### Layout Stability

- **Problem**: Grid transitions cause siblings to resize and jump continuously.
- **Fix**: By removing grid transitions (as mentioned in INP section), we eliminate the primary source of CLS.
- **Fix**: Explicitly set `aspect-ratio` or `min-height/width` for all containers to reserve space before children mount.

### Font Loading

- **Problem**: Custom fonts (Inter, Outfit) might cause layout shifts.
- **Fix**: Use `font-display: swap` (already in CSS) but ensure critical font metrics are matched to fallback fonts.

---

## 3. Implementation Steps

### [Component] State & Re-rendering

- [ ] Refactor `App.jsx`: Move simulation logic to a local hook/context.
- [ ] Apply `React.memo` to all UI leaf components (`MetricRow`, `IconButton`, etc.).

### [Component] CSS & Styling

- [ ] `index.css`: Remove `backdrop-blur` globally or replace with high-performance alternatives.
- [ ] `DashboardGrid.jsx`: Disable `transition-all` on the grid container.
- [ ] `ExtractionMonitor.jsx`: Remove transitions for `width` and `text` values. Use `transform` for the progress bar.

## 4. Verification

1. Re-build the frontend.
2. Use SSH tunnel to capture a new Performance profile.
3. Verify INP < 200ms and CLS < 0.1.
