pico-8 cartridge // http://www.pico-8.com
version 10
__lua__

-- object oriented infrastructure. see http://lua-users.org/wiki/inheritancetutorial

function inheritsfrom( baseclass )

    local new_class = {}
    new_class.__index = new_class

    if nil ~= baseclass then
        setmetatable( new_class, { __index = baseclass } )
    end

    -- implementation of additional oo properties starts here --

    -- return the class object of the instance
    function new_class:class()
        return new_class
    end

    -- return the super class object of the instance
    function new_class:superclass()
        return baseclass
    end

    -- return true if the caller is an instance of theclass
    function new_class:isa( theclass )
        local b_isa = false

        local cur_class = new_class

        while ( nil ~= cur_class ) and ( false == b_isa ) do
            if cur_class == theclass then
                b_isa = true
            else
                cur_class = cur_class:superclass()
            end
        end

        return b_isa
    end

    return new_class
end


-- vector class

vector = inheritsfrom( nil )

function vector:new( x, y )
	local newobj = { x = x, y = y }
	return setmetatable( newobj, self )
end

function vector:tostring()
	return self.x .. "," .. self.y
end

function vector:__unm()
	return vector:new( -self.x, -self.y )
end

function vector:__add( other )
	return vector:new( self.x + other.x, self.y + other.y )
end

function vector:__sub( other )
	return vector:new( self.x - other.x, self.y - other.y )
end

function vector:__mul( other )
	return vector:new( self.x * other.x, self.y * other.y )
end

function vector:__div( other )
	return vector:new( self.x / other.x, self.y / other.y )
end

function vector:__eq( other )
	return self.x == other.x and self.y == other.y
end

function vector:dot( other )
	-- todo abort on overflow
	return self.x * other.x + self.y * other.y
end

function vector:lengthsquared()
	return self:dot( self )
end

function vector:length()
	return sqrt( self:lengthsquared() )
end

function vector:manhattanlength()
	return abs( self.x ) + abs( self.y )
end

function vector:normal()
	local len = self:length()
	if len > 0 then
		return vector:new( self.x / len, self.y / len )
	end

	return vector:new( 0, 0 )
end

function vector:perpendicular()
	return vector:new( -self.y, self.x )
end

-- utilities 

function randinrange( min, max )
	assert( max > min )
	return min + rnd( max - min )
end

function wrap( x, min, maxexclusive )
	assert( maxexclusive > min )
	return min + ( x - min ) % ( maxexclusive - min )
end

function clamp( x, least, greatest )
	assert( greatest >= least )
	return min( greatest, max( least, x ))
end

function is_close( a, b, maxdist )
	local delta = b - a

	local manhattanlength = delta:manhattanlength()
	if manhattanlength > maxdist * 1.8 then		-- adding a fudge factor to account for diagonals.
		return false
	end

	if manhattanlength > 180 then
		printh( "objects may be close but we don't have the numeric precision to decide. ignoring." )
		return false
	end

	local distsquared = delta:lengthsquared()

	return distsquared <= maxdist * maxdist
end

function worldtomap( worldpos )
	local pos = worldpos / vector:new( 8, 8 )
	return vector:new( flr( pos.x ), flr( pos.y ))
end

function mapatworld( worldpos )
	local mappos = worldtomap( worldpos )
	return mget( mappos.x, mappos.y )
end

function spriterect( sprite, left, top, right, bottom, step, flipmode, spritewidth, spriteheight )
	step = step or 8
	flipmode = flipmode or "false"
	spritewidth = spritewidth or 1
	spriteheight = spriteheight or 1

	for y = top, bottom, step do
		for x = left, right, step do

			local flip = flipmode == "true" and true or ( flipmode == "random" and rnd( 2 ) == 1 or false )
			spr( sprite, x, y, 1, 1, flip )
		end
	end
end

-- class sprite

sprite = inheritsfrom( nil )

function sprite:new( x, y, width, height )
	assert( x )
	assert( y )

	width = width or 1
	height = height or 1

	local newobj = { 
		pos = vector:new( x, y ),
		spritedims = vector:new( width, height ),
		animation = { 0 },
		animationindex = 1,
		spriteflip = false,
		visible = true,
	}
	return setmetatable( newobj, self )
end

