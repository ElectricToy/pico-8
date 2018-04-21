pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- todo game title here
-- by jeff and liam wofford 
-- http://www.electrictoy.co

-->8
-- general utilities

debug_text = ''
function debug_print( text )
    debug_text = text
end

-- see http://lua-users.org/wiki/CopyTable
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

function dither_color( base, dither )
    return bor( base, shl( dither, 4 ))
end

function del_index( table, index )
    del( table, table[ index ])
end

function range_to_array( min, maxexclusive )
    arr = {}

    if min == nil or maxexclusive == nil then return arr end

    for i = 0, maxexclusive - min - 1 do
        arr[ i + 1 ] = min + i
    end
    return arr
end

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
    assert( max >= min )
    return min + rnd( max - min )
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
-->8
--systems

function rects_overlap( recta, rectb )
    function edges_overlap( la, ra, lb, rb )
        return not (
                la > rb or
                ra < lb
            )
    end

    return  edges_overlap( recta.x, recta.x + recta.w, rectb.x, rectb.x + rectb.w )
        and edges_overlap( recta.y, recta.y + recta.h, rectb.y, rectb.y + rectb.h )
end

-- level

local level = inheritsfrom( nil )
function level:new()
    local newobj = { 
        actors = {},
        ground_decorations = {},
        horizon_decorations = {},
        tick_count = 0,
        pending_calls = {},
        player = nil,
    }
    return setmetatable( newobj, self )
end

function level:time()
    return self.tick_count / 60.0
end

function level:after_delay( delay, fn )
    add( self.pending_calls, { deadline = self:time() + delay, fn = fn } )
end

function level:update_pending_calls()
    local now = self:time()

    for call in all( self.pending_calls ) do
        if now >= call.deadline then
            call.fn()
            del( self.pending_calls, call )
        end
    end
end

function level:eachactor( apply )
    for actor in all( self.actors ) do
        if actor.alive then
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
    for i = 1, count(self.actors) - 1 do
        for j = i + 1, count(self.actors) do
            update_actor_collision( self.actors[ i ], self.actors[ j ])
        end
    end
end

function level:update()

    local deltatime = 1.0 / 60.0

    self.tick_count += 1

    self:update_pending_calls()

    self:update_props()

    self:update_collision()

    -- update actors and remove dead ones
    for actor in all( self.actors ) do
        actor:update( deltatime )
        if not actor.alive then
            del( self.actors, actor )
        end
    end    
end

function level:camera_position()
    return vector:new( -64, -96 ) + vector:new( 32 + self.player.pos.x, 0 )
end

function level:draw()

    local cam = self:camera_position()

    cls( 3 )

    -- draw background
    camera( 0, cam.y )

    fillp( 0b1010010110100101 )
    rectfill( 0, cam.y, 128, -6, dither_color( 12, 13 ) )

    camera( cam.x, cam.y )

    -- draw actors
    self:eachactor( function( actor )
        actor:draw()
    end )
end

-- animation

local animation = inheritsfrom( nil )
function animation:new( min, maxexclusive )
    local newobj = { 
        frames=range_to_array( min, maxexclusive ),
        current_frame=1,
        frame_rate_hz=10,
    }

    return setmetatable( newobj, self )
end

function animation:update( deltatime )
    if count( self.frames ) < 1 then return end
    self.current_frame += deltatime * self.frame_rate_hz
end

function animation:frame()
    if count( self.frames ) < 1 then return nil end

    local fr = wrap( self.current_frame, 1, count( self.frames ) + 1 )
    return self.frames[ flr( fr ) ]
end

-- actor

local actor = inheritsfrom( nil )
function actor:new( level, x, y, wid, hgt )
    local newobj = { 
        level = level,
        alive = true,
        pos = vector:new( x or 0, y or x or 0 ),
        vel = vector:new( 0, 0 ),
        offset = vector:new( 0, -4 ),
        collision_size = vector:new( wid or 0, hgt or 0 ),
        collision_planes_inc = 0,
        collision_planes_exc = 0,
        do_dynamics = false,
        does_collide_with_ground = true,
        gravity_scalar = 1.0,
        jumpforce = 3,
        animations = {},
        current_animation_name = nil,
    }

    add( level.actors, newobj )

    return setmetatable( newobj, self )
end

function actor:may_collide( other )
    -- these collide if their inclusion planes overlap
    -- and their exclusion planes don't
    -- so to collide with the player (plane 1) without colliding with other obstacles (plane 2)
    -- inc 1 but exc 2
    return  self.alive
            and other.alive
            and band( self.collision_planes_inc, other.collision_planes_inc ) 
            and 0 == band( self.collision_planes_exc, other.collision_planes_exc )
end

function actor:collision_rect()
    return { x = self.pos.x,
             y = self.pos.y,
             w = self.collision_size.x,
             h = self.collision_size.y }
end

function actor:does_collide( other )
    return self:may_collide( other )
        and rects_overlap( self:collision_rect(), other:collision_rect() )
end

function actor:on_collision( other )
    -- override
