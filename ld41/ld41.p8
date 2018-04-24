pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- game title here
-- by jeff and liam wofford
-- http://www.electrictoy.co

-->8
-- general utilities

-- debug_lines = {}
-- function debug_print( text )
-- 	add( debug_lines, text )

-- 	while #debug_lines > 10 do
-- 		del_index( debug_lines, 1 )
-- 	end
-- end

-- function draw_debug_lines()
-- 	for i = 1, #debug_lines do
-- 		local line = debug_lines[ #debug_lines - i + 1 ]
-- 		print( line, 2, 7 * i, rel_color( 8, 1 - i ) )
-- 	end
-- 	print( '', 0, (#debug_lines+1) *7 )
-- end

local timesplayed = 0

local current_level = nil
local crafting_ui = nil
local inventory_display = nil
local current_player = nil


function establish( value, default )
	if value == nil then return default end
	return value
end

--todo!!
local messagedur = 3
local gamemessage = { text = '', time = nil }
function message( text )
	gamemessage.text = text
	gamemessage.time = time()
end
function curmessage()
	return ( gamemessage.time ~= nil and time() < gamemessage.time + messagedur ) and gamemessage.text or ''
end

function rel_color( base, change )
	local brighten_table = { 5, 13,  8, 11,  8,  6,  7,  7, 14, 10,  7,  7,  6, 12, 15,  7 }

	local darken_table =   { 0,  0,  0,  0,  0,  0,  5,  6,  2,  4,  9,  3, 13,  1,  8, 14 }

	while change > 0 do
		base = brighten_table[base+1]
		change -= 1
	end

	while change < 0 do
		base = darken_table[base+1]
		change += 1
	end

	return base
end

function maptoworld( x )
	return x * 8
end

function worldtomap( x )
	return flr( x / 8 )
end

-- insertion sort
function sort(a, compare)
	for i=1,#a do
		local j = i
		while j > 1 and compare( a[j-1], a[j] ) do
			a[j],a[j-1] = a[j-1],a[j]
			j = j - 1
		end
	end
end

function erase_elements(array, predicate)
	for i = #array, 1, -1 do
		local element = array[ i ]
		if predicate( element ) then
			del( array, element )
		end
	end
end

function shallowcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = orig_value
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function flicker( time, hertz, cutoff )
	return ( time * hertz ) % 1 <= establish( cutoff, 0.5 )
end

function dither_color( base, dither )
	return bor( base, shl( dither, 4 ))
end

function del_index( table, index )
	del( table, table[ index ])
end

function inheritsfrom( baseclass )

	local new_class = {}
	new_class.__index = new_class

	if nil ~= baseclass then
		setmetatable( new_class, { __index = baseclass } )
	end

	function new_class:class()
		return new_class
	end

	function new_class:superclass()
		return baseclass
	end

	return new_class
end


vector = inheritsfrom( nil )

function vector:new( x, y )
	local o = { x = establish( x, 0 ), y = establish( y, establish( x, 0 )) }
	return setmetatable( o, self )
end

function vector:copy()
	return vector:new( self.x, self.y )
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

-- utilities

function rand_int( min, maxinclusive )
	return flr( randinrange( min, maxinclusive + 1 ) )
end

function randinrange( min, maxexclusive )
	assert( maxexclusive >= min )
	return min + rnd( maxexclusive - min )
end

function pctchance( pct )
	return rnd( 100 ) < pct
end

function wrap( x, min, maxexclusive )
	assert( maxexclusive > min )
	return min + ( x - min ) % ( maxexclusive - min )
end

function clamp( x, least, greatest )
	assert( greatest >= least )
	return min( greatest, max( least, x ))
end

function lerp( a, b, alpha )
	return a + (( b - a ) * alpha )
end

function proportion( x, min, max )
	return ( x - min ) / ( max - min )
end

function is_close( a, b, maxdist )
	local delta = b - a

	local manhattanlength = delta:manhattanlength()
	if manhattanlength > maxdist * 1.8 then     -- adding a fudge factor to account for diagonals.
		return false
	end

	if manhattanlength > 180 then
		printh( "objects may be close but we don't have the numeric precision to decide. ignoring." )
		return false
	end

	local distsquared = delta:lengthsquared()

	return distsquared <= maxdist * maxdist
end

-->8
--systems

function rects_overlap( recta, rectb )
	function edges_overlap( la, ra, lb, rb )
		return not (
				la > rb or
				ra < lb
			)
	end

	return  edges_overlap( recta.l, recta.r, rectb.l, rectb.r )
		and edges_overlap( recta.t, recta.b, rectb.t, rectb.b )
end

-- global constants

local mapsegment_tile_size = vector:new( 16, 16 )
local mapsegment_tiles_across_map = 8
local weapon_check_distance = 20


local mapsegment = inheritsfrom( nil )
function mapsegment:new( segment_num, worldx )
	local o = {
		segment_num = segment_num,
		worldx = worldx,
	}
	return setmetatable( o, self )
end

function mapsegment:collision_rect()
	return {
		l = self.worldx,
		r = self.worldx + maptoworld( mapsegment_tile_size.x ),
		t = maptoworld( -mapsegment_tile_size.y ),
		b = 0,
	}
end

function mapsegment:right()
	return self:collision_rect().r
end

function mapsegment:colliding_tile( withactor )

	local myrect = self:collision_rect()
	local rect = withactor:collision_rect()

	rect.l -= myrect.l
	rect.t -= myrect.t
	rect.r -= myrect.l
	rect.b -= myrect.t

	rect.l = max( worldtomap( rect.l ), 0 )
	rect.t = max( worldtomap( rect.t ), 0 )
	rect.r = min( worldtomap( rect.r ), mapsegment_tile_size.x - 1 )
	rect.b = min( worldtomap( rect.b ), mapsegment_tile_size.y - 1 )

	local my_mapspace_ul = { x =    ( self.segment_num % mapsegment_tiles_across_map ) * mapsegment_tile_size.x,
							 y = flr( self.segment_num / mapsegment_tiles_across_map ) * mapsegment_tile_size.y }

	rect.l += my_mapspace_ul.x
	rect.t += my_mapspace_ul.y
	rect.r += my_mapspace_ul.x
	rect.b += my_mapspace_ul.y

	for y = rect.t, rect.b do
		for x = rect.l, rect.r do
			if fget( mget( x, y ), 7 ) then
				local tileworldspace = vector:new(
					myrect.l + maptoworld( x - my_mapspace_ul.x ),
					myrect.t + maptoworld( y - my_mapspace_ul.y ) )

				return tileworldspace
			end
		end
	end

	return nil
end

function mapsegment:draw()
	if self.segment_num > 0 then
		local segmentul_mapspace = {
			x =    ( self.segment_num % mapsegment_tiles_across_map ) * mapsegment_tile_size.x,
			y = flr( self.segment_num / mapsegment_tiles_across_map ) * mapsegment_tile_size.y
		}

		mapdraw( segmentul_mapspace.x,
				 segmentul_mapspace.y,
				 self.worldx, maptoworld( -mapsegment_tile_size.y ),
				 mapsegment_tile_size.x, mapsegment_tile_size.y )
	end
end

local animation = inheritsfrom( nil )
function animation:new( min, count, ssizex, ssizey )
	count = establish( count, 1 )
	local o = {
		frames = {},
		current_frame=1,
		frame_rate_hz=10,
		ssizex = establish( ssizex, 1 ),
		ssizey = establish( ssizey, establish( ssizex, 1 )),
		style = 'loop',
		drawscalex = 1,
		drawscaley = 1,
	}

	for i = 0, count - 1 do
		o.frames[ i + 1 ] = min + i * o.ssizex
	end

	return setmetatable( o, self )
end

function animation:update( deltatime )
	if #self.frames < 1 then return end
	self.current_frame += deltatime * self.frame_rate_hz
end

function animation:frame()
	if #self.frames < 1 then return nil end

	local fr = wrap( self.current_frame, 1, #self.frames + 1 )

	if self.style == 'stop' then
		fr = clamp( self.current_frame, 1, #self.frames )
	end

	return self.frames[ flr( fr ) ]
end

local actor = inheritsfrom( nil )
local creature = inheritsfrom( actor )

function actor:new( level, x, y, wid, hgt )
	local o = {
		level = level,
		tick_count = 0,
		active = true,
		alive = true,
		pos = vector:new( x, y ),
		vel = vector:new(),
		offset = vector:new(),
		collision_size = vector:new( establish( wid, 0 ), establish( hgt, 0 )),
		collision_planes_inc = 1,
		do_dynamics = false,
		landed_tick = nil,
		does_collide_with_ground = true,
		gravity_scalar = 1.0,
		jumpforce = 3,
		animations = {},
		current_animation_name = nil,
		flipy = false,
		damage = 2,
		deathcolorshift = -1,
		colorshift = 0,
		flashamount = 0,
		flashhertz = 6,
		floatbobamplitude = 0,
		floatbobfrequency = 1.2,
		transparent_color = 0,
	}

	add( level.actors, o )

	return setmetatable( o, self )
end

function actor:flash( time, hz, amount )
	if self.flashamount ~= 0 then return end

	if hz == nil then hz = 6 end
	if amount == nil then amount = 8 end

	self.flashamount = amount
	self.flashhertz = hz

	self.level:after_delay( time, function()
		self.flashamount = 0
	end )
end

function actor:dead()
	return not self.alive
end

function actor:die( cause )
	if self:dead() then return end

	self.colorshift = self.deathcolorshift
	self.flashamount = 0
	self.alive = false
	self.vel.x = 0
	self.collision_planes_inc = 0
	self.animations[ 'death' ].current_frame = 1
	self.current_animation_name = 'death'
end

function actor:age()
	return self.tick_count / 0x0.003c
end

function actor:may_collide( other )
	return  self.active
			and other.active
			and 0 ~= band( self.collision_planes_inc, other.collision_planes_inc )
end

function actor:collision_br()
	return self.pos + self.collision_size
end

function actor:collision_center()
	return self.pos + self.collision_size * vector:new( 0.5 )
end

function actor:collision_rect()
	return { l = self.pos.x,
			 t = self.pos.y,
			 r = self.pos.x + self.collision_size.x,
			 b = self.pos.y + self.collision_size.y }
end

function actor:does_collide( other )
	return self:may_collide( other )
		and rects_overlap( self:collision_rect(), other:collision_rect() )
end

function actor:on_collision( other )
end

function actor:update( deltatime )

	self.tick_count += 0x0.0001

	if self.do_dynamics then
		self.vel.y += self.gravity_scalar * 0.125

		self.pos.x += self.vel.x
		self.pos.y += self.vel.y

		local footheight = self:collision_br().y
		if self.does_collide_with_ground and footheight >= 0 then
			self.pos.y = -self.collision_size.y
			self:landed()
		end
	end

	local liveleft, liveright = self.level:live_actor_span()
	if self:collision_br().x + 8 < liveleft then
		self.active = false
	end

	if self.vel.x > 0 and self.pos.x > liveright then
		self.active = false
	end

	local anim = self:current_animation()
	if anim ~= nil then
		anim:update( deltatime )
	end
end

function actor:current_animation()
	if self.current_animation_name == nil then return nil end
	return self.animations[ self.current_animation_name ]
end

function actor:landed()
	if not self:grounded() then
	sfx(40)
	end

	self.vel.y = 0
	self.landed_tick = self.level.tick_count
end

function actor:grounded()
	return self.landed_tick ~= nil and self.level.tick_count - self.landed_tick < 0x0.0002
end

function actor:jump( amount )
	if self:dead() or not self:grounded() then return false end

	self.vel.y = -self.jumpforce * establish( amount, 1.0 )
	self.landed_tick = nil
	sfx(32)

	return true
end

function actor:postdraw( drawpos )
end

function actor:draw()
	local anim = self:current_animation()
	if anim ~= nil then
		local floatbobadjustment = sin( self:age() * self.floatbobfrequency ) * self.floatbobamplitude
		local drawpos = self.pos + self.offset + vector:new( 0, floatbobadjustment )
		local frame = anim:frame()
		local drawscalex = anim.drawscalex
		local drawscaley = anim.drawscaley

		local colorize = self.colorshift + ( flicker( self.level:time(), self.flashhertz ) and self.flashamount or 0 )

		draw_color_shifted( colorize, function()
			if self.transparent_color ~= 0 then
				palt( 0, false )
				palt( self.transparent_color, true )
			end

			if drawscalex == 1 and drawscaley == 1 then
				spr( frame, drawpos.x, drawpos.y, anim.ssizex, anim.ssizey, false, self.flipy )
			else
				local spritesheetleft = frame % 16 * 8
				local spritesheettop  = flr( frame / 16 ) * 8
				local spritesheetwid = anim.ssizex * 8
				local spritesheethgt = anim.ssizey * 8
				sspr( spritesheetleft, spritesheettop, spritesheetwid, spritesheethgt,
					  drawpos.x, drawpos.y, drawscalex * anim.ssizex * 8, drawscaley * anim.ssizey * 8, false, self.flipy )
			end

			if self.transparent_color ~= 0 then
				palt( 0, true )
				palt( self.transparent_color, false )
			end

			self:postdraw( drawpos )

		end )
	end
end

function actor:on_pickedup_by( other )
	self.current_animation_name = 'swirl'

	self.may_player_pickup = false
	self.collision_planes_inc = 0
end

local player = inheritsfrom( actor )
function player:new( level )
	local o = actor:new( level, 0, -14, 8, 14 )

	o.vel.x = 1		-- player speed

	o.immortal = false

	o.do_dynamics = true
	o.animations[ 'run' ] = animation:new( 32, 6, 1, 2 )
	o.animations[ 'run_armor' ] = animation:new( 38, 6, 1, 2 )
	o.current_animation_name = 'run'

	o.jump_count = 0

	o.coins = 0
	o.max_health = 6
	o.health = o.max_health

	o.max_satiation = 10
	o.satiation = o.max_satiation

	o.reach_distance = 12

	o.max_armor = 3
	o.armor = 0
	o.armorflicker = false

	o.deathcolorshift = 0
	o.deathcause = ''

	local death_anim = animation:new( 224, 7, 2, 2 )
	death_anim.style = 'stop'

	death_anim.frames = { 224, 226, 228, 230, 230, 230, 230, 230, 232, 232, 232, 232, 232, 232, 232, 234, 236 }
	o.animations[ 'death' ] = death_anim
	o.frame_rate_hz = 1
	return setmetatable( o, self )
end

function player:has_weapon()
	return self.level.inventory:item_count( 'bow' ) > 0
end

function player:ammo()
	return self.level.inventory:item_count( 'arrow' )
end

function player:use_ammo()
	return self.level.inventory:use( 'arrow', 1 )
end

function player:heal( amount )
	self.health = clamp( self.health + amount, 0, self.max_health )
end

function player:eat( amount )
	self.satiation = clamp( self.satiation + amount, 0, self.max_satiation )
end

function player:maybe_shoot( other )
	if self:dead() then return end
	if other:dead() then return end

	if abs( other.pos.x - self.pos.x ) < weapon_check_distance then
		
		if self:has_weapon() and self:ammo() > 0 then
			other:die()
			self:use_ammo()
		end
	end
end

function player:add_coins( amount )
	self.coins += amount
	sfx(36)
end

function player:drain_satiation( amount )
	if self:dead() or self.immortal then return end

	self.satiation -= amount

	if self.satiation < 0 then
		self.satiation = 0
		self:die( 'died from hunger' )
	end
end

function player:jump( amount )
	local jumped = self:superclass().jump( self, amount )

	if jumped then
		self.jump_count += 1
	end

	return jumped
end

function fastphase( phase )
	return phase >= 5 and ( phase % 3 ) == 1
end

function player:update( deltatime )

	if not self:dead() then
		self.vel.x = 1
		if fastphase( self.level:phase() ) then
			self.vel.x = 1.5
		end
	end

	self:superclass().update( self, deltatime )

	local creatures = self.level:actors_of_class( creature )
	foreach( creatures, function(creature)
		self:maybe_shoot( creature )
	end )

	self:drain_satiation( 0.002 )

	if self.current_animation_name ~= 'run' then
		self.animations[ 'run' ]:update( deltatime )
	end

	local frame = self.animations[ 'run' ].current_frame
	self.animations[ 'run_armor' ].current_frame = frame
end

function player:die( cause )
	if self:dead() then return end

	self.deathcause = cause
	self.vel.x = 0
	self.armorflicker = false
	self.armor = 0

	self:superclass().die( self, cause )
end

function player:add_health( amount )
	if amount > 1 then
	sfx(35)
	else
	sfx(34)
	end


	if self:dead() then return end
	self.health = clamp( self.health + amount, 0, self.max_health )
	if self.health == 0 then
		self:die( 'died from wounds' )
	end
end

function player:start_invulnerable()
	if self:dead() then return end
	self.invulnerable = true
	self.level:after_delay( 4.0, function()
		self.invulnerable = false
	end )
end

function player:take_damage( amount )
	if self.invulnerable or self.immortal or self:dead() then return end

	if amount <= 0 then return end

	self:flash( 0.25, 2, 5 )

	if self.armor > 0 then
		amount = 1

		self:start_invulnerable()
		self.armor -= 1

		self.armorflicker = self.armor == 0

		if self.armorflicker then
			self.level:after_delay( 4, function()
				self.armorflicker = false
			end)
		end
	end

	self:add_health( -amount )
	if self.health > 0 then
		self:start_invulnerable()
	end
end

function player:draw()
	if self:dead() or not self.invulnerable or self.armorflicker or flicker( self.level:time(), 8 ) then

		if not self:dead() then
			self.current_animation_name =
				( self.armor > 0 or ( self.armorflicker and flicker( self.level:time(), 6 ))) and 'run_armor' or 'run'
		end

		self:superclass().draw( self )
	end
end

function player:on_collision( other )
	if other.damage > 0 then
		self:take_damage( other.damage )
	end
end

local pickup = inheritsfrom( actor )
function pickup:new( level, itemname, item, x )

	local heightadd = flr( (rnd(1) ^ 2) * 4 ) * 16

	local o = actor:new( level, x, -10 - heightadd, 6, 6 )     -- todo randomize height somewhat

	local sprite = item.sprite

	o.itemname = itemname
	o.item = item
	o.animations[ 'idle' ] = animation:new( sprite )
	o.current_animation_name = 'idle'
	o.collision_planes_inc = 1
	o.may_player_pickup = true
	o.damage = 0
	o.floatbobamplitude = 2

	local swirl = animation:new( 25, 7, 1, 1 )
	swirl.style = 'stop'
	swirl.frames = { 25, 26, 27, 28, 29, 30, 31, 61 }
	o.animations[ 'pickup' ] = swirl

	return setmetatable( o, self )
end

function pickup:on_collision( other )
	self:on_pickedup_by( other )

	self:superclass().on_collision( self, other )
	sfx(33)
end

function pickup:on_pickedup_by( other )
	self.level.inventory:acquire( self.itemname )

	if self.item.onpickedup ~= nil then
		self.item.onpickedup( self.level )
	end

	self:superclass().on_pickedup_by( self, other )
end

local items = {
	rawmeat = {
		name = 'raw meat',
		sprite = 19,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 3 )
		end
	},
	mushroom = {
		name = 'a mushroom',
		sprite = 20,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 5 )
		end
	},
	wheat = {
		name = 'wheat',
		sprite = 21,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 2 )
		end
	},
	stick = {
		name = 'a stick',
		sprite = 22,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 10 )
		end
	},
	oil = {
		name = 'oil',
		sprite = 23,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 6 )
		end
	},
	metal = {
		name = 'metal',
		sprite = 24,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 6 )
		end
	},

	--

	bow = {
		name = 'a bow',
		sprite = 13,
		requirements = { stick = 4, metal = 2 },
		unavailable = function(level)
			return level.inventory:item_count( 'bow' ) > 0
		end,
		oncreated = function(level)
			level.inventory:acquire( 'bow' )
		end
	},
	arrow = {
		name = 'an arrow',
		sprite = 14,
		showinv = true,
		requirements = { stick = 1, metal = 1 },
		oncreated = function(level)
			level.inventory:acquire( 'arrow') 
		end
	},
	armor = {
		name = 'armor',
		sprite =  7,
		requirements = { metal = 3, oil = 2 },
		oncreated = function(level)
			current_player.armor = current_player.max_armor
		end
	},
	cookedmeat = {
		name = 'cooked meat',
		sprite = 10,
		requirements = { rawmeat = 1, torch = 1 },
		oncreated = function(level)
			current_player:heal( 2 )
			current_player:eat( 4 )
		end
	},
	stew = {
		name = 'stew',
		sprite = 11,
		requirements = { mushroom = 5, rawmeat = 3 },
		oncreated = function(level)
			current_player.max_satiation = min( current_player.max_satiation + 2, 12 )
			current_player.satiation = current_player.max_satiation
		end
	},
	pizza = {
		name = 'pizza',
		sprite = 12,
		requirements = { wheat = 3, mushroom = 3 },
		oncreated = function(level)
			current_player.max_health = min( current_player.max_health + 2, 16 )
			current_player:heal( 4 )
		end
	},
	torch = {
		name = 'a torch',
		sprite = 15,
		showinv = true,
		requirements = { oil = 1, stick = 1 },
		oncreated = function(level)
			level.inventory:acquire( 'torch' )
		end
	},

	--

	apple = {
		name = 'an apple',
		sprite = 17,
		shoulddrop = function(level)
			return pctchance( 1 )
		end,
		onpickedup = function(level)
			current_player:heal( 2 )
		end
	},
	banana = {
		name = 'a banana',
		sprite = 18,
		shoulddrop = function(level)
			return pctchance( 2 )
		end,
		onpickedup = function(level)
			current_player:eat( 1 )
		end
	},
	--


	home = { sprite = 61 },
}

