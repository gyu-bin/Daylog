"""Read existing artwork metadata; copy selected references byte-for-byte.

No image generation, segmentation, resizing, pixel edits, app edits or runtime tests.
Run with the bundled Python runtime providing Pillow. All writes stay beside this file.
"""
from pathlib import Path
from PIL import Image
import hashlib
import html
import json
import os
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
IDS = 'basic cherryBlossom summerVacation autumn winter halloween christmas hanbok cafe student fitness rainyDay pajamas astronaut'.split()
CLOUD_ORDER = 'body eyeLeft eyeRight lidLeft lidRight halfLeft halfRight browLeft browRight optics'.split()
VAC = ROOT / 'output/pio-vacation-outfits-2026-10-23'
VAC_MANIFEST = json.loads((VAC / 'manifest.json').read_text())
VAC_MAP = {(a['id'], a['mode']): a for a in VAC_MANIFEST['assets']}
PROPS = {
    'basic': ['juice glass', 'straw', 'citrus slice'],
    'cherryBlossom': ['juice glass', 'straw', 'citrus slice'],
    'summerVacation': ['juice glass', 'straw', 'citrus slice', 'opaque sunglasses'],
    'autumn': ['juice glass', 'straw', 'citrus slice', 'leaf decoration'],
    'winter': ['juice glass', 'straw', 'citrus slice'],
    'halloween': ['juice glass', 'straw', 'citrus slice', 'pumpkin bucket'],
    'christmas': ['juice glass', 'straw', 'citrus slice', 'gift (viewer-left day / viewer-right night)'],
    'hanbok': ['juice glass', 'straw', 'citrus slice'],
    'cafe': ['coffee cup with lid (no straw)'],
    'student': ['book', 'backpack', 'glasses', 'juice glass', 'straw', 'citrus slice'],
    'fitness': ['dumbbells', 'juice glass', 'straw', 'citrus slice'],
    'rainyDay': ['closed umbrella', 'juice glass', 'straw', 'citrus slice'],
    'pajamas': ['pillow (no drink)'],
    'astronaut': ['closed helmet/visor (no drink, no straw)'],
}

def rel(p):
    return str(Path(p).relative_to(ROOT))

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def png(p):
    p = Path(p)
    with Image.open(p) as im:
        item = {'path': rel(p), 'size': list(im.size), 'mode': im.mode,
                'bytes': p.stat().st_size, 'sha256': sha(p)}
        if 'A' in im.getbands():
            a = im.getchannel('A')
            item.update(alpha_extrema=list(a.getextrema()), alpha_bbox=a.getbbox())
        return item

def asset_png(catalog, asset):
    folder = ROOT / 'Daylog' / catalog / f'{asset}.imageset'
    c = json.loads((folder / 'Contents.json').read_text())
    names = [x['filename'] for x in c['images'] if x.get('filename')]
    assert len(set(names)) == 1, (asset, names)
    return folder / names[0]

def effective_pivot(outfit, part, parts):
    pid = part['id']
    if outfit == 'christmas' and pid in ['gift', 'handLeft', 'handRight']:
        return [790, 925], 'held gift group override; PioOverhaulCharacter.jointPivot'
    if outfit == 'pajamas' and pid in ['pillow', 'wingLeft', 'wingRight']:
        return [820, 900], 'held pillow group override; PioOverhaulCharacter.jointPivot'
    if outfit == 'rainyDay' and pid in ['umbrellaCanopy', 'umbrellaShaft', 'wingRight']:
        return [745, 875], 'held umbrella group override; PioOverhaulCharacter.jointPivot'
    grip = {('fitness','dumbbellLeft'):'wingLeft', ('fitness','dumbbellRight'):'wingRight',
            ('cafe','prop'):'wingLeft', ('student','prop'):'wingLeft', ('autumn','leaf'):'wingLeft',
            ('summerVacation','drink'):'wingRight', ('halloween','bag'):'wingRight'}.get((outfit,pid))
    if grip:
        return next(p['pivot'] for p in parts if p['id'] == grip), f'grip shared with {grip}'
    return part['pivot'], 'registration pivot'

