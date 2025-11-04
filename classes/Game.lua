-- KnotAgain!
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local RopeUntangler = require("classes.RopeUntangler")

local Game = {}
Game.__index = Game

function Game.new()
    local instance = setmetatable({}, Game)

    instance.screenWidth = 1000
    instance.screenHeight = 700
    instance.game = RopeUntangler.new()

    return instance
end

function Game:isGameOver()
    return self.game:isGameOver()
end

function Game:setScreenSize(width, height)
    self.screenWidth = width
    self.screenHeight = height
    self.game:setScreenSize(width, height)
end

function Game:startNewGame(difficulty, category)
    self.game:startNewGame(difficulty, category)
end

function Game:handleClick(x, y)
    self.game:handleClick(x, y)
end

function Game:handleMouseMove(x, y, dx, dy)
    self.game:handleMouseMove(x, y, dx, dy)
end

function Game:handleMouseRelease(x, y)
    self.game:handleMouseRelease(x, y)
end

function Game:handleKeypress(key)
    self.game:handleKeypress(key)
end

function Game:update(dt)
    self.game:update(dt)
end

function Game:draw()
    self.game:draw()
end

return Game
