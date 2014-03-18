require("framework.init")

-- define global module
game = {}
game.pomelo = require("pomelo.Pomelo").new()

function game.startup()
    game.enterMainScene()
end

function game.exit()
    CCDirector:sharedDirector():endToLua()
end

function game.enterMainScene()
    display.loadScene("SceneMain")
end

