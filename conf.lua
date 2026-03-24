--[[
  LÖVE 2D Yapılandırma
  love.conf() başlamadan önce çalışır.
--]]

function love.conf(t)
  t.identity    = "hicret"      -- Kayıt klasörü adı
  t.version     = "11.4"
  t.console     = false

  t.window.title        = "Hicret"
  t.window.width        = 800
  t.window.height       = 600
  t.window.resizable    = true
  t.window.minwidth     = 320
  t.window.minheight    = 240
  t.window.vsync        = 1
  t.window.msaa         = 2
  t.window.highdpi      = true

  -- Kullanılmayan modülleri kapat (performans)
  t.modules.joystick  = false
  t.modules.physics   = false
  t.modules.video     = false
end
