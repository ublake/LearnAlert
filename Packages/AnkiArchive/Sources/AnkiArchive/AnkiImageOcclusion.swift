import Foundation

/// Native Anki image-occlusion data is normalized geometry embedded in cloze fields.
/// Render it locally without depending on Anki's application-specific JS runtime.
enum AnkiImageOcclusion {
    static func render(fields: [String: String], ordinal: Int) throws -> AnkiTemplateRenderer.Result {
        guard let source = fields["Occlusion"], let image = fields["Image"], !image.isEmpty else {
            throw AnkiImportError.invalid("The image-occlusion card is missing its image or masks.")
        }
        let regex = try NSRegularExpression(pattern: #"\{\{c(\d+)::(rect|ellipse|polygon|text):([\s\S]*?)\}\}"#)
        let text = source as NSString
        var shapes: [[String: Any]] = []
        for match in regex.matches(in: source, range: NSRange(location: 0, length: text.length)) {
            var shape: [String: Any] = ["ordinal": Int(text.substring(with: match.range(at: 1))) ?? 0, "type": text.substring(with: match.range(at: 2))]
            let properties = text.substring(with: match.range(at: 3))
            for item in properties.components(separatedBy: ":") {
                let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                if pair.count == 2 { shape[String(pair[0])] = String(pair[1]) }
            }
            shapes.append(shape)
        }
        guard !shapes.isEmpty, shapes.count <= 2_000 else { throw AnkiImportError.invalid("The image-occlusion masks couldn't be converted.") }
        let json = String(data: try JSONSerialization.data(withJSONObject: shapes, options: [.sortedKeys]), encoding: .utf8)!
            .replacingOccurrences(of: "<", with: "\\u003c")
        func side(answer: Bool) -> String {
            let header = fields["Header"] ?? "", extra = answer ? fields["Back Extra"] ?? "" : ""
            return """
            <div>\(header)</div>
            <div class="learnalert-io" style="position:relative;display:inline-block;max-width:100%;line-height:0">\(image)<canvas style="position:absolute;inset:0;width:100%;height:100%;pointer-events:none"></canvas></div>
            \(answer ? "<div><button class=\"anki-sound\" id=\"learnalert-toggle-masks\">Toggle masks</button></div>" : "")
            <div>\(extra)</div>
            <script>(function(){
              const box=document.querySelector('.learnalert-io'),img=box.querySelector('img'),canvas=box.querySelector('canvas');
              if(!img)return;img.style.display='block';img.style.maxWidth='100%';img.style.height='auto';
              const shapes=\(json),target=\(ordinal + 1),answer=\(answer ? "true" : "false");let visible=true;
              function draw(){
                const scale=Math.min(1,2048/Math.max(img.naturalWidth,img.naturalHeight));
                const w=Math.max(1,img.naturalWidth*scale),h=Math.max(1,img.naturalHeight*scale);
                canvas.width=w;canvas.height=h;const c=canvas.getContext('2d');if(!visible)return;
                for(const s of shapes){
                  const n=k=>{const v=Number(s[k]||0);return Number.isFinite(v)?v:0},active=s.ordinal===target;
                  if(s.type!=='text'&&!active&&s.oi!=='1')continue;
                  c.save();c.translate(n('left')*w,n('top')*h);c.rotate(n('angle')/10000*Math.PI*2);
                  c.fillStyle=active?'#ff8e8e':s.fill||'#ffeba2';c.strokeStyle=active&&answer?'#dc5e71':'#34343b';c.lineWidth=Math.max(1,w/600);
                  c.beginPath();
                  if(s.type==='rect')c.rect(0,0,n('width')*w,n('height')*h);
                  else if(s.type==='ellipse')c.ellipse(n('rx')*w,n('ry')*h,Math.abs(n('rx')*w),Math.abs(n('ry')*h),0,0,Math.PI*2);
                  else if(s.type==='polygon'){
                    const points=(s.points||'').split(' ').map(p=>p.split(',').map(Number)).filter(p=>p.length===2&&p.every(Number.isFinite));
                    const minX=Math.min(...points.map(p=>p[0])),minY=Math.min(...points.map(p=>p[1]));
                    points.forEach((p,i)=>{const x=(p[0]-minX)*w,y=(p[1]-minY)*h;i?c.lineTo(x,y):c.moveTo(x,y)});c.closePath();
                  }else if(s.type==='text'){
                    const size=Math.max(8,(n('fs')||20)*(n('scale')||1)*scale);c.font=size+'px sans-serif';c.textBaseline='top';c.fillStyle=s.fill||'#222';c.fillText(s.text||'',0,0);c.restore();continue;
                  }
                  if(!(active&&answer))c.fill();c.stroke();c.restore();
                }
              }
              img.complete&&img.naturalWidth?draw():img.addEventListener('load',draw);
              const toggle=document.getElementById('learnalert-toggle-masks');if(toggle)toggle.onclick=()=>{visible=!visible;draw()};
            })();</script>
            """
        }
        return AnkiTemplateRenderer.Result(front: side(answer: false), back: side(answer: true), warnings: [])
    }
}
