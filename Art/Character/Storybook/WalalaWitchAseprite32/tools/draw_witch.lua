-- Native Aseprite drawing. Every coordinate is a pixel on a 32x32 canvas.
-- No image import, resampling, generated bitmap, or access to MyArt.
local out = assert(app.params.out, "Pass --script-param out=<asset directory>")
local normalized=out:gsub("\\", "/"):gsub("/+$", ""):lower()
assert(normalized:match("/art/character/storybook/walalawitchaseprite32$"), "Output must be WalalaWitchAseprite32")
assert(not ("/"..normalized.."/"):find("/myart/",1,true), "MyArt is read-only")
local colors = {
  I="35283f", D="513851", P="715180", V="9673a6", L="bd9bc7",
  H="e0c6df", B="746c8b", S="a5a0b9", W="d8d6e5", F="fff0e5",
  s="c78d83", t="eab29b", f="ffdac0", e="694337", a="dba75f",
  g="9b654c", G="d59c62", Y="f5d389", C="f8e7c6", c="d4ba9d",
  m="68b6bd", n="a1e1d3", z="e1fff0", r="a96e94",
}
local rgba, palette = {}, Palette(25)
palette:setColor(0, Color{r=0,g=0,b=0,a=0})
local order = ("IDPVLHB SWFstfeagGYCcmnzr"):gsub(" ", "")
for i=1,#order do
  local k=order:sub(i,i); local h=colors[k]
  local r,g,b=tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16)
  rgba[k]=app.pixelColor.rgba(r,g,b,255)
  palette:setColor(i,Color{r=r,g=g,b=b,a=255})
end
local names={"hair_back","legs","cape","outfit","face","hair_front","hat","hands_wand","magic"}
local sprite=Sprite(32,32,ColorMode.RGB)
sprite.gridBounds=Rectangle(0,0,1,1)
sprite:setPalette(palette)
sprite.data="Walala / native 32x32 / feet pivot 16,32 / wood and ore use cast / Aseprite Lua original"
local layers={}
for i,name in ipairs(names) do
  layers[name]=i==1 and sprite.layers[1] or sprite:newLayer()
  layers[name].name=name
end
local imgs, flip, ox, oy
local function px(layer,x,y,k)
  x=x+(ox or 0); y=y+(oy or 0)
  if flip then x=31-x end
  assert(x>=0 and x<32 and y>=0 and y<32, "Pixel outside 32x32: "..x..","..y)
  imgs[layer]:drawPixel(x,y,rgba[k])
end
local function rect(layer,x,y,w,h,k)
  for yy=y,y+h-1 do for xx=x,x+w-1 do px(layer,xx,yy,k) end end
end
local function line(layer,x0,y0,x1,y1,k)
  local dx,dy=math.abs(x1-x0),-math.abs(y1-y0)
  local sx,sy=x0<x1 and 1 or -1,y0<y1 and 1 or -1
  local err=dx+dy
  while true do
    px(layer,x0,y0,k)
    if x0==x1 and y0==y1 then break end
    local e=2*err
    if e>=dy then err=err+dy; x0=x0+sx end
    if e<=dx then err=err+dx; y0=y0+sy end
  end
