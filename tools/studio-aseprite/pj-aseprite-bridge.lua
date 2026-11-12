-- Aseprite dans Pokémon Studio Extra : lien avec Studio (lancé par Studio avec --script)
--  * Studio demande d'ouvrir un graphisme du projet (open<TAB>chemin)
--  * seuls les fichiers du dossier graphics du projet peuvent rester ouverts
local port = app.params.port
local root = app.params.root or ''

local function norm(p) return ((p or ''):gsub('/', '\\')):lower() end
local function rootDir() local r = norm(root); if r:sub(-1) ~= '\\' then r = r .. '\\' end; return r end
local function hasPath(fn) return fn and (fn:find('\\', 1, true) or fn:find('/', 1, true)) end
local function inside(fn) local r = rootDir(); return norm(fn):sub(1, #r) == r end

-- action différée (hors des évènements d'Aseprite)
local timers = {}
local function later(f)
  if Timer then
    local t
    t = Timer{ interval = 0.05, ontick = function() t:stop(); timers[t] = nil; f() end }
    timers[t] = true
    t:start()
  else
    f()
  end
end

local function refuse(sprite, saved)
  local fn = sprite.filename
  later(function()
    app.alert{ title = 'Pokémon Studio Extra',
               text = { saved and "Ce fichier a été enregistré hors des graphismes du projet :" or
                        "Seuls les graphismes du projet peuvent être ouverts ici :", root, '', fn } }
    pcall(function() sprite:close() end)
  end)
end

local function check(saved)
  local s = app.sprite
  if s and hasPath(s.filename) and not inside(s.filename) then refuse(s, saved) end
end

app.events:on('sitechange', function() check(false) end)
pcall(function()
  app.events:on('aftercommand', function(ev)
    if ev.name == 'SaveFileAs' or ev.name == 'SaveFile' or ev.name == 'SaveFileCopyAs' then check(true) end
  end)
end)

local function openFile(file)
  for _, s in ipairs(app.sprites) do
    if norm(s.filename) == norm(file) then
      pcall(function() app.sprite = s end)
      return
    end
  end
  app.open(file)
end

local ws
local function onreceive(kind, data)
  if kind ~= WebSocketMessageType.TEXT then return end
  local cmd, arg = data:match('^(%w+)\t?(.*)$')
  if cmd == 'open' and inside(arg) then
    later(function() openFile(arg) end)
  elseif cmd == 'root' then
    root = arg
  elseif cmd == 'exit' then
    later(function() app.command.Exit() end)
  end
end

if port and WebSocket then
  ws = WebSocket{ url = 'ws://127.0.0.1:' .. port, deflate = false, onreceive = onreceive }
  ws:connect()
  PjStudioBridge = ws -- garde le lien en vie
end