function ordered_items()
	local ordered = {}
	add( ordered, { name = 'stick', item = items.stick })
	add( ordered, { name = 'metal', item = items.metal })
	add( ordered, { name = 'oil', item = items.oil })
	add( ordered, { name = 'mushroom', item = items.mushroom })
	add( ordered, { name = 'rawmeat', item = items.rawmeat })
	add( ordered, { name = 'wheat', item = items.wheat })
	add( ordered, { name = 'torch', item = items.torch })
	add( ordered, { name = 'arrow', item = items.arrow })
	return ordered
end

local inventory = inheritsfrom( nil )
function inventory:new()
	local o = {
		itemcounts = {},
		owned_torch = false,
	}
	return setmetatable( o, self )
end

function inventory:item_count( type )
	return establish( self.itemcounts[ type ], 0 )
end

function inventory:missing_items( requirements )
	local arr = {}
	for itemname, count in pairs( requirements ) do
		if self:item_count( itemname ) < count then
			arr[ itemname ] = count
		end
	end
	return arr
end

function inventory:acquire( type )

	if not self.itemcounts[ type ] then
		self.itemcounts[ type ] = 0
	end

	if self.itemcounts[ type ] < 9 then
		self.itemcounts[ type ] += 1
		local item = items[ type ]

		message( 'got ' .. item.name )

		sfx( 33 )

		local gaineditems = {}
		gaineditems[ type ] = item
		inventory_display:on_gained( gaineditems )

		if item.name == 'a torch' then
			self.owned_torch = true
		end
	end
