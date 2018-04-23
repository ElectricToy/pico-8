pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- game title here
-- by jeff and liam wofford
-- http://www.electrictoy.co

-->8
-- general utilities

debug_lines = {}
function debug_print( text )
	add( debug_lines, text )

	while #debug_lines > 10 do
		del_index( debug_lines, 1 )
	end
end

function draw_debug_lines()
	for i = 1, #debug_lines do
		local line = debug_lines[ #debug_lines - i + 1 ]
		print( line, 2, 7 * i, rel_color( 8, 1 - i ) )
	end
	print( '', 0, (#debug_lines+1) *7 )
end

local current_level = nil
local crafting_ui = nil
local inventory_display = nil


function establish( value, default )
	if value == nil then return default end
	return value
end

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

	if change == 0 then
		return base
	elseif change > 0 then
		return rel_color( brighten_table[base+1], change - 1 )
	else
		return rel_color(   darken_table[base+1], change + 1 )
	end
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

	function new_class:isa( theclass )
		local b_isa = false

		local cur_class = new_class

		while nil ~= cur_class do
			if cur_class == theclass then
				b_isa = true
				break
			else
				cur_class = cur_class:superclass()
			end
		end

		return b_isa
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

function mapsegment:update()
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
		depth = 0,
		offset = vector:new(),
		collision_size = vector:new( establish( wid, 0 ), establish( hgt, 0 )),
		collision_planes_inc = 1,
		collision_planes_exc = 15,
		do_dynamics = false,
		landed_tick = nil,
		does_collide_with_ground = true,
		gravity_scalar = 1.0,
		jumpforce = 3,
		animations = {},
		current_animation_name = nil,
		flipx = false,
		flipy = false,
		damage = 2,
		parallaxslide = 0,
		deathcolorshift = -1,
		colorshift = 0,
		flashamount = 0,
		flashhertz = 6,
		floatbobamplitude = 0,
		floatbobfrequency = 1.2,
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
	return self.tick_count / 60.0
end

function actor:may_collide( other )
	return  self.active
			and other.active
			and 0 ~= band( self.collision_planes_inc, other.collision_planes_inc )
			and 0 == band( self.collision_planes_exc, other.collision_planes_exc )
end

function actor:collision_ul()
	return self.pos
end

function actor:collision_br()
	return self:collision_ul() + self.collision_size
end

function actor:collision_center()
	return self:collision_ul() + self.collision_size * vector:new( 0.5 )
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

	self.tick_count += 1

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

	self.pos.x += self.parallaxslide * self.level.player.vel.x

	local liveleft, liveright = self.level:live_actor_span()
	if self:collision_br().x + 8 < liveleft then
		self.active = false
	end

	if self.vel.x > 0 and self:collision_ul().x > liveright then
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
	return self.landed_tick ~= nil and self.level.tick_count - self.landed_tick < 2
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
			if drawscalex == 1 and drawscaley == 1 then
				spr( frame, drawpos.x, drawpos.y, anim.ssizex, anim.ssizey, self.flipx, self.flipy )
			else
				local spritesheetleft = frame % 16 * 8
				local spritesheettop  = flr( frame / 16 ) * 8
				local spritesheetwid = anim.ssizex * 8
				local spritesheethgt = anim.ssizey * 8
				sspr( spritesheetleft, spritesheettop, spritesheetwid, spritesheethgt,
					  drawpos.x, drawpos.y, drawscalex * anim.ssizex * 8, drawscaley * anim.ssizey * 8, self.flipx, self.flipy )
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
	local o = actor:new( level, 0, -64, 8, 14 )
	o.immortal = false
	o.do_dynamics = true
	o.depth = -100
	o.vel.x = 1
	o.animations[ 'run' ] = animation:new( 32, 6, 1, 2 )
	o.animations[ 'run_armor' ] = animation:new( 38, 6, 1, 2 )
	o.current_animation_name = 'run'
	o.collision_planes_exc = 0


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
	if self:dead() then return end
	self.satiation -= amount

	if self.satiation < 0 then
		self.satiation = 0
		self:die( 'died from hunger' )
	end
end

function player:jump( amount )
	local jumped = self:superclass().jump( self, amount )

	if jumped then
		self:drain_satiation( 0.01 )
		self.jump_count += 1
	end

	return jumped
end

function player:update( deltatime )
	self:superclass().update( self, deltatime )

	local creatures = self.level:actors_of_class( creature )
	for creature in all( creatures ) do
		self:maybe_shoot( creature )
	end

	self:drain_satiation( 0.001 + ( self.armor > 0 and 0.0005 or 0 ))

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

function player:grab()
	if self:dead() then return end

	local pickup, distsqr = self.level:closest_actor( self:collision_center(), function(actor)
		return actor.may_player_pickup
	end )

	if pickup ~= nil and
		( rects_overlap( self:collision_rect(), pickup:collision_rect() )
			or is_close( self:collision_center(), pickup:collision_center(), self.reach_distance )) then
		pickup:on_pickedup_by( self )
	sfx(33)
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
	local o = actor:new( level, x, -10, 6, 6 )     -- todo randomize height somewhat

	local sprite = item.sprite

	o.itemname = itemname
	o.item = item
	o.animations[ 'idle' ] = animation:new( sprite )
	o.current_animation_name = 'idle'
	o.collision_planes_inc = 1
	o.may_player_pickup = true
	o.damage = 0
	o.floatbobamplitude = 1

	local swirl = animation:new( 25, 7, 1, 1 )
	swirl.style = 'stop'
	swirl.frames = { 25, 26, 27, 28, 29, 30, 31, 61 }
	o.animations[ 'pickup' ] = swirl

	return setmetatable( o, self )
end

function pickup:on_collision( other )
	self:on_pickedup_by( other )

	if true then	-- todo
		self:superclass().on_collision( self, other )
	end
end

function pickup:on_pickedup_by( other )
	self.level.inventory:acquire( self.itemname )

	self:superclass().on_pickedup_by( self, other )
end

local items = {
	rawmeat = {
		name = 'raw meat',
		sprite = 19,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 2 )
		end
	},
	mushroom = {
		name = 'a mushroom',
		sprite = 20,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 4 )
		end
	},
	wheat = {
		name = 'wheat',
		sprite = 21,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 4 )
		end
	},
	stick = {
		name = 'a stick',
		sprite = 22,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 4 )
		end
	},
	oil = {
		name = 'oil',
		sprite = 23,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 4 )
		end
	},
	metal = {
		name = 'metal',
		sprite = 24,
		showinv = true,
		shoulddrop = function(level)
			return pctchance( 4 )
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
			-- todo prevent re-creating?
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
			level.player.armor = level.player.max_armor
		end
	},
	cookedmeat = {
		name = 'cooked meat',
		sprite = 10,
		requirements = { rawmeat = 1, torch = 1 },
		oncreated = function(level)
			level.player:heal( 2 )
			level.player:eat( 6 )
		end
	},
	stew = {
		name = 'stew',
		sprite = 11,
		requirements = { mushroom = 5, rawmeat = 3 },
		oncreated = function(level)
			level.player.max_satiation = min( level.player.max_satiation + 2, 12 )
			level.player.satiation = level.player.max_satiation
		end
	},
	pizza = {
		name = 'pizza',
		sprite = 12,
		requirements = { wheat = 3, mushroom = 3 },
		oncreated = function(level)
			level.player.max_health = min( level.player.max_health + 2, 16 )
			level.player:heal( 6 )
			level.player:eat( 2 )
		end
	},
	torch = {
		name = 'a torch',
		sprite = 15,
		showinv = true,
		requirements = { oil = 1, stick = 2 },
		oncreated = function(level)
			level.inventory:acquire( 'torch' )
		end
	},

	home = { sprite = 74 },
}

