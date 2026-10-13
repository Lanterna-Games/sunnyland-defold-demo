-- Movement for kinematic collision objects: the player, the frog and the opossum.
--
-- Defold never moves a kinematic object. The script sets its position and the engine
-- reports what it ran into, so the response is ours to write. This module is that
-- response, built from what the physics world offers:
--   * ray casts find the floor, before moving, so a body lands on it instead of in it
--   * contact points push the body back out of walls and ceilings, after moving
--
-- A body is a plain table kept in the self of a script. The functions act on the game
-- object of the script that calls them, which calls move() from fixed_update(), ride()
-- from late_update() and contact() from on_message().
local M = {}

M.GRAVITY = -980

local GROUND = hash("ground")
local CRATE = hash("crate")
local ONEWAY = hash("oneway")
-- What a body can stand on. Walls and ceilings are whatever the collision object's
-- mask lets through as contact points, and one-way floors are deliberately not in it.
local FLOORS = { GROUND, CRATE, ONEWAY }

-- The floor rays start this far above the feet, and the collision shape of a body ends
-- this far above them too. Anything lower is stepped onto instead of bumped into, which
-- is what makes slopes and tile seams smooth.
local STEP = 4
-- A body on the floor follows it down by up to this much per step, so it walks down
-- a slope instead of hopping down it.
local SNAP = 4
-- A one-way floor holds a body only if its feet were above it, give or take this much.
local ONEWAY_MARGIN = 1
-- Contact normals steeper than this are a floor or a ceiling, the rest are walls.
local WALL_NORMAL_Y = 0.7


-- half_width and feet place the floor rays: feet is how far below the game object's
-- position the body touches the floor.
function M.new(half_width, feet)
	return {
		velocity = vmath.vector3(),
		half_width = half_width,
		feet = feet,
		-- What the body stands on, where that was when last looked at and whether it
		-- moved the body since the last step (see ride)
		grounded = false,
		ground = nil,
		ground_position = nil,
		carried = false,
		-- How fast it was falling when it last touched down
		impact = 0,
		-- Contact points pile up between two steps. This is how far they pushed so far
		correction = vmath.vector3(),
		-- false lets the body through everything (the player's death drop)
		solid = true,
	}
end


-- Casts down from both edges and the middle of the body, over the distance it is about
-- to fall, and returns the highest hit.
local function find_floor(body, position, drop)
	local feet = position.y - body.feet
	local from = vmath.vector3(0, feet + STEP, 0)
	local to = vmath.vector3(0, feet + drop - (body.grounded and SNAP or 0), 0)

	local floor
	for side = -1, 1 do
		from.x = position.x + side * (body.half_width - 0.5)
		to.x = from.x
		local hit = physics.raycast(from, to, FLOORS)
		-- A ray that starts inside a shape misses it, so a body jumping up through a
		-- one-way platform ignores it for free. The margin covers the last pixels
		local holds = hit and (hit.group ~= ONEWAY or hit.position.y <= feet + ONEWAY_MARGIN
			or (body.grounded and hit.id == body.ground))
		if holds and (not floor or hit.position.y > floor.position.y) then
			floor = hit
		end
	end
	return floor
end


-- One step: gravity, then the move. Call it from fixed_update(), which runs at the
-- same fixed rate as the physics world. Returns the ray cast hit of the floor the body
-- ends up on, or nil in the air.
function M.move(body, dt)
	local position = go.get_position()
	local velocity = body.velocity

	if not body.grounded then
		velocity.y = velocity.y + M.GRAVITY * dt
	end

	local drop = velocity.y * dt
	local floor = body.solid and velocity.y <= 0 and find_floor(body, position, drop) or nil
	if floor then
		-- The physics world learns where a moving floor is only when it steps, so a hit
		-- on the floor that just carried the body is old news. ride() left it in place
		if not (body.carried and floor.id == body.ground) then
			position.y = floor.position.y + body.feet
		end
		body.impact = body.grounded and 0 or -velocity.y
		body.ground = floor.id
		body.ground_position = go.get_world_position(floor.id)
		velocity.y = 0
	else
		position.y = position.y + drop
	end
	body.grounded = floor ~= nil
	body.carried = false

	position.x = position.x + velocity.x * dt
	go.set_position(position)

	-- The physics world steps after this and answers with contact points
	body.correction = vmath.vector3()
	return floor
end


-- Kinematic objects don't push each other, so a body standing on a moving platform
-- has to follow it. Call it from late_update(): by then the property animations of
-- this frame have moved the platforms. go.exists() because a crate can break
-- underfoot.
function M.ride(body)
	if body.grounded and go.exists(body.ground) then
		local ground_position = go.get_world_position(body.ground)
		local moved = ground_position - body.ground_position
		if moved.x ~= 0 or moved.y ~= 0 then
			go.set_position(go.get_position() + moved)
			body.ground_position = ground_position
			body.carried = true
		end
	end
end


-- Pass in every contact_point_response from something solid. This is the separation
-- from the Defold physics manual: several contacts can report the same overlap, so
-- each one only adds what the earlier ones left uncorrected.
function M.contact(body, message)
	if not body.solid then
		return
	end

	local normal, distance = message.normal, message.distance
	if distance > 0 then
		local projection = vmath.project(body.correction, normal * distance)
		if projection < 1 then
			local compensation = (distance - distance * projection) * normal
			go.set_position(go.get_position() + compensation)
			body.correction = body.correction + compensation
		end
	end

	-- The normal points away from what was hit. Stop moving into it
	local velocity = body.velocity
	if math.abs(normal.y) < WALL_NORMAL_Y then
		if velocity.x * normal.x < 0 then
			velocity.x = 0
		end
	elseif velocity.y * normal.y < 0 then
		velocity.y = 0
	end
end


return M
