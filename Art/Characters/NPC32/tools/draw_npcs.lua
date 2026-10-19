-- Native Aseprite authoring: every cel is drawn on a 32 x 32 canvas.
-- Run by build_npcs.py. No source images or MyArt files are read or changed.
local out = assert(app.params.out, "out parameter required")
local specs = dofile(app.params.specs)
local pc = app.pixelColor
local ink = "4a3a4e"
local cream = "fff6e2"
local gold = "f0c888"
local function rgb(h)
  return tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16)
end
local function mix(h,t,a)
  local r,g,b=rgb(h);local x,y,z=rgb(t)
  return string.format("%02x%02x%02x",math.floor(r*(1-a)+x*a+.5),math.floor(g*(1-a)+y*a+.5),math.floor(b*(1-a)+z*a+.5))
end
local colors={}
local function color(h)
  if not colors[h] then local r,g,b=rgb(h);colors[h]=pc.rgba(r,g,b,255) end
  return colors[h]
end
local function ramp(h) return {mix(h,ink,.46),mix(h,ink,.18),h,mix(h,cream,.5)} end
local function point(im,x,y,h)
  if x>=0 and x<32 and y>=0 and y<32 then im:drawPixel(x,y,color(h)) end
end
local function rect(im,x1,y1,x2,y2,h)
  for y=y1,y2 do for x=x1,x2 do point(im,x,y,h) end end
end
local function line(im,x1,y1,x2,y2,h)
  local dx,dy=math.abs(x2-x1),-math.abs(y2-y1)
  local sx,sy=x1<x2 and 1 or -1,y1<y2 and 1 or -1
  local e=dx+dy
  while true do
    point(im,x1,y1,h);if x1==x2 and y1==y2 then break end
    local e2=2*e
    if e2>=dy then e=e+dy;x1=x1+sx end
    if e2<=dx then e=e+dx;y1=y1+sy end
  end