outfits = []
checked_paths = set()
for oid in IDS:
    home_path = ROOT / f'Daylog/PioOverhaulTrial.xcassets/pio_overhaul_{oid}_registration.dataset/registration.json'
    home = json.loads(home_path.read_text())
    home_parts = []
    for part in home['parts']:
        source = ROOT / f'output/pio-character-overhaul-artwork/full-catalog-v1/{oid}/layers/{part["id"]}.png'
        if not source.exists():
            source = ROOT / f'output/pio-completion-2026-10-23/expressions/{oid}/layers/{part["id"]}.png'
        packed = asset_png('PioOverhaulTrial.xcassets', part['asset'])
        pivot, reason = effective_pivot(oid, part, home['parts'])
        # Compare existing packed pixels to their declared source rectangle in memory only.
        # No images are written/edited/re-encoded, including reference copies.
        x,y,w,h = part['rect']
        with Image.open(source) as original, Image.open(packed) as runtime:
            pixel_match = original.crop((x,y,x+w,y+h)).convert('RGBA').tobytes() == runtime.convert('RGBA').tobytes()
        home_parts.append({'id': part['id'], 'canonical_full_canvas': png(source),
                           'runtime_packed_image': png(packed), 'source_rect': part['rect'],
                           'source_rect_pixels_match_runtime':pixel_match,
                           'registration_pivot': part['pivot'], 'effective_runtime_pivot': pivot,
                           'effective_pivot_reason': reason, 'current_z': part['z'],
                           'current_parent': 'movement (sibling layers; shared grip transform where applicable)'})
        checked_paths.update([source, packed])
    cloud = {'canvas': [1254,1254], 'new_shoulder_pivots': None, 'new_tablet_grips': None,
             'new_anchor_status': 'UNKNOWN_REQUIRES_RECONSTRUCTED_SEATED_ART', 'parts': []}
    if oid == 'basic':
        cloud['existing_independent_seated_parts'] = False
        cloud['flattened_sources'] = [png(asset_png('RoutimoriTrial.xcassets', f'routimori_sync_{state}')) for state in ['loading','failure']]
    else:
        reg = ROOT / f'output/pio-completion-2026-10-23/cloud/{oid}/registration.json'
        src = json.loads(reg.read_text())
        cloud.update(registration_path=rel(reg), registration_sha256=sha(reg),
                     existing_independent_seated_parts=True,
                     eye_slot_registration=src['parts'],
                     baked=src.get('baked'), independent=src.get('independent'))
        for part_id in CLOUD_ORDER:
            p = ROOT / f'output/pio-completion-2026-10-23/cloud/{oid}/layers/{part_id}.png'
            if not p.exists():
                continue
            packed = asset_png('PioOverhaulTrial.xcassets', f'pio_cloud_{oid}_{part_id}')
            cloud['parts'].append({'id': part_id, 'source': png(p), 'app_copy': png(packed),
                                   'byte_identical_app_copy': sha(p)==sha(packed),
                                   'current_z': CLOUD_ORDER.index(part_id), 'current_parent':'cloud root',
                                   'pivot':None, 'pivot_note':'Full-canvas image opacity animation; eye center in slot registration is not a shoulder joint'})
            checked_paths.update([p,packed])
        assert all(p['byte_identical_app_copy'] for p in cloud['parts'])
    vacation = []
    for mode in ['day','night']:
        if oid == 'basic':
            name = 'routimori_vacation_hammock' + ('_night' if mode=='night' else '')
            p = asset_png('RoutimoriTrial.xcassets', name)
            source = p
            version = 'existing Basic original'
            pivot = [68,465] if mode=='night' else [968,484]
            focus = [512,845] if mode=='night' else [512,740]
            degrees = 1.5
        else:
            entry = VAC_MAP[(oid,mode)]
            source = VAC / entry['path']
            name = f'routimori_vacation_{mode}_{oid}'
            p = asset_png('PioVacationScenes.xcassets', name)
            version = entry['active_candidate_version']
            pivot = [58,225] if mode=='night' else [968,500]
            focus = [512,870] if mode=='night' else [512,820]
            degrees = 0.55
        vacation.append({'mode':mode, 'source':png(source), 'app_copy':png(p),
                         'active_version':version, 'byte_identical_app_copy':sha(source)==sha(p),
                         'current_parent':'vacation canvas foreground (one flattened layer)',
                         'existing_renderer_attachment':pivot, 'existing_renderer_focus':focus,
                         'existing_sway_degrees':degrees, 'anchor_quality':'provisional renderer value; NOT independently confirmed two-knot roots',
                         'required_new_anchors':{k:None for k in ['leftTreeKnot','rightTreeKnot','leftClothJoin','rightClothJoin','leftShoulder','rightShoulder','leftEye','rightEye','leftGrip','rightGrip']},
                         'new_anchor_status':'UNKNOWN_REQUIRES_ARTIST_LAYERED_SOURCE',
                         'visually_observed_existing_props':PROPS[oid]})
        checked_paths.update([source,p])
        assert vacation[-1]['byte_identical_app_copy']
    evidence = {
        'standing_rig_neutral_not_full_home_screen': png(ROOT/f'docs/qa/pio-motion-v2-2026-10-23/native-final/{oid}-idle-native-220pt-alpha.png'),
        'cloud_receiving_light_reduce_motion': png(ROOT/f'docs/qa/pio-scenes-integration-2026-10-23/native-cloud-final/cloud-{oid}-receiving-light-reduce-motion.png'),
        'vacation_day_neutral':png(ROOT/f'docs/qa/pio-scenes-integration-2026-10-23/native-extremes/vacation-{oid}-day-native.png'),
        'vacation_night_neutral':png(ROOT/f'docs/qa/pio-scenes-integration-2026-10-23/native-extremes/vacation-{oid}-night-native.png'),
    }
    if oid == 'basic':
        evidence['cloud_receiving_light_reduce_motion']['validity'] = 'INVALID_FIXTURE_FOR_BASIC_SEATED_DISPLAY; forcing independent renderer produced empty character'
    design_asset = 'pio_wardrobe_basic_reference' if oid == 'basic' else f'pio_outfit_{oid}'
    outfits.append({'id':oid, 'approved_design_reference':png(asset_png('PioWardrobe.xcassets',design_asset)),
                    'home':{'canvas':[1254,1254], 'runtime_registration':rel(home_path),
                            'runtime_registration_sha256':sha(home_path), 'parts':home_parts},
                    'cloud':cloud, 'vacation':vacation, 'reviewed_existing_evidence':evidence,
                    'four_growth_stage_visual_artwork_verified_by_this_audit':False})

