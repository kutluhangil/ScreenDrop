# Seam Ripple — NameDrop-style monitor transition effect for macOS

## Goal

Build a native macOS menu bar app. When the mouse cursor crosses from one display to another, play a short, intense, liquid "wobble" distortion at the seam where the two displays meet. It should look like the iOS 17 NameDrop transition: the actual on-screen content near the seam (text, icons, window edges, wallpaper) bends and ripples like jelly or water, radiating outward from the exact point where the cursor crossed, on BOTH displays, then settles back to normal.

Hard visual rules:
- NO visible ring, circle outline, glow halo or any drawn shape. The effect is pure displacement of existing pixels. Nothing is "added" on top; only the existing content is warped.
- No visible rectangle or seam where the effect area ends. Distortion must fade to exactly zero at the overlay boundaries.
- Duration about 700 ms. Intense at the start, decaying smoothly.

## Core architecture (important: read this first)

macOS does not allow modifying how other apps render. So the effect is an illusion:

1. Detect the moment the cursor crosses a display boundary and compute the crossing point on the shared edge.
2. Instantly capture a strip of screen content on both sides of the seam (ScreenCaptureKit), excluding the cursor and this app's own windows.
3. Show that captured image in a transparent, borderless, click-through overlay window placed exactly over the strip, pixel-aligned, so at frame 0 it is indistinguishable from the real screen.
4. Render the image through a Metal fragment shader that applies an animated displacement field.
5. When the animation ends, remove the overlay. The real screen is revealed underneath, identical to the last frame.

## Tech constraints

- Swift + AppKit + Metal (MTKView). Do NOT use Electron, Tauri, web views, or SwiftUI animations for the effect itself.
- Minimum macOS 14 (for `SCScreenshotManager`).
- Menu bar only app (`LSUIElement = YES`), no Dock icon.
- Must work with displays of different resolutions, scale factors (Retina + non-Retina), refresh rates, and arrangements (side by side, stacked, offset heights).

## Phase 0 — Project setup

- Create the Xcode project, app target, menu bar status item with: Enable/Disable toggle, Intensity slider, "Test effect" button, Quit.
- Create `CLAUDE.md` in the repo root containing these rules, and follow them:
  - Do NOT run `git commit` or `git push`. The developer commits and pushes manually.
  - Do NOT create branches. Stay on the current branch.
  - Never add a "Co-Authored-By: Claude" trailer or any AI attribution anywhere.
- Add the Screen Recording permission flow: check with `CGPreflightScreenCaptureAccess()`, request with `CGRequestScreenCaptureAccess()`, and show a clear onboarding message if denied.

## Phase 1 — Cursor tracking and seam detection

- Poll `NSEvent.mouseLocation` on a display-synced timer (CVDisplayLink or `CADisplayLink` on macOS 14+). Polling needs no Accessibility or Input Monitoring permission; prefer it over event taps.
- Track which `NSScreen` contains the cursor. When it changes from screen A to screen B:
  - Determine the shared edge (vertical seam for side-by-side, horizontal for stacked) from the screens' frames.
  - Compute the shared segment as the intersection of the two edges (screens may have different heights or offsets).
  - Compute the crossing point C by intersecting the cursor's movement segment (previous position to current position) with the shared edge. Clamp C into the shared segment.
- Ignore jumps that are not real edge crossings (e.g. cursor warped by another app). Require the previous position to be within ~40 pt of the shared edge.
- Cooldown: do not retrigger within 450 ms, so jittering back and forth across the seam does not spam the effect.
- Note: `NSScreen` uses bottom-left origin global coordinates; ScreenCaptureKit and CoreGraphics use top-left. Write one well-tested conversion helper and use it everywhere.

## Phase 2 — Overlay windows