local inventory = inheritsfrom( nil )
function inventory:new()
	local o = {
		itemcounts = {}
	}
	return setmetatable( o, self )
end

function inventory:item_count( type )
	return establish( self.itemcounts[ type ], 0 )
end

function inventory:acquire( type )

	if not self.itemcounts[ type ] then
		self.itemcounts[ type ] = 0
	end

	if self.itemcounts[ type ] < 9 then
		self.itemcounts[ type ] += 1
		message( 'got ' .. items[ type ].name )

		local gaineditems = {}
		gaineditems[ type ] = items[ type ]
		inventory_display:on_gained( gaineditems )
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
		ground_decorations = {},
		horizon_decorations = {},
		tick_count = 0,
		pending_calls = {},
		inventory = inventory,
	}
	o.creation_records = {
		coin     = { chance =   100, earliestnext =   64, interval = 16, predicate = function() return sin( o:time() / 3 ) * sin( o:time() / 11 ) > 0.25 end },
		stone    = { chance =   0.5, earliestnext =   64, interval = 48, predicate = function() return ( #o:actors_of_class( creature ) == 0 ) or pctchance( 0.1 ) end  },
		tree     = { chance =    1, earliestnext = -100, interval = 0, predicate = function() return #o.actors < 10 end },
		shrub    = { chance =    1, earliestnext = -100, interval = 0, predicate = function() return #o.actors < 10 end  },
		creature = { chance =    0.25, earliestnext = 256, interval = 256, predicate = function() return #o:actors_of_class( creature ) == 0 end },
		material = { chance =   80, earliestnext = 64, interval = 24 },
	}

	local finishedobject = setmetatable( o, self )

	finishedobject.player = player:new( finishedobject )

	return finishedobject
end

function level:time()
	return self.tick_count / 60.0
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
	for actor in all( self.actors ) do
		if actor.active and ( class == nil or getmetatable( actor ) == class ) then
			add( arr, actor )
		end
	end
	return arr
end

function level:closest_actor( pos, filter )
	local closest = nil
	local closest_dist_sqr = nil

	for actor in all( self.actors ) do
		if actor.active and filter( actor ) and is_close( actor.pos, pos, 180 ) then
			local distsqr = ( actor.pos - pos ):lengthsquared()
			if closest_dist_sqr == nil or distsqr < closest_dist_sqr then
				closest = actor
				closest_dist_sqr = distsqr
			end
		end
	end

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
	for actor in all( self.actors ) do
		if actor.active then
			apply( actor )
		end
	end
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
		for segment in all( self.mapsegments ) do
			local collision = segment:colliding_tile( self.player )
			if collision ~= nil and footheight < collision.y + 4 then
				self.player.pos.y = collision.y - self.player.collision_size.y
				self.player:landed()
			end
		end
	end
end

function level:update()

	local deltatime = 1.0 / 60.0

	self.tick_count += 1

	self:update_pending_calls()

	self:maybe_create( creature, 'creature' )

	if self.player.alive then
		self:create_props()
		self:update_mapsegments()
	end

	self:update_collision()

	erase_elements( self.actors, function(actor)
		actor:update( deltatime )
		return not actor.active
	end)

	sort( self.actors, function( a, b )
		return a.depth < b.depth
	end )
end

function level:camera_pos()
	return vector:new( -64, -96 ) + vector:new( self.player.pos.x + 32, 0 )
end

function level:timeofday()
	return 0.5 + sin( self:time() / 50 ) * 0.5
end

function level:categoricaltimeofday()
	local thetime = self:timeofday()
	return thetime < 0.7 and 1 or ( thetime < 0.9 and 2 or 3 )
end

function level:draw()

	local cam = self:camera_pos()

	camera( 0, cam.y )

	local thetime = self:timeofday()
	local categoricaltime = self:categoricaltimeofday()

	function drawgrass()
		camera( 0, cam.y)
		rectfill( 0, 0, 128, 32, 3 )
		line( 0, 0, 128, 0, 0 )
	end

	rectfill( 0, -96, 128, 0, 12 )

	camera( cam.x, cam.y )

	self:eachactor( function( actor )
		if actor.depth > 0 then
			actor:draw()
		end
	end )

	drawgrass()

	camera( cam.x, cam.y )

	for segment in all( self.mapsegments ) do
		segment:draw()
	end

	self:eachactor( function( actor )
		if actor.depth <= 0 then
			actor:draw()
		end
	end )
end

local behaviors = {}

function creature:new( level, x )
	local whichcreature = rand_int( 1, 2 )

	local y = -16
	local wid = 16
	local hgt = 7

	local o = actor:new( level, x, y, wid, hgt )
	o.do_dynamics = true
	o.depth = -10
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
		for i = 1,4 do
			spr( 88, drawpos.x - 8*i, drawpos.y )
		end
	end
end

local stone = inheritsfrom( actor )
function stone:new( level, x )
	local size = rand_int( 1, 3 )

	local sprite = { 185, 167, 164 }
	local spritewidth =  { 1, 2, 3 }
	local spriteheight = { 1, 2, 2 }
	local spriteoffsetx = { -1, -4, -4 }
	local spriteoffsety = { -1, -2, -2 }
	local collisionwid = { 6, 12, 16 }
	local collisionhgt = { 6, 12, 12 }
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
	self:superclass().on_collision( self, other )
end

function coin:on_pickedup_by( other )
	other:add_coins( self.value )
	self.value = 0
	self:superclass().on_pickedup_by( self, other )
end

local tree = inheritsfrom( actor )
function tree:new( level, x )
	local scale = randinrange( 2, 4 )
	local o = actor:new( level, x, -14 * scale, scale * 2 * 8, scale * 8 )
	o.flipx = pctchance( 50 )
	o.animations[ 'idle' ] = animation:new( 128, 1, 1, 2 )
	o.current_animation_name = 'idle'
	o.collision_planes_inc = 0
	o.damage = 0
	o.parallaxslide = randinrange( 0.5, 8.0 ) / (scale*scale)
	o.depth = o.parallaxslide * 10
	o.animations[ 'idle' ].drawscalex = scale
	o.animations[ 'idle' ].drawscaley = scale

	return setmetatable( o, self )
end

local shrub = inheritsfrom( actor )
function shrub:new( level, x )
	local scale = randinrange( 1, 2 )
	local o = actor:new( level, x, 32 - 16 * scale, scale * 4 * 8, scale * 2 * 8 )
	o.flipx = pctchance( 33 )
	o.animations[ 'idle' ] = animation:new( 160, 1, 4, 2 )
	o.current_animation_name = 'idle'
	o.collision_planes_inc = 0
	o.damage = 0
	o.parallaxslide = -randinrange( 0.5, 1 ) / scale
	o.depth = o.parallaxslide * 10
	o.animations[ 'idle' ].drawscalex = scale
	o.animations[ 'idle' ].drawscaley = scale

	return setmetatable( o, self )
end


function level:maybe_create( class, classname )
	local _, liveright = self:live_actor_span()
	local creation_point = liveright - 2

	local record = self.creation_records[ classname ]
	if record.earliestnext < creation_point
		and ( record.predicate == nil or record.predicate() )
		and pctchance( record.chance ) then
		local obj = class:new( self, creation_point )
		record.earliestnext = creation_point + record.interval
		return obj
	end
	return nil
end


function level:create_props()
	local _, liveright = self:live_actor_span()

	self:maybe_create( stone, 'stone' )
	self:maybe_create( tree, 'tree' )
	self:maybe_create( shrub, 'shrub' )
	self:maybe_create( coin, 'coin' )

	local _, liveright = self:live_actor_span()
	local creation_point = liveright - 2

	local record = self.creation_records[ 'material' ]
	if record.earliestnext < creation_point then
		for itemname, type in pairs( items ) do
			if type.shoulddrop ~= nil then
				if type.shoulddrop( self ) then
					local pickup = pickup:new( self, itemname, type, liveright - 2, type.sprite )
				end
			end
		end
		record.earliestnext = creation_point + record.interval
	end
end

function world_to_mapsegment_cell_x( x )
	return flr( x / maptoworld( mapsegment_tile_size.x ) )
end

function level:update_mapsegments()
	local left, right = self:viewspan()

	erase_elements( self.mapsegments, function(segment)
		segment:update()
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

function inventorydisplay:update()
end

function inventorydisplay:highlight_items( items )
	self.flashstarttime = self.level:time()
	self.highlighted_items = items
end

function inventorydisplay:on_gained( items )
	self.item_use_message = ''
	self:highlight_items( items )
end

function inventorydisplay:on_used( items )
	self.item_use_message = 'used:'
	self:highlight_items( items )
end

function inventorydisplay:on_tried_to_use( items )
	self.item_use_message = 'need:'
	self:highlight_items( items )
end

function inventorydisplay:draw()

	local left = 54
	local top = 128 - 2 - 9 - 6
	local i = 0
	local now = self.level:time()

	local colorshift = 0 
	if self.flashstarttime ~= nil and now < self.flashstarttime + flashduration then
		colorshift = flicker( now, 2 ) and 8 or 0
	end

	for itemname, item in pairs( items ) do
		if item.showinv then
			local x = left + i * 9

			draw_color_shifted( self.highlighted_items[ itemname ] ~= nil and colorshift or 0, function()
				spr( item.sprite, x, top )
				
				local count = self.level.inventory:item_count( itemname )
				
				draw_shadowed( x + 2, top + 9, 0, 1, 2, function(x,y)
					print( '' .. count, x, y, 12 )
				end )
			end )

			i += 1
		end
	end

	-- show needs/used
	draw_color_shifted( colorshift, function()
		draw_shadowed( 40, top, 0, 1, 2, function(x,y)
			print_centered_text( self.item_use_message, x, y, 14 )
		end )		
	end )
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
	return self.tick_count / 60.0
end

function crafting:update()
	self.tick_count += 1

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

	draw_shadowed( rootbasis.x, rootbasis.y, 0, 1, 2, function(x,y,col)
		print( '⬅️', x - 10, y, 8 )
		print( '➡️', x + 10, y, 9 )
		print( '⬆️', x, y - 10, 10 )

		if self.activated ~= self.rootthingy then
			print( '⬇️', x, y + 10, 11 )
		end
	end )

	if self.activated == self.rootthingy then
		draw_shadowed( rootbasis.x + 4, rootbasis.y + 12, 0, 1, 2, function(x,y)
			print_centered_text( 'craft', x, y, 4 )
		end )
	end
end

function thingy:new( crafting, parent, item_config )
	local o = {
		crafting = crafting,
		parent = parent,
		item = items[ item_config.item ],
		sprite = item_config.item ~= nil and items[ item_config.item ].sprite or nil,
		children = {},
		pos = vector:new( 0, 0 ),
		destination = nil,
		lerpspeed = 0.25,
		flashstarttime = nil,
		flashendtime = nil,
	}

	local configchildren = item_config.children
	for child in all( configchildren ) do
		add( o.children, thingy:new( crafting, o, child ) )
	end

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
		if basecolorshift == 0 and not self:recursively_usable() then
			basecolorshift = 1
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
	for child in all( self.children ) do
		child:draw( basepos, activatedonly )
	end
end

function thingy:child_index( child )
	for i = 1, #self.children do
		if child == self.children[ i ] then
			return i
		end
	end
	return nil
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

	for child in all( self.children ) do
		child:update()
	end
end

function thingy:expand( parentindex, myindex )
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
		for child in all( self.children ) do
			child:collapse( recursive )
		end
	end
end

function thingy:activate()
	if not self:available() then
		self:flash( 0.05 )
		self.crafting:on_activating_item( self, true )
		inventory_display:on_tried_to_use( self.item.requirements )
		return
	end

	self.crafting:on_activating( self )

	local flashduration = 0.25

	if self.parent ~= nil and #self.children == 0 and self.item ~= nil then
		-- have the requirements?
		for itemname, count in pairs( self.item.requirements ) do
			if count > self.crafting.level.inventory:item_count( itemname ) then
				debug_print( 'failed ' .. itemname)
				inventory_display:on_tried_to_use( self.item.requirements )
				return false
			end
		end

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

	else
		self.crafting:on_activating_item( self, false )

		self.destination = vector:new( 0, 0 )

		flashduration = 0.15
		local myindex = (self.parent ~= nil ) and self.parent:child_index( self ) or 0

		for i = 1, #self.children do
			local child = self.children[ i ]

			child:expand( myindex, i )
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
				for child in all( self.children ) do
					if activated_child ~= child then
						child:collapse()
					end
				end
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
local current_level = nil

function restart_world()
	current_level = level:new( inventory:new() )
	crafting_ui = crafting:new( current_level, vector:new( 96, 2 + thingy_spacing + 2 ))
	inventory_display = inventorydisplay:new( current_level )

	game_state = 'playing'
end

function player_run_distance()
	return flr(( current_level.player.pos.x - 0 ) / 40 )
end

function deltafromplayer( actor )
	return actor.pos.x - current_level.player.pos.x
end

tidy_map()
restart_world()

--main loops
function _update60()

	update_buttons()

	if game_state == 'playing' then
		function update_input()
			local player = current_level.player
			if wentdown(4) or wentdown(5) then
				player:jump()
			end

			crafting_ui:update()
			inventory_display:update()

			-- manual movement
			if false then
				local move = 0
				if isdown( 0 ) then
					move += -1
				end
				if isdown( 1 ) then
					move += 1
				end
				player.vel.x = move
			end
		end


		if current_level.player:dead() then
			game_state = 'gameover_dying'
			current_level:after_delay( 2.0, function()
				game_state = 'gameover'
			end )
		else
			update_input()
		end

	elseif game_state == 'gameover' or game_state == 'title' then

		if wentdown( 4 ) or wentdown( 5 ) then
			restart_world()
		end
	end

	if current_level ~= nil then
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

function draw_shadowed( x, y, offsetx, offsety, darkness, fn )
	draw_color_shifted( -darkness, function()
		fn( x + offsetx, y + offsety )
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
		local player = current_level.player

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
					spr( sprite, left + x, top )
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


		draw_halveable_stat( iconleft, iconsy, player.health, player.max_health, 1, 2, 3 )
		draw_shadowed( 2, iconsy + 1, 0, 1, 1, function(x,y)
			print( 'life', x, y, 8 )
		end )
		iconsy += 9

		draw_fullicon_stat( iconleft, iconsy, player.armor, player.max_armor, 7, 8 )
		draw_shadowed( 6, iconsy + 1, 0, 1, 1, function(x,y)
			print( 'def', x, y, 13 )
		end )
		iconsy += 9

		draw_halveable_stat( iconleft, iconsy, player.satiation, player.max_satiation, 4, 5, 6 )
		draw_shadowed( 2, iconsy + 1, 0, 1, 1, function(x,y)
			print( 'food', x, y, 9 )
		end )

		iconsy += 9

		draw_shadowed( 2, 128 - 2 - 6, 0, 1, 2, function(x,y)
			print( 'gold ' .. player.coins, x, y, 10 )
		end )

		iconsy += 9

		crafting_ui:draw()
		inventory_display:draw()

		if player.jump_count == 0 then
			draw_shadowed( 64, 54, 0, 1, 2, function(x,y)
				print_centered_text( 'press z to jump!', x, y, 8 )
			end )
		end

		draw_shadowed( 90, 128-28, 0, 1, 2, function(x,y)
			print_centered_text( curmessage(), x, y, 12 )
		end )

	end

	function draw_ui_title()
		-- todo
	end

	function draw_ui_gameover()
		-- todo
		draw_shadowed( 64, 64, 0, 1, 2, function(x,y)
			print_centered_text( current_level.player.deathcause, x, y, 8 )
		end )
	end

	function draw_ui_gameover_fully()
		draw_ui_gameover()

		draw_shadowed( 64, 0, 0, 1, 2, function(x,y)
			print_centered_text( 'play again? z/x', x, y + 102, 12 )

			print_centered_text( 'coins: ' .. current_level.player.coins, x, y + 34, 11 )
		end )

	end

	if game_state == 'playing' then
		draw_ui_playing()
	elseif game_state == 'title' then
		draw_ui_title()
	elseif game_state == 'gameover_dying' then
		draw_ui_gameover()
	elseif game_state == 'gameover' then
		draw_ui_gameover_fully()
	end


	if false then
		draw_shadowed( 124, 2, 0, 1, 2, function(x,y)
			print_rightaligned_text( 'actors: ' .. #current_level.actors, x, y, 6 )
			y += 8
			print_rightaligned_text( 'segmts: ' .. #current_level.mapsegments, x, y, 6 )
			y += 8
			print_rightaligned_text( 'creats: ' .. #current_level:actors_of_class( creature ), x, y, 6 )
			y += 8
			print_rightaligned_text( 'coins : ' .. #current_level:actors_of_class( coin ), x, y, 6 )
			y += 8
		end )
	end
end

function _draw()

	current_level:draw()
	camera( 0, 0 )
	draw_ui()
	draw_debug_lines()
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
	actor.vel.x = current_level.player.vel.x * speedscale
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
			actor.flipx = true
		end,
	slide_left_fast =
		function(actor)
			actor.flipx = true
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
			actor.flipx = false
			set_player_relative_velocity( actor, 1.5 )
			while deltafromplayer( actor ) < -24 do
				yield()
			end
			set_player_relative_velocity( actor, 0.9 )
			wait( 0.2 )
			standard_attack_warning( actor )
			set_player_relative_velocity( actor, 4 )
		end,
	pounce_from_left =
		function(actor)
			local maxpounces = 3    -- todo based on level age
			local restpos = -32

			local numpounces = rand_int( 1, maxpounces )

			actor.pos.x = stage_left_appear_pos()
			actor.flipx = false
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
00777000008b80000aa0000067e00000007cc0000a7a9000044b30000000dd000077700000000000000700000007000000070000000700000007006000000060
07aaaa000878820009a000000eee000007cccd0009a9aa000045300000777d100766660000000000000000000007000000777000000700700000007000000070
0aaaaa000888820009aa00000eee20000ccccd007a9a4a000004400007dddd100666660070070070770707700777770007707700077077000700070000000000
09aaa90008822200009aa940002220000cccdd000aa4a490000055000dddd1100d666d0000000000000000000007000000777000700700007000000070000000
0099900000222000000444000000dd0000f4400000994900000005000011110000ddd00000000000000700000007000000070000000700006007000060000000
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
000eee0000eee00000eee200000eee0000eee000000eee00000ddd0000ddd00000ddd100000ddd0000ddd000000ddd0010100000000000005111111111500000
000eee2000eee20000eeee20000eeee000eeee00002eeee0000766d0007661000076661000076660007666000017666011000000000000005111111111500000
000ee82008ee222000eeee80000ee880022ee880002eee80000666d0076611d00066666000066660011666600016666010100000000000000555555555000000
00088840088e0244fff888800002e8f0022288ff4442e880000666d007660ddddd76666000017660011167661111676001000000000000000000000000000000
0044f4400f80044000ffff4000fffff004200ff0004448f0001176d006600dd0006666d000ddd6600d10066000ddd66010000000000000000000000000000000
0000f000ff00440000000040000040004400ff00000000f000006000d6001100000000d0000010001d00dd000000006001000000000000000000000000000000
0000f000f000400000000040000040004000f000000000f00000d000d000100000000010000010001000d000000000d010000000000000000000000000000000
0000ff00f0000000000000440000440040000000000000ff0000dd00d0000000000000110000110010000000000000dd01000000000000000000000000000000
800000000088a8a0000000000000000000000000088a8a0000000000000000000000000000000000000400000000000000000000000000000000000000000000
8822800000088882002280000088a8a0000288000088882000000000000000000000000000000000004140000000000000000000000000000000000000000000
08282282002888800882828800088882088288280822880000000000000000000000000000000000041424000000000000000000000000000000000000000000
00082882828228000800088222822280880008282288200000000000000000000000000000000000414442400000000000000000000000000000000000000000
00028882828882200080028282888800000000882828820000000000000000000000000000000000014442000000000000000000000000000000000000000000
00288882882828220000002888288000000000828828822200000000000000000000000000000000044144000000000000000000000000000000000000000000
02888000882808820000000082280000000000822088888200000000000000000000000000000000022122000000000000000000000000000000000000000000
88800000000000800000000002080000000000880000008000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000300030003000000000000000000000000000000000000000000000000000000000000000000000
00000000000053500000000000000000000000000000000003550533035133500000000000000000000000000000000000000000000000000000000000000000
0053530000035a53000053530000000050000053530000000553035505515a530000000000000000000000000000000000000000000000000000000000000000
03535350005353330003535350005350530003535350000013551533135553330000000000005353000000000000000000000000000000000000000000000000
53599353035390005053599353035a53535053599353000015131315151530005535535335535a57000000000000000000000000000000000000000000000000
53900953535900005353900953535333935353900953535013151513131330005335335335335307000000000000000000000000000000000000000000000000
590000935390000053590000935390000953590000935a5353035303530390005335335335339000000000000000000000000000000000000000000000000000
90000009990000009990000009990000009990000009933399099909990990009999999999990330000000000000000000000000000000000000000000000000
000cdc0dd0000000000cdc0dd0000000000cdc0dd0000000dcc0011d000000000000000000000000000000000000000000000000000000000000000000000000
00c11ddccdc0000000c11ddccdc0000000c11ddccdc000001c0dcdaa100000000000000000000000000000000000000000000000000000000000000000000000
0cddaa1dccc100000cddaa1dccc100000cddaa1dccc10000cd0ccd11110000000000000000000000000000000000000000000000000000000000000000000000
ccc1111ccccc1000ccc1111ccccc1000ccc1111ccccc1000cc10cdccdc1000000000000000000000000000000000000000000000000000000000000000000000
dcdccc1cdcdc1100dcdccc1cdcdc1100dcdccc1cdcdc11000cc11c1cccc100000000000000000000000000000000000000000000000000000000000000000000
0ccccdccccccc1100ccccdccccccc1100ccccdccccccc1100cd11cccdcc110000000000000000000000000000000000000000000000000000000000000000000
ccdcccccdccdcd10ccdcccccdccdcd10ccdcccccdccdcd1000cccdc1c1dc11000000000000000000000000000000000000000000000000000000000000000000
c11cdcdccccccc11c11cdcdccccccc11c11cdcdccccccc11000dcc11dcccc1000000000000000000000000000000000000000000000000000000000000000000
00011cc1c1dccc110001ccc1c1dccc11001cccc1c1dccc110000111cccdcd1100000000000000000000000000000000000000000000000000000000000000000
0000111c11ccdd110000c11c1cccdd1101ccc11c1cccdd11000011cccd1cd1110000000000000000000000000000000000000000000000000000000000000000
0000001c11cdccc100001c1c1ccdccc101cccc1c1ccdccc1000001111ccccc100000000000000000000000000000000000000000000000000000000000000000
000000d111dccd11000001d1ccdccd1101ccc1d1ccdccd11000000011cdcd1000000000000000000000000000000000000000000000000000000000000000000
000000c100dcc111000000c1ccdcc1110cccc1c1ccdcc1110000000001ccc1100000000000000000000000000000000000000000000000000000000000000000
00000cc111c1111100000cc111c1111101ccccc111c1111100000000001ccc100000000000000000000000000000000000000000000000000000000000000000
00001c11ccc1111000001c11ccc11110001c1c11ccc11110000000000000cdc00000000000000000000000000000000000000000000000000000000000000000
001ccdcc11111110001ccdcc11111110001ccdcc111111100000000000001c110000000000000000000000000000000000000000000000000000000000000000
000b000000000b00000b0000dddd0000111111110111111111111000011110000000000000000000000000000000000000000000000000000000000000000000
0b3bb0000000bb3b000bb0006666ddddbb33bb331bb3bb33bb3335001bb335000000000000000000000000000000000000000000000000000000000000000000
00b3bb00000bb3b000b3b00066666666111111111b331111111111101b3311100000000000000000000000000000000000000000000000000000000000000000
b3b33bb000b333bb0b3b3b006666666633bb33bb13bb33bb33bbb35113bbb3510000000000000000000000000000000000000000000000000000000000000000
0b3bb33b0b0bbb300033b0006666666633bb33bb133b33bb33bbb351133bb3510000000000000000000000000000000000000000000000000000000000000000
00b33b0000b33300003b000066666666bb33bb331533bb33bb333b3115333b310000000000000000000000000000000000000000000000000000000000000000
0b3bb300bb3bbbbb0bb5000066666666335533550115335533555331011553310000000000000000000000000000000000000000000000000000000000000000
00b3bbb000b333b00004000066666666111111110011111111111110001111100000000000000000000000000000000000000000000000000000000000000000
bb3b300000005b300000000066666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b33bb00000bb3000000000066666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bb30000bb33bbb0000000066666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005bbb0000bb3300000000066666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005000000b35bbb0000000066666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000000050000000000066666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000000400000000000dddd6666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000004000000000000000dddd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000bbb00000000000004000000000000000000000440000000000000000000000000000000000000000000000000000000000000000000
00000000000000b00000bbbbbbbb0000000004000400000004400000000044600000000000000000000000000000000000000000000000000000000000000000
0000000000b00bb0000bb33bbb000000000044400440000044000000044644666440044000000000000000000000000000000000000000000000000000000000
0000000000bbb33000bbbbbbb000000000000444d446640440000000044461164400440000000000000000000000000000000000000000000000000000000000
0000000000bb33030bbbb3300000000000004d446444644440000000004446d14661400000000000000000000000000000000000000000000000000000000000
000000000bb33000bbb33030bbbbbbb04400d6441644644600400000006411d11dd1100000000000000000000000000000000000000000000000000000000000
00000000bbb3300bbb33000bbbbb0000044464611d11d44d0040000000661ddddddd444000000000000000000000000000000000000000000000000000000000
00000000bbb3bbbbb3300bbbbbb0000000444444dddd44dd0044000044446dddddd4440000000000000000000000000000000000000000000000000000000000
0000000bbb33bbbb3333bbbbbb0b0000000441d441dd14dd404400000044441ddd11dd0000000000000000000000000000000000000000000000000000000000
000000bbbb3bbbb333bbbbbbb00b000000d611dd11dd11d4444000040066411dddddddd004040040000000000000000000000000000000000000000000000000
000000bbb3bbb3333bbbbbb3330bbbbb4066644ddddddd44d44ddd444446ddddddddddd000626660000000000000000000000000000000000000000000000000
00000bbbbbb3333bbbbbb33000bbbb0044466d41ddddd144d14dd4400441dddddddddddd46d55456000000000000000000000000000000000000000000000000
0000bb3bbbbbbbbbbbbb3300bbbbb00004441d11ddddd11dd11d14d00611dddddddddddd02655211000000000000000000000000000000000000000000000000
000bb33bb3333bbbb3333333bb33003000611ddddddddddddddd11dd0666dddddddddddd6d5d1511000000000000000000000000000000000000000000000000
00bb3bb3333bbb3333333bbbb33bb30b0666dddddddddddddddddddd006dddddddddddd015151111000000000000000000000000000000000000000000000000
bbbbbbbbb3bbbbbb33bbbbbbbbbbb33b0000dddddddddddddd00000000000dddddddd00011511110000000000000000000000000000000000000000000000000
00000440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00004444400000000000000044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00044444f00000000000004444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000444ff00000000000000444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000fff00000000000004444444f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0444fff0000000000000000044fff0ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ffffff00000000004442ffff0ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
000100002a63035610233402334000100001001963020610283402834000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
000100003f6103f6203d6303d6403c6503b6303a62039620386203762035630346303364032640316502f6502d6402b640296302765023630206301e6201a62016620136300f6300c63009630066200262101620
000100000b3500b3000b3500b3500b3500c3000c3500c3500d3500d3500e3500f3000f350113501330013350153501635018350193501c3501f3502235025350293502d350323503f6003f6003f6003f6003f600
000100002e6202e6112e6112e6112e6010f6010b6052e6102e6102e6002e6003160031600316003f600016003f600016003f600016003f600016003f600016003f600016003f600016003f600016003f60001600
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