blockers = [
    {'id':'CLOUD_BASIC_EYES','outfits':['basic'],'needed':['clean seated face/body','eyeLeft/Right','halfLeft/Right','lidLeft/Right','browLeft/Right'],'lossless_separation':'NO: baked eye pixels hide underlying facial fur. Standing eyes are donors only; clean seated face missing.'},
    {'id':'CLOUD_PAID_HANDS','outfits':IDS[1:],'needed':['restored torso and sleeves','armLeft/Right with hidden shoulders','hand front/back occlusion'],'lossless_separation':'NO for complete motion: exposed pixels could be isolated but hidden shoulders/torso are absent from body PNG.'},
    {'id':'CLOUD_TABLET','outfits':IDS[1:],'needed':['tablet complete outline behind hands','grip contact and front/back hand occlusion','torso under tablet'],'lossless_separation':'NO for complete independent tablet: hands/torso occlude portions; pixels are not recoverable by crop.'},
    {'id':'VACATION_EYES','outfits':IDS,'modes':['day','night'],'needed':['clean reclining face','eyeLeft/Right open/half/closed','correct glasses/visor overlays where existing'],'lossless_separation':'NO: flattened face has closed smiling eyes baked in. Home/cloud eye coordinates do not transfer to reclining pose.'},
    {'id':'VACATION_HANDS_PROPS','outfits':IDS,'modes':['day','night'],'needed':['restored torso/arms hidden roots','hands front/back','existing actual props only','reconstructed contact/occlusion regions'],'lossless_separation':'NO: hidden contact pixels missing. Café coffee; pajamas pillow; astronaut v2 NO DRINK; never add universal juice.'},
    {'id':'VACATION_ROPES','outfits':IDS,'modes':['day','night'],'needed':['two fixed rope/tree knots','moving cloth front/back','background behind moving cloth','per-file measured rope-cloth joins'],'lossless_separation':'NO for complete motion: rope/cloth/Pio flattened together; two fixed endpoints cannot remain fixed under one rigid rotation.'},
]
for b in blockers:
    b.update(status='BLOCKED_ASSET',resolved_by_this_audit=False)