function sprite:currentsprite()
	local index = wrap( self.animationindex, 1, #self.animation + 1 )
	return self.animation[ index ]
end

function sprite:draw()
	if self.visible == false then return end

	local pos = self.pos
	local sprite = self:currentsprite()
	spr( sprite, pos.x, pos.y, self.spritedims.x, self.spritedims.y, self.spriteflip )
end

function sprite:incrementanimation()
	self.animationindex = self.animationindex + 1

	return self:currentsprite()
end

function sprite:makeanimation( base, row, length )
	self.animation = {}
	for i = 1, length do 
		self.animation[ i ] = base + row * 16 + ( i - 1 )
	end
end

-- class body

body = inheritsfrom( nil )

function body:new( x, y, radius )
	assert( x )
	assert( y )
	assert( radius )

	local newobj = { 
		alive = true,
		pos = vector:new( x, y ),
		vel = vector:new( 0, 0 ),
		acc = vector:new( 0, 0 ),
		mass = 1.0,
		radius = radius,
		drag = 0.01,
		color = 1,
		sprite = sprite:new( x, y ),
		basesprite = 64,
		controller = nil,
		controllerimpulsescalar = 1.0,
		footoffset = vector:new( 4, 8 ),
		totalfootmovementdistance = 0,
		footstepdistance = 4,
		footprintsprite = 0,
		feetsnowiness = 0,
		footstep_sfx = nil,
		footstep_sfx_snowy = nil,
		currentmappos = nil,
		collisionmask = 0xff,
		collisionrefusalmask = 0,
	}
	add( bodies, newobj )

	setmetatable( newobj, self )

	newobj:updatecontrollerbasedanimations( vector:new( 0, 0 ))

	return newobj
end

function body:setbasesprite( base )
	self.basesprite = base
	self:updatecontrollerbasedanimations( vector:new( 0, 0 ))		-- to update animations.
end

function body:center()
	return self.pos + vector:new( 4, 4 )
end

function body:update()
	self.acc = self.acc - self.vel * vector:new( self.drag, self.drag )
	self.vel = self.vel + self.acc
	self.pos = self.pos + self.vel

	self.acc.x = 0
	self.acc.y = 0

	-- update "steps" (for footprints and whatnot)

	self.totalfootmovementdistance = self.totalfootmovementdistance + self.vel:length()
	self:updatefootsteps( self.vel )


	-- update map position updates.

	local newmappos = worldtomap( self:center() )

	if self.currentmappos == nil or self.currentmappos != newmappos then

		if self.currentmappos != nil then
			self:onleavingmappos( self.currentmappos )
		end

		self.currentmappos = newmappos

		self:onenteringmappos( self.currentmappos )
	end
end

function body:onenteringmappos( mappos )
end

function body:onleavingmappos( mappos )
end

function body:shouldcollidewithmapsprite( mapsprite )
	return fget( mapsprite, 0 ) or is_closed_gate( mapsprite )
end

function body:updateworldcollision()

	-- check collision with the boundaries of the world.

	self.pos.x = clamp( self.pos.x, 0, world_size.x - self.radius * 2 )
	self.pos.y = clamp( self.pos.y, 0, world_size.y - self.radius * 2 )

	-- check collision with the 4 corners.

	local center = self:center()
	local offset = vector:new( 2, 2 )

	for i = 0, 3 do
		local corner = center + offset

		local mapsprite = mapatworld( corner )
		if self:shouldcollidewithmapsprite( mapsprite ) then

			-- colliding. move out.

			self.pos = self.pos - offset
		end

		offset = offset:perpendicular()
	end

end

function body:draw()
	self.sprite.pos = self.pos
	self.sprite:draw()
end

function body:addimpulse( impulse )
	if self.mass > 0 then
		self.acc = self.acc + impulse / vector:new( self.mass, self.mass )
	end
end

function body:updatefootsteps( impulse )
	if self.totalfootmovementdistance > self.footstepdistance then
		self.totalfootmovementdistance = 0
		local newsprite = self.sprite:incrementanimation()

		if fget( newsprite, 6 ) then	-- footstep frame?
			self:onfootstep()
		end
	end
end

function body:updatecontrollerbasedanimations( impulse )
	self.sprite.animation = { self.basesprite }
	self.sprite.spriteflip = false
end

function body:addcontrollerimpulse( impulse )
	self:addimpulse( impulse * vector:new( self.controllerimpulsescalar, self.controllerimpulsescalar ) )
	self:updatecontrollerbasedanimations( impulse )
end

function body:footposition()
	return self.pos + self.footoffset
end

function body:onfootstep()

	-- decline snowiness.

	self.feetsnowiness = clamp( self.feetsnowiness - 0.1, 0, 1 )

	-- gather snowiness.

	local mapsprite = mapatworld( self:footposition() )

	local footstepsfx = nil
	if fget( mapsprite, 3 )	then -- snowy?
		self.feetsnowiness = clamp( self.feetsnowiness + 0.15, 0, 1 )

		footstepsfx = self.footstep_sfx_snowy or self.footstep_sfx
	else
		footstepsfx = self.footstep_sfx
	end

	if footstepsfx then
		sfx( footstepsfx )
	end

	-- place footprints
	if self.feetsnowiness > 0 and self.footprintsprite > 0 then
		self:makefootprint( self.pos )
	end
end

function body:makefootprint( pos )
	local footprint = sprite:new( pos.x, pos.y )
	footprint.animation = { self.footprintsprite }
	add( footprints, footprint )
end

-- class player

player = inheritsfrom( body )

function player:new( x, y )
	local newobj = body:new( x, y, 4 )

	newobj.drag = 0.5
	newobj.controllerimpulsescalar = 0.8
	newobj.collisionrefusalmask = 1			-- players don't collide with each other.
	newobj.footprintsprite = 112
	newobj.footstep_sfx = 0
	newobj.footstep_sfx_snowy = 2
	newobj.covering = nil
	newobj.enteredcoveringtime = nil

	return setmetatable( newobj, self )
end

function player:shouldcollidewithmapsprite( mapsprite )
	return fget( mapsprite, 0 )
end

function player:updatecontrollerbasedanimations( impulse )
	if impulse.x == 0 and impulse.y == 0 then
		self.sprite.animation = { self.basesprite }
		self.sprite.spriteflip = false
	elseif abs( impulse.y ) >= abs( impulse.x ) then
		local spriterow = impulse.y >= 0 and 0 or 1
		self.sprite:makeanimation( self.basesprite, spriterow, 4 )
		self.sprite.spriteflip = false
	else
		self.sprite:makeanimation( self.basesprite, 2, 4 )
		self.sprite.spriteflip = impulse.x >= 0
	end
end

function player:update()
	self:superclass().update( self )

	local newcovering = find_covering_hidingplace( self:center(), self.radius )

	if self.covering ~= newcovering then
		if self.covering then
			self:leavecovering( self.covering )
		end

		self.covering = newcovering

		if self.covering then
			self:entercovering( self.covering )
		end
	end
end

function player:entercovering( covering )
	self.enteredcoveringtime = stateticks
end

function player:leavecovering( covering )
	self.enteredcoveringtime = nil
end

function player:currentcovering()
	return self.covering
end

function player:secondsundercovering()
	return self.enteredcoveringtime and ticks_to_seconds( stateticks - self.enteredcoveringtime ) or 0
end

function player:updategates( mappos )
	local mapsprite = mget( mappos.x, mappos.y )

	-- update gates.
	if fget( mapsprite, 2 )	then -- gate?

		local horizontalgate = fget( mapsprite, 4 )

		local playsound = false

		if horizontalgate then
			-- what direction are we going?
			if self.vel.y > 0 then
				-- down				
				playsound = setgate( mappos, vector:new( 1, 0 ), 39, 40 )
			else
				-- up
				playsound = setgate( mappos, vector:new( 1, 0 ), 23, 24 )
			end
		else
			-- what direction are we going?
			if self.vel.x > 0 then
				-- right
				playsound = setgate( mappos, vector:new( 0, 1 ), 22, 38 )
			else
				-- left
				playsound = setgate( mappos, vector:new( 0, 1 ), 21, 37 )
			end
		end
		
		if playsound then
			sfx( 1 )
		end
	end
end

function player:onenteringmappos( mappos )
	printh( "entering " .. mappos:tostring() )
	self:updategates( mappos )
end

function player:onleavingmappos( mappos )
	self:updategates( mappos )
end


-- class chicken 

chicken = inheritsfrom( body )

function chicken:new( x, y )
	local newobj = body:new( x, y, 3 )

	newobj:setbasesprite( 113 )
	newobj.drag = 0.5
	newobj.controllerimpulsescalar = 0.8
	newobj.collisionmask = 0
	newobj.footprintsprite = 57

	newobj.fleedestination = nil
	newobj.fleeticks = 0

	newobj.wanderdirection = nil

	return setmetatable( newobj, self )
end

function chicken:update()

	self:superclass().update( self )

	self:update_ai()

	-- update chicken animations

	if self.fleedestination then
		-- moving
		self.sprite.animation = { self.basesprite + 2 }		
	else
		-- still
		local sprite = rnd( 100 ) < 2 and self.basesprite + 1 or self.basesprite
		self.sprite.animation = { sprite }		
	end


	self.sprite.spriteflip = self.vel.x > 0

end

function chicken:update_ai()

	if currentplayer == nil then return end

	if self.fleedestination then

		self.fleeticks += 1

		-- fleeing

		-- have we gotten to our destination?
		if is_close( self.fleedestination, self.pos, 4 ) then
			-- yes. stop fleeing
			self:makefootprint( self.pos )
			self.fleedestination = nil
			return
		end

		-- spent too long fleeing?
		if self.fleeticks > 30 * 1.25 then
			self:makefootprint( self.pos )
			self.fleedestination = nil
			return
		end

		self:addcontrollerimpulse( ( self.fleedestination - self.pos ):normal() )
		return
	else
		-- not fleeing. should we be?

		local maxresponsedistance = 3 * 8

		if is_close( currentplayer.pos, self.pos, maxresponsedistance ) then
			-- flee!

			local delta = currentplayer.pos - self.pos
		
			local normal = delta:normal()

			self.wanderdirection = nil
			self.fleedestination = self.pos + normal * -vector:new( 2 * 8, 2 * 8 ) + vector:new( 8 * randinrange( -2, 2 ), 8 * randinrange( -2, 2 ) )
			self.fleeticks = 0

			sfx( 3 )
		else
			self:updatewandering()
		end
	end
end

function chicken:updatewandering()
	if self.wanderdirection then
		if rnd( 100 ) < 5 then
			self.wanderdirection = nil
			return
		end

		self:addcontrollerimpulse( self.wanderdirection * vector:new( 0.25, 0.25 ) )
	else
		if rnd( 100 ) < 0.5 then
			self.wanderdirection = vector:new( randinrange( -10, 10 ), randinrange( -10, 10 ) ):normal()
		end
	end
end

-- class barrel

barrel = inheritsfrom( body )

function barrel:new( x, y )
	local newobj = body:new( x, y, 4 )
	newobj.drag = 0.25
	newobj.footprintsprite = 41
	newobj.footstepdistance = 1
	newobj.footoffset = vector:new( 4, 4 )

	setmetatable( newobj, self )
	newobj:setbasesprite( 9 )
	return newobj
end


-- class controller

controller = inheritsfrom( nil )

function controller:new( body )
	local newobj = { 
		body = body
	}
	if body != nil then body.controller = newobj end
	return setmetatable( newobj, self )
end

function controller:update()
end

-- class playercontroller 

playercontroller = inheritsfrom( controller )

function playercontroller:new( body )
	local newobj = controller:new( body )
	return setmetatable( newobj, self )
end

function playercontroller:update()
	local playerindex = 0

	local move = vector:new( 0, 0 )

	if btn( 0, playerindex ) then
		move.x -= 1
	end
	if btn( 1, playerindex ) then
		move.x += 1
	end
	if btn( 2, playerindex ) then
		move.y -= 1
	end
	if btn( 3, playerindex ) then
		move.y += 1
	end

	self.body:addcontrollerimpulse( move:normal() )
end

-- world state

map_size = vector:new( 48, 25 )
world_size = map_size * vector:new( 8, 8 )

thecamera = vector:new( 0, 0 )

function clearworld()
	thecamera = vector:new( 0, 0 )
	hider = nil
	seeker = nil
	winner = nil
	currentplayer = nil
	bodies = {}
	footprints = {}
	hidingplaces = {}
	shadows = {}
	donesearching()
end

function initializeworld()
	clearworld()

	tidymap()

	-- trees

	local smalltreecoveragebr = vector:new( 3.5 * 8, 3.5 * 8 )
	local largetreecoveragebr = vector:new( 3.5 * 8, 3.5 * 8 )

	local smalltreeshadowoffset = vector:new( 2, 2 )
	local largetreeshadowoffset = vector:new( 4, 4 )

	hidingplace:new( 135, 10 * 8, -1 * 8, vector:new( 0, 0 ), largetreecoveragebr, largetreeshadowoffset  )
	hidingplace:new( 131, 20 * 8,  2 * 8, vector:new( 0, 0 ), smalltreecoveragebr, smalltreeshadowoffset )
	hidingplace:new( 135, 26 * 8,  0 * 8, vector:new( 0, 0 ), largetreecoveragebr, largetreeshadowoffset )
	hidingplace:new( 135, 13 * 8, 10.5 * 8, vector:new( 0, 0 ), largetreecoveragebr, largetreeshadowoffset )
	hidingplace:new( 131, 16 * 8, 11 * 8, vector:new( 0, 0 ), smalltreecoveragebr, smalltreeshadowoffset )
	hidingplace:new( 135, 24 * 8, 22 * 8, vector:new( 0, 0 ), smalltreecoveragebr, largetreeshadowoffset )
	hidingplace:new( 131, 37 * 8, 18 * 8, vector:new( 0, 0 ), smalltreecoveragebr, smalltreeshadowoffset )
	hidingplace:new( 131, 37 * 8, -2 * 8, vector:new( 0, 0 ), smalltreecoveragebr, smalltreeshadowoffset )
	hidingplace:new( 131, -1 * 8,  7 * 8, vector:new( 0, 0 ), smalltreecoveragebr, smalltreeshadowoffset )
	hidingplace:new( 135, 45 * 8, 22 * 8, vector:new( 0, 0 ), largetreecoveragebr, largetreeshadowoffset )
	hidingplace:new( 135, 29 * 8, 13 * 8, vector:new( 0, 0 ), largetreecoveragebr, largetreeshadowoffset )

	-- sw barn
	local swbarn = hidingplace:new( 128, 0 * 8, 21 * 8, vector:new( 0, 0 ), vector:new( 7 * 8, 4 * 8 ))
	swbarn.draw = function( self )
		if self.visible == false then return end
		for y = 0, 3 do
			for x = 0, 6 do
				local index = band( y, 1 ) == 0 and 128 or ( x == 6 and 130 or 129 )
				spr( index, self.pos.x + x * 8, self.pos.y + y * 8 )
			end
		end
	end

	-- ne barn
	local nebarn = hidingplace:new( 196, 42*8, 0, vector:new( 0, 0 ), vector:new( 6 * 8, 4 * 8 ) )

	nebarn.draw = function( self )
		if self.visible == false then return end
		for y = 0, 3 do
			for x = 0, 5 do
				local index = band( y, 1 ) == 0 and 144 or ( x == 0 and 146 or 145 )
				spr( index, self.pos.x + x * 8, self.pos.y + y * 8 )
			end
		end
	end

	-- se shed
	hidingplace:new( 139, 40*8, 10*8, vector:new( 0, 0 ), vector:new( 3 * 8, 3 * 8 ))

	-- setup the barrels

		-- north
	for i = 0, 4 do
		local barrelxvariance = 1.0
		local barrelyvariance = 0
		local barrel = barrel:new( 8 * ( rnd( barrelxvariance ) + 15.75 + 0.5 * band( i, 1 ) ), 8 * ( rnd( barrelyvariance ) + 0 + i ) )
	end

		-- south
	for i = 0, 7 do
		local barrelxvariance = 0
		local barrelyvariance = 0
		local barrel = barrel:new( 8 * ( rnd( barrelxvariance ) + 31 + band( i, 1 ) ), 8 * ( rnd( barrelyvariance ) + 16.5 + i ) )
	end

	-- setup the chickens. oh yes.

	for i = 1, 6 do
		chicken:new( 8 * randinrange( 20, 28 ), 8 * randinrange( 2, 10 ) )
	end
	for i = 1, 6 do
		local chicken = chicken:new( 8 * randinrange( 22, 30 ), 8 * randinrange( 12, 24 ) )
		chicken:setbasesprite( 116 )
	end
end

function eachbody( apply )
	for body in all( bodies ) do
		if body.alive then
			apply( body )
		end
	end
end

function eachcontroller( apply )
	eachbody( function( body ) 
		if body.controller != nil then 
			apply( body.controller ) 
		end
	end )
end

-- class hidingplace

hidingplace = inheritsfrom( sprite )

function hidingplace:new( spriteindex, x, y, coverageul, coveragebr, shadowoffset )
	assert( spriteindex )
	assert( coverageul )
	assert( coveragebr )

	local newobj = sprite:new( x, y, 4, 4 )
	newobj.coverageul = coverageul
	newobj.coveragebr = coveragebr
	newobj.animation = { spriteindex }
	
	if shadowoffset == nil then
		shadowoffset = vector:new( 0, 0 )
	end
	newobj.shadow = sprite:new( x + shadowoffset.x, y + shadowoffset.y, 4, 4 )
	newobj.shadow.animation = { spriteindex }
	newobj.shadow.draw = function( self )
		-- recolor to dark gray (5)
		recolor( nil, 5, function()
			sprite.draw( self )
		end )
	end
	add( shadows, newobj.shadow )

	add( hidingplaces, newobj )

	return setmetatable( newobj, self )
end

function hidingplace:covers( pos, radius )
	return self.pos.x + self.coverageul.x <= pos.x and pos.x <= self.pos.x + self.coveragebr.x and
		   self.pos.y + self.coverageul.y <= pos.y and pos.y <= self.pos.y + self.coveragebr.y
end

function find_covering_hidingplace( pos, radius )
	for hidingplace in all( hidingplaces ) do
		if hidingplace:covers( pos, radius ) then
			return hidingplace
		end
	end
	return nil
end

-- initial scene

function is_snow( pos )
	-- everything outside the bounds is snow.
	if pos.x < 0 or pos.y < 0 or pos.x >= world_size.x or pos.y >= world_size.y then
		return true
	end

	return fget( mget( pos.x, pos.y ), 3 )
end

function is_closed_gate( spriteindex )
	return spriteindex == 16 or spriteindex == 32 or spriteindex == 48 or spriteindex == 49
end

function setgate( mappos, step, ulspriteindex, brspriteindex )
	local ulmappos = mappos
	local brmappos = mappos + step

	local spritehere = mget( mappos.x, mappos.y )
	if fget( spritehere, 5 ) then	-- ul rather than br
		-- ulmappos and brmappos already correct.
	else
		brmappos = mappos
		ulmappos = mappos - step
	end

	if mget( ulmappos.x, ulmappos.y ) != ulspriteindex or mget( brmappos.x, brmappos.y ) != brspriteindex then
		mset( ulmappos.x, ulmappos.y, ulspriteindex )
		mset( brmappos.x, brmappos.y, brspriteindex )

		return true
	else
		return false
	end
end


function tidymapcell( pos )
	local sprite = mget( pos.x, pos.y )
	
	-- randomize grass
	if sprite == 1 then
		if rnd( 100 ) < 5 then
			sprite = 53 + rnd( 4 )
		else
			sprite = 5 + rnd( 4 )
		end
		mset( pos.x, pos.y, sprite )
		return
	
	-- randomize snow
	elseif sprite == 2 or sprite == 3 or sprite == 4 then

		-- count snowy neighbors.

		local offset = vector:new( 1, 0 )
		local snowyneighbors = {}
		
		local grassyneighbors = {}
		for i = 0, 3 do
			if is_snow( pos + offset ) then
				add( snowyneighbors, i )
			else
				add( grassyneighbors, i )			
			end

			offset = offset:perpendicular()
		end

		-- printh( "snowyneighbors: " .. #snowyneighbors .. ", grassy: " .. #grassyneighbors )

		local newsprite = 2 + rnd( 2 )

		if #snowyneighbors == 0 then
			newsprite = 10
		elseif #snowyneighbors == 1 then
			newsprite = 11 + 16 * snowyneighbors[ 1 ]
		elseif #snowyneighbors == 2 then
			if snowyneighbors[ 1 ] == 0 then
				if snowyneighbors[ 2 ] == 1 then
					newsprite = 12
				elseif snowyneighbors[ 2 ] == 2 then
					newsprite = 14
				elseif snowyneighbors[ 2 ] == 3 then
					newsprite = 60
				end
			elseif snowyneighbors[ 1 ] == 1 then
				if snowyneighbors[ 2 ] == 2 then
					newsprite = 28
				elseif snowyneighbors[ 2 ] == 3 then
					newsprite = 30
				end
			else
				newsprite = 44
			end

		elseif #snowyneighbors == 3 then
			newsprite = 13 + 16 * grassyneighbors[ 1 ]
		end

		mset( pos.x, pos.y, newsprite )
	
	elseif fget( sprite, 2 ) then
		-- reset gates

		local horizontalgate = fget( sprite, 4 )

		local playsound = false
		if horizontalgate then
			setgate( pos, vector:new( 1, 0 ), 48, 49 )
		else
			setgate( pos, vector:new( 0, 1 ), 16, 32 )
		end
	end
end


function tidymap()
	for y = 0, map_size.y do
		for x = 0, map_size.x do
			tidymapcell( vector:new( x, y ))
		end
	end
end

-- game states

function ticks_to_seconds( ticks )
	return ticks / 30
end

function recolor( fromcolor, tocolor, fndraw )	
	if fromcolor then
		pal( fromcolor, tocolor, 0 )
	else
		for i = 1,15 do
			pal( i, tocolor, 0 )
		end
	end
	fndraw()
	pal()
end

function drawshadowed( offsetx, offsety, drawfn )
	for i = 1,15 do
		pal( i, 1, 0 )
	end
	drawfn( offsetx, offsety )
	pal()
	drawfn( 0, 0 )
end

function printshadowed( text, x, y, color )
	print( text, x, y + 1, 1 )
	print( text, x, y, color )
end

function drawpressxprompt( playernumber )
	local presspromptcolor = ( band( stateticks / 15, 1 ) != 0 ) and 7 or 12
	printshadowed( "p" .. playernumber .. " press —", 42, 78, presspromptcolor )
end

function drawcountdown( countdown )
	-- flicker, urgency color, etc.

	local totalseconds = flr( ticks_to_seconds( countdown ))

	local shown = totalseconds > 10 or totalseconds > 5 and flicker( 2 ) or flicker( 8 )

	if not shown then return end

	local color = totalseconds > 10 and 11 or ( totalseconds > 5 and 9 or 8 )

	local minutes = flr( totalseconds / 60 )
	local seconds = totalseconds % 60


	printshadowed( ( minutes > 0 and minutes or "" ) .. ":" .. ( seconds < 10 and "0" or "" ) .. seconds, 56, 2, color )
end

function flicker( hertz )
	if hertz == nil then
		return true
	end
	return band( flr( ticks_to_seconds( totalupdates * hertz ) ), 1 ) != 0
end

function barehideannouncement( basex, basey )
	spr( 192, basex, basey, 2, 2 )
	spr( 194, basex + 8 * 2 - 1, basey, 1, 2 )
	spr( 195, basex + 8 * 3 - 2, basey, 2, 2 )
	spr( 197, basex + 8 * 5 - 3, basey, 2, 2 )
	spr( 199, basex + 8 * 7 - 5, basey, 1, 2 )
end

function hideannouncement()
	local basex = 35
	local basey = 40

	drawshadowed( 0, 2, function( x, y )
		barehideannouncement( basex + x, basey + y )
	end )
end

function bareseekannouncement( basex, basey, recolor )
	if recolor then
		for i = 1,15 do
			pal( i, recolor, 0 )
		end
	end

	spr( 200, basex, basey, 2, 2 )		-- s
	spr( 202, basex + 8 * 5 + 2, basey, 2, 2 )		-- k

	if recolor == nil then
		pal( 12, 8, 0 )
	end
	spr( 197, basex + 8 * 2 - 2, basey, 2, 2 )		-- e
	spr( 197, basex + 8 * 4 - 4, basey, 2, 2 )		-- e
	spr( 199, basex + 8 * 7 , basey, 1, 2 )		-- !

	if recolor == nil then
		pal()
	end

	pal()
end

function seekannouncement()	
	local basex = 35
	local basey = 40

	bareseekannouncement( basex, basey + 2, 1 )
	bareseekannouncement( basex, basey )
end

function stateannouncement( text, color, y )
	local x = 64 - #text / 2 * 4
	printshadowed( text, x, y or 46, color or 8 )
end

function promptcoveredcountdown( secondsremaining, prompttext, color )
	local seconds = -flr( -secondsremaining )
	printshadowed( prompttext .. ": " .. seconds .. "..." , 40, 30, color )
end

function hiderwins()
	winner = hider
	gotostate( "outcome" )
end

function seekerwins()
	winner = seeker
	gotostate( "outcome" )
end

lastsearchedcovering = nil
seeker_searching = false
seeking_completion = 0

function donesearching()
	seeker_searching = false
	seeking_completion = 0
end

function updateseekercoveredsearching( hidercovering, seekercovering )

	-- ignore the same cover we last searched.
	if seekercovering == lastsearchedcovering then
		return
	end

	if not seeker_searching then
		sfx( 8 )
		seeker_searching = true
	end

	-- update button presses for searching.

	seeking_completion = clamp( seeking_completion - 0.001, 0, 1 )
	if actionbuttonjustdown() then
		sfx( 7 )
		seeking_completion = clamp( seeking_completion + 0.05, 0, 1 )
	end

	if seeking_completion >= 1.0 then
		if lastsearchedcovering then
			lastsearchedcovering.visible = true
		end

		lastsearchedcovering = seekercovering
		seekercovering.visible = false

		if seekercovering == hidercovering then
			seekerwins()
		else
			sfx( 9 )
		end

		donesearching()
	end
end

function updateseekersearching()

	-- first, if the hider isn't even hidden, just look for proximity.
	local hidercovering = hider:currentcovering()

	-- is the hider hidden?
	if hidercovering == nil then
		-- no. test proximity
		if is_close( hider.pos, seeker.pos, 8 ) then
			seekerwins()
			return
		end
	end

	-- test more fully.
	local seekercovering = seeker:currentcovering()
	if seekercovering then
		updateseekercoveredsearching( hidercovering, seekercovering )
	else
		if lastsearchedcovering then
			lastsearchedcovering.visible = true
		end
		lastsearchedcovering = nil
		seeker_searching = false
	end
end

function drawseekersearching()
	if seeker_searching then
		printshadowed( "press   to search", 30, 50, 8 )
		printshadowed( "      —", 28, 50 + ( flicker( 4 ) and 0 or 2 ) , 8 )
		local left = 30
		local right = 98
		rectfill( left, 60, left + ( right - left ) * seeking_completion, 66, 8 )
		rect    ( left, 60, right, 66, 14 )
	end
end

function drawgameover( color )
	local basey = 20
	-- shadow
	recolor( nil, 1, function()
		spr( 224, 27, basey + 2, 10, 1 )
	end )

	recolor( 12, color, function()
		spr( 224, 27, basey, 10, 1 )
	end )
end

totalupdates = 0

-- tuning constants

hiding_seconds = 60
seeking_seconds = 60

hiding_ticks = hiding_seconds * 30
seeking_ticks = seeking_seconds * 30

hider_finish_cover_time_limit_seconds = 4

gamestates = {}
stateticks = 0

action_button_was_down = false
action_button_down = false

function actionbutton()
	return action_button_down
end

function actionbuttonjustdown()
	return action_button_down and not action_button_was_down
end

gamestates[ "initial" ] = 
{
	beginstate = function( self )
		music( 0 )
		initializeworld()
	end,

	update = function( self )
		if actionbutton() then
			-- start the game
			gotostate( "hiding" )
		end
	end,

	draw = function( self )
		
		-- draw title

		drawshadowed( 0, 2, function( x, y ) 
			spr( 72, 22 + x, 40 + y, 7, 2 )
			spr( 104, x + 22 + ( 6 * 8 + 4 ), y + 40, 5, 2 )
		end )

		drawpressxprompt( 1 )
	end,

	endstate = function( self )
	end
}

gamestates[ "hiding" ] = 
{
	beginstate = function( self )
		music( 10 )

		sfx( 5 )

		hider = player:new( 2 * 8, 2 * 8 )
		local controller = playercontroller:new( hider )

		currentplayer = hider
	end,

	update = function( self )
		local remainingticks = hiding_ticks - stateticks
		if remainingticks <= 0 then
			gotostate( "hiding_done" )
			return
		end

		if remainingticks <= 30 * 4 then
			if remainingticks % 30 == 0 then
				sfx( 4 )
			end
		end

		local hiddenseconds = hider:secondsundercovering()
		if hiddenseconds > 0 then
			local remaining_cover_ticks = hider_finish_cover_time_limit_seconds * 30 - hiddenseconds * 30
			if remaining_cover_ticks % 30 == 0 then
				sfx( 13 )
			end
		end		

		if hiddenseconds >= hider_finish_cover_time_limit_seconds then
			gotostate( "hiding_done" )
			return
		end
	end,

	draw = function( self )
		local remainingticks = hiding_ticks - stateticks
		drawcountdown( remainingticks )

		local hiddenseconds = hider:secondsundercovering()
		if hiddenseconds and hiddenseconds > 0 then
			promptcoveredcountdown( hider_finish_cover_time_limit_seconds - hiddenseconds, "hide?", 12 )

		elseif ticks_to_seconds( stateticks ) < 3 then
			hideannouncement()
		end

	end,
	
	endstate = function( self )
		hider.controller = nil
		sfx( 11 )
	end
}

gamestates[ "hiding_done" ] = 
{
	beginstate = function( self )
		-- music( 0 )
	end,

	update = function( self )
		if ticks_to_seconds( stateticks ) > 1.25 then
			gotostate( "seeking_prepare" )
		end
	end,

	draw = function( self )
		stateannouncement( "hidden!", 12 )
	end,
	
	endstate = function( self )
	end
}

gamestates[ "seeking_prepare" ] = 
{
	beginstate = function( self )
		-- music( 0 )

		seeker = player:new( 2 * 8, 2 * 8 )
		seeker:setbasesprite( 68 )

		currentplayer = seeker
	end,

	update = function( self )
		if actionbutton() then
			-- start the game
			gotostate( "seeking" )
		end
	end,

	draw = function( self )
		drawpressxprompt( 2 )
		stateannouncement( "ready to seek?", 8 )
	end,
	
	endstate = function( self )
	end
}

gamestates[ "seeking" ] = 
{
	coveredtimelimit = 4,

	beginstate = function( self )
		music( 15 )

		sfx( 5 )

		local controller = playercontroller:new( seeker )
	end,

	update = function( self )
		updateseekersearching()

		local remainingticks = seeking_ticks - stateticks
		if remainingticks <= 0 then
			hiderwins()
			return
		end
	end,

	draw = function( self )
		local remainingticks = seeking_ticks - stateticks
		drawcountdown( remainingticks )

		if remainingticks <= 30 * 4 then
			if remainingticks % 30 == 0 then
				sfx( 4 )
			end
		end

		drawseekersearching()

		-- prompt failure

		if lastsearchedcovering then			
			stateannouncement( "not here!", 8 )
			lastsearchedcovering.visible = false

		elseif not seeker_searching and ticks_to_seconds( stateticks ) < 3 then
			seekannouncement()
		end
	end,
	
	endstate = function( self )
		seeker.controller = nil
	end
}

gamestates[ "outcome" ] = 
{
	beginstate = function( self )
		music( 8 )

		sfx( 6 )

		-- move the camera to the hider.
		currentplayer = hider

		-- uncover his covering, if any.
		if hider:currentcovering() then
			hider:currentcovering().visible = false
		end
	end,

	update = function( self )
		if stateticks > 30 * 1 then
			if actionbutton() then
				-- start the game
				gotostate( "hiding" )
			end
		end
	end,

	draw = function( self )
		if stateticks > 30 * 1 then
			drawpressxprompt( 1 )
		end

		local color = winner == hider and 12 or 8

		-- "game over'
		
		drawgameover( color )

		-- show outcome

		local winner_name = winner == hider and "hider" or "seeker"
		printshadowed( "the " .. winner_name .. " wins!", 36, 46, color )
	end,
	
	endstate = function( self )
		initializeworld()
	end
}

currentgamestate = nil

function gotostate( name )
	if currentgamestate then
		printh( "leaving old state" )
		currentgamestate:endstate()
	end

	currentgamestate = gamestates[ name ]
	assert( currentgamestate )

	printh( "entering state " .. name )
	stateticks = 0
	currentgamestate:beginstate()
end

-- init ********************

function _init()

	printh( "starting." )

	gotostate( "initial" )

end


-- updating and drawing

function collidebodies( a, b )
	-- colliding?

	-- collidable?
	if band( a.collisionmask, b.collisionmask ) == 0 
		or
	   band( a.collisionrefusalmask, b.collisionrefusalmask ) ~= 0 then

	   -- don't want to collide
	   return
	end

	-- overlapping?

	local minoverlapdistance = a.radius + b.radius

	if is_close( b.pos, a.pos, minoverlapdistance ) == false then
		return
	end

	-- overlapping. resolve collision.

	local totalmass = a.mass + b.mass

	if totalmass <= 0 then
		-- both immoveable. nothing to do.
		return
	end

	local massproportiona = a.mass / totalmass
	local massproportionb = 1.0 - massproportiona

	if a.mass <= 0 then
		massproportiona = 1
		massproportionb = 0
	elseif b.mass <= 0 then
		massproportiona = 0
		massproportionb = 1
	end

	local delta = b.pos - a.pos
	local dist = delta:length()

	-- degenerate?
	if dist <= 0 then
		return true
	end

	local overlapdistance = minoverlapdistance - dist

	local normal = delta:normal()

	-- already moving apart?

	-- if a.vel:dot( b.vel ) > 0 then
	-- 	return
	-- end

	-- reposition to not overlap.

	local adjustmentdist = overlapdistance + 1

	a.pos = a.pos - normal * vector:new( adjustmentdist * massproportionb, adjustmentdist * massproportionb )
	b.pos = b.pos + normal * vector:new( adjustmentdist * massproportiona, adjustmentdist * massproportiona )

	-- impulse to bounce velocity.

	local force = a.vel:dot( normal ) * a.mass + b.vel:dot( -normal ) * b.mass

	a:addimpulse( normal * vector:new( -force, -force ))
	b:addimpulse( normal * vector:new(  force,  force ))

end

function updatecollisions()

	-- body-to-world collision
	eachbody( function( body )
		body:updateworldcollision()
	end )

	-- body-to-body collision

	for i = 1, #bodies - 1 do
		for j = i + 1, #bodies do
			collidebodies( bodies[ i ], bodies[ j ] )
		end
	end
end

function _update()

	totalupdates += 1

	action_button_was_down = action_button_down
	action_button_down = btn( 5, 0 )

	if currentgamestate then
		stateticks += 1
		currentgamestate:update()
	end

	eachcontroller( function( control )
		control:update()
	end )

	eachbody( function( body )
		body:update() 
	end )

	-- update collision

	for iteration = 1,1 do
		updatecollisions()
	end

	-- remove dead bodies

	for index, body in pairs( bodies ) do
		if not body.alive then
			del( bodies, index )
		end
	end

	-- update thecamera

	if winner and hider then
		thecamera = thecamera + ( hider.pos - thecamera ) * vector:new( 0.1, 0.1 )
	elseif currentplayer then
		thecamera = currentplayer.pos
	end
end

function _draw()
	cls()

	local viewtranslation = thecamera - vector:new( 60, 60 )
	viewtranslation.x = clamp( viewtranslation.x, 0, world_size.x - 128 )
	viewtranslation.y = clamp( viewtranslation.y, 0, world_size.y - 128 )

	camera( viewtranslation.x, viewtranslation.y )

	map( 0, 0, 0, 0, 96, 64 )

	for shadow in all( shadows ) do
		shadow:draw()
	end

	-- draw footprints

	for footprint in all( footprints ) do
		footprint:draw()
	end

	-- draw bodies

	eachbody( function( body ) 
		body:draw() 
	end )

	-- draw hiding places.

		-- barn shadows
	spriterect( 25, 7*8, 22*8, 7*8, 24*8 )
	spriterect( 25, 43*8, 4*8, 47*8, 4*8 )

	for place in all( hidingplaces ) do
		place:draw()
	end

	-- draw the ui.
	camera( 0, 0 )
	if currentgamestate then
		currentgamestate:draw()
	end

end

__gfx__
00000000333333337777777777777777777777773333333333333333333333333333333300099000337777733377777733333337777777737333333700000000
000000003333333377677777777777777777777733b3333333533333333333333333333309422420376777733777777733333777777777737773377700000000
0070070033b33b337777777777777777677777773333333333333333333333333333333304211240777777777777777733377777777777337777777700000000
00000000333bb3337777777777777777777777773333333333333333333333333333333392111192777777777777777733777777777777337777777700000000
00000000333bb3337777777777777776777777773333333333333333333333333333333392111292777777777777777733777777777777337777777700000000
0070070033b33b3377777777777767777777777733333333333333333333b3333333333304212940777777777777777737777777777777337777777700000000
00000000333333337777777777777777777777773333333333333333333333333333333302499420377777773777777737777777777777737773377700000000
00000000333333337777777777777777777677773333333333333333333333333333333300022000337777733377777777777777777777737333333700000000
33344033333443037774476733333333555555553334403333344033333933333333933310101010000000003377773373333333777777777777777700000000
335a30033354430377744767335333335555555533a350033353a00333a353b333533ab301010101000000003777777377733333777777773777777300000000
333a35333339930377799767333333b3555555553a35333333333a333a353333333333a310101010000000007777777777777333777777773777777300000000
333a35333334430377744767333353335555555593533333333333a3435333333333333401010101000000007777777777777733777777773377773300000000
3b3a35333b344003777446673b33333355555555353333333b333339453333333333333410101010000000007777777777777733777777773377773300000000
333a3533333550037775566733333333555555553333333333333333033333333333333301010101000000007777777777777773777777773777777300000000
33393533333443007774476633333333555555553333333333333333003333333333333310101010000000007777777777777773773333773777777300000000
333335b3333443b0777447663333b33355555555333333b3333333b3333333333333333301010101000000007777777777777777333333337777777700000000
33333333333333337777777700000000555555333333333333333333333333333333333300770000000000007777773377777777377777770000000000000000
33593333335333b37677777700000000555555533333333333533333335333b3335333b307666006000000007777777377777773377777770000000000000000
333a3333333333337777777700000000555555553333333333333333333333333333333370600000000000007777777777777773337777770000000000000000
333a3533449445444494454400000000555555553333333333333339433333333333333476000060000000007777777777777733337777770000000000000000
3b3a3533449445444494454400000000555555559b3333333b3333a34a333333333333a406070070000000007777777777777733337777770000000000000000
333a3533333300337777667700000000555555553a33333333333a3503a3333333333a3500000760000000007777777777777333337777770000000000000000
333a35330000000066666666000000005555555533a333333333a353003a33333333a35300067600000000007777777377733333377777770000000000000000
333445b333333300777777660000000055555555333443b333344533333393333339353300700000000000007777773373333333377777770000000000000000
333333333333333377744767000000005555555533333333333333b3333333333333333300000000000000007777777777777777333333330000000000000000
335333b3335333b37774476700000000555555553333333333333333333333333333333300000000000000007777777737777777773333770000000000000000
333333333333333377799767000000005555555533333c3333a333333333e33333b3333300000000000000007777777737777777777777770000000000000000
4aaaaa9339aaaaa44494454400000000555555553b3333333aea33333333b3333333333300006000000000007777777733777777777777770000000000000000
43333333333333344494454400000000555555553333333333a333333333333333333c3300067000000000007777777733777777777777770000000000000000
05555555333555557775566700000000555555553335333333333333333333333333cac300000000000000007777777733377777777777770000000000000000
00333333333333336664466600000000355555553333333b333333333333333333333c3300000000000000003777777333333777777777770000000000000000
33333333333333337774476600000000335555553333333333333333333333333333333300000000000000003377773333333337777777770000000000000000
040000400400004004000040040000400a0000a00a0000a00a0000a00a0000a00007000000000000000000007770000770000000000000000000000000000000
444444444444444444444444444444440a0000a00a0000a00a0000a00a0000a00078777770777770000000078887007887000000000000000000000000000000
414444144144441441444414414444140aaaaaa00aaaaaa00aaaaaa00aaaaaa00788788887888887000000788788707887000000000000000000000000000000
444444444444444444444444444444440a1aa1a00a1aa1a00a1aa1a00a1aa1a00788888888888888700000788788777887000000000000000000000000000000
22222222222222222222222222222222099999900999999009999990099999900078887788887888700000788788788888770000000000000000000000000000
00cccd0000cccd0000cccd0000cccd00008882000088820000888200008882000078870078887788700770788787078870787000000000000000000000000000
04ccdd4000ccd40004ccdd40004cdd000a8822a000882a000a8822a000a822000078870078870788707887788887078877887707770000770000000000000000
00c00d0000c000000000000000000d00008002000080000000000000000002000788870078870788778888788887078870777878887007887700000000000000
040000400400004004000040040000400a0000a00a0000a00a0000a00a0000a00788870788877888788788788870788707887888888778888870000000000000
444444444444444444444444444444440a0000a00a0000a00a0000a00a0000a00788700788707887788887788700788707887887788788878870000000000000
444444444444444444444444444444440aaaaaa00aaaaaa00aaaaaa00aaaaaa00788700788707887788777788707888707877887788788778870000000000000
444444444444444444444444444444440aaaaaa00aaaaaa00aaaaaa00aaaaaa00788707888707888788778878878878778877887887788788870000000000000
442222444422224444222244442222440aa99aa00aa99aa00aa99aa00aa99aa07888707888778888878888707888707887888877888888888700000000000000
00cccd0000cccd0000cccd0000cccd00008882000088820000888200008882000777000777007777707777000777000777777770777777788700000000000000
04ccdd4000ccd40004ccdd40004cdd000a8822a000a822000a8822a000a822000000000000000000000000000000000000000000000788887000000000000000
00c00d0000c000000000000000000d00008002000000020000000000000002000000000000000000000000000000000000000000000077770000000000000000
0000044000000440000004400000044000000a0000000a0000000a0000000a000000777700000000000000000000000000000000000000000000000000000000
0044440000444400004444000044440000000a0000000a0000000a0000000a000007888870000000000000000000000000000000000000000000000000000000
04441400044414000444140004441400000aaa00000aaa00000aaa00000aaa000078888887000000000000000000000000000000000000000000000000000000
0444420004444200044442000444420000aa190000aa190000aa190000aa19000788877887000000000000000000000000000000000000000000000000000000
02222200022222000222220002222200009999000099990000999900009999000788877770000000000000000000000000000000000000000000000000000000
000ccd00000ccd00000ccd00000ccd00000882000008820000088200000882000078888770000000000000000000000000000000000000000000000000000000
000cc400000c4d00000cc400000ccd4000082a00000822a000082a00000822a00007888887070777000777007700007700000000000000000000000000000000
000c0d0000c000d0000c0d000000d000000802000000200000080200000020000000777888787888707888778870078870000000000000000000000000000000
000000000000000000000000000a0000000000000000000000090000000000000000000788788888878888888877778870000000000000000000000000000000
00000000000a000000000000009a0aaa000900000000000000490999000000000077000788788778878878878878878870000000000000000000000000000000
00000000009a000000000000000aa99000a900000000000000099880000000000788777888788778878878878878878870000000000000000000000000000000
00060000000aa0000000000000aa9990000990000000000000998880000000000788888888788788778878878888888870000000000000000000000000000000
0067060000a9aa0000a9aa9000aaa990009899000098998000999880000000000078888887887788888888707887788700000000000000000000000000000000
0000000000a99a900aa99a00000aaa00009889800998890000099900000000000007777770777077777777000770077000000000000000000000000000000000
00060000000a9900aa0a990000000040000988009909880000000040000000000000000000000000000000000000000000000000000000000000000000000000
00000000000040009000400000000000000040004000400000000000000000000000000000000000000000000000000000000000000000000000000000000000
2eeeeee2eee22eeeeee22ee200000000000000000000000000000000000000000088777777777700000000006666666666666666666666660000000000000000
e222222e222ee222222ee22e00000000000000000000000000000000000000007788773773777077700000006555655565556555655565560000000000000000
2222222e222e2222222e222e00000000000b00770000bb00000000000000000707777777733777777070000065dd65dd65dd65dd65dd65d60000000000000000
2222222e222e2222222e222e0000000b000bb7700000b3b0000000000000770377773777730788777770000065dd65dd65dd65dd65dd65d60000000000000000
2222222e222e2222222e222e00000bbb000b3777777733b0007000000000777777703777773778777777600065dd65dd65dd65dd65dd65d60000000000000000
2222222e222e2222222e222e0000003377733b07777b3b77707000000077073777733077373777733773700065dd65dd65dd65dd65dd65d60101000000000000
2222222e222e2222222e222e00000bb30777b4bb7730b4b7777700000007777777777077377777003676600065dd65dd65dd65dd65dd65d61010100000000000
2222222e222e2222222e222e0000000b0b77b4b3773044b3077700000077773377b7737707b773366767038265dd65dd65dd65dd65dd65d60101000000000000
c11111111111c111c1111111000000bbb0b77344770b4b77377500000707777307b777773bb733886555668265dd65dd65dd65dd65dd65d61010100000000000
c11111111111c111c111111100777777bbb3b74bb7b44777b377500007778377777b77773b3707826667667665dd65dd65dd65dd65dd65d60101000000000000
c11111111111c111c111111100007777b777bb4b30b477733557b000777777337777b37b033777667676676765dd65dd65dd65dd65dd65d61010100000000000
c11111111111c111c111111100000bbbbbb73b43333777330553b0007bb3777077377b7b377775776633366665dd65dd65dd65dd65dd65d60101000000000000
c11111111111c111c111111100000bb777bbb33333775555555b0000777bb77737773b77776567366303666665dd65dd65dd65dd65dd65d61010000000000000
c11111111111c111c111111100000b777777b3343b555b553b5530000773bbb777777773777633363036606665dd65dd65dd65dd65dd65d60101000000000000
c111111c111cc111c11111110000b77777777333b55bb5b5b3553000777777bbb3738870066766766766666665dd65dd65dd65dd65d765d61010000000000000
ccccccc1ccc11ccccccccccc0000bbb77b333b35577355557757700077777773bbbb8873330067766655566665dd65dd65dd65dd65d765d60101000000000000
000000000000000000000000000bbbb0bb33b4555577b335555770007777377777777b73655036333666666665dd65dd65dd65dd65d765d61010000000000000
00000000000000000000000000bb73bbb33b745335574b443777700073377777777333776663536633336606657d65d765dd65dd65d765d60101000000000000
00000000000000000000000000b37777b3377b555b57444b3777000077777770003bb3666736766260366660657765d765dd65dd657765d61010000000000000
00000000000000000000000000bb77777777b355555774507700000070077377777b3b767633666666666823657765d765dd65dd657765760100000000000000
000000000000000000000000000b70377774335b35357733700000000777303773b73b6766763306636632236577657765d765dd657765761010000000000000
000000000000000000000000000b0007773b5573530b353b7b000000087777773bb70b73676663306636536067776777677767dd677767760100000000000000
0000000000000000000000000000000b730555555533b533553b000008877773b37637636763363363666060677767776777677d677767761010000000000000
0000000000000000000000000000003303553b75b577753550b00000007777bb3770376666633663826666000666066606660666066606600100000000000000
00000000000000000000000000000b0003b77777777775003000000000077bb77733368806763666226666000000101010101010101010101000000000000000
0000000000000000000000000000000bbb03bb0307777b00b0000000000703776733b68235666633603366000001010101010101010101010100000000000000
00000000000000000000000000000000000bb00b03bb000000000000000007778803666630666663633600000000101010101010101010101000000000000000
000000000000000000000000000000000000b0000000000000000000000007738236677633766666636600000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000767067666667666606666000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000076666676336766600300000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000682673337660630000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000006663660330000000000000000000000000000000000000000000000000000
07777000007770000777700007777777770000000777777777770000077770000777777777770000077770007777000000000000000000000000000000000000
7cccc70007ccc7007cccc7007ccccccccc7000007ccccccccccc70007cccc7007888888888887000788887078888700000000000000000000000000000000000
07ccc70007ccc70007ccc70007ccccccccc7000007cccccccccc700007ccc7000788888888887000078887078888700000000000000000000000000000000000
07ccc70007ccc70007ccc70007cccccccccc700007ccc777777c700007ccc7000788877777787000078887788887000000000000000000000000000000000000
07ccc70007ccc70007ccc70007ccc7777cccc70007ccc7000007000007ccc7000788870000070000078887888870000000000000000000000000000000000000
07ccc77777ccc70007ccc70007ccc70007ccc70007ccc77777770000007c70000788870000000000078888888700000000000000000000000000000000000000
07ccccccccccc70007ccc70007ccc70007ccc70007cccccccccc7000007c70000788887777700000078888887000000000000000000000000000000000000000
07ccccccccccc70007ccc70007ccc70007ccc70007cccccccccc7000007c70000788888888870000078888870000000000000000000000000000000000000000
07ccccccccccc70007ccc70007ccc70007ccc70007ccc777777c7000000700000078888888887000078888887000000000000000000000000000000000000000
07ccc77777ccc70007ccc70007ccc70007ccc70007ccc70000070000000700000007777788887000078888888700000000000000000000000000000000000000
07ccc70007ccc70007ccc70007ccc7777cccc70007ccc70000000000000000000000000078887000078887888870000000000000000000000000000000000000
07ccc70007ccc70007ccc70007cccccccccc700007ccc77777770000007770000000000078887000078887788887000000000000000000000000000000000000
07ccc70007ccc70007ccc70007ccccccccc7000007cccccccccc700007ccc7000077777778887000078887078888700000000000000000000000000000000000
07ccc70007ccc70007ccc70007cccccccc70000007cccccccccc700007ccc7000788888888887000078887078888700000000000000000000000000000000000
777770007777700077777000777777777700000077777777777c7000007770007777777777770000777770007777000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000
07777777007777000770000070077777770000000777777007770077007777777007777770000000000000000000000000000000000000000000000000000000
7ccccccc77cccc707cc70007c77ccccccc7000007cccccc77ccc77cc77ccccccc77cccccc7000000000000000000000000000000000000000000000000000000
07cc777c707cccc707cc707cc707cc777c70000007cc77cc77cc77cc707cc777c707cc777c700000000000000000000000000000000000000000000000000000
07cc777707cc77cc77ccc7ccc707ccccc700000007cc77cc77cc77cc707ccccc7007cc777c700000000000000000000000000000000000000000000000000000
07cc7ccc77cccccc77ccccccc707cc777000000007cc77cc707cccc7007cc7770007ccccc7000000000000000000000000000000000000000000000000000000
07cc77cc77cc77cc77cc7c7cc707cc777700000007cc77cc707cccc7007cc7777007cc7c77000000000000000000000000000000000000000000000000000000
7ccccccc7ccc77cc7ccc777cc77ccccccc700000007cccc70007cc7007ccccccc77ccc77cc700000000000000000000000000000000000000000000000000000
07777777077700770777000770077777770000000007777000007700007777777007770077000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000080808000000004008080808080024010900002424341400000808080800040109000004043414000008080800003414090000000000000000080808000000400040004000400000000000000000004000400040004000000000000000000040004000400040000000000000000000400000400000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0202020202020201010101010101010101010101010101010101010101010101110101010101010101010114141414140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020201010101010101010101010103010101010101010101010101110101010101010101010114141414140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020201010101010101010101010101030301010101010301010101110101010303010101010114141414140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020101020101010101010101010301030301010101010101010101100101010303010101010114141414140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202010101010101010103010101010301010101010101010101010101200101010101010101010134141414140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020201010101010101010101010111010101010101010101010101010101110101010101010303010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202010101010101010101010101010111010101010101020203040302020101110101010101010103030101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020101010202010101010101010111020302020302020202020204030202110101010101010103030101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020201010202010101010101010212020302020202010202030404030202120201010101010303010101010303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0201020201010101010102010101020112020302020202020203030202020202120201010101030301010103030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020101010101010101010101030212030302040304020303040302030402120302010101010101010103030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101030212030101020303040101010404020203120202020102010101010101030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121303121212121303121212121222232030301030303030101010103030303120302020101010101010101030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101020212030303030303030101010103030303120203020101010101010101010103030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010301010101010101010101030312020203020302020302020302020202120303010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101020212020303020202020202020202030202322222212130312121212130312121210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010103010101010101010201010212030302020101020302020302020302030202010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0103010101030101030101010101010112020203020202020203010102030202030203010202010101010101030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010303030101010102020201010111020302030202010101010101030202030202010102010101010303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010303040301010102030301010111010103020301010101010101010101010102020101010101010303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010102030101010111010102020101010101010101010101010101020103030101010103030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1414141414141401010101020201010110010101010101010101010101010201010101010103030301010101030101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1414141414141424010101010101010120010101010303010101010101030101010102010103030101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1414141414141414010101010101020111010101010301010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1414141414141414010101010101010111010101010101010201010101010101010201010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00010000046100801008010030100201001010000001f6001e6001c6001a6001860015600126000f6000c6000560001600016000b600000000000000000000000000000000000000000000000000000000000000
000200000e1340c1340b1240b12401104011041f1441d1441a13417134161241610415104121040f1040c10400104001040010400104001040010400104001040010400104001040010400104001040010400104
000100000c0100c0100d0100e0100d0100b0100801006010060101c0001a0001800015000120000f0000c0000500001000010000b000000000000000000000000000000000000000000000000000000000000000
000200001513014130121200e110001000010014100151101211015110181101c1101f12021120211200010000100001000010000100001000010000100001000010000100001000010000100001000010000100
000000002301023030230302303023030230202301000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00001207012061120511204112031120311202112021120211201112011120111201112011000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
000b00000b0700b0610b0510b0410b0310b0310b0210b0210b0210b0110b0110b0110b0110b011000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
000200000b020090200b0200e0200c0000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000002402024020000002400024000240002402024020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200001d5201c52019520165201252016520195201c5201c5001c5001c5001e5000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000000000161001620016200162001610006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
010d00000653009530085300852108511085100851014500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
01100000006150160501605016050061500605016050260500615056050a605246151960526605006153f605006150160500615016050061500605016050061500615056050a605246151960526605006153f605
010d00001271512705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000c010000000000013010000000000007010000000e0100000014000150100000000000100101000011010000000000018010000000000007010000000c01000000000001301000000000000701000000
011000002852528521265202452500505245150050524515265252852026525245251f5250050500505005052152500505005051f510215250050524525005051f525005051c5051c51500505005051f51500505
011000000061500000000003b60523615000050061500605006150000000000006152361500000000000000000615000000000000615236150000000615000000000000000006150000023615006150000000000
011000000501000000000000c010000000000011010000001301000000140000e010000000000007010100000c010000000000013010000000000007010000000c01000000000001301000000000000701000000
01100000215250950526500235250b50524505245250c5051f5201f5251c5251c50518525005051c525005051f52500505005051f500215050050524505055051d515055051c505045051c515005051f50500505
001000001351513515115151051500000105150000010515115151351011515105150c5150000000000000000c5150000000000105150c5150000010515000000c51500000000000751500000000000c51500000
001000000c51500000000000e515000000000010515000000c5100c5151351500000105150000013515000000c515000000000000000000000000000000000001551500000000000000013515000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01130000097200b720097250c720097350e730097450f74500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705047150471500705007050c705
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000401500005040150000504005000050000500005040150000504015000050000500005000050000500005000050000500005000050000500005000050701500005070200702007011070150000500005
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 10401240
00 10111240
00 10111240
00 13141240
00 10401240
00 10111215
00 10111215
02 13141216
02 0c404140
00 00000000
03 1e404140
00 00000000
00 00000000
00 00000000
00 00000000
03 20404040
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000

