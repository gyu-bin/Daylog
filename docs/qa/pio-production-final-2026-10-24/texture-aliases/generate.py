#!/usr/bin/env python3
"""Byte-identical source texture aliases; does not edit/delete any PNG or registration."""
from pathlib import Path
import hashlib,json,struct
root=Path(__file__).resolve().parents[4]
catalog=root/'Daylog/PioCloudProduction.xcassets'
records={}
for imageset in sorted(catalog.glob('*.imageset')):
    contents=json.loads((imageset/'Contents.json').read_text())
    files={i['filename'] for i in contents['images'] if i.get('filename')}
    assert len(files)==1, (imageset,files)
    png=imageset/next(iter(files)); data=png.read_bytes()
    assert data[:8]==b'\x89PNG\r\n\x1a\n'
    width,height=struct.unpack('>II',data[16:24])
    records[imageset.stem]={'sha256':hashlib.sha256(data).hexdigest(),
      'path':str(png.relative_to(root)),'width':width,'height':height,'bytes':len(data)}
groups={}
for name,record in records.items():groups.setdefault(record['sha256'],[]).append(name)
aliases={name:min(groups[r['sha256']]) for name,r in records.items()}
for name,canonical in aliases.items():
    assert records[name]['sha256']==records[canonical]['sha256']
    assert (root/records[name]['path']).read_bytes()==(root/records[canonical]['path']).read_bytes()
dataset=catalog/'pio_cloud_production_texture_aliases.dataset'; dataset.mkdir(exist_ok=True)
(dataset/'Contents.json').write_text(json.dumps({'data':[{'filename':'aliases.json','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
(dataset/'aliases.json').write_text(json.dumps({'version':1,'aliases':aliases,'sourceSHA256':{k:v['sha256'] for k,v in records.items()}},indent=2,sort_keys=True)+'\n')
provenance={'scope':'New loading aliases only; source PNG and registration bytes unchanged',
 'sourceCount':len(records),'canonicalCount':len(groups),'duplicateCopies':len(records)-len(groups),
 'logicalRGBABytesBefore':sum(v['width']*v['height']*4 for v in records.values()),
 'logicalRGBABytesCanonical':sum(records[n]['width']*records[n]['height']*4 for n in set(aliases.values())),
 'aliases':aliases,'sources':records}
(Path(__file__).parent/'provenance.json').write_text(json.dumps(provenance,indent=2,sort_keys=True)+'\n')
print({k:v for k,v in provenance.items() if k not in ('sources','aliases')})
