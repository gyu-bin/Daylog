# Pio motion v2 — verified progress, 2026-10-23

Overall **PARTIAL**. The new native motion system is available for deliberate DEBUG review. This is not completion of every scene, animation, or production acceptance criterion.

## Delivered

- Basic + 13 costumes: **213 genuine separately registered artwork parts**, visible source pixels unchanged. Original 396 application PNGs unchanged. See `preservation-verification.json`.
- Ten native retained Core Animation actions: idle, bounce, walk, jump, landing, celebrate, greet, sleepy, surprised, encourage. Genuine independent eye substitutions, free-wing joints and walking feet; hands and held props share their attachment joint. Cloth/torso and body transforms remain grouped where artwork is grouped.
- Jump: anticipation, one large lift, hang, landing squash/recovery. Bounce: two smaller hops. Greeting: three waves with a free hand. Celebration: happy eyes, wide free wings and alternating shimmy. Surprise: fast recoil/hold/slow return. Encouragement: approach and longer held gesture. Christmas/Pajamas keep both hands on the gift/pillow, rather than inventing a free-handed wave.
- DEBUG wardrobe button **새 움직임 미리 보기** opens all 14 outfits × 10 actions, 64/120/220pt, light/dark preview backgrounds and play/pause. Review selection does not equip or purchase anything. Preview gestures intentionally repeat.
- Process flag `-PioOverhaulTrial` selects the new renderer in existing character slots using `PioAppearanceView`: dashboard/growth card, weekly review/restart, wardrobe and compatible in-app splash. This is opt-in; the production app was not replaced. Composed cloud/vacation scenes retain their existing renderer.
- Offline motion studies: 14 × 11 sequences including frontal bow and outfit-specific gesture studies. These extra studies are **not** all native actions. Compact review ZIP: `output/Pio-Motion-v2-Compact-Review-2026-10-23.zip` (58 entries, CRC verified).
- Vacation: 13 costumes × genuine day/night = **26 active transparent foreground candidates**. Astronaut v2 removes the impossible straw-through-visor prop. Originals, failed versions and provenance are preserved. These are flattened scene foregrounds, not independently rigged scenes. See `output/pio-vacation-outfits-2026-10-23/review.html`.

## Verification

| Check | Result | Evidence / boundary |
|---|---|---|
| Mac Debug build | PASS | `mac-build.log`, later native test builds |
| iPhone simulator Debug build + focused native test | PASS | `ios-native-test-v2.log`; new isolated iPhone17 / iOS27 simulator |
| Focused rig tests | PASS | 7 tests: resources, shared props, eye exclusivity/depth, layer reuse/stopping, distinct trajectories, landing mapping and ±2° held groups |
| Native rendered edge checks | PASS for sampled poses | All14 × 64/220pt × jump peak / neutral / landing =84 transparent PNGs; four borders alpha exactly0 |
| Native motion evidence | PASS for captured sequences | Actual CA presentation frames, not manual animation interpolation. Hanbok jump / Christmas greet:60 frames each, ~3s, recorded timestamps; encoded MP4s in `native-final/` |
| iPhone native pilot motion | PASS | 14 manifests resolve; Basic/Christmas/Hanbok/Astronaut actual CA jump positions differ; eight PNGs and native gallery view capture in `ios-native/` |
| 64/220 light/dark | PARTIAL | Canonical offline comparisons exist; native 64/220 alpha poses + iPhone220 light gallery verified. Not every outfit/action/background visually approved |
| Artwork/source preservation | PASS | 396 original PNG hashes unchanged;213 packed parts retain exact visible RGBA |
| CPU and memory | PARTIAL / observations | Controlled short Mac comparisons below, not a performance/leak certification |
| Offscreen / Reduce Motion end-to-end | NOT_TESTED | Source paths and explicit stop checks exist; OS accessibility toggling and scrolling UI acceptance not completed |
| All-outfit motion seams, full application screen matrix | PARTIAL | Pilot/native endpoint evidence; not every interpolation/event/screen approved |

The initial native harness failed during NSWindow teardown after captures; `isReleasedWhenClosed=false` fixed the test teardown. The initial iPhone harness attempted an unwritable accessibility environment override and failed compilation; it was removed. The final iPhone test explicitly reports OS Reduce Motion NOT_TESTED. Rejected centered native jump screenshots remain in historical folders and must not be presented as accepted evidence. The Mac cached-gallery capture omitted controls; use the iPhone native view capture for visible gallery layout, not the incomplete Mac capture. The standalone simulator screenshot taken after tests shows the Home Screen and is labelled accordingly.

## Controlled short Mac observations

Same350pt native host, two trials per scenario, .7s warmup then2s wall-time, no concurrent builds in the final measurement. Process CPU excludes WindowServer/GPU. The final canvas offset differs only in placement from this measured version, with identical textures and animation algorithm.

| Scenario | Mean process CPU |
|---|---:|
| Previous base rig jump | 1.90% |
| New base static | 0.38% |
| New base jump | 0.69% |
| New Christmas static | 0.24% |
| New Christmas jump | 0.20% |

RSS during scenario observations: approximately121–159MiB. Three42-switch batches settled at216,126,126MiB. Explicit stopping removed16 active tracks to0. Cache eviction, other test-host activity and short sampling affect these figures. They do not establish long-term leak freedom or device energy use. Historical16.08% was measured under different conditions and is not a valid direct before/after comparison. iPhone CPU/memory: NOT_TESTED. Raw data: `native-performance-observations.json`.

## Remaining work

1. Full all-outfit wing/optical seam review at intermediate animation phases and native120pt. Summer sunglasses still obscure small expressions; no artwork-quality PASS claimed.
2. Turn preview loops into appropriate bounded responses and low-distraction idle/event scheduling before enabling the new renderer by default. Native outfit-specific signature actions remain offline studies where not yet integrated.
3. Vacation scene-specific clean face/eye states, hands/props, front/back hammock and stationary anchor reconstruction; register common rope/body footprint across costumes. Flattened26-scene sources cannot independently blink or sip. Hanbok framing still varies.
4. Integrate previously authored cloud seated/eye-state candidates after visual/attachment approval; complete all-context outfit QA. New cloud and vacation sources were not silently substituted into working screens.
5. Native scrolling, background/resume and OS Reduce Motion checks; sustained Mac and iPhone CPU/RSS/energy measurements; complete wardrobe interactions and screen-reader/narrow-layout review.
6. Final user visual approval. Four visual growth-stage variants are no longer required by the latest overhaul brief; level calculations and thresholds were not changed.

No commits, pushes, deployment, real purchases, production installation, production data/schema/CloudKit or project bundle-identifier changes. Tests used existing in-memory test-store handling. iPhone tests installed only in a newly created empty simulator; existing devices/data were untouched. Mac verification used a command-line-only test bundle override. Existing unrelated uncommitted work was preserved.
