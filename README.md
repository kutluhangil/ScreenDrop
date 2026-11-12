<div align="center">

<img src="docs/media/hero.svg" alt="ScreenDrop — your displays, joined by water" width="100%">

<p>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-menu%20bar%20app-4fc3ff?style=for-the-badge&labelColor=030b14">
  <img alt="Metal" src="https://img.shields.io/badge/Metal-one%20shader-a78bfa?style=for-the-badge&labelColor=030b14">
  <img alt="ScreenCaptureKit" src="https://img.shields.io/badge/ScreenCaptureKit-IOSurface-7af0d2?style=for-the-badge&labelColor=030b14">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-4fc3ff?style=for-the-badge&labelColor=030b14">
</p>

<p><em>Slide the pointer from one monitor to the next and everything at the seam ripples like jelly<br>
from the exact point you crossed, on both screens, then settles. The iPhone NameDrop feeling, on a Mac.</em></p>

<img src="docs/media/seam-ripple.gif" alt="The ripple travelling across the seam between two displays" width="100%">

</div>

<img src="docs/media/divider.svg" width="100%" alt="">

## What it is

A menu bar app that plays a short, intense, liquid wobble at the seam where two displays meet, the moment your pointer crosses it.

| | |
|---|---|
| **Pure displacement** | Nothing is drawn on top: no ring, no glow, no shape. Only what is already on screen bends. |
| **Continuous** | One wave in global coordinates, so it flows across both displays. |
| **About 700 ms** | Intense at the start, decaying smoothly to exactly nothing. |
| **Any arrangement** | Side by side, stacked, offset heights, Retina and non-Retina, mixed refresh rates. |

<img src="docs/media/divider.svg" width="100%" alt="">

## How the illusion works

macOS doesn't let one app change how another draws, so ScreenDrop shows you a picture of the screen and bends the picture.

```mermaid
flowchart LR
  D[1 · Detect<br/>pointer polled on the display refresh] --> C[2 · Capture<br/>360 pt strips with ScreenCaptureKit<br/>straight into IOSurface]
  C --> V[3 · Cover<br/>pixel-aligned click-through windows]
  V --> R[4 · Ripple<br/>Metal displacement field]
  R --> X[5 · Reveal<br/>windows vanish, real screen matches]
```

The shader samples the strip through an animated field: a radial wave front, an organic perpendicular wobble from smooth noise, extra strength right at the seam and a mask that fades to nothing at the strip edges.

<img src="docs/media/divider.svg" width="100%" alt="">

## Settings

<div align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/media/settings-dark.png">
  <img src="docs/media/settings-light.png" alt="ScreenDrop settings" width="420">
</picture>
</div>

The menu bar holds **Enabled**, an **Intensity** slider and **Test effect**. The settings window adds an optional chromatic shift, *Skip full screen*, gentler motion when *Reduce Motion* is on, and launch at login.

<img src="docs/media/divider.svg" width="100%" alt="">

## Türkçe özet

**ScreenDrop**, imleç bir monitörden diğerine geçerken ek yerindeki yazı, pencere ve duvar kâğıdını geçiş noktasından itibaren su gibi dalgalandıran bir menü çubuğu uygulaması. Üstüne hiçbir şey çizilmiyor; yalnızca ekrandaki görüntü bükülüyor ve yaklaşık 700 ms'de yerine oturuyor. Ekran Kaydı izni yalnızca o an ek yeri boyunca ince bir şeridin görüntüsünü almak için kullanılıyor; görüntü kaydedilmiyor, Mac'ten çıkmıyor.

<img src="docs/media/divider.svg" width="100%" alt="">

## Install

Build from source with Xcode 26 or later:

```sh
brew install xcodegen
xcodegen generate
xcodebuild -scheme ScreenDrop -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/ScreenDrop.app /Applications/
open /Applications/ScreenDrop.app
```

Keep a single copy in `/Applications`: the Screen Recording permission is tied to the app's signature, so grant it again after each rebuild. Pointer polling needs no Accessibility or Input Monitoring permission.

<div align="center">
<br>
<a href="https://github.com/kutluhangil"><img src="docs/media/signature.svg" width="100%" alt="Built by kutluhangil"></a>
<sub>One Metal shader · nothing saved · nothing leaves your Mac.</sub>
</div>
