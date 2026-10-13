-- Plays the level from a script and prints a PASS or FAIL line per check.
-- world.script starts it when the engine runs with --config=test.smoke=1.
--
-- The test is an outsider on purpose: it presses buttons by posting the input actions
-- to the player and looks at what any script could see, positions, properties and
-- whether an object still exists. It moves the player around the level by setting its
-- position, which a kinematic object takes without complaint.
local M = {}

local PLAYER = "/player"
local PLAYER_SCRIPT = "/player#script"
-- Where the player stands at the start: on the grass, feet at y = 48
local SPAWN = vmath.vector3(62, 58, 0)

local checks, failures = 0, 0
local starts = 0
local held = {}
local scenario


-- Helpers. The scenario is a coroutine and every wait yields until the next frame,
-- which hands back the time it took.

local function check(label, ok, detail)
	checks = checks + 1
	if not ok then
		failures = failures + 1
	end
	print(string.format("%s  %s%s", ok and "PASS" or "FAIL", label, detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
end

local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 0.5)
end

local function wait(seconds)
	local time = 0
	repeat
		time = time + coroutine.yield()
	until time >= seconds
	return time
end

local function wait_until(condition, timeout)
	local time = 0
	while not condition() do
		if time >= timeout then
			return nil
		end
		time = time + coroutine.yield()
	end
	return time
end

local function position(id)
	return go.get_position(id or PLAYER)
end

local function health()
	return go.get(PLAYER_SCRIPT, "health")
end

local function send(action, pressed)
	msg.post(PLAYER_SCRIPT, "input", { action_id = hash(action), value = pressed and 1 or 0, pressed = pressed, released = not pressed })
end

local function hold(action)
	held[action] = true
	send(action, true)
end

local function release_all()
	for action in pairs(held) do
		send(action, false)
	end
	held = {}
end

local function tap(action)
	send(action, true)
	wait(0.05)
	send(action, false)
end

-- Waits for an object, the player by default, to stay put for a moment.
local function settle(id)
	local last = position(id)
	local still = 0
	wait_until(function()
		local now = position(id)
		still = vmath.length(now - last) < 0.01 and still + coroutine.yield() or 0
		last = now
		return still > 0.25
	end, 4)
	return position(id)
end

-- Puts the player somewhere with nothing held and, unless told otherwise, full health.
local function place(x, y, hearts)
	release_all()
	go.set(PLAYER_SCRIPT, "health", hearts or 3)
	go.set_position(vmath.vector3(x, y, position().z), PLAYER)
	wait(0.05)
end

-- Hurting the player leaves it invincible for a while. Sit that out somewhere safe.
local function recover()
	place(SPAWN.x, SPAWN.y)
	wait(1.4)
end


-- The scenario.

local function start_of_level()
	local player = settle()
	check("the player starts on the grass with 3 health", near(player.x, SPAWN.x) and near(player.y, SPAWN.y) and health() == 3, player)
	local cherry = go.get_world_position("/cherry19")
	check("the cherry inside the crate sits where the crate is", near(cherry.x, 248) and near(cherry.y, 40), cherry)
	local gem = go.get_world_position("/door_gem")
	check("the gem behind the temple door sits behind the door", near(gem.x, 2007) and near(gem.y, 76), gem)
end


local function walking_and_jumping()
	local start = settle()
	hold("right")
	local time = wait(0.5)
	local travelled = position().x - start.x
	check("walks right at 110 px/s", near(travelled, 110 * time, 4), travelled / time)
	release_all()
	wait(0.1)
	local stopped = position().x
	wait(0.2)
	check("stops at once", near(position().x, stopped, 0.01))

	local floor = position().y
	local top = floor
	tap("jump")
	local airborne = wait_until(function()
		top = math.max(top, position().y)
		return top > floor + 1 and near(position().y, floor, 0.01)
	end, 2)
	-- 300^2 / (2 * 980) = 45.9 px, plus the first step, which has no gravity yet
	check("a jump rises about 48 px", near(top - floor, 48.4, 1), top - floor)
	check("and lasts about 0.6 s", airborne and near(airborne, 0.62, 0.08), airborne)

	hold("down")
	hold("right")
	wait(0.3)
	check("crouching stays put", near(position().x, stopped, 0.01), position().x)
	release_all()

	hold("left")
	wait(2.5)
	check("the wall at the left edge stops the player", near(position().x, 10), position().x)
	release_all()
end


local function slopes()
	-- down the steep slope at x = 160..176 and on along the flat a tile lower
	place(140, 58)
	settle()
	hold("right")
	wait(0.67)
	release_all()
	check("walking down the steep slope ends a tile lower", near(settle().y, 42), position().y)

	hold("left")
	wait(1.0)
	release_all()
	check("and walking back up ends a tile higher", near(settle().y, 58), position().y)

	-- the gentle slope up the first hill, at x = 400..432
	place(380, 42)
	settle()
	hold("right")
	wait(1.0)
	release_all()
	check("walks up the gentle slope", settle().y > 50, position().y)
end


local function one_way_tiles()
	-- the log bridge after the first slope, over a pit
	place(300, 60)
	check("one-way tiles hold what lands on them", near(settle().y, 42), position().y)
end


local function pickups()
	place(144, 58)
	settle()
	check("a cherry overhead is out of reach from the ground", go.exists("/cherry"))
	tap("jump")
	wait(0.6)
	check("jumping collects it", not go.exists("/cherry"))
	settle()
end


local function crates()
	-- set down on top of it, too gently to break it
	place(248, 60)
	check("a crate holds the player's weight", near(settle().y, 58) and go.exists("/crate"), position().y)

	place(248, 90)
	local top = 0
	wait_until(function() return not go.exists("/crate") end, 1)
	check("landing hard on a crate breaks it", not go.exists("/crate"))
	wait_until(function()
		top = math.max(top, position().y)
		return position().y < top
	end, 1)
	check("and bounces the player", top > 70, top)
	local cherry = go.get_world_position("/cherry19")
	check("the cherry inside stays where the crate was", go.exists("/cherry19") and near(cherry.x, 248) and near(cherry.y, 40), cherry)

	place(248, 42)
	wait(0.2)
	check("and can be collected", not go.exists("/cherry19"))
end


local function enemies()
	local opossum = position("/oposum4")
	place(opossum.x, opossum.y + 40)
	local lowest, bounced = math.huge, false
	wait_until(function()
		lowest = math.min(lowest, position().y)
		bounced = position().y > lowest + 15
		return bounced
	end, 1)
	check("falling onto an opossum bounces the player", bounced and lowest > opossum.y, lowest - opossum.y)
	check("without hurting it", health() == 3, health())
	place(SPAWN.x, SPAWN.y)
	wait(1)
	check("the opossum drops off the screen and is gone", not go.exists("/oposum4"))

	-- walking into one from the side
	local frog = settle("/frog")
	place(frog.x - 8, frog.y - 1)
	wait(0.1)
	check("walking into a frog costs a heart", health() == 2, health())
	wait(0.2)
	check("and knocks the player back", position().x < frog.x - 20, position().x - frog.x)
	recover()

	local jumped = wait_until(function() return position("/frog").y > frog.y + 10 end, 2.5)
	check("frogs jump", jumped ~= nil)

	-- a full round of the eagle's patrol takes 4.8 s
	local low, high = math.huge, -math.huge
	wait_until(function()
		local x = position("/eagle").x
		low, high = math.min(low, x), math.max(high, x)
		return false
	end, 5)
	check("eagles patrol 48 px each way", near(low, 319 - 48, 1.5) and near(high, 319 + 48, 1.5), low .. " .. " .. high)
end


local function hazards()
	-- held in place, the second hit comes when the invincibility runs out
	place(1687, 42)
	local function stay(hearts)
		return function()
			go.set_position(vmath.vector3(1687, 42, position().z), PLAYER)
			return health() == hearts
		end
	end
	local first = wait_until(stay(2), 1)
	check("spikes hurt", first ~= nil, health())
	local second = wait_until(stay(1), 2)
	check("staying on them hurts again after 1.2 s", second and near(second, 1.2, 0.1), second)
	recover()
end


local function ladder()
	place(1890, 74)
	settle()
	hold("up")
	wait(0.1)
	check("pressing up at the ladder grabs it", position().x == 1896, position().x)
	local from = position().y
	local time = wait(1.0)
	check("climbs at 60 px/s", near((position().y - from) / time, 60, 3), (position().y - from) / time)
	release_all()
	wait(0.1)
	from = position().y
	wait(0.2)
	check("hangs still with nothing held", position().y == from)

	hold("up")
	wait(2.5)
	check("stops at the top of the ladder", near(position().y, 218), position().y)
	check("collects the gem up there", not go.exists("/gem5"))
	release_all()
	tap("jump")
	wait(0.2)
	check("can't jump off while inside the shaft", near(position().y, 218) and position().x == 1896, position())

	hold("down")
	wait_until(function() return position().y <= 74 end, 4)
	release_all()
	check("steps off at the bottom", near(settle().y, 74), position().y)

	hold("up")
	wait(0.7)
	release_all()
	from = position().y
	tap("jump")
	wait(0.1)
	check("jumps off the ladder", position().y > from + 15, position().y - from)
	settle()
end


local function crank_and_door()
	place(2007, 74)
	settle()
	check("the gem can't be had while the door is shut", go.exists("/door_gem"))

	place(2212, 74)
	settle()
	tap("up")
	wait(0.2)
	place(2007, 74)
	wait(0.3)
	check("pulling the crank opens the door and lets the gem out", not go.exists("/door_gem"))
end


local function crusher()
	place(2160, 74)
	local hit = wait_until(function() return health() < 3 end, 1.5)
	check("walking under the crusher brings it down on the player", hit ~= nil, health())
	local block, player = position("/crusher"), position()
	check("it stops above the player's head", block.y - 16 >= player.y + 10 - 0.5, block.y - 16 - (player.y + 10))
	place(2200, 74)
	wait(2.5)
	check("then goes back up", near(position("/crusher").y, 128), position("/crusher").y)

	-- with nobody under it, it goes all the way
	place(2160, 74)
	wait(0.2)
	place(2200, 74)
	local lowest = math.huge
	wait_until(function()
		lowest = math.min(lowest, position("/crusher").y)
		return false
	end, 1.5)
	check("an unobstructed slam goes 48 px down", near(lowest, 80, 1), lowest)
	recover()
	wait(1)
end


local function platforms()
	local platform = position("/platform_long")
	place(platform.x, platform.y + 19)
	settle()

	local low, high, off = math.huge, -math.huge, 0
	wait_until(function()
		local y = position("/platform_long").y
		low, high = math.min(low, y), math.max(high, y)
		off = math.max(off, math.abs(position().y - (y + 18)))
		return false
	end, 5.2)
	check("the platform travels 80 px up and back", near(low, 72, 1) and near(high, 152, 1), low .. " .. " .. high)
	check("and carries the player all the way", off < 1.5, off)

	-- dropped into the middle of it, the player is not lifted onto it
	platform = position("/platform_long")
	place(platform.x, platform.y)
	wait(0.4)
	check("the platform is not solid from below", position().y < position("/platform_long").y, position().y - position("/platform_long").y)
	recover()
end


local function wait_for_restart()
	local before = starts
	local restarted = wait_until(function() return starts > before end, 6)
	wait(0.5)
	return restarted ~= nil
end


local function death()
	local frog = settle("/frog2")
	place(frog.x - 8, frog.y - 1, 1)
	wait(0.3)
	check("losing the last heart kills the player", health() == 0, health())
	check("and restarts the level", wait_for_restart())
	local player = settle()
	check("with everything back in place", near(player.x, SPAWN.x) and near(player.y, SPAWN.y) and health() == 3, player)
	check("including what was broken, killed or collected", go.exists("/crate") and go.exists("/oposum4") and go.exists("/cherry"))
end


local function pit()
	place(300, -45)
	wait(0.2)
	check("falling out of the level is a death", health() == 0, health())
	check("and restarts the level", wait_for_restart())
	settle()
end


local function exit_door()
	place(3480, 74)
	check("stands on the ground by the exit", near(settle().y, 74), position().y)
	hold("right")
	wait(0.6)
	release_all()
	wait(1.0)
	check("the door takes over and walks the player to its middle", near(position().x, 3530, 2), position().x)
	wait(0.8)
	check("where it fades out", go.get("/player#sprite", "tint.w") == 0, go.get("/player#sprite", "tint.w"))
end


local function run()
	start_of_level()
	walking_and_jumping()
	slopes()
	one_way_tiles()
	pickups()
	crates()
	enemies()
	hazards()
	ladder()
	crank_and_door()
	crusher()
	platforms()
	death()
	pit()
	exit_door()
end


local function step(dt)
	local ok, message = coroutine.resume(scenario, dt)
	if not ok then
		print("FAIL  the test script broke: " .. tostring(message))
		print(debug.traceback(scenario))
		failures = failures + 1
	end
	if coroutine.status(scenario) == "dead" then
		print(string.format("%d checks, %d failed", checks, failures))
		sys.exit(failures == 0 and 0 or 1)
	end
end


-- Called from the init() of world.script. A timer belongs to the script that creates
-- it, so the scenario runs inside the level's collection, where go.* reaches the
-- level's objects. A restart takes the timer down with the collection, and the next
-- init() picks the scenario up where it left off.
function M.start()
	starts = starts + 1
	scenario = scenario or coroutine.create(run)
	timer.delay(0, true, function(_, _, dt)
		step(dt)
	end)
end


return M
