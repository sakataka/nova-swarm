# Design QA

This is the July 2026 launch-bay design review, retained as history. Its pass result applies to that revision, not the current game. Current assets and typography are documented in [visual-refresh.md](docs/visual-refresh.md), and current controls and verification commands in [README.md](README.md).

The current title uses Oxanium text over `public/assets/refresh/title.png`, with controls drawn using `panel.png`. The HUD, pause/result menus and portrait touch pad are rendered through `scripts/ui_layer.gd` and `scripts/game.gd`; all dynamic labels use the bundled font. The earlier image-backed logo/button and fallback-font descriptions below refer to the July implementation.

## Evidence

- Original concept identifier: `exec-05adc0f5-ab2b-4252-84cd-7b88809e4644` (not stored in this repository).
- Implementation screenshot: `nova-pro-title-final.png` (temporary evidence, not stored in this repository).
- Viewport: Godot logical viewport 960 x 720 px; Retina capture 1920 x 1440 px
- State: title screen, MANUAL mode selected, before deployment
- Full-view comparison: `nova-title-comparison-final.png` (temporary evidence).
- Focused control comparison: `nova-title-controls-comparison.png` (temporary evidence).

## Findings

Actionable P0/P1/P2 findings: none.

- Fonts and typography: The source's condensed military display hierarchy is preserved through the generated title lockup and framed navigation labels. Small operational text remains subordinate and legible. Native fallback text is limited to secondary telemetry and does not compete with the image-backed title.
- Spacing and layout rhythm: The launch-bay scene, central ship, mode selector, and primary deployment action retain the source's top-to-bottom hierarchy. Controls are intentionally compacted to preserve the 960 x 720 gameplay viewport and reliable hit targets.
- Colors and visual tokens: Navy, cyan, cobalt, white, and restrained gold are consistent across the title, HUD chassis, item icons, shield, stage banners, and overlays. The earlier red/magenta terminal treatment was removed.
- Image quality and asset fidelity: The title scene, logo, controls, HUD chassis, item icons, and shield are image-backed assets. No visible key art or non-standard icon was substituted with code-drawn geometry. Transparency edges and crops were checked at native scale.
- Copy and content: `NOVA SWARM`, `MANUAL`, `AI DEMO`, and `DEPLOY` match the selected direction. Secondary copy is concise and does not expose implementation instructions.
- Interaction and affordance: Selected and idle mode states are visually distinct. `DEPLOY` is the dominant action and all title controls retain explicit hit regions.

## Comparison History

1. Initial implementation — `nova-pro-title.png` (temporary evidence)
   - Finding: [P1] The deployment control was undersized and visually cropped, weakening the primary action.
   - Finding: [P2] The control crop contained edge artifacts and insufficient contrast.
   - Fix: Regenerated `DEPLOY` as a standalone image-backed asset, trimmed it independently, and increased cyan luminance.
2. Second implementation — `nova-pro-title3.png` (temporary evidence)
   - Post-fix evidence: The full button frame and label were restored at the intended scale.
   - Finding: [P2] Thin white edge remnants remained after background-key removal.
   - Fix: Removed the edge remnants, shaved the affected transparent bounds, and reimported the texture.
3. Final implementation — `nova-pro-title-final.png` (temporary evidence)
   - Post-fix evidence: Full-view and focused comparisons show a complete, high-contrast primary action with no clipping or edge artifacts.

## Open Questions

- None blocking. The implementation uses a more compact bottom control arrangement than the concept image as an intentional adaptation for the native 960 x 720 viewport.

## Implementation Checklist

- [x] Selected launch-bay art direction applied to the title screen.
- [x] Image-backed title controls and deployment action integrated.
- [x] HUD, item, shield, banner, and overlay visual language unified.
- [x] Required fidelity surfaces reviewed at native scale.
- [x] P1/P2 findings fixed and recaptured.

## Follow-up Polish

- P3: A future accessibility settings screen could expose HUD scale and reduced-flash options; this is outside the selected visual target and does not block this release.

final result: passed