end

function inventory:use( type, count )
	assert( self:item_count( type ) >= count )
	self.itemcounts[ type ] -= count
end

local level = inheritsfrom( nil )
function level:new( inventory )
	local o = {
		actors = {},
		mapsegments = {},
		tick_count = 0,
		pending_calls = {},
		inventory = inventory,
		last_creation_cell = 0,
	}
	o.creation_records = {
		coin     = { chance =   100, earliestnext =   64, interval = 8, predicate = function() 
			return sin( o:time() / 3 ) * sin( o:time() / 11 ) > 0.25 
		end },

		stone    = { chance =   100, earliestnext =   64, interval = 48, predicate = function() 
			return ( #o:actors_of_class( creature ) == 0 ) and pctchance( o:phase() * 2 )
		end },

		creature = { chance =   100, earliestnext = 256, interval = 256, predicate = function() 
			return o:phase() >= 3 and #o:actors_of_class( creature ) == 0 and pctchance( o:phase() * 2 - 2 )
			end },

		material = { chance =   100, earliestnext = 64, interval = 24, create = function(level, creation_point)
			for itemname, type in pairs( items ) do
				if type.shoulddrop ~= nil then
					if type.shoulddrop( level ) then
						pickup:new( level, itemname, type, creation_point, type.sprite )
						break	-- drop just one thing at a time
					end
				end
			end
		end },
	}

	local finishedobject = setmetatable( o, self )

	finishedobject.player = player:new( finishedobject )

	return finishedobject
end

function level:creation_cell()
	return flr( self.player.pos.x / 8 )
end

function level:time()
	return self.tick_count / 0x0.003c
end

function level:ramptime()
	if self.base_tick == nil then
		return 0
	end
	return ( self.tick_count - self.base_tick ) / 0x0.003c
end

local day_length = 30

function level:phase()
	if timesplayed == 1 and self.player.jump_count == 0 then return 1 end
	if timesplayed == 1 and not self.inventory.owned_torch then return 2 end

	return 3 + flr( self:ramptime() / day_length )
end

function level:time_left_in_phase()
	return day_length - self:ramptime() % day_length
end

function level:after_delay( delay, fn )
	add( self.pending_calls, { deadline = self:time() + delay, fn = fn } )
end

function level:viewspan()
	local cam = self:camera_pos()
	return cam.x, cam.x + 128
end

function level:live_actor_span()
	local left, right = self:viewspan()
	return left - 16, right + 32
end

function level:actors_of_class( class )
	local arr = {}
	foreach( self.actors, function(actor)
		if actor.active and ( class == nil or getmetatable( actor ) == class ) then
			add( arr, actor )
		end
	end)
	return arr
end

function level:closest_actor( pos, filter )
	local closest = nil
	local closest_dist_sqr = nil

	foreach( self.actors, function(actor)
		if actor.active and filter( actor ) and is_close( actor.pos, pos, 180 ) then
			local distsqr = ( actor.pos - pos ):lengthsquared()
			if closest_dist_sqr == nil or distsqr < closest_dist_sqr then
				closest = actor
				closest_dist_sqr = distsqr
			end
		end
	end )

	return closest, closest_dist_sqr
end

function level:update_pending_calls()
	local now = self:time()

	erase_elements( self.pending_calls, function(call)
		if now >= call.deadline then
			call.fn()
			return true
		end
		return false
	end )
end

function level:eachactor( apply )
	foreach( self.actors, function(actor)
		if actor.active then
			apply( actor )
		end
	end )
end

function update_actor_collision( a, b )
	if a:does_collide( b ) then
		a:on_collision( b )
		b:on_collision( a )
	end
end

function level:update_collision()

	for i = 1, #self.actors - 1 do
		local actor = self.actors[ i ]
		if self.player ~= actor then 
			update_actor_collision( actor, self.player )
		end
	end

	local footheight = self.player:collision_rect().b
	if self.player.vel.y >= 0 then
		foreach( self.mapsegments, function( segment )
			local collision = segment:colliding_tile( self.player )
			if collision ~= nil and footheight < collision.y + 4 then
				self.player.pos.y = collision.y - self.player.collision_size.y
				self.player:landed()
			end
		end )
	end
end

function level:update()

	self.tick_count += 0x0.0001

	if self.base_tick == nil and ( timesplayed > 1 or self.inventory.owned_torch ) then
		self.base_tick = self.tick_count
	end

	self:update_pending_calls()

	if self.player.alive then
		self:create_props()
		self:update_mapsegments()
	end

	self:update_collision()

	erase_elements( self.actors, function(actor)
		actor:update( 1.0 / 60.0 )
		return not actor.active
	end)

	-- put the player atop everything else
	del( self.actors, self.player )
	add( self.actors, self.player )

	-- fix wrapping
	local limit = 32000
	if self.player.pos.x >= limit then
		foreach( self.actors, function(actor)
			actor.pos.x -= limit
		end )

		for _, record in pairs( self.creation_records ) do
			record.earliestnext -= limit
		end

		foreach( self.mapsegments, function(segment)
			segment.worldx -= limit
		end )
	end
end

function level:camera_pos()
	return vector:new( self.player.pos.x - 32, -96 )
end

function level:draw()

	local cam = self:camera_pos()

	cls( 3 )

	camera( 0, cam.y )

	-- local thetime = self:timeofday()

	rectfill( 0, -96, 128, 0, 12 )
	line( 0, 0, 128, 0, 5 )

	camera( cam.x, cam.y )

	foreach( self.mapsegments, function(segment)
		segment:draw()
	end)

	self:eachactor( function( actor )
		actor:draw()
	end )
end

local behaviors = {}

function creature:new( level, x )
	local maxcreaturetype = flr(( level:phase() - 4 ) / 2 ) + 1
	local whichcreature = rand_int( 1, max( 1, maxcreaturetype ))

	local y = -16
	local wid = 14
	local hgt = 7

	if whichcreature == 3 then
        hgt = 14
	end

	local o = actor:new( level, x, y, wid, hgt )
	o.do_dynamics = true
	o.current_animation_name = 'run'
	o.jumpforce = 1.5
	o.whichcreature = whichcreature

	if whichcreature == 1 then
		o.animations[ 'stop' ] = animation:new( 64, 1, 2, 1 )
		o.animations[ 'death' ] = o.animations[ 'stop' ]
		o.animations[ 'run' ] = animation:new( 64, 3, 2, 1 )
		o.animations[ 'coil' ] = o.animations[ 'run' ]
		o.animations[ 'pounce' ] = o.animations[ 'run' ]
		o.behavior = cocreate( behaviors.slide_left_fast )
	elseif whichcreature == 2 then
		o.animations[ 'run' ] = animation:new( 80, 3, 2, 1 )
		o.animations[ 'coil' ] = animation:new( 86, 1, 2, 1 )
		o.animations[ 'pounce' ] = animation:new( 88, 1, 2, 1 )
		o.animations[ 'stop' ] = o.animations[ 'pounce' ]
		o.animations[ 'death' ] = o.animations[ 'stop' ]
		o.behavior = cocreate( behaviors.pounce_from_left )
	else 
		o.animations[ 'run' ] = animation:new( 96, 3, 2, 2 )
		o.animations[ 'pounce' ] = animation:new( 102, 1, 2, 2 )
		o.animations[ 'stop' ] = o.animations[ 'run' ]
		o.animations[ 'death' ] = o.animations[ 'stop' ]
		o.behavior = cocreate( behaviors.maybe_jump )
	end

	return setmetatable( o, self )
end

function creature:die( cause )
	if self:dead() then return end

	self:superclass().die( self, cause )

	self:flash( 0.2, 2, 5 )

	self.flipy = true
	self.landed_tick = nil
	self.collision_size.y -= 4
	self.behavior = nil

	self.level.inventory:acquire( 'rawmeat' )
end

function creature:update( deltatime )
	if self.behavior ~= nil then
		coresume( self.behavior, self )
		if not costatus( self.behavior ) then
			self.behavior = nil
		end
	end

	self:superclass().update( self, deltatime )
end

function creature:postdraw( drawpos )
	self:superclass().postdraw( self, drawpos  )

	if self.whichcreature == 2 then -- snake
		for i = 1,6 do
			spr( 88, drawpos.x - 8*i, drawpos.y )
		end
	end
end

local stone = inheritsfrom( actor )
function stone:new( level, x )
	local size = rand_int( 1, 2 )
	if level:phase() == 2 then size = 1 end

	local sprite = { 136, 130, 164 }
	local spritewidth =  { 1, 2, 3 }
	local spriteheight = { 1, 2, 2 }
	local spriteoffsetx = { -3, -4, -4 }
	local spriteoffsety = { -3, -2, -2 }
	local collisionwid = { 4, 12, 16 }
	local collisionhgt = { 4, 12, 12 }
	local damage = { 1, 2, 2 }

	local o = actor:new( level, x, -collisionhgt[ size ], 0, 0 )
	o.animations[ 'idle' ] = animation:new( sprite[size], 1, spritewidth[size], spriteheight[size] )
	o.current_animation_name = 'idle'
	o.do_dynamics = false
	o.offset.x = spriteoffsetx[ size ]
	o.offset.y = spriteoffsety[ size ]
	o.collision_size.x = collisionwid[ size ]
	o.collision_size.y = collisionhgt[ size ]
	o.damage = damage[ size ]

	if size == 1 then
		o.transparent_color = 14
	end

	return setmetatable( o, self )
end

local coin = inheritsfrom( actor )
function coin:new( level, x )
	local y = -48 + 8 * flr( sin( x / 300 ) * 5 )
	local o = actor:new( level, x, y, 4, 4 )
	o.animations[ 'idle' ] = animation:new( 16 )
	o.current_animation_name = 'idle'
	o.collision_planes_inc = 1
	o.may_player_pickup = true
	o.damage = 0
	o.floatbobamplitude = 1

	o.value = 1

	return setmetatable( o, self )
end

function coin:on_collision( other )
	self:on_pickedup_by( other )
end

function coin:on_pickedup_by( other )
	other:add_coins( self.value )
	self.value = 0
	self:superclass().on_pickedup_by( self, other )
end

function level:maybe_create( class, classname )
	local _, liveright = self:live_actor_span()
	local creation_point = liveright - 2

	local record = self.creation_records[ classname ]
	if record.earliestnext < creation_point
		and ( record.predicate == nil or record.predicate() )
		and pctchance( record.chance ) then

		-- create
		record.earliestnext = creation_point + record.interval
		if record.create ~= nil then
			return record.create( self, creation_point )
		else
			return class:new( self, creation_point )
		end
	end
	return nil
end


function level:create_props()
	if self.last_creation_cell == self:creation_cell() then return end

	self.last_creation_cell = self:creation_cell()

	if not self:maybe_create( coin, 'coin' ) then
		if not self:maybe_create( creature, 'creature' ) then
			if not self:maybe_create( stone, 'stone' ) then
				self:maybe_create( material, 'material' )
			end
		end
	end
end

function world_to_mapsegment_cell_x( x )
	return flr( x / maptoworld( mapsegment_tile_size.x ) )
end

function level:update_mapsegments()
	local left, right = self:viewspan()

	erase_elements( self.mapsegments, function(segment)
		local farleft = segment:right() < left
		return farleft
	end )

	firstopenleft = right
	if #self.mapsegments > 0 then
		firstopenleft = max( firstopenleft, self.mapsegments[ #self.mapsegments ].worldx + maptoworld( mapsegment_tile_size.x ) )
	end
	for worldcellx = world_to_mapsegment_cell_x( firstopenleft ), world_to_mapsegment_cell_x( right ) do
		local segment = mapsegment:new( rand_int( 0, 5 ), maptoworld( worldcellx * mapsegment_tile_size.x ) )
		add( self.mapsegments, segment )
	end

end

-->8
--input
local buttonstates = {}
local lastbuttonstates = {}
function wentdown( btn )
	return buttonstates[ btn ] and not lastbuttonstates[ btn ]
end
function jumpwentdown()
	return wentdown( 4 ) or wentdown( 5 )
end

function isdown( btn )
	return buttonstates[ btn ]
end

function update_buttons()
	lastbuttonstates = shallowcopy( buttonstates )

	for i = 0,5 do
		buttonstates[ i ] = btn( i )
	end
end

-->8
--crafting

local flashduration = 2
local inventorydisplay = inheritsfrom( nil )
function inventorydisplay:new( level )
	local o = {
		level = level,
		highlighted_items = {},
		flashstarttime = nil,
		item_use_message = '',
	}
	return setmetatable( o, self )
end

function inventorydisplay:highlight_items( items )
	self.flashstarttime = self.level:time()
	self.highlighted_items = items
end

function inventorydisplay:highlighting()
	return self.flashstarttime ~= nil and self.level:time() < self.flashstarttime + flashduration
end

function inventorydisplay:on_gained( items )
	-- don't highlight if higher priority
	if self:highlighting() and self.item_use_message == 'used:' or self.item_use_message == 'need:' then
		return
	end

	self.item_use_message = ''
	self:highlight_items( items )
end

function inventorydisplay:on_used( items )
	self.item_use_message = 'used:'
	self:highlight_items( items )
end

function inventorydisplay:on_tried_to_make( item )
	self.item_use_message = 'need:'
	self:highlight_items( self.level.inventory:missing_items( item.requirements ) )
end

function inventorydisplay:draw()

	local left = 54
	local top = 128 - 2 - 9 - 6
	local i = 0
	local now = self.level:time()

	local colorshift = 0 
	if self:highlighting() then
		colorshift = flicker( now, 2 ) and 8 or 0
	end

	local ordered = ordered_items()

	foreach( ordered, function(itemrecord)
		local item = itemrecord.item
		local itemname = itemrecord.name

		if item.showinv then
			local x = left + i * 9

			draw_color_shifted( self.highlighted_items[ itemname ] ~= nil and colorshift or 0, function()
				spr( item.sprite, x, top )
				
				local count = self.level.inventory:item_count( itemname )
				
				draw_shadowed( x + 2, top + 9, function(x,y)
					print( '' .. count, x, y, 12 )
				end )
			end )

			i += 1
		end
	end )

	-- show needs/used
	if self:highlighting() then
		draw_color_shifted( colorshift, function()
			draw_shadowed( 40, top, function(x,y)
				print_centered_text( self.item_use_message, x, y, 14 )
			end )		
		end )
	end
end

local item_tree =
	{ item = nil,
		children = {
			{ item = 'torch' },
			{ item = 'cookedmeat',
				children = {
					{ item = 'pizza' },
					{ item = 'cookedmeat' },
					{ item = 'stew' },
				}
			},
			{ item = 'arrow',
				children = {
					{ item = 'bow' },
					{ item = 'armor' },
					{ item = 'arrow' },
				}
			},
			{ item = 'home' },
		}
	}

local thingy_spacing = 20

local thingy = inheritsfrom( nil )

local crafting = inheritsfrom( nil )
function crafting:new( level, pos )
	local o = {
		level = level,
		pos = pos,
		tick_count = 0,
		pending_calls = {},
		activated = nil,
		homebutton = false,
		lockout_input = false,
		last_activate_time = nil,
	}

	local resultself =  setmetatable( o, self )

	resultself.rootthingy = thingy:new( resultself, nil, item_tree )
	resultself.homebutton = resultself.rootthingy.children[ 4 ]
	resultself.homebutton.homebutton = true
	resultself.rootthingy:activate()

	return resultself
end

function crafting:on_activating( thing )
	self.activated = thing
end

function crafting:on_activating_item( thing, takingaction )

	self.last_activate_time = self:time()

	if not takingaction then return end

	self.lockout_input = true

	if not thing.homebutton then
		self:after_delay( 0.4, function()
			self:reset()
		end )
	else
		self:reset()
	end
end

function crafting:update_pending_calls()
	local now = self:time()

	erase_elements( self.pending_calls, function(call)
		if now >= call.deadline then
			call.fn()
			return true
		end
		return false
	end )
end

function crafting:reset()
	self.last_activate_time = nil
	self.activated = nil
	self.lockout_input = false
	self.rootthingy:collapse( true )
	self.rootthingy:activate()
end

function crafting:after_delay( delay, fn )
	add( self.pending_calls, { deadline = self:time() + delay, fn = fn } )
end

function crafting:time()
	return self.tick_count / 0x0.003c
end

function crafting:update()
	self.tick_count += 0x0.0001

	self:update_pending_calls()

	if self.activated ~= nil then
		self.activated:update_input()
	end

	if self.last_activate_time ~= nil then
		if self:time() - self.last_activate_time > 6 then
			self:reset()
		end
	end

	self.rootthingy:update()
end

function crafting:draw()

	local rootbasis = self.pos

	self.rootthingy:draw( rootbasis, false )

	if self.activated ~= nil then
		self.rootthingy:draw( rootbasis, true )
	end

	function special_shadow( x, y, col1, col2, drawfn )
		drawfn( x, y+1, col1 )
		drawfn( x, y, col2 )
	end

	draw_shadowed( rootbasis.x, rootbasis.y, function(x,y,col)
		print( '⬅️', x - 10, y, 8 )
		print( '➡️', x + 10, y, 9 )
		print( '⬆️', x, y - 10, 10 )

		if self.activated ~= self.rootthingy then
			print( '⬇️', x, y + 10, 11 )
		end
	end )

	if self.activated == self.rootthingy then
		draw_shadowed( rootbasis.x + 4, rootbasis.y + 12, function(x,y)
			print_centered_text( 'craft', x, y, 4 )
		end )
	end
end

function thingy:new( crafting, parent, item_config )
	local sprite = nil
	if item_config.item ~= nil and items[ item_config.item ] then
		sprite = items[ item_config.item ].sprite
	end
	
	local o = {
		crafting = crafting,
		parent = parent,
		item = items[ item_config.item ],
		sprite = sprite,
		children = {},
		pos = vector:new( 0, 0 ),
		destination = nil,
		lerpspeed = 0.25,
		flashstarttime = nil,
		flashendtime = nil,
	}

	local configchildren = item_config.children
	foreach( configchildren, function(child)
		add( o.children, thingy:new( crafting, o, child ) )
	end )

	return setmetatable( o, self )
end

function thingy:flash( duration )
	self.flashstarttime = self.crafting:time()
	self.flashendtime = self.flashstarttime + establish( duration, 1 )
end

function thingy:flash_age()
	if self.flashstarttime == nil then return nil end
	return self.crafting:time() - self.flashstarttime
end

function thingy:flashing()
	return self.flashendtime ~= nil and ( self.flashendtime > self.crafting:time() )
end

function thingy:recursively_usable()
	if self.homebutton then return true end
	if #self.children == 0 and self:available() then return true end

	for child in all( self.children ) do
		if child:recursively_usable() then
			return true
		end
	end
	return false
end

function thingy:available()
	if self.homebutton or #self.children > 0 then return true end

	if self.item.unavailable ~= nil and self.item.unavailable( self.crafting.level ) then return false end

	for itemname, count in pairs( self.item.requirements ) do
		if self.crafting.level.inventory:item_count( itemname ) < count then
			return false
		end
	end

	return true
end

function thingy:drawself( basepos )
	local selfpos = basepos + self.pos

	if self.sprite == nil then return end

	local colorize = 0
	if self:flashing() and flicker( self:flash_age(), 2 ) then
		colorize = 8
	end

	draw_color_shifted( colorize, function()

		local basecolorshift = colorize
		if basecolorshift == 0 then
			basecolorshift = self:recursively_usable() and 1 or 0
		end
		draw_color_shifted( basecolorshift, function()
			spr( 46, selfpos.x - 2, selfpos.y - 2, 2, 2 )
		end )

		local iconcolorshift = colorize
		if iconcolorshift == 0 and #self.children > 0 then
			iconcolorshift = -1
		end

		draw_color_shifted( iconcolorshift, function()
			spr( self.sprite, selfpos.x, selfpos.y )
		end )
	end )
end


function thingy:drawchildren( basepos, activatedonly )
	foreach( self.children, function(child)
		child:draw( basepos, activatedonly )
	end )
end

function thingy:child_from_button( button )
	if button == nil then return nil end

	if button <= #self.children then
		return self.children[ button ]
	else
		return nil
	end
end

function thingy:has_activated_descendant()
	if self.crafting.activated == self then return true end

	for child in all( self.children ) do
		if child:has_activated_descendant() then
			return true
		end
	end
	return false
end

function thingy:draw( basepos, activatedonly )
	if activatedonly and not self:has_activated_descendant() then return end

	local selfpos = basepos + self.pos

	local drawselfontop = true

	if not drawselfontop then
		self:drawself( basepos )
	end

	self:drawchildren( selfpos:copy(), activatedonly )

	if drawselfontop then
		self:drawself( basepos )
	end
end

function thingy:update()

	if self.destination ~= nil then
		function decisive_lerp( from, to, alpha )
			local result = lerp( from, to, alpha )
			if abs( to - result ) < 0.25 then
				result = to
			end
			return result
		end
		self.pos.x = decisive_lerp( self.pos.x, self.destination.x, self.lerpspeed )
		self.pos.y = decisive_lerp( self.pos.y, self.destination.y, self.lerpspeed )
	end

	foreach( self.children, function(child)
		child:update()
	end )
end

function thingy:expand( myindex )
	if myindex == 1 then
		self.destination = vector:new( -thingy_spacing, 0 )
	elseif myindex == 2 then
		self.destination = vector:new(  thingy_spacing, 0 )
	elseif myindex == 3 then
		self.destination = vector:new( 0, -thingy_spacing )
	elseif myindex == 4 then
		self.destination = vector:new( 0, 0 )
	end
end

function thingy:collapse( recursive )
	self.destination = vector:new( 0, 0 )

	if self.homebutton then
		self.destination = vector:new( 0, thingy_spacing )
	end

	if recursive then
		foreach( self.children, function(child)
			child:collapse( recursive )
		end )
	end
end

function thingy:activate()
	if not self:available() then
		self:flash( 0.05 )
		self.crafting:on_activating_item( self, true )
		sfx(41)
		inventory_display:on_tried_to_make( self.item )
		message( 'for ' .. self.item.name )
		return
	end

	self.crafting:on_activating( self )

	local flashduration = 0.25

	if self.parent ~= nil and #self.children == 0 and self.item ~= nil then
		-- yes
		for itemname, count in pairs( self.item.requirements ) do
			self.crafting.level.inventory:use( itemname, count )
		end

		local action = self.item.oncreated
		if action ~= nil then
			action( self.crafting.level )
		end

		inventory_display:on_used( self.item.requirements )
		message( 'made ' .. self.item.name )

		self.crafting:on_activating_item( self, true )
		sfx(39)
	else
		self.crafting:on_activating_item( self, false )

		self.destination = vector:new( 0, 0 )

		flashduration = 0.15

		for i = 1, #self.children do
			self.children[ i ]:expand( i )
		end
	end

	if self.parent ~= nil then
		self:flash( flashduration )
	end

end

function thingy:update_input()

	if self.crafting.lockout_input then return end

	if btnp( 3 ) and self.parent ~= nil then
		self.crafting.homebutton:flash( 0.15 )
		self.crafting:reset()
		sfx(37)
	else
		local button = nil
		if btnp( 2 ) then
			button = 3
		elseif btnp( 1 ) then
			button = 2
		elseif btnp( 0 ) then
			button = 1
		end

		local activated_child = self:child_from_button( button )

		if activated_child ~= nil then

			if #activated_child.children > 0 then
				foreach( self.children, function(child)
					if activated_child ~= child then
						child:collapse()
						sfx(37)
					end
				end )
			end

			activated_child:activate()
		end

	end
end

-->8
--one-time setup

function tidy_map()
	for mapx = 0, 127 do
		for mapy = 0, 32 do

			function platformsprite( sprite )
				return 132 <= sprite and sprite <= 135
			end

			local mapsprite = mget( mapx, mapy )
			local segmentx = mapx % mapsegment_tile_size.x
			local segmenty = mapy % mapsegment_tile_size.y
			if platformsprite( mapsprite ) then
				local leftplatform = segmentx > 0 and platformsprite( mget( mapx - 1, mapy ))
				local rigtplatform = segmentx < mapsegment_tile_size.x - 1 and platformsprite( mget( mapx + 1, mapy ))

				local newsprite = 132
				if not leftplatform then
					newsprite = not rigtplatform and 135 or 133
				elseif not rigtplatform then
					newsprite = 134
				end
				mset( mapx, mapy, newsprite )
			end
		end
	end
end

--level creation
music()

local game_state = 'title'

function restart_world()
	timesplayed += 1
	current_level = level:new( inventory:new() )
	current_player = current_level.player
	crafting_ui = crafting:new( current_level, vector:new( 96, 2 + thingy_spacing + 2 ))
	inventory_display = inventorydisplay:new( current_level )
end

function player_run_distance()
	return flr(( current_player.pos.x - 0 ) / 40 )
end

function deltafromplayer( actor )
	return actor.pos.x - current_player.pos.x
end

tidy_map()
restart_world()

--main loops
function _update60()

	update_buttons()

	if game_state == 'playing' then
		function update_input()
			if jumpwentdown() then
				current_player:jump()
			end

			crafting_ui:update()

			-- manual movement
			if false then
				local move = 0
				if isdown( 0 ) then
					move += -1
				end
				if isdown( 1 ) then
					move += 1
				end
				current_player.vel.x = move
			end
		end


		if current_player:dead() then
			game_state = 'gameover_dying'
			current_level:after_delay( 2.0, function()
				game_state = 'gameover'
			end )
		else
			update_input()
		end

	elseif game_state == 'gameover' then
		if jumpwentdown() then
			restart_world()
			game_state = 'playing'
		end
	elseif game_state == 'title' then
		if jumpwentdown() then
			game_state = 'playing'
		end
	end

	if current_level ~= nil and game_state ~= 'title' then
		current_level:update()
	end
end

function draw_color_shifted( shift, fn )
	for i = 0,15 do
		pal( i, rel_color( i, shift ))
	end

	fn()

	pal()
end

function draw_shadowed( x, y, fn )
	draw_color_shifted( -2, function()
		fn( x, y + 1 )
	end )

	fn( x, y )
end

function print_centered_text( text, x, y, color )
	print( text, x - #text / 2 * 4, y, color )
end

function print_rightaligned_text( text, x, y, color )
	print( text, x - #text * 4, y, color )
end

function draw_ui()

	function draw_ui_playing()
		local iconstepx = 8

		local iconright = 126
		local iconleft  = 19

		function draw_halveable_stat( pos, top, stat, max, full_sprite, half_sprite, empty_sprite )

			local left = pos

			for i = 0, (max - 1) / 2 do
				local x = i * iconstepx

				local equivalent_x = i * 2

				local sprite = 0

				if equivalent_x + 1 < stat then sprite = full_sprite
				elseif equivalent_x < stat then sprite = half_sprite
				else sprite = empty_sprite end

				if sprite > 0 then
					local flashrate = stat > 2 and 0 or ( 3 - stat )
					draw_color_shifted( ( flashrate > 0 and flicker( current_level:time(), flashrate ) ) and 8 or 0, function()
						spr( sprite, left + x, top )
					end )
				end
			end
		end

		function draw_fullicon_stat( pos, top, stat, max, full_sprite, empty_sprite )

			local left = pos

			for i = 0, max - 1 do
			local x = i * iconstepx

			local sprite = 0

			if i < stat then sprite = full_sprite
			else sprite = empty_sprite end

			if sprite > 0 then
				spr( sprite, left + x, top )
			end
			end
		end

		local iconsy = 2


		draw_halveable_stat( iconleft, iconsy, current_player.health, current_player.max_health, 1, 2, 3 )
		draw_shadowed( 2, iconsy + 1, function(x,y)
			print( 'life', x, y, 8 )
		end )
		iconsy += 9

		draw_fullicon_stat( iconleft, iconsy, current_player.armor, current_player.max_armor, 7, 8 )
		draw_shadowed( 6, iconsy + 1, function(x,y)
			print( 'def', x, y, 13 )
		end )
		iconsy += 9

		draw_halveable_stat( iconleft, iconsy, current_player.satiation, current_player.max_satiation, 4, 5, 6 )
		draw_shadowed( 2, iconsy + 1, function(x,y)
			print( 'food', x, y, 9 )
		end )

		iconsy += 9

		draw_shadowed( 2, 128 - 2 - 6, function(x,y)
			print( 'score ' .. current_player.coins * 10, x, y, 10 )
		end )

		iconsy += 9

		crafting_ui:draw()
		inventory_display:draw()

		local phase = current_level:phase()
		if phase == 1 then
			draw_shadowed( 64, 54, function(x,y)
				print_centered_text( 'press z to jump!', x, y, 8 )
			end )
		end

		if phase == 2 then
			draw_shadowed( 64, 46, function(x,y)
				print_centered_text( 'craft a    with   and', x, y+1, 8 )
				spr( 15, x - 9, y )
				spr( 22, x + 20, y )
				spr( 23, x + 44, y )
			end )
		end

		draw_shadowed( 90, 128-28, function(x,y)
			print_centered_text( curmessage(), x, y, 12 )
		end )

		local phasespeed = fastphase( phase ) and 1 or 0
		local nextphasespeed = fastphase( phase + 1 ) and 1 or 0
		local speedchange = nextphasespeed - phasespeed
		if speedchange ~= 0 and current_level:time_left_in_phase() < 3 and flicker( current_level:time(), 2 ) then
			draw_shadowed( 64, 54, function(x,y)
				print_centered_text( speedchange > 0 and 'get ready!' or 'nearly there!', x, y, 8 )
			end )
		end

	end

	function draw_ui_gameover()
		draw_shadowed( 64, 64, function(x,y)
			print_centered_text( current_level.player.deathcause, x, y, 8 )
		end )
	end

	function drawlogo()
		spr( 148, 16, 16, 12, 4 )
	end

	if game_state == 'playing' then
		draw_ui_playing()
	elseif game_state == 'title' then
		drawlogo()

		draw_shadowed( 64, 0, function(x,y)
			print_centered_text( 'press z to start', x, y + 108, 12 )
		end )
	elseif game_state == 'gameover_dying' then
		draw_ui_gameover()
	elseif game_state == 'gameover' then
		drawlogo()
		draw_ui_gameover()

		draw_shadowed( 64, 0, function(x,y)
			print_centered_text( 'press z to play again', x, y + 108, 12 )
			print_centered_text( 'score: ' .. current_level.player.coins * 10, x, y + 64 + 10, 10 )
		end )
	end


	-- -- todo!!! debug
	-- if true then
	-- 	draw_shadowed( 124, 2, function(x,y)
	-- 		print_rightaligned_text( 'phase: ' .. current_level:phase(), x, y, 6 )
	-- 		y += 8

	-- 	end )
	-- end
end

function _draw()

	current_level:draw()
	camera( 0, 0 )
	draw_ui()
	-- draw_debug_lines()
end

function wait( seconds )
	for i = 0, seconds * 60 do
		yield()
	end
end

function stage_left_appear_pos()
	local left, _ = current_level:live_actor_span()
	return left + 2
end

function standard_attack_warning( actor, delay )
	delay = establish( delay, 0.5 )
	actor:flash( delay )
	wait( delay )
end

function set_player_relative_velocity( actor, speedscale )
	actor.vel.x = current_player.vel.x * speedscale
end

behaviors = {
	still = function() end,
	hopping =
		function(actor)
			while true do
				actor:jump()
				yield()
			end
		end,
	slide_left_slow =
		function(actor)
			actor.vel.x = -0.5
		end,
	slide_left_fast =
		function(actor)
			actor.vel.x = -2
			while deltafromplayer( actor ) > 64 do
				yield()
			end
			set_player_relative_velocity( actor, 1 )
			wait( 0.4 )
			set_player_relative_velocity( actor, 0.8 )

			standard_attack_warning( actor )
			actor.vel.x = -3
		end,
	slide_right_fast =
		function(actor)
			actor.pos.x = stage_left_appear_pos()
			set_player_relative_velocity( actor, 1.5 )
			while deltafromplayer( actor ) < -24 do
				yield()
			end
			set_player_relative_velocity( actor, 0.9 )
			wait( 0.2 )
			standard_attack_warning( actor )
			set_player_relative_velocity( actor, 4 )
		end,
	maybe_jump = 
		function(actor)
			actor.vel.x = 0
			actor.jumpforce = 3

			while deltafromplayer( actor ) > 52 do
				yield()
			end

			if pctchance(50) then
				standard_attack_warning( actor )
				actor:jump()
			end
		end,
	pounce_from_left =
		function(actor)
			local maxpounces = clamp( actor.level:phase() - 7, 1, 3 )
			local restpos = -32

			local numpounces = rand_int( 1, maxpounces )

			actor.pos.x = stage_left_appear_pos()
			local stored_collision_planes = actor.collision_planes_inc

			actor.current_animation_name = 'run'
			set_player_relative_velocity( actor, 1.25 )
			while deltafromplayer( actor ) < restpos do
				yield()
			end

			for i = 1, numpounces do

				actor.colorshift = 0

				actor.current_animation_name = 'run'
				set_player_relative_velocity( actor, 0.95 )
				wait( 1 )

				actor.current_animation_name = 'coil'
				standard_attack_warning( actor )

				actor.collision_planes_inc = stored_collision_planes
				actor.current_animation_name = 'pounce'
				actor:jump()
				set_player_relative_velocity( actor, 2.5 )

				while not actor:grounded() do
					yield()
				end

				actor.current_animation_name = 'stop'
				actor.vel.x = 0
				stored_collision_planes = actor.collision_planes_inc
				actor.collision_planes_inc = 0

				actor.colorshift = -1

				while deltafromplayer( actor ) > restpos do
					yield()
				end
			end
		end,
}

__gfx__
00000000088088000880000000000000000004000000000000000000777666d000000000000000007000000000000000009900004000000076000000700a0000
00000000878888108788022000220220099909900990002000000020744222d202222222000000006740000004444200097a40004444400066600000a7900000
00700700888888128888122202222222979999929799202200222022642224d20222222200000000044400004477942097aaa00007004400064000000aa90000
00077000888881128888122202222222994999429994222202222222622244d2022222220000000004442000499988209aa4a400007004000004c00090944000
0007700008881122088112220222222294444422994222220222222206244d220222222200000000002220004298822004aa990000070400000c4cd000004400
007007000011122000111220002222209422222094222220022222200664dd2000222220000000000000dd004422222000094900000062000000c2d000000420
00000000000122000001220000022200044420000444200002200000000622200022222000000000000006000222220000000900000002200000cd0000000020
00000000000020000000200000002000002220000022200000222000000020000000200000000000000000000000000000000000000000000000000000000000
000000000000b000004000007000000000000000700a0000000b0000000dd0000000000000070000000700000000000000000000007000000670000006700000
00777000008b80000aa0000067e00000007990000a7a9000044b30000000dd000077700000000000000700000007000000070000000700000007006000000060
07aaaa000878820009a000000eee00000799940009a9aa000045300000777d100766660000000000000000000007000000777000000700700000007000000070
0aaaaa000888820009aa00000eee2000099994007a9a4a000004400007dddd100666660070070070770707700777770007707700077077000700070000000000
09aaa90008822200009aa94000222000099944000aa4a490000055000dddd1100d666d0000000000000000000007000000777000700700007000000070000000
0099900000222000000444000000dd0000f5500000994900000005000011110000ddd00000000000000700000007000000070000000700006007000060000000
00000000000000000000000000000600000000000004900000000000000000000000000000070000000700000000000000000000000070000000760000007600
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00044400044440000044000000044400044440000004400000044400044440000044000000044400044440000004400011111111111010100555555555000000
00444f004444f0ff4444400000444f004444f0440444440000444f004444f0ff4444400000444f004444f0dd0444440011111111010101015111111111500000
0444ff00444ff0ff4444f0000444ff00444ff04404444f000444ff00444ff0f74444f0000444ff00444ff0d104444f0011111110101010005111111111500000
044fff0000fff00f044ff000044fff0000fff0040044ff00044fff0000fff006044ff000044fff0000fff0010044ff0011110101000000005111111111500000
000fff0044ffffff00fff000000fff00fffff444000fff0000076600d176676600fff00000076600767661110007660011101010000000005111111111500000
004fff0040ff400000fff0f000ffff00f04ff000000fff040016760010666000007660f000766600606660000006760d11110000000000005111111111500000
004fff0040fff00000fffff000ffff00f0fff000000fff4400166600106660000067667000f66600f06660000006661d11101000000000005111111111500000
000fff0000fff00000fff000000fff0000fff000000fff0000066600006660000066600000066600006660000006660011010000000000005111111111500000
000eee0000eee00000eee200000eee0000eee000000eee00000ddd0000ddd00000ddd100000ddd0000ddd000000ddd0010100000000400005111111111500000
000eee2000eee20000eeee20000eeee000eeee00002eeee0000766d0007661000076661000076660007666000017666011000000004140005111111111500000
000ee82008ee222000eeee80000ee880022ee880002eee80000666d0076611d00066666000066660011666600016666010100000041424000555555555000000
00088840088e0244fff888800002e8f0022288ff4442e880000666d007660ddddd76666000017660011167661111676001000000414442400000000000000000
0044f4400f80044000ffff4000fffff004200ff0004448f0001176d006600dd0006666d000ddd6600d10066000ddd66010000000014442000000000000000000
0000f000ff00440000000040000040004400ff00000000f000006000d6001100000000d0000010001d00dd000000006001000000044144000000000000000000
0000f000f000400000000040000040004000f000000000f00000d000d000100000000010000010001000d000000000d010000000022122000000000000000000
0000ff00f0000000000000440000440040000000000000ff0000dd00d0000000000000110000110010000000000000dd01000000000000000000000000000000
0a8a880000000008000000000000000000a8a8800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28888000000822880a8a880000082200028888000088200000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888200282282802888800088282880008822808288288000000000000000000000000000000000000000000000000000000000000000000000000000000000
00822828288280000822282228800080000288228280008800000000000000000000000000000000000000000000000000000000000000000000000000000000
02288828288820000088882828200800002882828800000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22828288288882000008828882000000222882882800000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28808288000888200000822800000000288888022800000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800000000008880000802000000000080000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000300030003000000000000000000000000000000000000000000000000000000000000000000000
00000000000053500000000000000000000000000000000003550533035133500000000000000000000000000000000000000000000000000000000000000000
0053530000035a53000053530000000050000053530000000553035505515a530000000000000000000000000000000000000000000000000000000000000000
03535350005353330003535350005350530003535350000013551533135553330000000000005353000000000000000000000000000000000000000000000000
53599353035390005053599353035a53535053599353000015131315151530005535535335535a57000000000000000000000000000000000000000000000000
53900953535900005353900953535333935353900953535013151513131330005335335335335307000000000000000000000000000000000000000000000000
590000935390000053590000935390000953590000935a5353035303530390005335335335339000000000000000000000000000000000000000000000000000
90000009990000009990000009990000009990000009933399099909990990009999999999990330000000000000000000000000000000000000000000000000
000a9a0990000000000a9a0990000000000a9a09900000009aa00449000000000000000000000000000000000000000000000000000000000000000000000000
00a4499aa9a0000000a4499aa9a0000000a4499aa9a000004a09a9ff400000000000000000000000000000000000000000000000000000000000000000000000
0a99ff49aaa400000a99ff49aaa400000a99ff49aaa40000a90aa944440000000000000000000000000000000000000000000000000000000000000000000000
aaa4444aaaaa4000aaa4444aaaaa4000aaa4444aaaaa4000aa40a9aa9a4000000000000000000000000000000000000000000000000000000000000000000000
9a9aaa4a9a9a44009a9aaa4a9a9a44009a9aaa4a9a9a44000aa44a4aaaa400000000000000000000000000000000000000000000000000000000000000000000
0aaaa9aaaaaaa4400aaaa9aaaaaaa4400aaaa9aaaaaaa4400a944aaa9aa440000000000000000000000000000000000000000000000000000000000000000000
aa9aaaaa9aa9a940aa9aaaaa9aa9a940aa9aaaaa9aa9a94000aaa9a4a49a44000000000000000000000000000000000000000000000000000000000000000000
a44a9a9aaaaaaa44a44a9a9aaaaaaa44a44a9a9aaaaaaa440009aa449aaaa4000000000000000000000000000000000000000000000000000000000000000000
00044aa4a49aaa440004aaa4a49aaa44004aaaa4a49aaa440000444aaa9a94400000000000000000000000000000000000000000000000000000000000000000
0000444a44aa99440000a44a4aaa994404aaa44a4aaa9944000044aaa94a94440000000000000000000000000000000000000000000000000000000000000000
0000004a44a9aaa400004a4a4aa9aaa404aaaa4a4aa9aaa4000004444aaaaa400000000000000000000000000000000000000000000000000000000000000000
00000094449aa94400000494aa9aa94404aaa494aa9aa944000000044a9a94000000000000000000000000000000000000000000000000000000000000000000
000000a4009aa444000000a4aa9aa4440aaaa4a4aa9aa4440000000004aaa4400000000000000000000000000000000000000000000000000000000000000000
00000aa444a4444400000aa444a4444404aaaaa444a4444400000000004aaa400000000000000000000000000000000000000000000000000000000000000000
00004a44aaa4444000004a44aaa44440004a4a44aaa44440000000000000a9a00000000000000000000000000000000000000000000000000000000000000000
004aa9aa44444440004aa9aa44444440004aa9aa444444400000000000004a440000000000000000000000000000000000000000000000000000000000000000
000b000000000b00000440000000000011111111011111111111100001111000eeeeeeee00000000000000000000000000000000000000000000000000000000
0b3bb0000000bb3b0000446000000000bb33bb331bb3bb33bb3335001bb33500eeeeeeee00000000000000000000000000000000000000000000000000000000
00b3bb00000bb3b00446446664400440111111111b331111111111101b331110ee1510ee00000000000000000000000000000000000000000000000000000000
b3b33bb000b333bb044461164400440033bb33bb13bb33bb33bbb35113bbb351e111010e00000000000000000000000000000000000000000000000000000000
0b3bb33b0b0bbb30004446d14661400033bb33bb133b33bb33bbb351133bb351e151100e00000000000000000000000000000000000000000000000000000000
00b33b0000b33300006411d11dd11000bb33bb331533bb33bb333b3115333b31e110100e00000000000000000000000000000000000000000000000000000000
0b3bb300bb3bbbbb00661ddddddd444033553355011533553355533101155331e101010e00000000000000000000000000000000000000000000000000000000
00b3bbb000b333b044446dddddd4440011111111001111111111111000111110e000000e00000000000000000000000000000000000000000000000000000000
bb3b300000005b300044441ddd11dd00000000000666666600660000066066666666006600000660666666666066000006600000066660066650000000000000
0b33bb00000bb3000066411dddddddd0000000006666666660665000066566666666606660006665666666666566600066650006666665066500000000000000
00bb30000bb33bbb4446ddddddddddd0000000006665556665665000066566555566656660006665556665555566600066650066655665066500000000000000
0005bbb0000bb3300441dddddddddddd000000006650005555665000066566500006655666066655000665000056660666550066500665066500000000000000
0005000000b35bbb0611dddddddddddd000000006666666600665000066566666666650666066650000666500006660666500665000665066500000000000000
00040000000050000666dddddddddddd000000005666666660665000066566666666550566066550000666500005660665500665000665066500000000000000
0004000000004000006dddddddddddd0000000000555555665665000066566566655500066666500000066500000666665000666666665066500000000000000
000400000000400000000dddddddd000000000006660006665666000666566506665000056665500000066650000566655006655555665066500006000000000
000000000000000000000bbb00000000000000006666666665666666666566500666500006665000066666666650066650006650000665066666666500000000
00000000000000b00000bbbbbbbb0000000000005666666655566666665566650066650005655000006666666665056550006660006665066666666500000000
0000000000b00bb0000bb33bbb000000000000000555555550055555555055500005550000550000000555555555005500005550005555055555555500000000
0000000000bbb33000bbbbbbb00000000007077aaa777777777770000000000000000077aaa77700000007777777000007a00077777700000077777770000000
0000000000bb33030bbbb3300000000007a000aaa777aaaaaaaaaaa000000000007a000000777a97a077777aaaaaaaaa0000077777aa9900000077aaa9900000
000000000bb33000bbb33030bbbbbbb00000000007aaaaaaaaaaaaaaa00000000000000007aaaa900007aaaaaaaaaaaaaaa00007aaaa7a07aaa77aaaa9900000
00000000bbb3300bbb33000bbbbb00000000000007aaaaaaaaaaaaaaaa000707aa077aaa7aaaaa90077aaaaaaaaaaaaaaaa9000aaaaa99000000aaaaa9900000
00000000bbb3bbbbb3300bbbbbb000000000000007aaaaaaaaaaaaaaaa00000000000007aaaaaa90007aaaaaaaaaaaaaaaa9007aaaaa9900000aaaaaa9900000
0000000bbb33bbbb3333bbbbbb0b0000000070077aaaaa9999aaaaaaaaa000000000007aaaaaaa907aaaaaaa9999aaaaaa99007aaaa999707aaaaaaa99900000
000000bbbb3bbbb333bbbbbbb00b0000000000007aaaaa999999aaaaaaa00000000007aaaaaaaa9000aaaa99990000aaaa9007aaaaa99000000aaaaa99000000
000000bbb3bbb3333bbbbbb3330bbbbb000000007aaaaa9900000aaaaaa9700000007aaaa9aaaa9000aaaa000007a00aaa90aaaaaaa990000007aaaa99000000
00000bbbbbb3333bbbbbb33000bbbb00000000007aaaaa99000007aaaaa900000aa7aaaa997aaa90000aaa7770000000099000aaaaaa77777777aaaa99000000
0000bb3bbbbbbbbbbbbb3300bbbbb000000000007aaaa999070aa77aaaa90000007aaaa9997aaaa070aaaaaaa7777770000007aaaaaaaaaaaaaaaaaa99000000
000bb33bb3333bbbb3333333bb33003000000007aaaaa9900000077aaaa9000007aaaa99aa07aaa900000aaaaaaaaaa7900007aaaaaaaaaaaaaaaaa999000000
00bb3bb3333bbb3333333bbbb33bb30b07a07aa7aaaaa9900000777aaaa900007aaaa9990007aaa900700009aaaaaaaaa970aaaaaaaaaaaaaaaaaaa990000000
bbbbbbbbb3bbbbbb33bbbbbbbbbbb33b00000007aaaaa990007777aaaa990007aaaa99900007aaa907770000009997aaa99007aaaa99999999aaaaa990000000
0000044000000000000000000000000000000007aaaaaa777777aaaaaa99007aaaaaa7777777aaa9077a70000000007aaa9007aaaa9900000aaaaaa990000000
00004444400000000000000044000000007aa07aaaaaaaaaaaaaaaaaa99007aaaaaaaaaaaaaaaaa977aaaaaa0000007aaa997aaaaa9900000aaaaaa990000000
00044444f000000000000044444400000000007aaaaaaaaaaaaaaaaa99907aaaaaaaaaaaaaaaaaa97aaaaaaaa777777aaa997aaaa997a07aaaaaaa9990000000
0000444ff000000000000004444440000000007aaaaaaaaaaaaaaaa99907aaaa99999999999aaaa97aaaaaaaaaaaaaaaa9997aaaa9900000aaaaaa9900000000
00000fff00000000000004444444f00077aa7aaaaaaaaaaaaaaaa999977aaaa9990000000007aaa909aaaaaaaaaaaaaaa9907aaaa9907000aaaaaa9900000000
0444fff0000000000000000044fff0ff0aa0aaaaaaaaaaaaaa999797aaaaaa9990a000aaa0a7aaa90099aaaaaaaaaaa9979aaaaaa970007aaaaaaa9900000000
0000ffffff00000000004442ffff0ff0000000099999999999990000009999990000000000009999000099999999999990000999999000000099999900000000
000fff0000000000000040ffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00eee0000000000000000eefff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00eeee00000000000400eeeef0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
022ee8800000000004488eee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
022288ff00000000004f8ee200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04200ff00000000000ff8e2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4400ff00000000000ff0220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4000f000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
40000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007777700000000000000077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077777700000000000007777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007777700000000000000777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000777000000000000077777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770000000000000000077777077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000777777000000000077777777077000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000777000000000000007077777777000ff440000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000077777000000f44400000044000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700000000000700777770000000ff00000000444400000000000044000000000000fff00000000000000000000000000000000000000000000000000000
077777700000000007777777000000004ff8800000444ff000000000004440000000000eeff00000000000000000000000000000000000000000000000000000
0777777700000000007777770000000004f8eeefff444ff000000000000444000000000eefff4000000000eeeff0000000000000000000000000000000000000
077007700000000000777770000000000448eeefff4440f0044000eeff044400000000eeefff440000000eeeefff44000000000eef0f44000000000000000000
770077000000000007707700000000000002eeeffffffff0ff40eeeeffff4400000000eeeeff44000fff88eeffffff00000088eeeffff4000000000000000000
700070000000000007000000000000000000000000ff40000ff488eeffff444000040088e0fff4400000282244fff4ff00fff8eeefffff400000000000000000
70000000000000000700000000000000000000000000000000fff880000fffff00fffff88000ffff0ffff20000444400444448e2244fffff0000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008484000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084848400000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084848484000000000000000000848400000000000084840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084848484000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000008484848400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000008484848484840000000000000000000000000000000000000000000084848484848400000000008484840000008484000084840000848400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000084848484000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
060000000000000a000000000000000b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00110000180531a6002210018053180531d1001805322100180531d1001f100180531805321100180532100018053221002210018053180531805318000180001805318000180001805318053180531800018000
011100000935509345093550934509355093450935509345053550534505355053450535505345053550534502355023450235502345023550234502355023450235502345023550234502355023450235502345
011100001825518235182551823518255182351825518235182551823518255182351825518235182551823515255152351525515235152551523515255152351525515235152551523515255152351525515235
01110000073550734507355073450735507345073550734500355003450035500345003550034500355003450a3550a3450a3550a3450a3550a3450a3550a3450c3550c3450c3550c3450c3550c3450c3550c345
011100001625516235162551623516255162351625516235132551323513255132351325513235132551323511255112351125511235112551123511255112351525515235152551523515255152351525515235
011100000535505345053550534505355053450535505345053550534505355053450535505345053550534505355053450535505345053550534505355053450535505345053550534505355053450535505345
011100001525515235152551523515255152351525515235152551523515255152351525515235152551523515255152351525515235152551523515255152351525515235152551523515255152351525515235
011100001805318003000001805330643180530000018003180530000018003180533063318053306032462318053180530000018053306431805300000180531805300000180530000030633180331805330633
01110000073550734507355073450735507345073550734507355073450735507345093550934509355093450a3550a3450a3550a3450a3550a3450a3550a3450c3300c3000c3300c3000c3300c3000c3300c300
011100001a2551a2351a2551a2351a2551a2351a2551a235132551323513255132351325513235132551323518255182351825518235182551823518255182351523015200152301520015230152001523015200
001100000530505305053050530505305053050530505305391053910500000000000000000000000000000000000000000000000000000000000000000000003911539115000000000000000000000000000000
00110000261602615026150261502615226142261322611524160241502415024150241522414224132241151d1601d1501d1501d1501d1501d1501d1501d1501d1521d1521d1521d1521d1521d1421d1321d115
00110000241602413024115211602115021150211522115221152211522115221152211522114221132211151a1601a1401a1321a1151d1601d1401d1321d115211602114021132211151d1601d1401d1321d115
001100002616026120221602212026160261202916029120211602115021132211151f1601f1501f1321f11521160211201f1601f120211602112024160241201816018150181501815018152181421813218115
001100002616026120221602212026160261202916029120211602114021132211121f1601f1401f1321f1121a1601a1501a1501a1501a1521a1421a1321a1121c1601c1501c1501c1501c1521c1421c1321c112
001100001d1501d1501d1501d1501d1501d1501d1501d1501d1521d1521d1521d1521d1521d1421d1321d1221d1151d1021d1021d10235115351153c1153c11539115391151d1021d1021d1021d1021d1021d102
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
0001000037620376101320011260132601526017260192601a2601b2601c2601c26031620316103f200012003f200012003f200012003f200012003f200012003f200012003f200012003f200012003f20001200
0002000028560295002a5602c5002d5203254036560165000b5001050010500185000d5001250013500135000f500145003f50015500135001550016500165001750017500185001a5001b5001e5002150023500
0002000016610196301c6401a0003f65033650226501c65018630126201a0001a0001a0001a0001a0001a000163411636116361163611534112331103110d330083301a0001a0001a0001a0001a0001a0001a000
0004000014040150611507116071180711d0712c0611d0002600034000053000630026000340000533006341083510a3510c3500e3500f3510f3510f3510f3510f3510e3510c3510b35109341073310532101311
00020000170511a0511e051270512f0513a000370503705037050370403704037030370303702037020370103701037010370103700037000380003800037000330002c0001b000150001500036000340002f000
000100002a63035610233302333000100001001963020610283302833000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
000100003e0103d0303d0403c0403b0203a0203802037020350403303030050306002f60031640316402f6402d6302b62029620226101d6101961012610086100560002600016000c60009600066000260101600
000100000b3500b3000b3500b3500b3500c3000c3500c3500d3500d3500e3500f3000f350113501330013350153501635018350193501c3501f3502235025350293502d350323503f6003f6003f6003f6003f600
000100002e6202e6112e6112e6012e6010f6010b6052e6102e6102e6002e6003160031600316003f600016003f600016003f600016003f600016003f600016003f600016003f600016003f600016003f60001600
000300000537005370053700030005370053700537005370053000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000200003a65039650386503665034650306502d65029650246501e6501865001650026001e600000001960013600086000160000000000000000000000000000000000000000000000000000000000000000000
__music__
01 01024a00
00 01024500
00 03044a00
00 05064300
01 01024a07
00 01024a07
00 08094a07
00 05060b07
00 01020c07
00 01020c07
00 03040d07
00 03040e07
00 03040d07
00 03040e07
02 05060f07

