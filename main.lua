--[[
  HİCRET — Ana Giriş Noktası  v0.6
  LÖVE 2D 11.x | DUT Design Agency
--]]

require("src.utils.loader")

local StateManager       = require("src.systems.state_manager")
local InputManager       = require("src.systems.input_manager")
local AudioManager       = require("src.systems.audio_manager")
local TouchManager       = require("src.systems.touch_manager")
local Config             = require("src.utils.config")
local I18n               = require("src.systems.i18n")

local BootState          = require("src.states.boot")
local MenuState          = require("src.states.menu")
local WorldMapState      = require("src.states.world_map")
local ChapterState       = require("src.states.chapter")
local ActState           = require("src.states.act")
local OutcomeState       = require("src.states.outcome")
local ArchiveState       = require("src.states.archive")
local SettingsState      = require("src.states.settings")
local NetworkState       = require("src.states.network")
local NetworkRevealState = require("src.states.network_reveal")

function love.load()
  love.window.setTitle("Hicret")
  love.graphics.setDefaultFilter("linear", "linear")
  love.keyboard.setKeyRepeat(true)

  Config.init()
  Config.applyWindowSettings()
  I18n.init("tr")

  StateManager.register("boot",           BootState)
  StateManager.register("menu",           MenuState)
  StateManager.register("world_map",      WorldMapState)
  StateManager.register("chapter",        ChapterState)
  StateManager.register("act",            ActState)
  StateManager.register("outcome",        OutcomeState)
  StateManager.register("archive",        ArchiveState)
  StateManager.register("settings",       SettingsState)
  StateManager.register("network",        NetworkState)
  StateManager.register("network_reveal", NetworkRevealState)

  InputManager.init()
  StateManager.switch("boot")
end

function love.update(dt)
  InputManager.update(dt)
  AudioManager.update(dt)
  TouchManager.update(dt)
  StateManager.update(dt)
end

function love.draw()
  Config.pushViewport()
    StateManager.draw()
  Config.popViewport()
end

-- ─── Klavye ─────────────────────────────────────────────────────────
function love.keypressed(key, scancode, isrepeat)
  StateManager.keypressed(key, scancode, isrepeat)
end
function love.keyreleased(key, scancode)
  StateManager.keyreleased(key, scancode)
end

-- ─── Fare ───────────────────────────────────────────────────────────
function love.mousepressed(x, y, button)
  local lx, ly = Config.toLogical(x, y)
  StateManager.mousepressed(lx, ly, button)
end
function love.mousereleased(x, y, button)
  local lx, ly = Config.toLogical(x, y)
  StateManager.mousereleased(lx, ly, button)
end
function love.mousemoved(x, y, dx, dy)
  local lx, ly = Config.toLogical(x, y)
  local ldx = dx * (Config.VIRTUAL_W / Config.screenW)
  local ldy = dy * (Config.VIRTUAL_H / Config.screenH)
  if StateManager.mousemoved then StateManager.mousemoved(lx, ly, ldx, ldy) end
end
function love.wheelmoved(wx, wy)
  local mx, my = Config.toLogical(love.mouse.getPosition())
  if StateManager.wheelmoved then StateManager.wheelmoved(mx, my, wy) end
end

-- ─── Dokunmatik ─────────────────────────────────────────────────────
function love.touchpressed(id, x, y, dx, dy, pressure)
  local lx, ly = Config.toLogical(x, y)
  TouchManager.pressed(id, lx, ly)
  StateManager.touchpressed(id, lx, ly, pressure)
end
function love.touchreleased(id, x, y, dx, dy, pressure)
  local lx, ly = Config.toLogical(x, y)
  TouchManager.released(id, lx, ly)
  StateManager.touchreleased(id, lx, ly, pressure)
end
function love.touchmoved(id, x, y, dx, dy, pressure)
  local lx, ly = Config.toLogical(x, y)
  local ldx = dx * (Config.VIRTUAL_W / Config.screenW)
  local ldy = dy * (Config.VIRTUAL_H / Config.screenH)
  TouchManager.moved(id, lx, ly, ldx, ldy)
  StateManager.touchmoved(id, lx, ly, ldx, ldy, pressure)
end

-- ─── StateManager — wheelmoved ve mousemoved yönlendirmesi ──────────
-- (StateManager bu olayları state'e iletmek için genişletildi)
local _sm_orig_update = StateManager.update
do
  local _cur_wheel = StateManager
  -- Basit wheel/mousemoved yönlendirme — state'de tanımlıysa çağır
  local SM_meta = getmetatable(StateManager) or {}
  -- wheelmoved ve mousemoved'u StateManager üzerinden ilet
  function StateManager.wheelmoved(mx, my, dy)
    local cur = StateManager._getCurrent and StateManager._getCurrent()
    if cur and cur.wheelmoved then cur:wheelmoved(mx, my, dy) end
  end
  function StateManager.mousemoved(mx, my, dx, dy)
    local cur = StateManager._getCurrent and StateManager._getCurrent()
    if cur and cur.mousemoved then cur:mousemoved(mx, my, dx, dy) end
  end
  -- _getCurrent helper
  function StateManager._getCurrent()
    -- state_manager içindeki _current'e erişim için bir hook
    -- state_manager.lua'ya _getCurrent eklenecek
    return nil
  end
end

function love.resize(w, h)
  Config.onResize(w, h)
end

function love.quit()
  AudioManager.stopAll()
  local SaveSystem = require("src.systems.save_system")
  SaveSystem.flush()
  return false
end
