function love.conf(t)
  t.identity = "stonegrove"
  t.window.title = require("game.logger").VERSION
  t.window.width = 1100
  t.window.height = 700
  t.window.resizable = true
  t.window.minwidth = 800
  t.window.minheight = 500
end
