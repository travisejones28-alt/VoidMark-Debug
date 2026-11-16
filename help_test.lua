-- lua5.1 help_test.lua: every /vmd subcommand is in the Help window; it opens.
local function read(p) local f=assert(io.open(p)); local s=f:read('*a'); f:close(); return s end
local frames={}
local function frame(kind,name)
  local f={kind=kind,scripts={},shown=true}
  setmetatable(f,{__index=function(t,k)
    if k=='SetScript' then return function(s,e,fn) s.scripts[e]=fn end end
    if k=='Show' then return function(s) s.shown=true end end
    if k=='Hide' then return function(s) s.shown=false end end
    if k=='IsShown' then return function(s) return s.shown end end
    if k=='SetText' then return function(s,v) s.text=v end end
    if k=='GetText' then return function(s) return s.text or '' end end
    if k=='CreateFontString' then return function() return frame('FontString') end end
    return function() end
  end})
  if name then _G[name]=f end
  return f
end
CreateFrame=function(kind,name) return frame(kind,name) end
UIParent=frame('Frame'); UISpecialFrames={}
assert(loadfile('Help.lua'))()
local H=VoidMarkDebugHelp
local source=read('VoidMarkDebug.lua')
local handler=source:sub((source:find('SlashCmdList.VOIDMARKDEBUG',1,true)))
local listed={}
for entry in read('Help.lua'):gmatch("{'(/vmd[^']*)'") do for w in entry:gmatch('%w+') do listed[w]=true end end
local count=0
for w in handler:gmatch('cmd=="(%w+)"') do count=count+1; assert(listed[w],'Help.lua is missing /vmd '..w) end
for w in handler:gmatch('word=="(%w+)"') do assert(listed[w] or w=='faq' or w=='commands','missing '..w) end
assert(count>=8,'commands found')
local f=H.Open('report'); assert(f and f:IsShown())
local text,found=H.Text('report'); assert(found>0 and text:find('/vmd report',1,true))
local _,none=H.Text('zzzz'); assert(none==0)
print('PASS: Help lists all '..count..' /vmd commands and opens')
