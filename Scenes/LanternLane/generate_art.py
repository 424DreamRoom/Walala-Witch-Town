"""Deterministic original pixel artwork. Run with Python + Pillow from any directory."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import random

OUT = Path(__file__).parent / 'Art'
OUT.mkdir(exist_ok=True)
rng = random.Random(831)
W, H = 640, 360
im = Image.new('RGBA', (W, H), '#242e37')
d = ImageDraw.Draw(im)
font = ImageFont.load_default()

def box(x,y,w,h,c): d.rectangle((x,y,x+w-1,y+h-1), fill=c)
def line(points,c,width=1): d.line(points, fill=c, width=width)
def text(x,y,s,c='#ffe7a5'): d.text((x,y),s,font=font,fill=c,stroke_width=0)
def panel(x,y,w,h,c):
    box(x,y,w,h,'#242b30'); box(x+2,y+2,w-4,h-4,c); line([(x+2,y+2),(x+w-3,y+2)],'#d4b57b')
def window(x,y,w,h):
    panel(x,y,w,h,'#34464b'); box(x+3,y+3,w-6,h-6,'#927d54')
    box(x+5,y+4,w//2-5,h-9,'#dec380'); box(x+w//2+2,y+4,w//2-7,h-9,'#acaa77')
    line([(x+w//2,y+2),(x+w//2,y+h-3)],'#393c37',2); box(x-2,y+h,w+4,3,'#202d32')
def sign(x,y,w,h,s,c='#ad5144'):
    panel(x,y,w,h,c); tw=d.textbbox((0,0),s,font=font)[2]; text(x+(w-tw)//2,y+(h-11)//2,s)
def pipe(points):
    line(points,'#252d30',6); line([(x-1,y) for x,y in points],'#899484',3); line([(x-2,y) for x,y in points],'#b1b092')

# Upper city: a layered, lived-in service district, not a source-image backdrop.
box(0,0,640,210,'#354448')
for x,y,w,h,c in [(0,12,96,173,'#566365'),(94,-8,145,210,'#747567'),(241,9,127,196,'#7d7560'),(370,-9,162,217,'#666e62'),(534,10,106,214,'#374b4c')]:
    box(x,y,w,h,c); box(x+w-7,y,7,h,'#303f41')
    for yy in range(max(y,0)+5,y+h,12):
        line([(x+2,yy),(x+w-8,yy)],'#515e57')
        for xx in range(x+(6 if yy%24 else 18),x+w-9,26): line([(xx,yy-10),(xx,yy)],'#636e61')
    box(x-2,y+24,w+3,5,'#303d3b'); box(x-2,y+24,w+3,1,'#b2a780')
for x,y in [(12,44),(51,44),(113,29),(158,29),(267,39),(309,39),(391,24),(439,24),(487,24),(563,43)]: window(x,y,28,32)
# Rooftop tanks, vents and conduits.
panel(183,0,43,25,'#879187')
for y in range(5,22,4): line([(188,y),(220,y)],'#3c5151')
pipe([(232,0),(232,79),(247,79),(247,154)])
pipe([(538,0),(538,84),(526,84),(526,189)])
for x in [6,83,357,619]: pipe([(x,1),(x,193)])
box(96,83,428,7,'#292f30'); box(96,83,428,2,'#b4a17a')
for x in range(102,524,17): box(x,90,4,5,'#262d2d')
# Left staircase with landings, worn nosing and metal balustrade.
box(0,93,99,146,'#293c40'); box(5,94,87,12,'#b0a176')
for i in range(15):
    y=108+i*8; x=12-i//4
    box(x,y,77,8,'#596c64'); box(x,y,77,2,'#b1b28a'); box(x+4,y+3,67,2,'#7e8872'); box(x+9+(i*19)%42,y,11,1,'#dfcca0')
line([(6,103),(6,224),(88,224),(88,104)],'#233236',4)
line([(4,102),(4,222),(86,222),(86,102)],'#aab398',2)
for y in range(110,221,23): line([(88,y),(98,y+8)],'#b5b597',2)
box(0,231,102,7,'#303c37'); box(5,231,97,2,'#cebd8c')
# Shop recesses, brick pilasters, warm interiors.
for x,w in [(105,132),(251,121),(389,140)]:
    box(x,113,w,97,'#292e2c'); box(x+4,118,w-8,88,'#5b5140')
    for yy in range(123,205,9):
        for xx in range(x+5,x+w-8,15): box(xx+(7 if yy%2 else 0),yy,10,2,'#827053')
    box(x+8,139,w-16,44,'#c79b59'); box(x+10,142,w-20,38,'#e7bd72')
    for xx in range(x+17,x+w-14,23):
        box(xx,139,3,46,'#433f32'); box(xx+4,151,12,16,'#89664a')
    box(x+5,184,w-10,7,'#d2ab6d'); box(x+5,191,w-10,18,'#514c3c')
    for xx in range(x+10,x+w-8,12): line([(xx,193),(xx,207)],'#80765a')
    box(x-3,110,6,100,'#9b9070'); box(x+w-2,110,6,101,'#857f62')
# Small eateries each with a distinct silhouette.
sign(108,92,127,24,'MOON NOODLES','#a14f3e')
sign(253,91,119,24,'MOSS KITCHEN','#5f7a66')
sign(391,89,134,25,'GOLDEN STEAM','#ba8142')
for x,w,col in [(104,137,'#c68754'),(249,126,'#8f9b74'),(386,148,'#b4a776')]:
    d.polygon([(x,119),(x+w,119),(x+w+5,135),(x-4,135)],fill=col)
    for xx in range(x,x+w,15): d.polygon([(xx,120),(xx+7,120),(xx+9,135),(xx-2,135)],fill='#ddd0a0')
    box(x-4,135,w+9,4,'#443f33')
    for xx in range(x-3,x+w,8): box(xx,139,6,3,col)
# Doors, curtains, counters and individual dishes.
box(202,144,27,64,'#293b39'); window(205,146,19,34); box(222,185,2,3,'#ddbc73')
box(339,143,27,66,'#293b36'); box(341,146,23,29,'#73948b')
for x in range(342,364,8): line([(x,147),(x,174)],'#b5c3a2')
for x in range(116,195,16):
    box(x,178,11,3,'#f4dfaa'); box(x+2,181,7,2,'#a76643'); box(x+3,174,5,3,'#6a8862')
for x in range(398,511,20):
    box(x,170,14,9,'#9d623e'); box(x,168,14,2,'#e8c389'); box(x+2,164,10,3,'#c99e65'); box(x+4,160,5,3,'#e8d3a1')
for x in [123,176,278,320,412,476,509]:
    line([(x,138),(x,149)],'#333c34'); box(x-5,150,11,12,'#b44d36'); box(x-4,151,9,8,'#efb15e'); box(x-3,162,7,2,'#473e31')
# Vertical neon signs, menus, dangling wires, meters.
for x,y,s,c in [(92,53,'RAMEN','#a84f3c'),(239,65,'TEA','#588272'),(529,78,'INN','#b28a48')]:
    panel(x,y,16,len(s)*12+7,c)
    for j,ch in enumerate(s): text(x+4,y+3+j*12,ch)
for x,y in [(112,151),(289,145),(491,143)]:
    panel(x,y,14,22,'#e0cf9f')
    for yy in range(y+5,y+19,4): box(x+4,yy,7-(yy%3),1,'#815f46')
for x in [160,302,461]:
    panel(x,67,29,16,'#b0ad8d')
    for xx in range(x+5,x+25,4): line([(xx,71),(xx,79)],'#515e55')
for pts in [[(0,21),(98,40),(244,26),(381,43),(640,19)],[(77,81),(215,69),(379,80),(555,52)],[(0,6),(235,18),(463,4)]]:
    line(pts,'#202d32'); line([(x,y+2) for x,y in pts],'#414b47')
# Right alley: dim shutter, cables, vending machine and lit doorway.
box(549,111,87,117,'#253638'); panel(570,124,54,91,'#374b49')
for y in range(129,207,5): line([(574,y),(620,y)],'#53645a')
box(559,114,4,100,'#a39062'); box(552,115,10,3,'#e5c580')
panel(534,155,28,60,'#6a8077'); box(538,161,20,26,'#b5caaa')
for y in [165,175]:
    for x in [541,548,555]: box(x,y,3,7,'#d98752')
box(539,194,12,8,'#293b3c'); box(554,190,3,3,'#d7aa64')
# Reference-driven stacked commercial facades: signs replace repetitive upper windows.
# Original motifs, not copied image pixels; staggered heights and service equipment.
d.polygon([(98,88),(146,3),(200,88)], fill='#45485e')
for inset in range(0,24,6):
    line([(100+inset,85),(146,11+inset),(197-inset,85)], '#a99a74',2)
window(130,56,32,29)
for x,y,w,h,title,col in [(194,0,123,34,'NIGHT MARKET','#527e79'),(193,36,125,55,'MOON BOWL','#b77e48'),(200,94,112,28,'HOT / FRESH','#ad6659'),(328,0,102,76,'STEAM HOUSE','#b2784c'),(442,17,83,45,'HERB & TEA','#5b7260')]:
    sign(x,y,w,h,title,col)
# Illustrated bowl medallion and circular exhaust, echoing the reference's large silhouettes.
d.ellipse((215,45,294,87),fill='#354b4b',outline='#e0b878',width=2)
d.pieslice((231,47,279,84),0,180,fill='#d2a15c')
for xx in [239,250,261,270]: line([(xx,65),(xx-3,56),(xx+2,49)],'#e6c88a',2)
box(238,80,35,3,'#ab6953')
d.ellipse((344,20,415,76),fill='#263f43',outline='#b9a26d',width=3)
for yy in range(32,70,8): line([(351,yy),(407,yy)],'#5f8176',3)
box(329,79,98,8,'#d0bc8b')
for x,y in [(329,95),(352,106),(380,97),(399,111)]:
    panel(x,y,25,18,'#b6b397')
    d.ellipse((x+4,y+4,x+14,y+14),fill='#4e5b59',outline='#7a8475')
    for xx in range(x+17,x+23,3): box(xx,y+4,1,10,'#5c6b62')
# Tall projecting signs and cornices break the original uniform row.
for x,y,s,col in [(316,93,'SOUP','#577e85'),(432,70,'TEA','#9d985e'),(524,29,'ROOMS','#9b784c')]:
    panel(x,y,14,len(s)*11+7,col)
    for j,ch in enumerate(s): text(x+3,y+3+j*11,ch)
for x,y,w in [(100,88,91),(194,123,122),(328,132,102),(448,83,75)]:
    box(x,y,w,5,'#303d42'); box(x,y,w,1,'#b6a375')
    for xx in range(x+2,x+w-4,8): box(xx,y+5,5,3,'#8d9064')
# Narrow central double doors under the sign tower.
panel(204,148,29,62,'#514b62')
for xx in [209,222]:
    box(xx,154,7,36,'#34464c'); box(xx,192,7,12,'#a29371'); box(xx+2,176,2,4,'#ddbf75')
# Upper stair flight now reaches the top-left edge; existing walk boundary stays intact.
box(0,0,89,216,'#354547')
for y in range(4,216,9):
    box(2,y,81,3,'#b7b49a'); box(2,y+3,81,3,'#78867c'); box(2,y+6,81,3,'#424e53')
    box(5+(y*7)%57,y,12,1,'#d3c7a3')
line([(86,0),(86,211)],'#b2b99c',2)
# Paving: aligned 16 x 16 square cells, alternating ochre and sage.
box(0,216,640,121,'#575e45')
for row,y in enumerate(range(216,344,16)):
    for col,x in enumerate(range(0,640,16)):
        c = '#b2a568' if (row+col)%2 == 0 else '#818f70'
        box(x,y,16,16,c)
        line([(x,y+15),(x+15,y+15)], '#97966a' if (row+col)%2 == 0 else '#78866b')
        if rng.random()<.12: box(x+4,y+7,3,1,'#9b9d76')
# Upper gutter and stair landing connect into the lane.
box(101,211,440,6,'#414f43'); box(102,211,438,1,'#c3b27c')
for x in range(107,533,9): box(x,214,5,1,'#202f2d')
# Do not stripe across the square checker pattern.
# Ambient contact shadows along walls; alley darkness.
box(105,217,429,4,'#737c59'); box(550,217,90,5,'#475d50')
for x,y in [(163,267),(504,294),(58,285)]:
    panel(x,y,27,12,'#67745a')
    for xx in range(x+4,x+24,4): line([(xx,y+3),(xx,y+8)],'#394c43')
for _ in range(110):
    x,y=rng.randrange(640),rng.randrange(222,326)
    if rng.random()<.5: box(x,y,2,1,'#c2b881')
    else: box(x,y,1,2,'#737d57')
for x,y in [(148,229),(378,278),(564,303),(30,253)]:
    box(x,y,5,3,'#d6c89b'); box(x+1,y,1,2,'#847955')
# Raised foreground deck edge and darkness below.
box(0,330,640,30,'#273b3b'); box(0,330,640,4,'#b0a077'); box(0,334,640,4,'#667764')
for x in range(0,640,32):
    box(x,340,30,20,'#354a46'); line([(x+2,343),(x+27,343)],'#58695a'); box(x+5,347,18,10,'#243735')
# Staggered facade bases approach two thirds of the frame without narrowing the main route.
panel(329,204,42,29,'#585763')
for xx in [334,351]:
    panel(xx,208,14,22,'#8b7d60'); box(xx+4,212,6,12,'#384e4d')
box(327,233,47,3,'#b3a57d')
# Raised support bays, with visible posts rather than a flat bottom border.
for x in range(100,640,48):
    box(x,338,6,22,'#667274'); box(x+1,340,2,18,'#9b9b88'); box(x+8,342,35,3,'#182e33')
# Lower stair flight descends off screen; a landing separates it from the upper one.
box(0,271,76,89,'#2f4144')
for y in range(272,360,9):
    box(0,y,71,3,'#b6b197'); box(0,y+3,71,3,'#7a8376'); box(0,y+6,71,3,'#3b494e')
line([(74,274),(74,359)],'#b7b699',2)
# Broad cool shadow on the right, fading in stepped pixel bands across all static detail.
shade=Image.new('RGBA',(640,360)); sd=ImageDraw.Draw(shade)
for x in range(530,640,4):
    alpha=int(185*((x-530)/110)**0.65)
    sd.rectangle((x,0,x+3,359),fill=(8,25,26,alpha))
im=Image.alpha_composite(im,shade); d=ImageDraw.Draw(im)
im.save(OUT/'lane.png')
# Transparent foreground railing, deliberately independent from the ground.
im=Image.new('RGBA',(640,360)); d=ImageDraw.Draw(im)
for x in range(83,640,32):
    box(x,309,4,28,'#283b3a'); box(x,309,1,25,'#bdc09a'); box(x-2,335,8,3,'#1f3333')
    line([(x+4,316),(x+30,331)],'#526d60',2)
box(78,306,562,4,'#2b4140'); box(78,306,562,1,'#c8c7a0'); box(78,310,562,2,'#839783')
box(78,326,562,3,'#3f5950'); box(78,326,562,1,'#8f9c7a')
for x in range(83,640,32):
    box(x-2,303,8,5,'#d7cf9e')
# Handrail follows the lower stairs instead of crossing the opening.
line([(75,271),(75,359)],'#2a3e40',4)
line([(73,271),(73,359)],'#a4ac90',2)
# Foreground hanging cables and corner foliage.
line([(0,6),(132,21),(337,12),(489,26),(640,4)],'#1e3033',2)
for cx,cy in [(5,321),(625,327),(638,304)]:
    for _ in range(42):
        x=cx+rng.randrange(-18,19); y=cy+rng.randrange(-15,15)
        box(x,y,rng.randrange(3,8),3,rng.choice(['#294c43','#3c6150','#557650','#7f8d58']))
# Right-edge near-black silhouettes like the reference's framing shadow.
d.polygon([(626,0),(640,0),(640,360),(594,360),(599,300),(618,279),(610,229),(624,199)],fill='#102624')
for x,y in [(614,250),(601,286),(623,210)]:
    line([(x,y+35),(x,y)],'#102624',4)
    for dx,dy in [(-12,5),(5,0),(-8,16),(7,20)]: box(x+dx,y+dy,14,5,'#102624')
im.save(OUT/'foreground.png')
# Freestanding objects: transparent sprites anchored at their feet for Y sorting.
for kind in ['planter','table','menu','crate','lamp']:
    im=Image.new('RGBA',(48,64)); d=ImageDraw.Draw(im)
    d.ellipse((5,53,43,62),fill='#354c4160')
    if kind=='planter':
        box(10,42,29,16,'#795b43'); box(8,40,33,4,'#c29d67'); box(12,46,25,2,'#a88356')
        for x in range(14,38,7): line([(x,45),(x,56)],'#4c5140')
        for _ in range(65):
            x=rng.randrange(9,38); y=rng.randrange(19,43)
            box(x,y,4,3,rng.choice(['#375849','#52734e','#7d914f','#a6ad62']))
    elif kind=='table':
        for x in [11,34]: box(x,36,3,20,'#3b463c'); box(x+1,36,1,19,'#b8a070')
        box(5,30,38,7,'#674e3b'); box(5,28,38,5,'#c29963'); box(7,28,34,1,'#edc68b')
        box(11,24,11,3,'#ece0b1'); box(13,21,7,3,'#b7804a'); box(29,20,5,8,'#d8d2a0'); box(30,20,4,2,'#607259')
        for x in [5,37]: box(x,45,8,3,'#ad784c'); box(x+1,48,2,9,'#45483a')
    elif kind=='menu':
        d.polygon([(10,57),(16,22),(34,22),(41,57),(36,57),(31,28),(20,28),(15,57)],fill='#b59766')
        panel(12,23,24,28,'#354c45'); text(15,26,'MENU','#ddd3a3')
        for y in [38,42,46]: box(17,y,13,1,'#c5bf8e')
    elif kind=='crate':
        for x,y in [(7,40),(22,29)]:
            panel(x,y,22,18,'#a5804c')
            for yy in range(y+4,y+16,4): box(x+3,yy,16,1,'#554e36')
            for xx in range(x+4,x+19,6): box(xx,y-3,4,4,'#b9a34d')
    else:
        box(21,9,3,47,'#263c3b'); box(21,10,1,43,'#99a886'); box(16,55,13,3,'#304942')
        line([(22,12),(34,12),(34,17)],'#3a5148',2); panel(29,16,11,13,'#dbb76b'); box(32,19,5,7,'#ffe6a0')
    im.save(OUT/(kind+'.png'))
# Original courier sprite sheet: 4 directions, 4 step phases; bottom pixel is foot anchor.
im=Image.new('RGBA',(96,128)); d=ImageDraw.Draw(im)
for direction in range(4):
    for frame in range(4):
        ox,oy=frame*24,direction*32
        bob=1 if frame in [1,3] else 0
        def p(x,y,w,h,c): box(ox+x,oy+y-bob,w,h,c)
        p(8,24+(1 if frame==1 else 0),4,5,'#25373e'); p(14,24+(1 if frame==3 else 0),4,5,'#25373e')
        p(7,28+(1 if frame==1 else 0),5,2,'#d5b887'); p(14,28+(1 if frame==3 else 0),5,2,'#d5b887')
        p(6,14,13,11,'#34464a'); p(7,14,11,9,'#c76c45'); p(8,15,3,7,'#e19a5f')
        p(5,17,3,6,'#bf704d'); p(18,17,3,6,'#b85d40'); p(5,22,3,3,'#dfb580'); p(18,22,3,3,'#dfb580')
        p(7,4,12,11,'#293a3d'); p(8,7,10,7,'#e3b783'); p(8,4,11,5,'#394347'); p(6,7,4,3,'#394347')
        if direction==1: p(7,7,12,7,'#394347'); p(9,17,8,9,'#6e8672'); p(10,18,6,2,'#bac09a')
        else:
            if direction!=3: p(16,10,1,2,'#293b3b')
            if direction!=2: p(10,10,1,2,'#293b3b')
            p(10,14,9,2,'#e0bc70'); p(17,15,3,6,'#e0bc70')
        p(6,5,14,2,'#a0aaa0'); p(14,3,4,3,'#a0aaa0')
im.save(OUT/'courier.png')
print('Generated 8 original pixel-art textures in',OUT)