- For each of the two screens, create an `NSWindow` covering a strip along the seam: strip width 360 pt on each side, full length of the shared segment plus 120 pt margin at both ends (clamped to the screen).
- Window config: `.borderless`, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`, `ignoresMouseEvents = true`, level above normal windows and the Dock (`.screenSaver` or `CGShieldingWindowLevel()`), collection behavior `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`.
- Pre-create these windows and their MTKViews when the display configuration is known, keep them hidden (`orderOut`), and just reposition + `orderFrontRegardless()` on trigger. Creating windows on trigger is too slow.
- Rebuild windows on `NSApplication.didChangeScreenParametersNotification` (displays added, removed, rearranged, resolution changed).

## Phase 3 — Capture

- On trigger, capture both strips with `SCScreenshotManager.captureImage` using an `SCContentFilter` for each display that excludes this app's own windows, `sourceRect` set to the strip, `showsCursor = false`, and output size in native pixels (multiply by `backingScaleFactor`).
- Capture both displays concurrently. Measure and log capture latency.
- If latency is above ~40 ms, implement an optional "low latency mode": a continuous `SCStream` limited to the seam strips at low frame rate, keeping the latest frame ready. Make it a setting, off by default, because a continuous stream costs power and keeps the system screen-recording indicator visible.
- Upload the result into an `MTLTexture` (use `CVMetalTextureCache` / IOSurface, avoid CPU copies).

## Phase 4 — The distortion shader (the actual effect)

Render a full-strip quad that samples the captured texture with displaced UVs. Work in global points so the wave is continuous across both displays: pass C, the strip's global origin, and the scale factor as uniforms.

For each pixel at global position `p`, time `t` in seconds since trigger:

- `d = length(p - C)`, `dir = normalize(p - C)`
- Wave front radius: `r = speed * t` (speed ≈ 1400 pt/s)
- Front envelope: `front = exp(-pow(d - r, 2) / (2 * width^2))` (width ≈ 70 pt)
- Time decay: `decay = exp(-t / tau)` (tau ≈ 0.25 s)
- Radial ripple: `radial = dir * amplitude * sin(k * (d - r)) * front * decay` (amplitude ≈ 14 pt at full intensity, wavelength `2π/k` ≈ 90 pt)
- Jelly wobble: add a perpendicular component, `perp = vec2(-dir.y, dir.x) * amplitude * 0.35 * noise(p * 0.02, t * 6) * front * decay`, using smooth value or simplex noise, so it feels organic rather than a clean mathematical ring.
- Near-seam boost: multiply everything by `1 + 0.6 * exp(-distanceToSeam / 60)` so it is most intense right at the junction.
- Boundary fade: multiply the total displacement by a smoothstep mask that reaches exactly 0 within 40 pt of every overlay edge that is not the seam. This is mandatory, otherwise a rectangle will be visible.
- Sample: `color = texture.sample(uv + displacement / stripSizeInPoints)`. Use clamp-to-edge addressing.
- Optional, off by default: very subtle chromatic aberration (sample R and B with displacement × 1.04 and × 0.96). No added brightness, glow or color tint.

The animation ends when `decay < 0.01` (about 700 ms at tau = 0.25 s). Then hide the overlays. Expose amplitude, speed, wavelength and tau as tunable constants; Intensity slider scales amplitude.

## Phase 5 — Polish and edge cases

- Respect Reduce Motion (`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`): disable the effect or use a very gentle version.
- Do nothing when the cursor crosses during a fullscreen game or when the frontmost app is a fullscreen video, if it can be detected; make it a setting.
- Handle Mission Control, Spaces switching, and screens going to sleep without crashing or leaving stuck overlays. Always hide overlays on any error.
- Different refresh rates: each MTKView drives its own display's refresh rate, but time `t` comes from a shared start timestamp so both halves stay in sync.
- Performance target: no dropped frames on an M-series Mac, CPU near 0% when idle.

## Phase 6 — Verification

- "Test effect" button triggers the effect at the center of the first detected seam without needing to move the mouse.
- Debug mode (hidden setting): draw the overlay bounds and the crossing point in red, log capture latency and frame times.
- Manually test: two displays side by side, stacked, different heights, Retina + non-Retina mix, display unplugged mid-animation.

## Known limitation to accept

During the ~700 ms effect, the strip shows a frozen snapshot. Live content in that area (video, animations) pauses briefly. This is inherent to the approach and acceptable as long as the effect stays short.
