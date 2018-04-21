pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- todo game title here
-- by jeff and liam wofford 
-- http://www.electrictoy.co

-->8
-- general utilities

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

function overlaps( recta, rectb )
    return false -- todo!!!
end

-- level

local level = inheritsfrom( nil )
function level:new()
    local newobj = { 
        actors = {},
        tick_count = 0,
        pending_calls = {},
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

function level:update()

    self.tick_count += 1

    self:update_pending_calls()

    self:eachactor( function( actor )
        actor:update()
    end )

    -- remove dead actors
    for actor in all( self.actors ) do
        actor:update()
        if not actor.alive then
            del( self.actors, actor )
        end
    end    
end

function level:draw()

    -- draw background

    -- draw level

    -- draw actors
    self:eachactor( function( actor )
        actor:draw()
    end )
end

-- animation

local animation = inheritsfrom( nil )
function animation:new()
    local newobj = { 
        frames={},
        current_frame=1,
        frame_rate_hz=15,
    }

    return setmetatable( newobj, self )
end

function animation:update( deltatime )
    if count( self.frames ) < 1 then return end
    self.current_frame += deltatime / self.frame_rate_hz
end

function animation:frame()
    if count( self.frames ) < 1 then return nil end
    else return self.frames[ wrap( 1, self.current_frame, count( self.frames ) + 1 )]
end

-- actor

local actor = inheritsfrom( nil )
function actor:new( level, x, y, wid, hgt )
    local newobj = { 
        level = level,
        alive = true,
        pos = vector:new( x, y ),
        collision_rect = vector:new( wid, hgt ),
        collision_planes_inc = 0,
        collision_planes_exc = 0,
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
            and not band( self.collision_planes_exc, other.collision_planes_exc )
end

function actor:does_collide( other )
    return self:may_collide( other )
        and overlaps( self:collision_rect(), other:collision_rect() )
end

function actor:draw()
    -- todo
end

-->8
--jeff's code


--level creation
local current_level = level:new()
local player = actor:new(level, 64, 64, 8, 14)


--main loops
function _update60()
    current_level:update()
end

function _draw()
    current_level:draw()

    -- todo
end


-->8
--liam's code

-- todo


