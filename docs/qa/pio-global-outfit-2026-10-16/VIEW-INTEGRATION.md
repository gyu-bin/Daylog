# Pio global appearance — view integration audit

This is a source/asset audit, not a runtime QA pass. Build and screenshot results
must be recorded separately. No new character artwork was generated or edited.

## Authoritative appearance

App appearances now resolve through `PioAppearanceCoordinator.shared`. The
coordinator reads verified wardrobe ownership and the existing growth source;
views do not retain their own equipped-outfit preferences. Shop catalog previews
are intentionally separate from the current equipped appearance.

The existing `RoutimoriSplashTrial` / `PioOutfitMotionView.isTrialEnabled` gate
continues to protect production behavior. All original non-trial Saessagi paths
remain available. The native launch screen remains static.

## Actual surface inventory

| Surface | Integration | Authored-art limitation | Runtime QA |
|---|---|---|---|
| Dashboard header, wide and compact | `TodaySaessagi` resolves `.dashboard`; common appearance renderer | Existing whole-body idle/rest/celebration only. Trial walking lane remains disabled; do not report independent walk/run as supported. | NOT_TESTED |
| Growth card and level-up | `.growth`, existing XP/event source; 156–180 pt hero; shared compatibility notice | Existing outfit remains selected across stages, but all four stage numbers reuse the same reference art. | NOT_TESTED |
| In-app splash | `.splash`, existing timing/layout, approved basic wave or supported outfit motion | Premium independent wave is unavailable unless an already-approved layered pilot supports it. No extra startup waits. | NOT_TESTED |
| Vacation day | `.vacationDay`, original registered hammock foreground and background; shared visible notice | Premium reclining/drink/hammock art absent. Original basic scene is explicitly retained. | NOT_TESTED |
| Vacation night | `.vacationNight`, original night registration/lighting/sway; shared visible notice | Premium night reclining/drink/hammock art absent. Actual night artwork is reclining with a drink, not a separate sleeping pose. | NOT_TESTED |
| Cloud downloading | `.cloudDownloading`, coordinator scene asset passed to original renderer; notice outside illustration | Premium tablet-holding pose absent. | NOT_TESTED |
| Cloud completed | `.cloudCompleted`, original expressive pose, cloud/check and animation; visible notice | Premium joyful face/raised-wing scene pose absent. | NOT_TESTED |
| Cloud failed | `.cloudFailed`, original expressive pose, cloud/error and animation; visible notice | Premium worried face/tablet-holding pose absent. | NOT_TESTED |
| Weekly review | Detail sheet resolves `.weeklyReview`; common renderer and notice | Whole-body idle replaces the old Saessagi-specific behavior only in trial; distinct stage art absent. | NOT_TESTED |
| Welcome/return | `RestartCard` resolves `.welcome` and requests greeting | Basic approved wave; premium unsupported independent wave falls back through coordinator and is described accessibly. | NOT_TESTED |
| Settings previews | Existing vacation/cloud preview screens reuse the above scene paths | Same explicit compatibility limitations. | NOT_TESTED |
| Wardrobe | Owned by separate purchase/UI integration work | Current equipped hero must use authoritative resolution; catalog previews may use explicit preview API. | NOT_TESTED |
| Widgets | No Pio appearance found: current widget brand symbol is SF `leaf.fill` | No character slot; no App Group appearance write/reload introduced. | NOT_TESTED |
| Menu bar | No Pio appearance found: existing monochrome `MenuBarIcon` is a leaf/sun template | No character slot; template icon preserved. | NOT_TESTED |

## Inspected flattened assets

The following source files were visually inspected. They are complete approved
foregrounds; the costume, limbs, expression, prop occlusion and/or hammock are
not independently replaceable layers.

- `routimori_vacation_hammock.png`: reclining basic Pio, drink and full hammock.
- `routimori_vacation_hammock_night.png`: lit reclining basic Pio, drink and full hammock with different registration.
- `routimori_sync_loading.png`: seated basic Pio holding a tablet.
- `routimori_sync_success.png`: basic Pio with joyful face and raised wings.
- `routimori_sync_failure.png`: worried basic Pio holding a tablet.

For every premium outfit (`cherryBlossom`, `summerVacation`, `autumn`, `winter`,
`halloween`, `christmas`, `hanbok`, `cafe`, `student`, `fitness`, `rainyDay`,
`pajamas`, `astronaut`), the five matching scene variants are missing. The
coordinator reports exact expected asset keys as the original scene key suffixed
with `_<outfitID>`. These are required artwork identifiers, not generated assets.

## Reusable scene attachment boundary

Cloud configuration accepts only the coordinator's `.existingScene` asset name.
Vacation native hosts accept coordinator-resolved day/night foreground names at
construction and recreate only when those approved asset names change. Original
backgrounds, registration, pivots, transforms, animation tracks and hit testing
remain intact. The renderer never places an upright catalog PNG over a composed
reclining or tablet scene. The coordinator currently correctly resolves the
original scene plus an explicit premium-compatibility notice.

## Local verification performed

- Swift frontend parsing passed for modified view sources.
- `git diff --check` passed for modified tracked view sources.
- Home-card specified text contrast calculations: light minimum 5.11:1;
  dark minimum 8.97:1, against the primary card surface.
- No Xcode builds, runtime screenshots or motion recordings were run in this
  subtask; the coordinating task serializes those checks.

Global outfit visual compatibility remains **PARTIAL** until the missing scene
and growth-stage artwork is available and verified. Source wiring alone does not
turn those missing variants into supported appearances.
