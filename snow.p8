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
		spriteDims = vector:new( width, height ),
		animation = { 0 },
		animationindex = 1,
		spriteflip = false,
	}
	return setmetatable( newobj, self )
end

function sprite:currentsprite()
	local index = wrap( self.animationindex, 1, #self.animation + 1 )
	return self.animation[ index ]
end

function sprite:draw()
	local pos = self.pos
	local sprite = self:currentsprite()
	spr( sprite, pos.x, pos.y, self.spriteDims.x, self.spriteDims.y, self.spriteflip )
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
		mass = 1.0,	-- todo: 3.141 * radius * radius,
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
		currentmappos = nil,				-- todo
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

	local covering = find_covering_hidingplace( self.pos, self.radius )
	if covering then
		printh( "TODO: covered" )
	end
end

function player:updategates( mappos )
	local mapsprite = mget( mappos.x, mappos.y )

	-- update gates.
	if fget( mapsprite, 2 )	then -- gate?

		local horizontalgate = fget( mapsprite, 4 )

		if horizontalgate then
			-- what direction are we going?
			if self.vel.y > 0 then
				-- down				
				setgate( mappos, vector:new( 1, 0 ), 39, 40 )
			else
				-- up
				setgate( mappos, vector:new( 1, 0 ), 23, 24 )
			end
		else
			-- what direction are we going?
			if self.vel.x > 0 then
				-- right
				setgate( mappos, vector:new( 0, 1 ), 22, 38 )
			else
				-- left
				setgate( mappos, vector:new( 0, 1 ), 21, 37 )
			end
		end
		
	end
end

function player:onenteringmappos( mappos )
	-- todo
	printh( "entering " .. mappos:tostring() )
	self:updategates( mappos )
end

function player:onleavingmappos( mappos )
	-- todo
	printh( "entering " .. mappos:tostring() )
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
	newobj.footprintsprite = 120

	newobj.fleedestination = nil
	newobj.fleeticks = 0

	newobj.wanderdirection = nil

	return setmetatable( newobj, self )
end

function chicken:update()

	self:superclass().update( self )

	self:update_ai()		-- todo: really should be a controller, but inheritance didn't work for me.

	-- update chicken animations

	if self.fleedestination then
		-- moving
		self.sprite.animation = { self.basesprite + 2 }		
	else
		-- still
		-- todo!!! pecking animation
		local sprite = rnd( 100 ) < 2 and self.basesprite + 1 or self.basesprite
		self.sprite.animation = { sprite }		
	end

end

function chicken:update_ai()

	if currentplayer == nil then return end

	if self.fleedestination then

		self.fleeticks += 1

		-- fleeing

		-- Have we gotten to our destination?
		if is_close( self.fleedestination, self.pos, 4 ) then
			-- yes. stop fleeing
			self:makefootprint( self.pos )
			self.fleedestination = nil
			return
		end

		-- spent too long fleeing?
		if self.fleeticks > 30 * 2 then
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
	newobj.footprintsprite = 104
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
	currentplayer = nil
	bodies = {}
	footprints = {}
	hidingplaces = {}
	shadows = {}
end

function initializeworld()
	clearworld()

	tidymap()

	-- trees

	-- TODO tree coverage radii
	local smalltreecoverageradius = 4 * 8
	local largetreecoverageradius = 4 * 8

	local smalltreeshadowoffset = vector:new( 1, 1 )
	local largetreeshadowoffset = vector:new( 4, 4 )

	hidingplace:new( 192, 10 * 8, -1 * 8, vector:new( 0, 0 ), vector:new( largetreecoverageradius, largetreecoverageradius ), 139, largetreeshadowoffset  )
	hidingplace:new( 135, 20 * 8,  2 * 8, vector:new( 0, 0 ), vector:new( smalltreecoverageradius, smalltreecoverageradius ), 139, smalltreeshadowoffset )
	hidingplace:new( 192, 26 * 8,  0 * 8, vector:new( 0, 0 ), vector:new( largetreecoverageradius, largetreecoverageradius ), 139, largetreeshadowoffset )
	hidingplace:new( 192, 14 * 8, 11 * 8, vector:new( 0, 0 ), vector:new( largetreecoverageradius, largetreecoverageradius ), 139, largetreeshadowoffset )
	hidingplace:new( 192, 24 * 8, 22 * 8, vector:new( 0, 0 ), vector:new( smalltreecoverageradius, smalltreecoverageradius ), 139, largetreeshadowoffset )
	hidingplace:new( 135, 37 * 8, 18 * 8, vector:new( 0, 0 ), vector:new( smalltreecoverageradius, smalltreecoverageradius ), 139, smalltreeshadowoffset )
	hidingplace:new( 135, 37 * 8, -2 * 8, vector:new( 0, 0 ), vector:new( smalltreecoverageradius, smalltreecoverageradius ), 139, smalltreeshadowoffset )
	hidingplace:new( 135, -1 * 8,  7 * 8, vector:new( 0, 0 ), vector:new( smalltreecoverageradius, smalltreecoverageradius ), 139, smalltreeshadowoffset )
	hidingplace:new( 192, 45 * 8, 22 * 8, vector:new( 0, 0 ), vector:new( largetreecoverageradius, largetreecoverageradius ), 139, largetreeshadowoffset )

	-- TODO barn and shed radii
	-- sw barn
	hidingplace:new( 128, 0 * 8, 21 * 8, vector:new( 0, 0 ), vector:new( 4 * 8, 4 * 8 ))
	local barnpart = hidingplace:new( 132, 4 * 8, 21 * 8, vector:new( 0, 0 ), vector:new( 3 * 8, 4 * 8 ) )
	barnpart.spriteDims = vector:new( 3, 4 )

	-- ne barn
	hidingplace:new( 196, 42*8, 0, vector:new( 0, 0 ), vector:new( 4 * 8, 4 * 8 ) )
	barnpart = hidingplace:new( 200, 46*8, 0, vector:new( 0, 0 ), vector:new( 2 * 8, 4 * 8 ) )
	barnpart.spriteDims = vector:new( 2, 4 )

	-- se shed
	hidingplace:new( 202, 40*8, 10*8, vector:new( 0, 0 ), vector:new( 2 * 8, 2 * 8 ))

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

function hidingplace:new( spriteIndex, x, y, coverageUL, coverageBR, shadowIndex, shadowOffset )
	assert( spriteIndex )
	assert( coverageUL )
	assert( coverageBR )

	local newobj = sprite:new( x, y, 4, 4 )
	newobj.coverageUL = coverageUL
	newobj.coverageBR = coverageBR
	newobj.animation = { spriteIndex }
	
	if shadowIndex then
		if shadowOffset == nil then
			shadowOffset = vector:new( 0, 0 )
		end
		newobj.shadow = sprite:new( x + shadowOffset.x, y + shadowOffset.y, 4, 4 )
		newobj.shadow.animation = { shadowIndex }
		add( shadows, newobj.shadow )
	end

	add( hidingplaces, newobj )

	return setmetatable( newobj, self )
end

function hidingplace:covers( pos, radius )
	return self.pos.x + self.coverageUL.x <= pos.x and pos.x <= self.pos.x + self.coverageBR.x and
		   self.pos.y + self.coverageUL.y <= pos.y and pos.y <= self.pos.y + self.coverageBR.y
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

		sfx( 1 )
	end
end


function tidymapcell( pos )
	local sprite = mget( pos.x, pos.y )
	
	if sprite == 1 then
		if rnd( 100 ) < 5 then
			sprite = 53 + rnd( 4 )
		else
			sprite = 5 + rnd( 4 )
		end
		mset( pos.x, pos.y, sprite )
		return
	end

	if not ( sprite == 2 or sprite == 3 or sprite == 4 ) then
		return
	end

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
	return flr( ticks / 30 )
end

function printshadowed( text, x, y, color )
	print( text, x, y + 1, 1 )
	print( text, x, y, color )
end

function drawpressxprompt()
	local presspromptcolor = ( band( stateTicks / 15, 1 ) != 0 ) and 7 or 12
	printshadowed( "press —", 48, 78, presspromptcolor )
end

function drawcountdown( countdown )
	local totalseconds = ticks_to_seconds( countdown )
	local minutes = flr( totalseconds / 60 )
	local seconds = totalseconds % 60
	printshadowed( ( minutes > 0 and minutes or "" ) .. ":" .. ( seconds < 10 and "0" or "" ) .. seconds, 56, 2, 8 )
end

hiding_seconds = 10
seeking_seconds = hiding_seconds

hiding_ticks = hiding_seconds * 30
seeking_ticks = seeking_seconds * 30

gamestates = {}
stateTicks = 0

gamestates[ "initial" ] = 
{
	beginstate = function( self )
		-- music( 0 )
		initializeworld()
	end,

	update = function( self )
		if btn( 4, 0 ) or btn( 5, 0 ) then
			-- start the game
			gotostate( "hiding" )
		end
	end,

	draw = function( self )
	drawpressxprompt()
	end,

	endstate = function( self )
	end
}

gamestates[ "hiding" ] = 
{
	beginstate = function( self )
		-- music( 0 )

		hider = player:new( 2 * 8, 2 * 8 )
		local controller = playercontroller:new( hider )

		currentplayer = hider
	end,

	update = function( self )
		local remainingTicks = hiding_ticks - stateTicks
		if remainingTicks <= 0 then
			gotostate( "seeking_prepare" )
		end
	end,

	draw = function( self )
		local remainingTicks = hiding_ticks - stateTicks
		drawcountdown( remainingTicks )
	end,
	
	endstate = function( self )
		hider.controller = nil
	end
}

gamestates[ "seeking_prepare" ] = 
{
	ticks = 0,
	beginstate = function( self )
		-- music( 0 )

		seeker = player:new( 2 * 8, 2 * 8 )
		seeker:setbasesprite( 68 )

		currentplayer = seeker
	end,

	update = function( self )
		if btn( 4, 0 ) or btn( 5, 0 ) then
			-- start the game
			gotostate( "seeking" )
		end
	end,

	draw = function( self )
		drawpressxprompt()
	end,
	
	endstate = function( self )
	end
}

gamestates[ "seeking" ] = 
{
	beginstate = function( self )
		-- music( 0 )

		local controller = playercontroller:new( seeker )
	end,

	update = function( self )
		local remainingTicks = seeking_ticks - stateTicks
		if remainingTicks <= 0 then
			gotostate( "outcome" )
		end
	end,

	draw = function( self )
		local remainingTicks = seeking_ticks - stateTicks
		drawcountdown( remainingTicks )
	end,
	
	endstate = function( self )
		seeker.controller = nil
	end
}

gamestates[ "outcome" ] = 
{
	beginstate = function( self )
		-- music( 0 )
	end,

	update = function( self )
		if btn( 4, 0 ) or btn( 5, 0 ) then
			-- start the game
			gotostate( "hiding" )
		end
	end,

	draw = function( self )
		drawpressxprompt()
	end,
	
	endstate = function( self )
		initializeworld()
	end
}

currentgamestate = nil

function gotostate( name )
	if currentgamestate then
		printh( "Leaving old state" )
		currentgamestate:endstate()
	end

	currentgamestate = gamestates[ name ]
	assert( currentgamestate )

	printh( "Entering state " .. name )
	stateTicks = 0
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

	if currentgamestate then
		stateTicks += 1
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

	if currentplayer then
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

	-- Draw the UI.
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
33333333333333337777777700000000555555333333333333333333333333333333333300000000000000007777773377777777377777770000000000000000
33593333335333b37677777700000000555555533333333333533333335333b3335333b300000000000000007777777377777773377777770000000000000000
333a3333333333337777777700000000555555553333333333333333333333333333333300000000000000007777777777777773337777770000000000000000
333a3533449445444494454400000000555555553333333333333339433333333333333400000000000000007777777777777733337777770000000000000000
3b3a3533449445444494454400000000555555559b3333333b3333a34a333333333333a400000000000000007777777777777733337777770000000000000000
333a3533333300337777667700000000555555553a33333333333a3503a3333333333a3500000000000000007777777777777333337777770000000000000000
333a35330000000066666666000000005555555533a333333333a353003a33333333a35300000000000000007777777377733333377777770000000000000000
333445b333333300777777660000000055555555333443b333344533333393333339353300000000000000007777773373333333377777770000000000000000
333333333333333377744767000000005555555533333333333333b3333333333333333300000000000000007777777777777777333333330000000000000000
335333b3335333b37774476700000000555555553333333333333333333333333333333300000000000000007777777737777777773333770000000000000000
333333333333333377799767000000005555555533333c3333a333333333e33333b3333300000000000000007777777737777777777777770000000000000000
4aaaaa9339aaaaa44494454400000000555555553b3333333aea33333333b3333333333300000000000000007777777733777777777777770000000000000000
43333333333333344494454400000000555555553333333333a333333333333333333c3300000000000000007777777733777777777777770000000000000000
05555555333555557775566700000000555555553335333333333333333333333333cac300000000000000007777777733377777777777770000000000000000
00333333333333336664466600000000355555553333333b333333333333333333333c3300000000000000003777777333333777777777770000000000000000
33333333333333337774476600000000335555553333333333333333333333333333333300000000000000003377773333333337777777770000000000000000
040000400400004004000040040000400a0000a00a0000a00a0000a00a0000a00000000000000000000000000000000000000000000000000000000000000000
444444444444444444444444444444440a0000a00a0000a00a0000a00a0000a00000000000000000000000000000000000000000000000000000000000000000
414444144144441441444414414444140aaaaaa00aaaaaa00aaaaaa00aaaaaa00000000000000000000000000000000000000000000000000000000000000000
444444444444444444444444444444440a1aa1a00a1aa1a00a1aa1a00a1aa1a00000000000000000000000000000000000000000000000000000000000000000
22222222222222222222222222222222099999900999999009999990099999900000000000000000000000000000000000000000000000000000000000000000
00cccd0000cccd0000cccd0000cccd00008882000088820000888200008882000000000000000000000000000000000000000000000000000000000000000000
04ccdd4000ccd40004ccdd40004cdd000a8822a000882a000a8822a000a822000000000000000000000000000000000000000000000000000000000000000000
00c00d0000c000000000000000000d00008002000080000000000000000002000000000000000000000000000000000000000000000000000000000000000000
040000400400004004000040040000400a0000a00a0000a00a0000a00a0000a00000000000000000000000000000000000000000000000000000000000000000
444444444444444444444444444444440a0000a00a0000a00a0000a00a0000a00000000000000000000000000000000000000000000000000000000000000000
444444444444444444444444444444440aaaaaa00aaaaaa00aaaaaa00aaaaaa00000000000000000000000000000000000000000000000000000000000000000
444444444444444444444444444444440aaaaaa00aaaaaa00aaaaaa00aaaaaa00000000000000000000000000000000000000000000000000000000000000000
442222444422224444222244442222440aa99aa00aa99aa00aa99aa00aa99aa00000000000000000000000000000000000000000000000000000000000000000
00cccd0000cccd0000cccd0000cccd00008882000088820000888200008882000000000000000000000000000000000000000000000000000000000000000000
04ccdd4000ccd40004ccdd40004cdd000a8822a000a822000a8822a000a822000000000000000000000000000000000000000000000000000000000000000000
00c00d0000c000000000000000000d00008002000000020000000000000002000000000000000000000000000000000000000000000000000000000000000000
0000044000000440000004400000044000000a0000000a0000000a0000000a000077000000000000000000000000000000000000000000000000000000000000
0044440000444400004444000044440000000a0000000a0000000a0000000a000766600600000000000000000000000000000000000000000000000000000000
04441400044414000444140004441400000aaa00000aaa00000aaa00000aaa007060000000000000000000000000000000000000000000000000000000000000
0444420004444200044442000444420000aa190000aa190000aa190000aa19007600006000000000000000000000000000000000000000000000000000000000
02222200022222000222220002222200009999000099990000999900009999000607007000000000000000000000000000000000000000000000000000000000
000ccd00000ccd00000ccd00000ccd00000882000008820000088200000882000000076000000000000000000000000000000000000000000000000000000000
000cc400000c4d00000cc400000ccd4000082a00000822a000082a00000822a00006760000000000000000000000000000000000000000000000000000000000
000c0d0000c000d0000c0d000000d000000802000000200000080200000020000070000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000a0000000000000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000a000000000000009a0aaa000900000000000000490999000000000000000000000000000000000000000000000000000000000000000000000000
00000000009a000000000000000aa99000a900000000000000099880000000000000000000000000000000000000000000000000000000000000000000000000
00060000000aa0000000000000aa9990000990000000000000998880000000000000600000000000000000000000000000000000000000000000000000000000
0067060000a9aa0000a9aa9000aaa990009899000098998000999880000000000006700000000000000000000000000000000000000000000000000000000000
0000000000a99a900aa99a00000aaa00009889800998890000099900000000000000000000000000000000000000000000000000000000000000000000000000
00060000000a9900aa0a990000000040000988009909880000000040000000000000000000000000000000000000000000000000000000000000000000000000
00000000000040009000400000000000000040004000400000000000000000000000000000000000000000000000000000000000000000000000000000000000
2eeeeee22eeeeee22eeeeee22eeeeee22eeeeee22eeeeee22eeeeee0000000000000000000000000000000000000000000000000000000000000000000000000
e222222ee222222ee222222ee222222ee222222ee222222ee222222e000000000000000000000000000000000000000000000000000000000000000000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e00000000000b00770000bb00000000000000000000050055000055000000000000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e0000000b000bb7700000b3b0000000000000000500055550000055500000000000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e00000bbb000b3777777733b0007000000000055500055555555555550050000000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e0000003377733b37777b3b77707000000000005555555555555555555050000000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e00000bb33777b4bb7733b4b7777700000000055555555555555555555555000000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e0000000b3b77b4b3773344b3377700000000000555555555555555555555000000000000
eee22eeeeee22eeeeee22eeeeee22eeeeee22eeeeee22eeeeee22ee0000000bbb3b77344773b4b77377500000000005555555555555555555555000000000000
222ee222222ee222222ee222222ee222222ee222222ee222222ee22e00777777bbb3b74bb7b44777b37750000055555555555555555555555555500000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e00007777b777bb4b33b477733557b0000000555555555555555555555555505000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e00000bbbbbb73b43333777333553b0000000055555555555555555555555555000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e00000bb777bbb33333775555555b00000000055555555555555555555555555000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e00000b777777b3343b555b553b5530000000055555555555555555555555555000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e0000b77777777333b55bb5b5b35530000000555555555555555555555555550000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e0000bbb77b333b3557735555775770000000555555555555555555555555555000000000
2eeeeee22eeeeee22eeeeee22eeeeee22eeeeee22eeeeee22eeeeee0000bbbb3bb33b4555577b335555770000005555555555555555555555555555000000000
e222222ee222222ee222222ee222222ee222222ee222222ee222222e00bb73bbb33b745335574b44377770000055555555555555555555555555555000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e00b37777b3377b555b57444b377700000055555555555555555555555555555000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e00bb77777777b35555577453770000000055555555555555555555555550555000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e000b70377774335b35357733700000000005505555555555555555555555555000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e000b0007773b5573533b353b7b0000000005000555555555555555555555555000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e0000000b733555555533b533553b00000000000555555555555555555555500000000000
2222222e2222222e2222222e2222222e2222222e2222222e2222222e0000003303553b75b577753550b000000000005555555555555555555055500000000000
eee22eeeeee22eeeeee22eeeeee22eeeeee22eeeeee22eeeeee22ee000000b0003b7777777777500300000000000050005555555555555505555050000000000
222ee222222ee222222ee222222ee222222ee222222ee222222ee22e0000000bbb03bb0307777b00b00000000000000555055555555555555550000000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e00000000000bb00b03bb0000000000000000000000055055555555555550000000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e000000000000b00000000000000000000000000000005055555505555500000000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e000000000000000000000000000000000000000000000050555555000000000000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e000000000000000000000000000000000000000000000000000000000000000000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e000000000000000000000000000000000000000000000000000000000000000000000000
222e2222222e2222222e2222222e2222222e2222222e2222222e222e000000000000000000000000000000000000000000000000000000000000000000000000
00000000008877777777770000000000c1111111c1111111c1111111c1111111c1111111c1111111666666666666666666666666000000000000000000000000
00000000778877377377707770000000c1111111c1111111c1111111c1111111c1111111c1111111655565556555655565556556000000000000000000000000
00000007077777777337777770700000c1111111c1111111c1111111c1111111c1111111c111111165dd65dd65dd65dd65dd65d6000000000000000000000000
00007703777737777337887777700000c1111111c1111111c1111111c1111111c1111111c111111165dd65dd65dd65dd65dd65d6000000000000000000000000
00007777777337777737787777776000c1111111c1111111c1111111c1111111c1111111c111111165dd65dd65dd65dd65dd65d6000000000000000000000000
00770737777333773737777337737000c1111111c1111111c1111111c1111111c1111111c111111165dd65dd65dd65dd65dd65d6010100000000000000000000
00077777777773773777773336766000c111111cc111111cc111111cc111111cc111111cc111111c65dd65dd65dd65dd65dd65d6101010000000000000000000
0077773377b7737737b7733667670382ccccccc11cccccc11cccccc11cccccc11cccccc11cccccc165dd65dd65dd65dd65dd65d6010100000000000000000000
0707777337b777773bb7338865556682c11111111111c1111111c1111111c1111111c1111111c11165dd65dd65dd65dd65dd65d6101010000000000000000000
07778377777b77773b37378266676676c11111111111c1111111c1111111c1111111c1111111c11165dd65dd65dd65dd65dd65d6010100000000000000000000
777777337777b37b3337776676766767c11111111111c1111111c1111111c1111111c1111111c11165dd65dd65dd65dd65dd65d6101010000000000000000000
7bb3777377377b7b3777757766333666c11111111111c1111111c1111111c1111111c1111111c11165dd65dd65dd65dd65dd65d6010100000000000000000000
777bb77737773b777765673663336666c11111111111c1111111c1111111c1111111c1111111c11165dd65dd65dd65dd65dd65d6101000000000000000000000
0773bbb7777777737776333633366066c11111111111c1111111c1111111c1111111c1111111c11165dd65dd65dd65dd65dd65d6010100000000000000000000
777777bbb37388733667667667666666c1111111111cc111111cc111111cc111111cc111111cc11165dd65dd65dd65dd65d765d6101000000000000000000000
77777773bbbb88733333677666555666ccccccccccc11cccccc11cccccc11cccccc11cccccc11ccc65dd65dd65dd65dd65d765d6010100000000000000000000
7777377777777b736555363336666666c1111111c1111111c1111111c1111111c1111111c111111165dd65dd65dd65dd65d765d6101000000000000000000000
73377777777333776663536633336606c1111111c1111111c1111111c1111111c1111111c1111111657d65d765dd65dd65d765d6010100000000000000000000
77777773333bb3666736766263366660c1111111c1111111c1111111c1111111c1111111c1111111657765d765dd65dd657765d6101000000000000000000000
70077377777b3b767633666666666823c1111111c1111111c1111111c1111111c1111111c1111111657765d765dd65dd65776576010000000000000000000000
0777333773b73b676676333663663223c1111111c1111111c1111111c1111111c1111111c11111116577657765d765dd65776576101000000000000000000000
087777773bb73b736766633366365360c1111111c1111111c1111111c1111111c1111111c111111167776777677767dd67776776010000000000000000000000
08877773b37637636763363363666060c111111cc111111cc111111cc111111cc111111cc111111c677767776777677d67776776101000000000000000000000
007777bb377337666663366382666600ccccccc11cccccc11cccccc11cccccc11cccccc11cccccc1066606660666066606660660010000000000000000000000
00077bb7773336883676366622666600c11111111111c1111111c1111111c1111111c1111111c111000010101010101010101010100000000000000000000000
000703776733b6823566663363336600c11111111111c1111111c1111111c1111111c1111111c111000101010101010101010101010000000000000000000000
00000777883366663366666363360000c11111111111c1111111c1111111c1111111c1111111c111000010101010101010101010100000000000000000000000
00000773823667763376666663660000c11111111111c1111111c1111111c1111111c1111111c111000000000000000000000000000000000000000000000000
00000076706766666766660666600000c11111111111c1111111c1111111c1111111c1111111c111000000000000000000000000000000000000000000000000
00000007666667633676660030000000c11111111111c1111111c1111111c1111111c1111111c111000000000000000000000000000000000000000000000000
00000000068267333766063000000000c1111111111cc111111cc111111cc111111cc111111cc111000000000000000000000000000000000000000000000000
000000000006663660330000000000000cccccccccc11cccccc11cccccc11cccccc11cccccc11ccc000000000000000000000000000000000000000000000000

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
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000c010000000000013010000000000007010000000e0100000014000150100000000000100101000011010000000000018010000000000007010000000c01000000000001301000000000000701000000
011000002852528521265202452500505245150050524515265252852026525245251f5250050500505005052152500505005051f510215250050524525005051f525005051c5051c51500505005051f51500505
011000000061500000000003b60523615000050061500605006150000000000006152361500000000000000000615000000000000615236150000000615000000000000000006150000023615006150000000000
011000000501000000000000c0100000000000090100000000010000001400004010000000000007010100000c01000000000000702000000000000a000040250002000000000000701000000000000c01000000
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
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 10401240
01 10111240
00 10111240
00 13141240
00 10401240
00 10111215
00 10111215
02 13141216
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
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000