end
local function poly(im,pts,h,edge)
  for y=0,31 do
    local xs={}
    for i=1,#pts do
      local a,b=pts[i],pts[i%#pts+1]
      if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then
        xs[#xs+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])
      end
    end
    table.sort(xs)
    for i=1,#xs-1,2 do rect(im,math.ceil(xs[i]),y,math.floor(xs[i+1]),y,h) end
  end
  for i=1,#pts do local a,b=pts[i],pts[i%#pts+1];line(im,a[1],a[2],b[1],b[2],edge or h) end
end
local function box(im,x1,y1,x2,y2,h,edge)
  rect(im,x1,y1,x2,y2,edge or ink);rect(im,x1+1,y1+1,x2-1,y2-1,h)
end
local layerNames={"Boots","Clothing","Face and hands","Hair","Headwear","Accessories"}
local function draw(s,d,phase,mode)
  local ims={};for i=1,6 do ims[i]=Image(32,32,ColorMode.RGB) end
  local boots,cloth,skin,hair,hat,detail=table.unpack(ims)
  -- Hats and dresses often share a hue, so the hat ramp is pushed darker
  -- to keep the silhouette readable instead of merging into the body.
  local c,h,k=ramp(s.cloth),ramp(s.hair),ramp(mix(s.hat,ink,.30))
  local sk=ramp(s.skin)
  local back=d=="up";local side=d=="right" or d=="left"
  -- Author right-facing pixels, then mirror full layers for the left view.
  local guideLeft=s.kind=="guide" and d=="left"
  local cx=side and (guideLeft and 15 or 17) or 16
  local walk=mode=="walk";local eat=mode=="eat"
  local bob=walk and (phase%2==1 and -1 or 0) or 0
  local function y(v) return v+bob end
  local step=walk and ({-1,0,1,0})[phase+1] or 0
  -- Distinct boot stride, with both planted contact poses reaching row 31.
  local lx,rx=cx-3-step,cx+2+step
  if side then lx=cx-2-step;rx=cx+1+step end
  local liftL=walk and (phase>=2 and 1 or 0) or 0
  local liftR=walk and (phase<2 and 1 or 0) or 0
  box(boots,lx-1,28-liftL,lx+2,31-liftL,"8a6468")
  box(boots,rx-1,28-liftR,rx+2,31-liftR,"8a6468")
  line(boots,lx,29-liftL,lx+1,29-liftL,"c8a090")
  line(boots,rx,29-liftR,rx+1,29-liftR,"c8a090")
  -- Tapered shoulders and readable short coat/dress; no scaling of old art.
  local w=side and 4 or 6
  poly(cloth,{{cx-w+1,y(21)},{cx+w-1,y(21)},{cx+w+1,y(24)},{cx+w-1,y(26)},{cx+w,y(28)},{cx-w,y(28)},{cx-w+1,y(26)},{cx-w-1,y(24)}},c[3],ink)
  poly(cloth,{{cx-w+2,y(22)},{cx-1,y(22)},{cx-2,y(25)},{cx-w+1,y(27)}},c[4])
  poly(cloth,{{cx+2,y(22)},{cx+w-1,y(23)},{cx+w-2,y(26)},{cx+w-1,y(27)},{cx+2,y(27)}},c[2])
  line(cloth,cx-w+1,y(28),cx+w-1,y(28),c[1])
  line(cloth,cx,y(24),cx-1,y(27),c[2])
  -- Cream collar, cuffs, shoulder cape or occupational apron.
  if not back then
    poly(cloth,{{cx-4,y(21)},{cx,y(23)},{cx+4,y(21)},{cx+2,y(24)},{cx,y(23)},{cx-2,y(24)}},cream)
    point(detail,cx,y(23),gold)
  else
    poly(cloth,{{cx-4,y(21)},{cx+4,y(21)},{cx+5,y(25)},{cx-5,y(25)}},c[2])
    line(cloth,cx-3,y(22),cx+1,y(22),c[4])
  end
  if s.apron and not back then
    poly(cloth,{{cx-2,y(23)},{cx+2,y(23)},{cx+3,y(27)},{cx-3,y(27)}},s.apron,ink)
    line(cloth,cx-1,y(25),cx+1,y(25),c[2])
  end
  local arm=walk and step or 0
  rect(skin,cx-w-1,y(25)+arm,cx-w,y(26)+arm,sk[3])
  point(skin,cx-w-1,y(25)+arm,sk[4])
  if not side then rect(skin,cx+w,y(25)-arm,cx+w+1,y(26)-arm,sk[3]) end
  -- Head: skin, ears, separated eyes, warm cheek clusters and small mouth.
  poly(skin,{{cx-5,y(13)},{cx+4,y(13)},{cx+6,y(15)},{cx+6,y(18)},{cx+3,y(21)},{cx-3,y(21)},{cx-6,y(18)},{cx-6,y(15)}},sk[3],ink)
  rect(skin,cx-3,y(14),cx+2,y(18),sk[4])
  line(skin,cx-2,y(20),cx+2,y(20),sk[3])
  if not back then
    if side then
      if guideLeft then
        rect(skin,cx-3,y(16),cx-2,y(18),ink);point(skin,cx-3,y(16),cream)
        point(skin,cx-5,y(18),sk[2]);point(skin,cx-3,y(20),sk[1])
      else
        rect(skin,cx+2,y(16),cx+3,y(18),ink);point(skin,cx+2,y(16),cream)
        point(skin,cx+5,y(18),sk[2]);point(skin,cx+3,y(20),sk[1])
      end
    else
      local blink=mode=="idle" and phase==1 or eat and phase==2
      if blink then
        line(skin,cx-4,y(17),cx-2,y(17),ink);line(skin,cx+2,y(17),cx+4,y(17),ink)
      else
        -- 2x2 eyes: highlight upper-left, iris lower-right; no tall dark bar.
        rect(skin,cx-4,y(16),cx-3,y(17),ink);rect(skin,cx+3,y(16),cx+4,y(17),ink)
        point(skin,cx-4,y(16),cream);point(skin,cx+3,y(16),cream)
        point(skin,cx-3,y(17),s.eye or "7a5340");point(skin,cx+4,y(17),s.eye or "7a5340")
      end
      point(skin,cx-5,y(19),sk[2]);point(skin,cx+5,y(19),sk[2])
      point(skin,cx,y(20),sk[1])
    end
  end
  -- Hair cut and rear silhouette are individual for each character.
  if back then
    poly(hair,{{cx-7,y(12)},{cx+6,y(12)},{cx+7,y(16)},{cx+5,y(21)},{cx+2,y(23)},{cx-4,y(22)},{cx-7,y(18)}},h[3],ink)
    poly(hair,{{cx-5,y(14)},{cx-1,y(14)},{cx-2,y(20)},{cx-4,y(21)}},h[4])
    line(hair,cx+3,y(15),cx+3,y(20),h[2])
  else
    poly(hair,{{cx-7,y(12)},{cx+6,y(12)},{cx+7,y(14)},{cx+5,y(16)},{cx+3,y(14)},{cx+1,y(17)},{cx-1,y(14)},{cx-3,y(16)},{cx-4,y(14)},{cx-6,y(18)},{cx-7,y(17)}},h[3],ink)
    line(hair,cx-5,y(13),cx-2,y(13),h[4]);line(hair,cx+1,y(13),cx+4,y(13),h[4])
    line(hair,cx-7,y(15),cx-7,y(19),h[2]);line(hair,cx+6,y(14),cx+6,y(19),h[2])
    if side then
      local sign=guideLeft and -1 or 1
      poly(hair,{{cx-6*sign,y(13)},{cx,y(13)},{cx,y(18)},{cx-2*sign,y(20)},{cx-5*sign,y(20)},{cx-7*sign,y(17)}},h[3],ink)
      line(hair,cx-5*sign,y(15),cx-4*sign,y(18),h[4])
    end
  end
  if s.style=="braids" then
    for _,x in ipairs({cx-7,cx+6}) do
      for i=0,2 do box(hair,x+(i%2),y(19+i*2),x+2+(i%2),y(21+i*2),h[3]);point(hair,x+1+(i%2),y(19+i*2),h[4]) end
      point(detail,x+1,y(25),gold)
    end
  elseif s.style=="long" or s.style=="locks" then
    for _,x in ipairs({cx-7,cx+5}) do
      poly(hair,{{x,y(17)},{x+2,y(17)},{x+3,y(24)},{x+1,y(26)},{x-1,y(24)}},h[3],ink)
      line(hair,x,y(18),x+1,y(23),h[4])
    end
  elseif s.style=="curls" then
    for _,x in ipairs({cx-7,cx+5}) do
      for i=0,2 do poly(hair,{{x,y(17+i*2)},{x+2,y(16+i*2)},{x+3,y(18+i*2)},{x+1,y(20+i*2)},{x-1,y(18+i*2)}},h[3],ink);point(hair,x+1,y(17+i*2),h[4]) end
    end
  elseif s.style=="bob" then
    rect(hair,cx-7,y(18),cx-5,y(21),h[2]);point(hair,cx-6,y(19),h[4])
    rect(hair,cx+5,y(18),cx+7,y(21),h[2]);point(hair,cx+6,y(19),h[3])
  end
  -- Headwear silhouettes: bent pointed, brimmed, work cap and cook's beret.
  if s.head=="cap" then
    poly(hat,{{cx-7,y(8)},{cx-4,y(5)},{cx+3,y(5)},{cx+6,y(8)},{cx+6,y(11)},{cx-7,y(11)}},k[3],ink)
    poly(hat,{{cx-5,y(7)},{cx+1,y(6)},{cx+2,y(9)},{cx-5,y(9)}},k[4])
    poly(hat,{{cx-8,y(11)},{cx+8,y(11)},{cx+9,y(12)},{cx+4,y(13)},{cx-7,y(12)}},k[2],ink)
  elseif s.head=="beret" then
    poly(hat,{{cx-9,y(9)},{cx-6,y(5)},{cx+2,y(4)},{cx+7,y(7)},{cx+8,y(10)},{cx+5,y(12)},{cx-7,y(12)}},k[3],ink)
    poly(hat,{{cx-6,y(7)},{cx+1,y(5)},{cx+4,y(7)},{cx-5,y(9)}},k[4])
    line(hat,cx-5,y(12),cx+5,y(12),k[1])
  else
    local tip=s.tip or 0
    poly(hat,{{cx-8,y(10)},{cx-5,y(8)},{cx-3,y(4)},{cx+1+tip,y(1)},{cx+7+tip,y(2)},{cx+6+tip,y(4)},{cx+3,y(4)},{cx+5,y(8)},{cx+7,y(10)}},k[3],ink)
    poly(hat,{{cx-5,y(8)},{cx-2,y(4)},{cx+1+tip,y(3)},{cx+2,y(5)},{cx,y(8)}},k[4])
    line(hat,cx+3,y(6),cx+5,y(9),k[2])
    local brim=s.wide and 13 or 12
    poly(hat,{{cx-brim,y(11)},{cx-8,y(9)},{cx+7,y(9)},{cx+brim,y(11)},{cx+brim,y(12)},{cx+6,y(13)},{cx-7,y(13)},{cx-brim,y(12)}},k[2],ink)
    line(hat,cx-10,y(11),cx-6,y(10),k[4]);line(hat,cx-5,y(10),cx+5,y(10),k[3])
    line(hat,cx-5,y(9),cx+5,y(9),gold)
    -- Brim shadow only at the temples; the centre stays clear for the fringe.
    line(hat,cx-brim+2,y(13),cx-6,y(13),k[1]);line(hat,cx+6,y(13),cx+brim-2,y(13),k[1])
  end
  -- Headwear signature and occupational accessories occupy their own layer.
  local ax=cx+5
  box(detail,ax-1,y(8),ax+1,y(10),gold);point(detail,ax,y(9),cream)
  if s.prop=="goggles" or s.prop=="hammer" then
    box(detail,cx-5,y(8),cx-1,y(11),"b2c3b8");box(detail,cx+1,y(8),cx+5,y(11),"b2c3b8")
    point(detail,cx-3,y(9),cream);point(detail,cx+3,y(9),cream);point(detail,cx,y(9),gold)
  elseif s.prop=="star" then
    line(detail,ax,y(7),ax,y(11),gold);line(detail,ax-2,y(9),ax+2,y(9),gold);point(detail,ax,y(9),cream)
  elseif s.prop=="leaf" then
    poly(detail,{{ax-2,y(8)},{ax+1,y(7)},{ax+2,y(9)},{ax,y(11)}},"9eb785",ink);point(detail,ax,y(8),cream)
  end
  if (not back or s.kind=="guide") and not eat then
    if s.prop=="hammer" then
      line(detail,cx+8,y(23),cx+8,y(28),"b48a67");box(detail,cx+6,y(21),cx+10,y(24),"9cabb0");point(detail,cx+7,y(22),cream)
    elseif s.prop=="lantern" then
      local lanternX=cx+(back and 9 or -9)
      local lanternY=bob+arm
      line(detail,lanternX,23+lanternY,lanternX,25+lanternY,ink)
      box(detail,lanternX-2,25+lanternY,lanternX+2,29+lanternY,gold)
      rect(detail,lanternX-1,26+lanternY,lanternX+1,27+lanternY,cream)
      line(detail,lanternX-1,29+lanternY,lanternX+1,29+lanternY,"a07558")
      local bookX=cx+(back and -6 or 6)
      box(detail,bookX-2,y(23),bookX+1,y(27),"936172");line(detail,bookX-1,y(24),bookX,y(24),gold)
    elseif s.prop=="book" or s.prop=="star" then
      box(detail,cx+4,y(23),cx+8,y(27),s.prop=="book" and "936172" or k[1]);line(detail,cx+5,y(24),cx+7,y(24),gold)
    elseif s.prop=="letter" then
      box(detail,cx+3,y(24),cx+8,y(28),"aa7b65");box(detail,cx+4,y(24),cx+7,y(26),cream);point(detail,cx+6,y(25),"936172")
    elseif s.prop=="leaf" then
      box(detail,cx+4,y(24),cx+8,y(28),"b48a67");poly(detail,{{cx+6,y(24)},{cx+4,y(21)},{cx+6,y(22)},{cx+8,y(20)},{cx+8,y(23)}},"9eb785",ink)
    elseif s.prop=="spoon" then
      line(detail,cx+8,y(22),cx+7,y(28),gold);box(detail,cx+7,y(21),cx+9,y(23),cream)
    elseif s.prop=="reeds" then
      for i=0,2 do line(detail,cx+6+i,y(27),cx+5+i,y(21-i%2),gold) end
    elseif s.prop=="goggles" then
      box(detail,cx+4,y(24),cx+8,y(28),"aa7b65");line(detail,cx+6,y(24),cx+6,y(27),"b2c3b8")
    else
      line(detail,cx+3,y(22),cx-1,y(27),"aa7b65");box(detail,cx-4,y(26),cx,y(28),gold)
    end
  end
  if eat then
    -- Four distinct spoon positions; bowl and hands remain on editable cels.
    poly(detail,{{cx-4,y(25)},{cx+4,y(25)},{cx+3,y(28)},{cx-3,y(28)}},cream,ink)
    line(detail,cx-2,y(25),cx+2,y(25),"b48a67")
    local spoon=({25,22,21,24})[phase+1]
    line(detail,cx+4,spoon,cx+6,spoon+2,gold);point(detail,cx+3,spoon,cream)
    rect(skin,cx+5,spoon+2,cx+6,spoon+3,sk[3])
  end
  if d=="left" and s.kind~="guide" then
    for i,im in ipairs(ims) do
      local mirrored=Image(32,32,ColorMode.RGB)
      for py=0,31 do for px=0,31 do mirrored:drawPixel(31-px,py,im:getPixel(px,py)) end end
      ims[i]=mirrored
    end
  end
  return ims
end

for _,s in ipairs(specs) do
  local neutral
  if s.kind=="guide" and app.params.preserve_guide then
    local original=app.open(app.params.preserve_guide)
    assert(#original.frames==1,"Only a static guide source can be extended")
    neutral={}
    for i=1,6 do
      local cel=assert(original.layers[i]:cel(1))
      local im=Image(32,32,ColorMode.RGB)
      for py=0,cel.image.height-1 do for px=0,cel.image.width-1 do
        im:drawPixel(px+cel.position.x,py+cel.position.y,cel.image:getPixel(px,py))
      end end
      neutral[i]=im
    end
    original:close()
  end
  local sprite=Sprite(32,32,ColorMode.RGB)
  sprite.gridBounds=Rectangle(0,0,1,1)
  sprite:assignColorSpace(ColorSpace{ sRGB=true })
  sprite.data="Original native 32x32 NPC; authored with Aseprite Lua pixel API. Feet anchor (16,32)."
  local layers={sprite.layers[1]};layers[1].name=layerNames[1]
  for i=2,#layerNames do layers[i]=sprite:newLayer();layers[i].name=layerNames[i] end
  local poses,tags={},{}
  if s.kind=="resident" or s.kind=="guide" then
    for _,d in ipairs({"down","up","right","left"}) do
      local first=#poses+1
      for p=0,3 do poses[#poses+1]={d,p,"walk",.14} end
      tags[#tags+1]={"walk_"..d,first,#poses}
    end
  end
  if s.kind=="guide" then
    poses[#poses+1]={"down",0,"idle",.9};poses[#poses+1]={"down",1,"idle",.16}
    tags[#tags+1]={"idle",17,18}
    for _,d in ipairs({"up","right","left"}) do
      poses[#poses+1]={d,0,"idle",1}
      tags[#tags+1]={"idle_"..d,#poses,#poses}
    end
  else
    local first=#poses+1
    poses[#poses+1]={"down",0,"idle",.9};poses[#poses+1]={"down",1,"idle",.16}
    tags[#tags+1]={"idle",first,#poses}
    first=#poses+1
    for p=0,3 do poses[#poses+1]={"down",p,"eat",.5} end
    tags[#tags+1]={"eat",first,#poses}
  end
  app.transaction("Draw "..s.id.." on 32x32 canvas",function()
    for f,p in ipairs(poses) do
      if f>1 then sprite:newEmptyFrame(f) end
      sprite.frames[f].duration=p[4]
      local images=draw(s,p[1],p[2],p[3])
      if neutral and f==17 then images=neutral end
      for i,im in ipairs(images) do sprite:newCel(layers[i],f,im,Point(0,0)) end
    end
    for _,t in ipairs(tags) do local tag=sprite:newTag(t[2],t[3]);tag.name=t[1] end
  end)
  local paletteColors,seen={},{}
  for _,cel in ipairs(sprite.cels) do
    for it in cel.image:pixels() do local v=it();if pc.rgbaA(v)>0 and not seen[v] then seen[v]=true;paletteColors[#paletteColors+1]=v end end
  end
  table.sort(paletteColors)
  local palette=Palette(#paletteColors+1);palette:setColor(0,Color{r=0,g=0,b=0,a=0})
  for i,v in ipairs(paletteColors) do palette:setColor(i,Color{r=pc.rgbaR(v),g=pc.rgbaG(v),b=pc.rgbaB(v),a=255}) end
  sprite:setPalette(palette)
  sprite:saveAs(out.."/"..s.kind.."s/"..s.id..".aseprite")
  if s.kind=="guide" then
    -- A single-frame native portrait preserves the original front-facing view.
    local portrait=Sprite(32,32,ColorMode.RGB)
    portrait.layers[1].name=layerNames[1]
    for i=2,6 do portrait:newLayer().name=layerNames[i] end
    for i=1,6 do
      local cel=sprite.layers[i]:cel(17)
      portrait:newCel(portrait.layers[i],1,cel.image,cel.position)
    end
    local tag=portrait:newTag(1,1);tag.name="idle"
    portrait:saveAs(out.."/portraits/"..s.id..".aseprite")
    portrait:close()
  end
  sprite:close()
  print("AUTHORED "..s.id.." 32x32 "..#poses.." frames "..#paletteColors.." colors")
end
