import json,math,hashlib,collections,datetime,pathlib
p=pathlib.Path(__file__).resolve().parent
d=json.loads((p/'time-reference.compact.json').read_text())
trans={t['id']:t for t in d['transitions']}
assert len(d['cases'])==160 and len(trans)==45
folds=collections.Counter(); gaps=0; maxerr=0.0
for c in d['cases']:
 if c['status']=='error':
  assert c['kind']=='synthetic-gap-probe', c
  assert 'invalidDate' in c['error'], c
  gaps+=1
  continue
 utc=datetime.datetime.fromisoformat(c['utc'].replace('Z','+00:00'))
 expected=2440587.5+utc.timestamp()/86400
 delta=abs(c['julianDay']-expected);maxerr=max(maxerr,delta)
 assert delta<=1e-9,(c['id'],delta)
 local=datetime.datetime.fromisoformat(c['localISO'])
 assert local==utc,c
 assert int(local.utcoffset().total_seconds())==c['offsetSeconds'],c
 if c['kind']=='synthetic-fold-probe':
  t=trans[c['transitionID']]
  folds['first' if c['offsetSeconds']==t['offsetBefore'] else 'second']+=1
assert gaps==23
for name in ['eduardo','buenosAires','reykjavik']:
 n=json.loads((p/f'natal-{name}.json').read_text())
 assert len(n['bodies'])==10
 assert len(n['cusps'])==12
 assert n['createdAt']=='1970-01-01T00:00:00Z'
 c=next(x for x in d['cases'] if x['id']==name)
 assert (n['birthDate'],n['birthTime'],n['timezone'])==(c['input']['birthDate'],c['input']['birthTime'],c['input']['timezoneName'])
summary={'cases':len(d['cases']),'transitions':len(trans),'accepted':137,'gapsRejected':gaps,'foldSelectionCounts':dict(folds),'maxJulianDayCrosscheckError':maxerr,'transitionsByZone':dict(collections.Counter(t['timezone'] for t in trans.values()))}
(p/'validation.json').write_text(json.dumps(summary,sort_keys=True,separators=(',',':'))+'\n')
selected=[x for x in d['cases'] if x['kind']=='existing-golden-fixture']
for kind,zone,year in [('synthetic-transition-probe','Europe/Madrid','1940'),('synthetic-gap-probe','Europe/Madrid','1974'),('synthetic-fold-probe','Europe/Madrid','1976'),('synthetic-gap-probe','America/Argentina/Buenos_Aires','1988'),('synthetic-gap-probe','America/New_York','1974'),('synthetic-fold-probe','America/Los_Angeles','2024')]:
 selected.append(next(x for x in d['cases'] if x['kind']==kind and x['input']['timezoneName']==zone and x['input']['birthDate'].startswith(year)))
(p/'selected-reference.compact.json').write_text(json.dumps({'metadata':d['metadata'],'cases':selected},ensure_ascii=False,separators=(',',':'))+'\n')
print(json.dumps(summary,sort_keys=True))