result = {'schema_version':1,'date':'2026-10-24','scope':'Read-only artwork audit/specification. No new source art or app implementation.',
          'verdict':'PARTIAL','resolved_blocker_groups':0,'total_blocker_groups':6,
          'coordinate_contract':{'origin':'top-left','x':'right','y':'down','unit':'source pixel',
                                 'unknown_new_pivots':'null; must be measured on reconstructed art, never inferred from standing rig'},
          'blockers':blockers, 'outfits':outfits,
          'metadata_warning':'Historical registration status strings and vacation manifest not-app-integrated scope are stale provenance. Current app-copy presence/hash is audited independently; presence is not production runtime approval.',
          'counts':{'outfits':len(outfits),'home_parts':sum(len(x['home']['parts']) for x in outfits),
                    'cloud_parts':sum(len(x['cloud']['parts']) for x in outfits),'vacation_sources':sum(len(x['vacation']) for x in outfits),
                    'unique_art_paths_hashed':len(checked_paths),'existing_neutral_pngs_visually_reviewed':56,
                    'full_home_screen_outfit_matrix_visually_reviewed':False,
                    'historical_invalid_basic_cloud_fixture_pngs':4}}
HERE.mkdir(parents=True,exist_ok=True)
(HERE/'inventory.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')

# References are intentionally copied, never decoded/re-encoded.
reference_paths = [
    asset_png('RoutimoriTrial.xcassets','routimori_sync_loading'),
    asset_png('RoutimoriTrial.xcassets','routimori_sync_failure'),
]
for oid in ['christmas','hanbok','astronaut']:
    reference_paths += [ROOT/f'output/pio-completion-2026-10-23/cloud/{oid}/layers/body.png',
                        asset_png('PioWardrobe.xcassets',f'pio_outfit_{oid}')]
for oid in ['christmas','astronaut']:
    for mode in ['day','night']:
        reference_paths += [VAC/VAC_MAP[(oid,mode)]['path']]
reference_paths += [ROOT/'docs/qa/pio-scenes-integration-2026-10-23/native-cloud-final/cloud-basic-receiving-light-reduce-motion.png']
reference_paths += [ROOT/'docs/qa/pio-outfit-phase2.2-2026-10-16/candidates/base'/p for p in ['eye-open-v1.png','eye-half-v1.png','eyelid-closed-v1.png']]
copies=[]
for source in reference_paths:
    # Preserve source path inside references, allowing duplicate leaf names safely.
    dest=HERE/'references'/rel(source)
    dest.parent.mkdir(parents=True,exist_ok=True)
    if dest.exists():
        assert sha(dest)==sha(source), f'Refusing to overwrite differing reference: {dest}'
    else:
        shutil.copyfile(source,dest)
    assert sha(source)==sha(dest)
    copies.append({'source':rel(source),'copy':str(dest.relative_to(HERE)),'sha256':sha(source),'byte_identical':True})
(HERE/'reference-copies.json').write_text(json.dumps(copies,ensure_ascii=False,indent=2)+'\n')

