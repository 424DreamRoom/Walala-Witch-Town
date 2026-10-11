"""Create a nearest-neighbor source contact sheet for choosing placeholder regions."""
from pathlib import Path
from io import BytesIO
import zipfile
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent / "sources"
sheet = Image.open(ROOT / "HenryFood.png").convert("RGBA")
print("HENRY SHEET", sheet.size)
canvas = Image.new("RGB", (640, 800), "#c7bda9")
draw = ImageDraw.Draw(canvas)
for row in range(8):
    for col in range(8):
        food = sheet.crop((col*16,row*16,col*16+16,row*16+16)).resize((64,64),Image.Resampling.NEAREST)
        canvas.paste(food,(col*80+8,row*80),food)
        draw.text((col*80+8,row*80+64),str(col)+","+str(row),fill="#302a25")
with zipfile.ZipFile(ROOT / "food-fleurman_0.zip") as archive:
    for index in range(1,11):
        food = Image.open(BytesIO(archive.read("24x24/tea_%02d.png" % index))).convert("RGBA")
        food = food.resize((48,48),Image.Resampling.NEAREST)
        x,y = (index-1)%8*80+8,640+(index-1)//8*80
        canvas.paste(food,(x,y),food)
        draw.text((x,y+50),"tea_%02d"%index,fill="#302a25")
    print(archive.read("food-Fleurman.txt").decode())
for name,member in [("food-bluecarrot16_20201221_0.zip","food-bluecarrot16.txt"),("food-7soul1_20201212.zip","food-7Soul1.txt")]:
    with zipfile.ZipFile(ROOT / name) as archive:
        print(archive.read(member).decode())
canvas.save(ROOT / "source-contact-sheet.png")