end

function actor:update( deltatime )

    if self.do_dynamics then
        self.vel.y += self.gravity_scalar * 0.125

        self.pos.x += self.vel.x
        self.pos.y += self.vel.y

        if self.does_collide_with_ground and self.pos.y >= 0 then
            self.pos.y = 0
            self.vel.y = 0
        end
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

function actor:grounded()
    return self.pos.y >= -0.1
end

function actor:jump( amount )
    if not self:grounded() then return end

    self.vel.y = -self.jumpforce * ( amount or 1.0 )
end

function actor:draw()
    local anim = self:current_animation()
    if anim ~= nil then 
        spr( anim:frame(), self.pos.x + self.offset.x, self.pos.y + self.offset.y )
    end
end

-- decoration

local decoration = inheritsfrom( actor )
function decoration:new( level, x, y )
    local newobj = actor:new( level, x ,y )
    return setmetatable( newobj, self )
end

function decoration:update( deltatime )
    self:superclass().update( self, deltatime )

    -- die if too far left
    if self.pos.x < self.level.player.pos.x - 96 then
        self.alive = false
    end
end

function level:update_props()
    
    if pctchance( 1 ) then
        local prop = decoration:new( self, self.player.pos.x + 96, 0 )
        prop.animations = {}
        prop.animations[ 'idle' ] = animation:new( 17, 18 )
        prop.current_animation_name = 'idle'

        -- todo
        prop.collision_planes_inc = 1
    end
end

--player

local player = inheritsfrom( actor )
function player:new( level )
    local newobj = actor:new( level, 0, -64, 8, 14 )
    newobj.do_dynamics = true
    newobj.vel.x = 1
    newobj.offset = vector:new( 0, -15 )
    newobj.animations[ 'run' ] = animation:new( 32, 37 ) 
    newobj.current_animation_name = 'run'
    newobj.collision_planes_inc = 1

    newobj.leg_anim = animation:new( 48, 54 )
    
    return setmetatable( newobj, self )
end

function player:update( deltatime )
    self:superclass().update( self, deltatime )
    self.leg_anim:update( deltatime )
end

function player:draw()
    self:superclass().draw( self )
    spr( self.leg_anim:frame(), self.pos.x + self.offset.x, self.pos.y + self.offset.y + 8 )
end

function actor:on_collision( other )
    -- todo
end

-->8
--jeff's code

--level creation
local current_level = level:new()
current_level.player = player:new( current_level )

--main loops
local buttonstates = {}
function _update60()

    function update_input()
        local lastbuttonstates = shallowcopy( buttonstates )

        for i = 0,5 do
            buttonstates[ i ] = btn( i )
        end

        function wentdown( btn )
            return buttonstates[ btn ] and not lastbuttonstates[ btn ]
        end

        if wentdown(4) then
            current_level.player:jump()
        end
    end

    update_input()
    current_level:update()
end

function _draw()

    -- world

    current_level:draw()

    -- ui

    camera( 0, 0 )
    print( debug_text, 8, 8, 8 )

end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
444444440000b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
41114141008b80000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
117617610878820007aaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
41661661088882000aaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4f11f1100882220009aaa90000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ff777f0002220000099900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f77ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00044400044440000044000000044400044440000004400004444000000000000000000000000000000000000000000000000000000000000000000000000000
00444f004444f0ff4444400000444f004444f044044444004444f000000000000000000000000000000000000000000000000000000000000000000000000000
0444ff00444ff0ff4444f0000444ff00444ff04404444f00444ff000000000000000000000000000000000000000000000000000000000000000000000000000
044fff0000fff00f044ff000044fff0000fff0040044ff0000fff000000000000000000000000000000000000000000000000000000000000000000000000000
000fff0044ffffff00fff000000fff00fffff444000fff0000fff000000000000000000000000000000000000000000000000000000000000000000000000000
004fff0040ff400000fff0f000ffff00f04ff000000fff0400fff000000000000000000000000000000000000000000000000000000000000000000000000000
004fff0040fff00000fffff000ffff00f0fff000000fff4400fff000000000000000000000000000000000000000000000000000000000000000000000000000
000fff0000fff00000fff000000fff0000fff000000fff0000fff000000000000000000000000000000000000000000000000000000000000000000000000000
000eee0000eee00000eee200000eee0000eee000000eee0000000000000000000000000000000000000000000000000000000000000000000000000000000000
000eee2000eee20000eeee20000eeee000eeee00002eeee000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ee82008ee222000eeee80000ee880022ee880002eee8000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088840088e0244fff888800002e8f0022288ff4442e88000000000000000000000000000000000000000000000000000000000000000000000000000000000
0044f4400f80044000ffff4000fffff004200ff0004448f000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000f000ff00440000000040000040004400ff00000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000f000f000400000000040000040004000f000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ff00f0000000000000440000440040000000000000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0001000015100141001410014100151000810017100191001a1001c1000d1001e10020100221002510013000291002d1002e100100001d1001f1000d000201002110021100210002210022100221001300022100
