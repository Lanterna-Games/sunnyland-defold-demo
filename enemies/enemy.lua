-- What every enemy has in common. A script cannot inherit from another, so sharing
-- code means a Lua module that the enemy scripts call from their own callbacks.
-- The state stays in the self of each script: a module is loaded once and its locals
-- would be shared by every enemy in the level.
local kinematic = require("world.kinematic")

local M = {}

local GROUND = hash("ground")
local CRATE = hash("crate")

local HOP_HEIGHT, HOP_TIME = 16, 0.15
local DROP_HEIGHT, DROP_TIME = 240, 0.6


-- Stomped: flips over, hops and drops off the screen. Property animations do the
-- moving, and the last one deletes the game object when it completes.
function M.die(self)
	self.dead = true
	msg.post("#collisionobject", "disable")
	if self.timer then
		timer.cancel(self.timer)
	end
	go.cancel_animations(".")
	sprite.set_vflip("#sprite", true)

	local y = go.get_position().y
	go.animate(".", "position.y", go.PLAYBACK_ONCE_FORWARD, y + HOP_HEIGHT, go.EASING_OUTQUAD, HOP_TIME, 0, function()
		go.animate(".", "position.y", go.PLAYBACK_ONCE_FORWARD, y - DROP_HEIGHT, go.EASING_INQUAD, DROP_TIME, 0, function()
			go.delete()
		end)
	end)
end


-- For the enemies that walk and keep a kinematic body in self.body: walls stop them.
function M.contact(self, message)
	if message.other_group == GROUND or message.other_group == CRATE then
		kinematic.contact(self.body, message)
	end
end


return M