rows=[]
for o in outfits:
    h=o['home']; c=o['cloud']; v=o['vacation']
    roots='; '.join(f"{p['id']}={p['effective_runtime_pivot']}" for p in h['parts'] if p['id'] in ['wingLeft','wingRight','handLeft','handRight','sprout','gift','hat','helmet','pillow','prop'])
    eye_slots='Baked: no clean seated eyes' if o['id']=='basic' else '; '.join(f"{p['id']}={p['center']}" for p in c['eye_slot_registration'] if p['id'] in ['eyeLeft','eyeRight'])
    rows.append(f"| {o['id']} | {len(h['parts'])} | {roots} | {eye_slots} | {', '.join(PROPS[o['id']])} |")
table='''# Per-outfit handoff — current anchors, not new art approval

Exact source paths, dimensions, SHA-256, packed rectangles, every z/pivot and day/night source are in [inventory.json](inventory.json). Existing standing runtime pivots below are NOT reusable seated/reclining shoulder coordinates. All new shoulders/grips/two-knot anchors remain `null` until actual hidden-root artwork exists.

| Outfit | Genuine standing parts | Existing effective standing pivots (px) | Existing seated eye slot centers (px) | Actual vacation props observed in day and night |
|---|---:|---|---|---|
'''+ '\n'.join(rows)+'''\n
All standing/paid seated source canvases: 1254×1254 RGBA. Vacation full-canvas source: 1024×1536 RGBA. Runtime standing tight crops retain an explicit source rectangle and pivot; they are packed delivery, not new high-resolution reconstruction.

Special constraints: summer opaque sunglasses obscure eye expression; student glasses must stay above eyes. Astronaut closed visor must remain closed and above the clean face, with no added drink/straw. Pajamas has pillow, no drink; café coffee is not a juice/straw assembly. Christmas gift side changes between day/night authored sources and needs continuity approval.
'''
(HERE/'PER-OUTFIT.md').write_text(table)

cards=[]
for o in outfits:
    figures=[]
    for name,meta in o['reviewed_existing_evidence'].items():
        p=ROOT/meta['path']; src=html.escape(os.path.relpath(p,HERE),quote=True)
        label=name.replace('_',' ')
        if o['id']=='basic' and name.startswith('cloud_'):
            label+=' — INVALID historical fixture; empty Basic is not actual fallback proof'
        figures.append(f'<figure><a href="{src}"><img loading="lazy" src="{src}" alt="{html.escape(label)}"></a><figcaption>{html.escape(label)}</figcaption></figure>')
    cards.append(f'<section><h2>{o["id"]}</h2><div class="grid">'+''.join(figures)+'</div></section>')
(HERE/'review.html').write_text('''<!doctype html><meta charset="utf-8"><title>Pio existing artwork audit</title>
<style>body{font:15px system-ui;background:#f5f2ea;color:#183d31;margin:30px}h1{font-size:26px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:14px}figure{margin:0;background:white;padding:10px}img{display:block;width:100%;max-height:490px;object-fit:contain}figcaption{font-size:12px;padding:8px}section{margin:30px 0}a{color:inherit}</style>
<h1>기존 원화 / 네이티브 렌더 증거 검토 — PARTIAL</h1><p>원화 신규 제작 없음. 실제 홈 전체 화면 14종 검증 아님: 첫 열은 기존 220pt standing rig. 나머지는 기존 cloud / vacation native evidence. Basic cloud 원본은 존재하나 이 과거 캡처는 잘못된 fixture 선택으로 비어 있음. 새 runtime·motion-extreme 검증을 대신하지 않음.</p>
<p><a href="ARTWORK-SPEC.md">Layer spec</a> · <a href="inventory.json">Exact sources / SHA / anchors</a> · <a href="VISUAL-REVIEW.md">Review findings</a></p>
'''+''.join(cards))
print(json.dumps({'counts':result['counts'],'references':len(copies),'copy_bytes':sum((HERE/c['copy']).stat().st_size for c in copies)},indent=2))
