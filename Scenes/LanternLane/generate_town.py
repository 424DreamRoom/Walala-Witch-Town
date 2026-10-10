"""Original orthogonal top-down town artwork; Python + Pillow, no source-image pixels."""
from pathlib import Path
import json, random
from PIL import Image, ImageDraw, ImageFont
OUT=Path(__file__).parent/'Art'
OUT.mkdir(exist_ok=True)
r=random.Random(2026)
font=ImageFont.load_default()
W,H=1280,960
im=Image.new('RGBA',(W,H),'#839468'); d=ImageDraw.Draw(im)
for y in range(0,H,16):
 for x in range(0,W,16):
  d.rectangle((x,y,x+15,y+15),fill=r.choice(['#839468','#87996a','#809166']))
  if r.random()<.25: d.line((x+4,y+8,x+7,y+8),fill='#a8b17b')
# Broad orthogonal pedestrian avenues and perimeter loop.
roads=[(32,312,1248,416),(32,632,1248,736),(360,32,456,928),(760,32,856,928),(32,32,1248,80),(32,880,1248,928),(32,32,96,928),(1184,32,1248,928)]
for a,b,c,e in roads:
 d.rectangle((a-4,b-4,c+3,e+3),fill='#586f60')
 for y in range(b,e,16):
  for x in range(a,c,16):
   col='#c0b677' if (x//16+y//16)%2==0 else '#98a178'
   d.rectangle((x,y,min(x+15,c-1),min(y+15,e-1)),fill=col)
   d.line((x,y+15,min(x+15,c-1),y+15),fill='#899171')
# Shop plots: visible side/rear lanes, door paths, contact shadows.
buildings=[]
labels=['MOON NOODLES','HERB & TEA','LANTERN INN','MOSS BOOKS','GOLDEN STEAM','NIGHT MARKET','POST & PARCEL','BATH HOUSE','FLOWER SHOP']
for row,fy in enumerate([288,608,864]):
 for col,cx in enumerate([224,624,1024]):
  i=row*3+col
  buildings.append({'kind':'shop_'+str(i),'x':cx,'y':fy,'w':160,'h':96})
  d.rectangle((cx-108,fy-150,cx+108,fy+16),fill='#a6a279')
  for y in range(fy-148,fy+16,8): d.line((cx-106,y,cx+106,y),fill='#999974')
  d.rectangle((cx-18,fy,cx+18, min(fy+40,928)),fill='#d0be85')
  d.rectangle((cx-76,fy-94,cx+88,fy+6),fill='#596b5655')
# Small planted islands / flowers, not a farming system.
for cx,cy in [(520,470),(920,470),(520,800),(920,800),(128,470),(1120,800)]:
 d.rectangle((cx-22,cy-16,cx+22,cy+16),fill='#526b51')
 d.rectangle((cx-19,cy-13,cx+19,cy+13),fill='#748a57')
 for j in range(15):
  x,y=cx+r.randrange(-17,18),cy+r.randrange(-11,12)
  d.rectangle((x,y,x+2,y+2),fill=r.choice(['#e2c279','#d89775','#b7bf81']))
im.save(OUT/'town_ground.png')
roofs=[('#627e70','#93a384'),('#b18c56','#d2b675'),('#687782','#91a1a1')]
for i,b in enumerate(buildings):
 im=Image.new('RGBA',(192,192));d=ImageDraw.Draw(im)
 roof,light=roofs[i%3]
 # Floor footprint y=96..192, raised front wall y=132..190; roof's large visible top.
 d.rectangle((16,84,175,190),fill='#3b5048')
 d.rectangle((20,120,171,188),fill='#d1bd86')
 for y in range(127,186,10):
  d.line((22,y,169,y),fill='#b3a175')
  for x in range(24+(y%3)*6,168,24): d.line((x,y-8,x,y),fill='#bdaa7e')
 d.rectangle((12,28,179,124),fill='#344c47')
 d.polygon([(12,32),(96,8),(179,32),(179,123),(12,123)],fill=roof)
 # Orthogonal roof planes: horizontal ridge; NO isometric diamond footprint.
 d.rectangle((12,32,179,37),fill=light)
 for y in range(42,120,9):
  d.line((15,y,176,y),fill=light,width=2)
  for x in range(16+(y%2)*8,176,16): d.line((x,y,x-3,y+6),fill='#465f58')
 d.rectangle((9,121,182,127),fill='#344b46');d.line((10,121,181,121),fill=light,width=2)
 # Chimney and roof service unit seen from above.
 d.rectangle((143,40,158,65),fill='#495d55');d.rectangle((140,37,159,46),fill='#c3b68b');d.rectangle((144,39,156,43),fill='#3e524e')
 d.rectangle((30,53,57,74),fill='#bdc2a3');d.rectangle((33,55,54,65),fill='#758979')
 for x in range(35,54,4):d.line((x,56,x,64),fill='#3f5953')
 # Storefront, windows and wide striped canopy.
 for x in [27,123]:
  d.rectangle((x,145,x+37,177),fill='#476359');d.rectangle((x+3,148,x+34,173),fill='#e5cb83')
  d.line((x+18,148,x+18,173),fill='#758570',width=2);d.line((x+3,160,x+34,160),fill='#758570',width=2)
 d.rectangle((78,146,111,189),fill='#506557');d.rectangle((82,151,107,174),fill='#9eaf94');d.rectangle((102,178,104,180),fill='#f2d18a')
 d.rectangle((20,128,171,143),fill='#526b59')
 text=labels[i]; tw=d.textbbox((0,0),text,font=font)[2];d.text(((192-tw)//2,130),text,font=font,fill='#f4dda0')
 for x in range(23,171,12):d.rectangle((x,143,x+7,149),fill='#d9b675')
 d.rectangle((74,189,115,191),fill='#e0cf9b')
 im.save(OUT/(b['kind']+'.png'))
# Tree canopy with a narrow trunk footprint, sorted by trunk feet.
im=Image.new('RGBA',(64,88));d=ImageDraw.Draw(im)
d.rectangle((28,49,36,85),fill='#695d41');d.rectangle((29,52,31,82),fill='#b09662')
for x,y,rr,c in [(31,32,28,'#365c4c'),(23,28,22,'#54774f'),(37,20,21,'#6f8e59'),(28,12,14,'#99a66b')]:
 d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=c)
for j in range(40):
 x,y=r.randrange(12,52),r.randrange(8,43);d.rectangle((x,y,x+3,y+1),fill='#839d62')
im.save(OUT/'town_tree.png')
props=[{'kind':'town_tree','x':x,'y':y,'w':12,'h':10} for x,y in [(120,140),(330,470),(730,470),(1130,470),(120,780),(730,810),(1130,140),(520,180),(920,180)]]
for x,y in [(320,300),(720,300),(1120,300),(320,620),(720,620),(1120,620)]:props.append({'kind':'planter','x':x,'y':y,'w':29,'h':12})
for x,y in [(304,270),(704,590),(1104,270)]:props.append({'kind':'menu','x':x,'y':y,'w':20,'h':10})
(OUT/'town_layout.json').write_text(json.dumps({'size':[W,H],'buildings':buildings,'props':props},indent=2),encoding='utf-8')
print('Generated orthogonal town: 1280x960, nine separate roofed shops')
