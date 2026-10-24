# Cloud component render preview

These are **offline component renders**, not application screenshots or screen recordings. The Mac was locked during live UI verification. Full FirstSyncView layout, buttons, accessibility navigation, window lifecycle and actual cloud operations are not demonstrated here.

- `render-preview.swift` embeds the current `RoutimoriSyncStage`, `RoutimoriSyncStyle`, and `CloudShape` source. The sole stage alteration replaces catalog-name loading with the corresponding PNG file path. Display enum cases are a CLI shim.
- Twelve static renders cover receiving / ready / trouble at 220 and 340 points, 2× rendering, and opaque light/dark backgrounds. Static configurations enable Reduce Motion.
- `ready-accent-peak.png` samples 0.35 seconds (10-point happy lift). `trouble-accent-peak.png` samples 2.3/3 seconds (−0.045 radians concerned tilt).
- `cloud-motion-render-preview.mp4`: 6 seconds, 24 fps, 144 frames; left receiving, middle ready, right trouble. The three component layers use their actual registered CAKeyframeAnimation values, durations, repeat behavior, and per-segment CAMediaTimingFunction control points. The harness inverts each timing cubic and applies the resulting value to the model layer. Because headless root rendering ignored sampled transform subkeys, the harness applies each resulting native model affine transform to CGContext before rendering that layer’s content. This is not a capture of the render server or app runtime.
- Native cloud/icon rasterization uses the actual SwiftUI ImageRenderer calls. Characters are composited over an opaque background; hidden RGB in fully transparent pixels is not treated as visible artwork.
- The successful state remains available in the existing settings preview. Real `.found` / `.empty` sync states continue automatically without a newly introduced confirmation screen.

Reproduction (from repository root; script records this workspace's absolute root):

```sh
swiftc -module-cache-path /tmp/routimori-cloud-module-cache -parse-as-library -O docs/qa/routimori-vacation-cloud-2026-10-16/cloud-render-preview/render-preview.swift -o /tmp/routimori-cloud-render
/tmp/routimori-cloud-render
ffmpeg -framerate 24 -i docs/qa/routimori-vacation-cloud-2026-10-16/cloud-render-preview/frames/%04d.png -vf scale=1530:556 -c:v libx264 -pix_fmt yuv420p -crf 18 docs/qa/routimori-vacation-cloud-2026-10-16/cloud-render-preview/cloud-motion-render-preview.mp4
```

Pixel check: comparing character-region pixels at t=0 and t=1.9167 seconds changed 101,898 receiving, 97,044 ready, and 102,423 trouble pixels. This catches accidentally static output; it is not an app performance measurement.