end
local function poly(layer,points,k,border)
  for y=0,31 do for x=0,31 do
    local inside=false; local j=#points
    for i=1,#points do
      local p,q=points[i],points[j]
      if (p[2]>y)~=(q[2]>y) and x<(q[1]-p[1])*(y-p[2])/(q[2]-p[2])+p[1] then inside=not inside end
      j=i
    end
    if inside then px(layer,x,y,k) end
  end end
  if border then for i,p in ipairs(points) do local q=points[i%#points+1]; line(layer,p[1],p[2],q[1],q[2],border) end end
end
local function stamp(layer,x,y,rows)
  for yy,row in ipairs(rows) do for xx=1,#row do local k=row:sub(xx,xx); if k~="." then px(layer,x+xx-1,y+yy-1,k) end end end
end
local function boot(x,y,side,back)
  stamp("legs",x,y,side and {".III.",".DPDI","IPPLI","IIIII"} or {".III",".DPD","IPPD","IIII"})
  if back then px("legs",x+2,y+1,"V") end
end
local function head(direction,bob,blink,sway)
  oy=bob
  local side=direction=="right" or direction=="left"
  if side then
    stamp("hair_back",10,12,{"..IIIII...",".IBSSSWI..","IBSWWWWWI.","IBSWWWWWBI","IBSWWWWSBI",".IBSWWSBI.",".IBSSWSI..","..IBSSI...","...III...."})
    stamp("face",17,14,{".III..","IfttI.","IffftI","IffftI","IffftI",".IftI.","..II.."})
    if blink then line("face",20,16,21,16,"e") else rect("face",20,15,2,3,"e"); px("face",20,15,"F"); px("face",21,17,"a") end
    px("face",21,18,"s")
    stamp("hair_front",15,12,{"IIIII..","SWWWWI.","SWWWSI.","SWWI...","SWI....","SWI....","SWI....","WSI....","SI.....","I......"})
    line("hair_front",16,14,16,18,"F"); px("hair_front",15,20+sway,"W")
  elseif direction=="up" then
    -- Align the back-view hair with the collar and brim center at x=15.5.
    stamp("hair_back",10,12,{"..IIIIIIII..",".IBSSSSSSBI.","IBSWWWWWWBSI","IBSWWWWWWBSI","IBSWWWWWWBSI","IBSWWWWWWBSI",".IBSWWWWBSI.","..IBSWWBSI..","...IBSSBI...","....IIII...."})
    line("hair_front",13,15,13,18,"F"); line("hair_front",16,15,16,19,"W"); line("hair_front",19,15,19,18,"F")
    px("hair_front",12,20+sway,"S"); px("hair_front",21,20-sway,"S")
  else
    stamp("hair_back",8,12,{"...IIIIIIII...","..IBSSSSSSBI..",".IBSWWWWWWBSI.","IBSWWWWWWWWBSI","IBSWWWWWWWWBSI",".IBSWWWWWWBSI.",".IBSWWWWWWBSI.","..IBSWWWWBSI..","...IBSSSSBI...","....IIIIII...."})
    stamp("face",11,14,{".IIIIIIII.","IttffffttI","IftfffftfI","IffffffffI","IffffffffI",".IffffffI.","..IffffI..","...IIII..."})
    for _,x in ipairs({13,18}) do
      if blink then line("face",x,17,x+1,17,"e") else rect("face",x,16,2,3,"e"); px("face",x,16,"F"); px("face",x+1,18,"a") end
    end
    px("face",13,19,"r"); px("face",18,19,"r"); px("face",16,20,"s")
    stamp("hair_front",9,12,{"..IIIIIIIIII..",".ISWWWWWWWWWI.","ISWWWWWWWWWSWI","ISWWWWSIWWWWSI","ISWI.......WSI","ISWI.......WSI","ISWI.......WSI",".IWI.......WSI",".IWSI.....ISWI","..ISI.....ISI.","...I.......I.."})
    px("hair_front",11,20+sway,"W"); px("hair_front",21,20-sway,"S")
  end
  -- Curved felt crown, asymmetrical brim, stitched cream band and moon clasp.
  local hat="hat"
  poly(hat,{{6,11},{10,10},{12,6},{16,3},{19,2},{23,3},{24,5},{21,5},{20,4},{19,6},{20,8},{22,10},{26,11},{27,13},{24,14},{7,14},{4,13},{4,12}},"P","I")
  poly(hat,{{11,10},{13,7},{17,4},{20,3},{21,4},{18,5},{17,8},{18,10}},"V")
  line(hat,14,7,16,5,"L"); line(hat,14,8,15,8,"L"); px(hat,18,4,"H")
  poly(hat,{{19,6},{20,8},{22,10},{24,11},{19,11},{17,9}},"D")
  line(hat,10,10,22,10,"g"); line(hat,9,11,23,11,"C"); line(hat,10,12,22,12,"c")
  line(hat,5,12,8,12,"V"); line(hat,7,13,24,13,"V"); line(hat,9,13,18,13,"L"); px(hat,25,12,"P")
  if direction~="up" then
    stamp(hat,21,9,{".YY","YC.","YC.",".YY"})
  else line(hat,11,11,20,11,"C") end
  oy=0
end
local function draw(direction,action,p)
  imgs={}; for _,name in ipairs(names) do imgs[name]=Image(32,32,ColorMode.RGB) end
  flip=direction=="left"; ox=0; oy=0
  local side=direction=="right" or direction=="left"
  local back=direction=="up"
  local moving=action=="walk" or action=="run"
  local running=action=="run"
  local swing=moving and ({-2,-1,0,1,2,1,0,-1})[p+1] or 0
  local bob=moving and ({0,-1,-1,0,0,-1,-1,0})[p+1] or (action=="idle" and p==1 and -1 or 0)
  local sway=moving and ({-1,-1,0,1,1,1,0,-1})[p+1] or (action=="idle" and p==2 and 1 or 0)
  local flight=running and (p==1 or p==2 or p==5 or p==6) and -1 or 0
  if running then bob=bob+flight; if side then ox=1 end end
  local feet_y=28+flight
  if side then
    boot(13-(running and swing or math.floor(swing/2)),feet_y-(moving and p<4 and 1 or 0),true,true)
    boot(16+(running and swing or math.floor(swing/2)),feet_y-(moving and p>=4 and 1 or 0),true,false)
  else
    boot(11+(moving and math.floor(swing/2) or 0),feet_y-(moving and p<4 and 1 or 0),false,back)
    boot(17-(moving and math.floor(swing/2) or 0),feet_y-(moving and p>=4 and 1 or 0),false,back)
  end
  oy=bob
  local tail=running and 2 or 0
  if side then
    poly("cape",{{13,21},{18,21},{19,24},{19,27},{10-tail,27},{12+sway-tail,24}},"P","I")
    poly("cape",{{13,22},{16,22},{14,25},{11-tail,26}},"V")
    line("cape",11-tail,26,15,26,"L")
    stamp("outfit",15,21,{".IIII.","ICCCPI",".IcVPI",".IPVPI",".IPVPI",".IPVPI","IPPPPI","IIIIII"})
    line("outfit",18,23,20,26,"g"); rect("outfit",19,25,3,3,"I"); rect("outfit",20,25,2,2,"G"); px("outfit",20,25,"Y")
  else
    poly("cape",{{11,21},{20,21},{22+sway,25},{23+sway,27},{18,27},{16,24},{13,27},{8+sway,27},{9+sway,24}},back and "V" or "P","I")
    poly("cape",{{11,22},{15,22},{12,25},{9+sway,26}},"L")
    line("cape",18,23,21+sway,26,"D")
    if back then
      stamp("outfit",12,22,{"ICCCCCCI",".IcVVcI.",".IPVVDI.",".IPVVDI.","IPVVVVDI","IPPPPPDI","IIIIIIII"})
      line("cape",12,24,11+sway,26,"P")
    else
      stamp("outfit",12,21,{".IIIIII.","ICCCCCCI",".IcCCcI.",".IPYVPI.",".IPVVPI.",".IPVVPI.","IPVVVVPI","IIIIIIII"})
      px("outfit",15,23,"Y"); line("outfit",18,23,20,26,"g")
    end
    stamp("outfit",20,25,{"III","IGI","IYI","III"})
  end
  oy=0
  head(direction,bob,action=="idle" and p==3,sway)
  oy=bob
  local magic=action=="cast"
  local fishing=action:sub(1,5)=="fish-"
  if magic or fishing then
    local pose=magic and p or (action=="fish-cast" and p+2 or action=="fish-reel" and 6-p or 4+p)
    local hands={{21,24},{21,23},{22,22},{23,21},{23,22},{23,23},{22,23},{21,24}}
    local tips=side and {{23,18},{22,14},{24,12},{27,14},{28,19},{28,20},{26,19},{24,19}} or back and {{24,17},{23,13},{23,9},{25,10},{26,12},{26,13},{25,14},{24,17}} or {{24,19},{23,15},{23,13},{25,15},{26,22},{26,23},{25,23},{24,20}}
    local h,t=hands[pose+1],tips[pose+1]
    line("hands_wand",h[1],h[2],t[1],t[2],"I")
    line("hands_wand",h[1]+1,h[2],t[1]+1,t[2],"G")
    px("hands_wand",t[1],t[2],"C"); px("hands_wand",t[1]+1,t[2],"Y")
    line("hands_wand",side and 19 or 20,23,h[1],h[2],"P")
    rect("hands_wand",h[1]-1,h[2],3,2,"I"); rect("hands_wand",h[1],h[2],2,1,"f")
    rect("hands_wand",side and 15 or 10,24+(pose%2),2,2,"t")
    if magic and p>=2 and p<=6 then
      local x,y=t[1],t[2]
      if p==2 then px("magic",x-2,y-2,"m"); px("magic",x+2,y+2,"n") end
      if p==3 then
        line("magic",x-2,y,x,y-2,"m"); line("magic",x,y-2,x+2,y,"n"); line("magic",x+2,y,x,y+2,"m"); line("magic",x,y+2,x-2,y,"n"); px("magic",x,y,"z")
      elseif p==4 or p==5 then
        rect("magic",x-1,y-1,3,3,"n"); px("magic",x,y,"z")
        if side then line("magic",x-3,y,x-2,y,"z"); px("magic",x+2,y-2,"n"); px("magic",x+2,y+2,"m")
        elseif back then line("magic",x,y-4,x,y-2,"z"); px("magic",x-3,y-2,"n"); px("magic",x+3,y-2,"m")
        else line("magic",x,y+2,x,y+4,"z"); px("magic",x-3,y+2,"n"); px("magic",x+3,y+2,"m") end
        if p==5 then px("magic",x-3,y-3,"m"); px("magic",x-2,y+3,"n") end
      elseif p==6 then px("magic",x-3,y-1,"m"); px("magic",x+2,y+2,"n"); px("magic",x,y+3,"m") end
    end
  else
    local arm=moving and math.floor(swing/2) or 0
    if side then
      if running then stamp("hands_wand",18,22+arm,{"III","IVI","IfI",".II"})
      else stamp("hands_wand",18+arm,23,{"II","VI","tI","II"}) end
    elseif running then
      stamp("hands_wand",8,22+arm,{".II","IPI","Ift",".II"})
      stamp("hands_wand",21,22-arm,{"II.","IPI","tfI","II."})
    else
      stamp("hands_wand",9,23+arm,{"II","VI","tI","II"})
      stamp("hands_wand",21,23-arm,{"II","IP","It","II"})
    end
  end
  ox=0; oy=0
  return imgs
end
local definitions={{"idle",4,0.7},{"walk",8,0.1},{"run",8,0.065},{"cast",8,0.09},{"fish-cast",4,0.1125},{"fish-wait",2,0.5},{"fish-reel",4,0.15}}
local directions={"down","up","right","left"}
local frameIndex=0
local tagSpecs={}
for _,direction in ipairs(directions) do
  for _,def in ipairs(definitions) do
    local first=frameIndex+1
    for p=0,def[2]-1 do
      frameIndex=frameIndex+1
      local frame=frameIndex==1 and sprite.frames[1] or sprite:newEmptyFrame(frameIndex)
      frame.duration=def[1]=="idle" and ({0.7,0.9,0.7,0.12})[p+1] or def[3]
      local images=draw(direction,def[1],p)
      for _,name in ipairs(names) do sprite:newCel(layers[name],frame,images[name],Point(0,0)) end
    end
    tagSpecs[#tagSpecs+1]={first=first,last=frameIndex,action=def[1],direction=direction}
  end
end
assert(frameIndex==152)
-- Add tags after all frames: inserting at a tag's end otherwise extends its range.
for _,spec in ipairs(tagSpecs) do
  local tag=sprite:newTag(spec.first,spec.last)
  tag.name=spec.action.."-"..spec.direction
  tag.color=Color{r=spec.action=="cast" and 104 or 189,g=spec.action=="cast" and 182 or 155,b=199}
  tag.aniDir=AniDir.FORWARD
  tag.data=(spec.action=="cast" and "One shot; wood/ore/weed/farm all use this casting motion" or "Native 32x32 pixel poses")
end
sprite:saveAs(out.."/walala-witch.aseprite")
print("ASEPRITE DRAW PASS: "..sprite.width.."x"..sprite.height..", "..#sprite.frames.." frames, "..#sprite.layers.." layers, "..#sprite.tags.." tags")
