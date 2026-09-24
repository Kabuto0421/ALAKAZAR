from PIL import Image, ImageFilter, ImageDraw
from pathlib import Path
import json
import math
import sys

PROJECT = Path(__file__).resolve().parents[1]
OUTPUT = PROJECT.parent / 'animation-review'

def components(mask):
    mask=mask.filter(ImageFilter.MaxFilter(5))
    w,h=mask.size
    coords={(x,y) for y in range(h) for x in range(w) if mask.getpixel((x,y))}
    result=[]
    while coords:
        first=coords.pop(); stack=[first]; pts=[first]
        while stack:
            x,y=stack.pop()
            for p in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                if p in coords: coords.remove(p);stack.append(p);pts.append(p)
        if len(pts)>60: result.append(pts)
    return sorted(result,key=len,reverse=True)

def bounds(pts):
    return [min(p[0] for p in pts),min(p[1] for p in pts),max(p[0] for p in pts)+1,max(p[1] for p in pts)+1]

def markers(im):
    im=im.convert('RGBA');w,h=im.size
    hair=Image.new('L',im.size);boots=Image.new('L',im.size)
    for y in range(h):
        for x in range(w):
            r,g,b,a=im.getpixel((x,y))
            if a<128:continue
            if y<h*.77 and 85<=r<=220 and max(r,g,b)-min(r,g,b)<=16:hair.putpixel((x,y),255)
            if y>h*.65 and r>45 and r>g*1.22 and g>b*1.15:boots.putpixel((x,y),255)
    hs=components(hair); bs=components(boots)
    hb=bounds(hs[0]); bb=[bounds(p) for p in bs[:2]]
    return {'head':hb,'boots':bb,'anchor':[sum((b[0]+b[2])/2 for b in bb)/len(bb),max(b[3] for b in bb)],'head_width':hb[2]-hb[0]}

def main():
    """Measure artwork independently of the landmarks stored in the Godot profile.

    Run test_sword_animation.gd first to export the rectangles used by Godot.
    These color-based measurements are specific to the current silver-haired
    character. Inspect detected regions when replacing the artwork or palette.
    """
    sheet = Image.open(PROJECT/'assets/sprites/attacks/sword-attack-directions.png').convert('RGBA')
    static = Image.open(PROJECT/'assets/sprites/adventurer_weapon_directions_64.png').convert('RGBA')
    geometry = json.loads((OUTPUT/'render-geometry.json').read_text())
    rects = {(item['direction'], item['frame']): item['rect'] for item in geometry}
    annotated = Image.new('RGBA',(480*8,480*4),(20,25,31,255))
    report = []
    failures = []
    for direction,count in enumerate([6,5,5,5]):
        idle = Image.new('RGBA',(480,480))
        idle.alpha_composite(static.crop((direction*362,724,(direction+1)*362,1086)),(59,98))
        idle_markers = markers(idle)
        side = 76 if direction == 2 else 64
        scale = side/362
        idle_anchor = [
            -side/2 + (idle_markers['anchor'][0]-59)*scale,
            (27-side) + (idle_markers['anchor'][1]-98)*scale,
        ]
        idle_head = idle_markers['head_width']*scale
        for frame in range(-1,count):
            im = idle.copy() if frame == -1 else sheet.crop((frame*480,direction*480,(frame+1)*480,(direction+1)*480))
            found = markers(im)
            draw = ImageDraw.Draw(im)
            draw.rectangle(found['head'],outline='yellow',width=2)
            for bb in found['boots']:
                draw.rectangle(bb,outline='orange',width=2)
            x,y = found['anchor']
            draw.line((x-20,y,x+20,y),fill='cyan',width=3)
            draw.text((10,10),f'{direction} / {frame}',fill='white')
            annotated.alpha_composite(im,((frame+1)*480,direction*480))
            if frame == -1:
                continue
            result = {'direction':direction,'frame':frame}
            for label,rect in [('unadjusted',[-44,-61,88,88]),('after',rects[direction,frame])]:
                sx,sy = rect[2]/480,rect[3]/480
                anchor = [rect[0]+found['anchor'][0]*sx,rect[1]+found['anchor'][1]*sy]
                error = math.dist(anchor,idle_anchor)
                head_error = abs(found['head_width']*sx/idle_head-1)*100
                result[label] = {'foot_anchor_error_px':round(error,3),'head_width_error_percent':round(head_error,3)}
                if label == 'after' and (error > 1 or head_error > 5):
                    failures.append(result)
            report.append(result)
        for frame in range(count,7):
            unused = sheet.crop((frame*480,direction*480,(frame+1)*480,(direction+1)*480))
            if unused.getchannel('A').getbbox() is not None:
                failures.append({'unexpected_frame':[direction,frame]})
    summary = {
        label: {
            'max_foot_anchor_error_px':max(row[label]['foot_anchor_error_px'] for row in report),
            'max_head_width_error_percent':max(row[label]['head_width_error_percent'] for row in report),
        } for label in ['unadjusted','after']
    }
    (OUTPUT/'visual-metrics.json').write_text(json.dumps({'summary':summary,'frames':report,'failures':failures},indent=2))
    annotated.save(OUTPUT/'detected-landmarks.png')
    print(json.dumps(summary,indent=2))
    print(f'VISUAL GEOMETRY: {len(report)} frames, {len(failures)} failures')
    return bool(failures)

if __name__ == '__main__':
    sys.exit(main())
