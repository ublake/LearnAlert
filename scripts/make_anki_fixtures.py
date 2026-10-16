# Regenerate with the official anki==26.9.3 Python package (not an app dependency).
from pathlib import Path
import tempfile, wave, math, struct, base64, shutil
from anki.collection import Collection, ExportAnkiPackageOptions
from anki.stdmodels import StockNotetypeKind
import json
root=Path(__file__).resolve().parents[1]/'Packages/AnkiArchive/Tests/AnkiArchiveTests/Fixtures'
root.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory() as temp:
 col=Collection(str(Path(temp)/'collection.anki2'))
 media=Path(col.media.dir())
 (media/'cat.png').write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a4ioAAAAASUVORK5CYII='))
 with wave.open(str(media/'tone.wav'),'wb') as w:
  w.setparams((1,2,8000,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(1500*math.sin(2*math.pi*440*i/8000))) for i in range(800)))
 def add(model,fields,deck,guid):
  note=col.new_note(col.models.by_name(model));note.fields=fields;note.guid=guid;note.tags=['fixture','한국어'];col.add_note(note,col.decks.id(deck))
 add('Basic (and reversed card)',['<b>고양이</b><img src="cat.png">[sound:tone.wav]','A cat'],'Import sample::Korean','fixture-cat')
 add('Cloze',['Hangul has {{c1::vowels::sounds}} and {{c2::consonants}}.','Extra explanation'],'Import sample::Korean','fixture-cloze')
 add('Basic',['<img src="cat.png">','<img src="cat.png">'],'Import sample::Pictures','fixture-picture')
 add('Basic',['What does 안녕 mean?','Hello'],'Import sample::Korean','fixture-basic')
 model=col.models.new('Styled custom')
 for name in ['Expression','Meaning','Extra']:
  field=col.models.new_field(name);col.models.add_field(model,field)
 template=col.models.new_template('Styled')
 template['qfmt']='<div id="custom-front">{{Expression}}</div>{{#Extra}}<aside>{{Extra}}</aside>{{/Extra}}<script>document.getElementById("custom-front").dataset.ready="yes";</script>'
 template['afmt']='{{FrontSide}}<hr id="answer">{{Meaning}}'
 col.models.add_template(model,template);model['css']='.card { font-family: Arial; font-size: 22px; } #custom-front { color: #4488cc; }'
 col.models.add(model)
 add('Styled custom',['<ruby>韓<rt>한</rt></ruby>','Korea','An extra note'],'Import sample::Custom','fixture-styled')
 io=json.loads(col._backend.get_stock_notetype_legacy(StockNotetypeKind.KIND_IMAGE_OCCLUSION))
 col.models.add(io)
 add('Image Occlusion',['{{c1::rect:left=.1:top=.2:width=.3:height=.25:oi=1}}{{c2::ellipse:left=.6:top=.5:rx=.1:ry=.15:oi=1}}','<img src="cat.png">','Name the hidden part','A diagram explanation',''],'Import sample::Pictures','fixture-occlusion')
 for legacy in [False,True]:
  path=root/('legacy.apkg' if legacy else 'modern.apkg')
  col.export_anki_package(out_path=str(path),limit=None,options=ExportAnkiPackageOptions(with_media=True,with_scheduling=False,legacy=legacy))
 print('cards',col.card_count(),'notes',col.note_count())
 col.close()

native=Path(__file__).resolve().parents[1]/'LearnAlertTests/Fixtures'
native.mkdir(parents=True,exist_ok=True)
shutil.copyfile(root/'modern.apkg',native/'anki-modern.apkg')
