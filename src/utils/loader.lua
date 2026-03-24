--[[
  loader.lua — Modül yükleme yardımcıları
  require("src.utils.loader") çağrısıyla global olarak yüklenir.
--]]

-- LÖVE'nin require yoluna src/ ekle (gerekirse)
-- love.filesystem.setRequirePath çalışmayanlar için fallback
local paths = love.filesystem.getRequirePath()
if not paths:find("src") then
  love.filesystem.setRequirePath(paths .. ";src/?.lua;src/?/init.lua")
end
