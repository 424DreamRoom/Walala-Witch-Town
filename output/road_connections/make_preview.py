from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

folder = Path(__file__).resolve().parent
preview = Image.new("RGB", (1280, 394), "#453022")
font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 18)
draw = ImageDraw.Draw(preview)
draw.text((16, 5), "月芽农场 · 东侧连接路", fill="#ead6ad", font=font)
draw.text((656, 5), "小镇 · 西侧连接路", fill="#ead6ad", font=font)
for x, name in [(0, "farm_arrival.png"), (640, "town_to_farm.png")]:
    with Image.open(folder / name) as image:
        preview.paste(image.convert("RGB"), (x, 34))
preview.save(folder / "connected_roads_preview.png")
