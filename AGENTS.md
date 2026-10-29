# ScreenDrop — Codex kuralları

- `git commit` ve `git push` çalıştırma. Geliştirici commit ve push'u kendisi yapar.
- Branch oluşturma. Mevcut branch'te kal.
- Hiçbir yere "Co-Authored-By: Codex" ya da başka bir AI imzası ekleme.

## Proje
- Spesifikasyon: `seam-ripple-prompt.md`. Efekt yalnızca mevcut piksellerin bükülmesi; ışık, halka ya da şekil çizilmez.
- Proje `project.yml`'dan xcodegen ile üretilir: `xcodegen generate`.
- Testler: `xcodebuild -scheme ScreenDrop -destination 'platform=macOS' test`.
- README görselleri: `TEST_RUNNER_SCREENDROP_RENDER_DIR=/klasor xcodebuild ... test`.
