pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- game title here
-- by jeff and liam wofford 
-- http://www.electrictoy.co

-- u⬆️ d⬇️ l⬅️ r➡️ z🅾️ x❎
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

function establish( value, default )
    if value == nil then return default end
    return value
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
-- see https://www.lexaloffle.com/bbs/?tid=2477
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

-- see http://lua-users.org/wiki/copytable
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
    local newobj = { x = establish( x, 0 ), y = establish( y, establish( x, 0 )) }
    return setmetatable( newobj, self )
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

function sign( x )
    return x > 0 and 1 or ( x < 0 and -1 or 0 )
end

function sign_no_zero( x )
    return x >= 0 and 1 or -1
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
local shadow_y_divisor = 6
local weapon_check_distance = 32


-- mapsegment
local mapsegment = inheritsfrom( nil )
function mapsegment:new( segment_num, worldx )
    local newobj = {
        segment_num = segment_num,
        worldx = worldx,
    }
    return setmetatable( newobj, self )
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

    -- move into my frame of reference, still in world units
    rect.l -= myrect.l
    rect.t -= myrect.t
    rect.r -= myrect.l
    rect.b -= myrect.t

    -- move into map units, still in my frame of reference, ensuring
    -- we don't go out of bounds
    rect.l = max( worldtomap( rect.l ), 0 )
    rect.t = max( worldtomap( rect.t ), 0 )
    rect.r = min( worldtomap( rect.r ), mapsegment_tile_size.x - 1 )
    rect.b = min( worldtomap( rect.b ), mapsegment_tile_size.y - 1 )

    local my_mapspace_ul = { x =    ( self.segment_num % mapsegment_tiles_across_map ) * mapsegment_tile_size.x, 
                             y = flr( self.segment_num / mapsegment_tiles_across_map ) * mapsegment_tile_size.y }

    -- move into map space
    rect.l += my_mapspace_ul.x
    rect.t += my_mapspace_ul.y
    rect.r += my_mapspace_ul.x
    rect.b += my_mapspace_ul.y

    -- debug_print( withactor.pos.x .. ',' .. withactor.pos.y .. ' ' .. myrect.l .. ',' .. myrect.t .. ' ' .. rect.l .. ',' .. rect.t .. ',' .. rect.r .. ',' .. rect.b )

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

-- animation

local animation = inheritsfrom( nil )
function animation:new( min, count, ssizex, ssizey )
    count = establish( count, 1 )
    local newobj = { 
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
        newobj.frames[ i + 1 ] = min + i * newobj.ssizex
    end

    return setmetatable( newobj, self )
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

-- actor

local actor = inheritsfrom( nil )
local creature = inheritsfrom( actor )

function actor:new( level, x, y, wid, hgt )
    local newobj = { 
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
        want_shadow = false,
        damage = 2,
        parallaxslide = 0,
        deathcolorshift = -1,
        colorshift = 0,
        flashamount = 0,
        flashhertz = 6,
        floatbobamplitude = 0,
        floatbobfrequency = 1.2,
    }

    add( level.actors, newobj )

    return setmetatable( newobj, self )
end

function actor:flash( time, hz, amount )
    if self.flashamount ~= 0 then return end  -- one at a time please

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
    -- these collide if their inclusion planes overlap
    -- and their exclusion planes don't
    -- so to collide with the player (plane 1) without colliding with other obstacles (plane 2)
    -- inc 1 but exc 2
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
    -- override
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

    -- die if too far left
    local liveleft, liveright = self.level:live_actor_span()
    if self:collision_br().x + 8 < liveleft then
        self.active = false
    end

    -- die if too far right and rightbound
    if self.vel.x > 0 and self:collision_ul().x > liveright then
        self.active = false
    end

    -- update animation
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
    self.vel.y = 0
    self.landed_tick = self.level.tick_count
end

function actor:grounded()
    return self.landed_tick ~= nil and self.level.tick_count - self.landed_tick < 2
end

function actor:jump( amount )
    if self:dead() or not self:grounded() then return end

    self.vel.y = -self.jumpforce * establish( amount, 1.0 )
    self.landed_tick = nil
    sfx(32)
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

        --draw shadow
        -- if self.want_shadow then
        --     draw_color_shifted( -4, function()
        --         spr( frame, drawpos.x, (-self:collision_br().y) / shadow_y_divisor, anim.ssizex, anim.ssizey, false, true )
        --     end )
        -- end
    end
end

function actor:on_pickedup_by( other )
    self.active = false    
end

--player

local player = inheritsfrom( actor )
function player:new( level )
    local newobj = actor:new( level, 0, -64, 8, 14 )
    newobj.immortal = true
    newobj.do_dynamics = true
    newobj.want_shadow = true
    newobj.depth = -100
    newobj.vel.x = 1    -- player run speed
    newobj.animations[ 'run' ] = animation:new( 32, 6, 1, 2 ) 
    newobj.animations[ 'run_armor' ] = animation:new( 38, 6, 1, 2 ) 
    newobj.current_animation_name = 'run'
    newobj.collision_planes_exc = 0

    newobj.coins = 0
    newobj.max_health = 6
    newobj.health = newobj.max_health

    newobj.max_satiation = 10
    newobj.satiation = newobj.max_satiation

    newobj.reach_distance = 12

    newobj.max_armor = 3
    newobj.armor = 0
    newobj.armorflicker = false

    newobj.deathcolorshift = 0
    newobj.deathcause = ''

    local death_anim = animation:new( 224, 7, 2, 2 )
    death_anim.style = 'stop'

    -- death frames
    death_anim.frames = { 224, 226, 228, 230, 230, 230, 230, 230, 232, 232, 232, 232, 232, 232, 232, 234, 236 }
    newobj.animations[ 'death' ] = death_anim
    
    return setmetatable( newobj, self )
end

function player:maybe_shoot( other )
    -- todo and we have a weapon and ammo!!!
    if abs( other.pos.x - self.pos.x ) < weapon_check_distance then
        -- todo!!!
        -- other:die()
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
    self:superclass().jump( self, amount )
    self:drain_satiation( 0.01 )
end

function player:update( deltatime )
    self:superclass().update( self, deltatime )

    -- fire weapon if appropriate
    local creatures = self.level:actors_of_class( creature )
    for creature in all( creatures ) do
        self:maybe_shoot( creature )
    end

    -- update satiation

    self:drain_satiation( 0.002 + ( self.armor > 0 and 0.001 or 0 ))

    -- sync anims
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

-- pickups
local pickup = inheritsfrom( actor )
function pickup:new( level, x, animframe, fn_on_pickup )
    local newobj = actor:new( level, x, -16, 6, 6 )
    newobj.animations[ 'idle' ] = animation:new( animframe ) 
    newobj.current_animation_name = 'idle'
    newobj.collision_planes_inc = 1
    newobj.may_player_pickup = true
    newobj.damage = 0
    newobj.fn_on_pickup = fn_on_pickup
    newobj.floatbobamplitude = 1

    return setmetatable( newobj, self )    
end

function pickup:on_pickedup_by( other )
    self.fn_on_pickup( self, other )
    self:superclass().on_pickedup_by( self, other )
end

-- level

local level = inheritsfrom( nil )
function level:new()
    local newobj = {
        actors = {},
        mapsegments = {},
        ground_decorations = {},
        horizon_decorations = {},
        tick_count = 0,
        pending_calls = {},        
    }
    newobj.creation_records = {
        coin     = { chance =   100, earliestnext =   64, interval = 16, predicate = function() return sin( newobj:time() / 3 ) * sin( newobj:time() / 11 ) > 0.25 end },
        stone    = { chance =   0.5, earliestnext =   64, interval = 48, predicate = function() return ( #newobj:actors_of_class( creature ) == 0 ) or pctchance( 0.1 ) end  },
        tree     = { chance =    1, earliestnext = -100, interval = 0, predicate = function() return #newobj.actors < 20 end },
        shrub    = { chance =    1, earliestnext = -100, interval = 0 },
        creature = { chance =    100, earliestnext = 256, interval = 256, predicate = function() return #newobj:actors_of_class( creature ) == 0 end },
    }

    newobj.player = player:new( newobj )
    return setmetatable( newobj, self )
end

function level:time()
    return self.tick_count / 60.0
end

function level:after_delay( delay, fn )
    add( self.pending_calls, { deadline = self:time() + delay, fn = fn } )
end

function level:viewspan()
    local cam = self:camera_position()
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

    -- actor collision
    for i = 1, #self.actors - 1 do
        for j = i + 1, #self.actors do
            update_actor_collision( self.actors[ i ], self.actors[ j ])
        end
    end

    -- mapsegment collision with player
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

    self:update_creatures()

    if self.player.alive then
        self:create_props()
        self:create_coins()
        self:update_mapsegments()
    end

    self:update_collision()

    -- update actors and remove dead ones
    erase_elements( self.actors, function(actor)
        actor:update( deltatime )
        return not actor.active
    end)

    sort( self.actors, function( a, b )
        return a.depth < b.depth
    end )
end

function level:camera_position()
    return vector:new( -64, -96 ) + vector:new( self.player.pos.x + 32, 0 )
end

function nibblerot( bits, offset )
    offset = wrap( offset, 0, 4 )
                                            -- 00001001
    bits = shl( bits, 4 )                   -- 10010000

    bits = shr( bits, offset )              -- 01001000
    local upper = shr( bits, 4)             -- 00000100
    bits = bor( bits, upper )               -- 01001100

    return band( bits, 0b1111 )             -- 00001100
end

function level:timeofday()
    return 0.5 + sin( self:time() / 50 ) * 0.5
end

function level:categoricaltimeofday()
    local thetime = self:timeofday()
    return thetime < 0.7 and 1 or ( thetime < 0.9 and 2 or 3 )
end

function level:draw()

    local cam = self:camera_position()

    -- draw background
    camera( 0, cam.y )

    function ditherpattern( topdensity, bottomdensity, offsetx )
        local patterns = {
            0b0000,
            0b0000,
            0b0010,
            0b1000,
            0b0101,
            0b1010,
            0b1101,
            0b0111,
            0b1111,
            0b1111,
        }

        local pattern = 0
        for y = 0, 3 do
            local ydensity = lerp( topdensity, bottomdensity, y / 3.0 )
            local patternindex = 1 + 2*flr( ydensity * 4 + 0.5 ) + ( band( y, 1 ) == 0 and 1 or 0 )
            local rowpattern = patterns[ patternindex ]
            rowpattern = nibblerot( rowpattern, offsetx )

            pattern = bor( pattern, shl( rowpattern, 4 * (3 - y)))
        end

        return pattern
    end

    function fillstrip( top, topdensity, bottomdensity, color, offsetx )
        fillp( ditherpattern( topdensity, bottomdensity, offsetx ))
        rectfill( 0, top, 128, top + 3, color )
    end

    function fillstripseries( top, height, topdensity, bottomdensity, color, offsetx )
        offsetx = establish( offsetx, 0 )
        local bot = top + height - 1
        for row = top, bot, 4 do
            local proportionalrow = proportion( row, top, bot )
            local proportionalbot = proportion( min( bot, row + 3 ), top, top + height - 1 )
            local striptopdense = clamp( lerp( topdensity, bottomdensity, proportionalrow ), 0, 1 )
            local stripbotdense = clamp( lerp( topdensity, bottomdensity, proportionalbot ), 0, 1 )
            fillstrip( row, striptopdense, stripbotdense, color, offsetx )
        end
    end

    -- grass
    cls( 1 )

    local thetime = self:timeofday()
    local categoricaltime = self:categoricaltimeofday()

    function drawgrass()
        camera( 0, cam.y )

        -- matrix: grasscolors[ categoricaltime ][ darklevel ]
        local grasscolors = {
            {
                5, 3, 11
            },
            {
                1, 5, 3
            },
            {
                0, 1, 3
            },
        }

        local gc = grasscolors[ categoricaltime ]

        local grassscrolloffsetx = -( self.player.pos.x % 4 )
        fillstripseries(  0, 6 , 0, 1, dither_color( gc[2], gc[3] ), grassscrolloffsetx )
        fillstripseries(  4, 20, 0, 1, dither_color( gc[3], gc[2] ), grassscrolloffsetx )
        fillstripseries(  24, 8, 0, 1, dither_color( gc[2], gc[1] ), grassscrolloffsetx )

        -- boundary line
        line( 0, 0, 128, 0, 0 )
    end

    -- sky

    local skycolors = {
        {
            1, 13, 7, 12
        },
        {
            0, 1, 10, 9
        },
        {
            0, 1, 13, 1
        },
    }

    local sc = skycolors[ categoricaltime ]
    fillstripseries( -96, 16, 0, 1, dither_color( sc[4], sc[4] ) )
    fillstripseries( -80, 8, 0, 1, dither_color( sc[4], sc[3] ) )
    fillstripseries( -72,  8, 0, 1, dither_color( sc[3], sc[4] ) )
    fillstripseries( -64, 8, 0, 1, dither_color( sc[4], sc[4] ) )
    fillstripseries( -56, 32, 0, 1, dither_color( sc[4], sc[2] ) )
    fillstripseries( -32, 32, 0, 1, dither_color( sc[2], sc[1] ) )

    camera( cam.x, cam.y )

    -- draw behind-grass actors
    self:eachactor( function( actor )
        if actor.depth > 0 then
            actor:draw()
        end
    end )

    drawgrass()
 
    camera( cam.x, cam.y )

    -- draw mapsegments

    for segment in all( self.mapsegments ) do
        segment:draw()
    end

    -- draw in-front-of-grass actors
    self:eachactor( function( actor )
        if actor.depth <= 0 then
            actor:draw()
        end
    end )
end

local behaviors = {}

-- creature
function creature:new( level, x )
    local whichcreature = 2 --todo!!! rand_int( 1, 2 )

    local y = -16
    local wid = 16
    local hgt = 7

    local newobj = actor:new( level, x, y, wid, hgt )
    newobj.do_dynamics = true
    newobj.depth = -10
    newobj.want_shadow = true
    newobj.current_animation_name = 'run'
    newobj.jumpforce = 1.5
    newobj.whichcreature = whichcreature

    -- tiger
    if whichcreature == 1 then
        newobj.animations[ 'stop' ] = animation:new( 64, 1, 2, 1 )         
        newobj.animations[ 'death' ] = newobj.animations[ 'stop' ]
        newobj.animations[ 'run' ] = animation:new( 64, 3, 2, 1 ) 
        newobj.animations[ 'coil' ] = newobj.animations[ 'run' ]
        newobj.animations[ 'pounce' ] = newobj.animations[ 'run' ]
        newobj.behavior = cocreate( behaviors.slide_left_fast )
    elseif whichcreature == 2 then
        newobj.animations[ 'run' ] = animation:new( 80, 3, 2, 1 ) 
        newobj.animations[ 'coil' ] = animation:new( 86, 1, 2, 1 ) 
        newobj.animations[ 'pounce' ] = animation:new( 88, 1, 2, 1 ) 
        newobj.animations[ 'stop' ] = newobj.animations[ 'pounce' ]
        newobj.animations[ 'death' ] = newobj.animations[ 'stop' ]
        newobj.behavior = cocreate( behaviors.pounce_from_left )
    end

    return setmetatable( newobj, self )
end

function creature:die( cause )
    if self:dead() then return end

    self:superclass().die( self, cause )

    self:flash( 0.2, 2, 5 )

    self.flipy = true
    self.landed_tick = nil
    self.collision_size.y -= 4
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

-- stone

local stone = inheritsfrom( actor )
function stone:new( level, x )
    local size = rand_int( 1, 2 )

    local sprite = { 185, 167, 164 }
    local spritewidth =  { 1, 2, 3 }
    local spriteheight = { 1, 2, 2 }
    local spriteoffsetx = { -1, -4, -4 }
    local spriteoffsety = { -1, -2, -2 }
    local collisionwid = { 6, 12, 16 }
    local collisionhgt = { 6, 12, 12 }

    local newobj = actor:new( level, x, -collisionhgt[ size ], 0, 0 )
    newobj.animations[ 'idle' ] = animation:new( sprite[size], 1, spritewidth[size], spriteheight[size] ) 
    newobj.current_animation_name = 'idle'
    newobj.do_dynamics = false
    newobj.offset.x = spriteoffsetx[ size ]
    newobj.offset.y = spriteoffsety[ size ]
    newobj.collision_size.x = collisionwid[ size ]
    newobj.collision_size.y = collisionhgt[ size ]

    return setmetatable( newobj, self )        
end

-- coin

local coin = inheritsfrom( actor )
function coin:new( level, x )
    local y = -48 + 8 * flr( sin( x / 300 ) * 5 )
    local newobj = actor:new( level, x, y, 4, 4 )
    newobj.animations[ 'idle' ] = animation:new( 9 ) 
    newobj.current_animation_name = 'idle'
    newobj.collision_planes_inc = 1
    newobj.may_player_pickup = true
    newobj.damage = 0
    newobj.floatbobamplitude = 1

    newobj.value = 1

    return setmetatable( newobj, self )    
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
    local newobj = actor:new( level, x, -14 * scale, scale * 2 * 8, scale * 8 )
    newobj.flipx = pctchance( 50 )
    newobj.animations[ 'idle' ] = animation:new( 128, 1, 1, 2 )
    newobj.current_animation_name = 'idle'
    newobj.collision_planes_inc = 0
    newobj.damage = 0
    newobj.parallaxslide = randinrange( 0.5, 8.0 ) / (scale*scale)
    newobj.depth = newobj.parallaxslide * 10
    newobj.animations[ 'idle' ].drawscalex = scale
    newobj.animations[ 'idle' ].drawscaley = scale

    return setmetatable( newobj, self )    
end

local shrub = inheritsfrom( actor )
function shrub:new( level, x )
    local scale = randinrange( 1, 2 )
    local newobj = actor:new( level, x, 32 - 16 * scale, scale * 4 * 8, scale * 2 * 8 )
    newobj.flipx = pctchance( 33 )
    newobj.animations[ 'idle' ] = animation:new( 160, 1, 4, 2 )
    newobj.current_animation_name = 'idle'
    newobj.collision_planes_inc = 0
    newobj.damage = 0
    newobj.parallaxslide = -randinrange( 0.5, 1 ) / scale
    newobj.depth = newobj.parallaxslide * 10
    newobj.animations[ 'idle' ].drawscalex = scale
    newobj.animations[ 'idle' ].drawscaley = scale

    return setmetatable( newobj, self )    
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

    if pctchance( 0.25 ) then
        local pickup = pickup:new( self, liveright - 2, 7, function( pickup, actor )
            actor.armor = actor.max_armor
        end )
    end
end

function level:create_coins()
    self:maybe_create( coin, 'coin' )
end

function world_to_mapsegment_cell_x( x )
    return flr( x / maptoworld( mapsegment_tile_size.x ) )
end

function level:update_mapsegments()
    local left, right = self:viewspan()

    -- update and remove any expired (too far left) segments
    erase_elements( self.mapsegments, function(segment)
        segment:update()
        local farleft = segment:right() < left
        return farleft
    end )

    -- create new segments to fill screen.

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

local item_tree =
    -- root
    { sprite = 0, action = nil,
        children = {
            -- light
            { sprite = 15, action = nil },          

            -- food
            { sprite = 10, action = nil,            
                children = {
                    { sprite = 10, action = nil },  
                    { sprite = 11, action = nil },  
                    { sprite = 12, action = nil },  
                }
            },

            -- weapons
            { sprite = 13, action = nil,
                children = {
                    { sprite = 13, action = nil },      
                    { sprite = 14, action = nil },      
                }
            },

            -- 'home'
            { sprite = 27, action = nil },
        }
    }

local thingy_spacing = 16

local thingy = inheritsfrom( nil )

local crafting = inheritsfrom( nil )
function crafting:new( pos )
    local newobj = {
        pos = pos,
        tick_count = 0,
        pending_calls = {},        
        activated = nil,
        homebutton = false,
        lockout_input = false,
    }

    local resultself =  setmetatable( newobj, self )

    resultself.rootthingy = thingy:new( resultself, nil, item_tree )
    resultself.homebutton = resultself.rootthingy.children[ 4 ]
    resultself.homebutton.homebutton = true
    resultself.rootthingy:activate()

    return resultself
end

function crafting:on_activating( thing )
    self.activated = thing
end

function crafting:on_activating_item( thing )

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

    self.rootthingy:update()
end

function crafting:draw()
    self.rootthingy:draw( self.pos, false )

    -- draw again, but only the activated branch
    if self.activated ~= nil then
        self.rootthingy:draw( self.pos, true )
    end

    if self.activated == self.rootthingy then
        draw_shadowed( self.pos.x + 4, self.pos.y + 12, 0, 1, 2, function(x,y)
            print_centered_text( 'craft', x, y, 4 )
        end )
    end
end

function thingy:new( crafting, parent, item_config )
    local newobj = {
        crafting = crafting,
        parent = parent,
        sprite = item_config.sprite,
        action = item_config.action,
        children = {},
        pos = vector:new( 0, 0 ),
        destination = nil,
        lerpspeed = 0.1,
        flashstarttime = nil,
        flashendtime = nil,
    }

    local configchildren = item_config.children
    for child in all( configchildren ) do
        add( newobj.children, thingy:new( crafting, newobj, child ) )
    end

    return setmetatable( newobj, self )
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

function thingy:available()
    if self.homebutton or #self.children > 0 then return true end
    -- todo!!!
    return false
end

function thingy:drawself( basepos )
    local selfpos = basepos + self.pos

    if self.sprite == 0 then return end

    local colorize = 0
    if self:flashing() and flicker( self:flash_age(), 2 ) then
        colorize = 8
    end

    draw_color_shifted( colorize, function()

        local basecolorshift = colorize
        if basecolorshift == 0 and not self:available() then
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
    -- 1 = left; 2 = right; 3 = up; 4 = down

    local adjustedindex = myindex
    -- todo!!!
    -- if myindex == 1 then adjustedindex = parentindex end
    -- if myindex == 3 then adjustedindex = ( parentindex == 1 ) and 3 or 1 end

    if adjustedindex == 1 then
        self.destination = vector:new( -thingy_spacing, 0 )
    elseif adjustedindex == 2 then
        self.destination = vector:new(  thingy_spacing, 0 )
    elseif adjustedindex == 3 then
        self.destination = vector:new( 0, -thingy_spacing )
    elseif adjustedindex == 4 then
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
        -- unavailable
        self:flash( 0.05 )
        return
    end

    self.crafting:on_activating( self )

    local flashduration = 0.25

    -- leaf node?
    if self.parent ~= nil and #self.children == 0 then
        -- yes. do what we do

        if self.action ~= nil then
            self.action()
        end

        self.crafting:on_activating_item( self )
    else
        -- container. Expand children.

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

    -- home button
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

            -- if non-leaf, collapse other children
            if #activated_child.children > 0 then
                for child in all( self.children ) do
                    if activated_child ~= child then
                        child:collapse()
                    end
                end
            end

            activated_child:activate()

            -- if root, move down
            if self.parent == nil then
                -- todo
                -- self.destination = vector:new( 0, thingy_spacing )
            end
        end

    end
end

-->8
--one-time setup

function tidy_map()
    for mapx = 0, 127 do
        for mapy = 0, 32 do

            -- fixup platform ends
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

local crafting_ui = crafting:new( vector:new( 96, 2 + thingy_spacing + 2 ))
local current_level = nil

local game_state = 'title'
local current_level = nil

function restart_world()
    current_level = level:new()

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


function level:update_creatures()
    -- create new creature if desired
    self:maybe_create( creature, 'creature' )
end

--main loops
function _update60()

    update_buttons()

    -- update game state logic

    if game_state == 'playing' then
        function update_input()
            local player = current_level.player
            if wentdown(4) then
                player:jump()
            end

            if wentdown(5) then
                player:grab()
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

        -- update input
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


        -- draw player health
        
        draw_halveable_stat( iconleft, iconsy, player.health, player.max_health, 1, 2, 3 )
        draw_shadowed( 2, iconsy + 1, 0, 1, 1, function(x,y)
            print( 'life', x, y, 8 )
        end )

        -- draw player distance

        local dist = player_run_distance()
        draw_shadowed( iconright, iconsy, 0, 1, 2, function(x,y)
            print_rightaligned_text( '' .. dist .. ' m', x, y, 11 )
        end )

        iconsy += 9

        -- draw player armor

        draw_fullicon_stat( iconleft, iconsy, player.armor, player.max_armor, 7, 8 )
        draw_shadowed( 6, iconsy + 1, 0, 1, 1, function(x,y)
            print( 'def', x, y, 13 )
        end )

        -- draw player coins

        draw_shadowed( iconright, iconsy, 0, 1, 2, function(x,y)
            print_rightaligned_text( '' .. player.coins .. ' g', x, y, 10 )
        end )

        iconsy += 9

        -- draw player satiation

        draw_halveable_stat( iconleft, iconsy, player.satiation, player.max_satiation, 4, 5, 6 )
        draw_shadowed( 2, iconsy + 1, 0, 1, 1, function(x,y)
            print( 'food', x, y, 9 )
        end )

        iconsy += 9

        crafting_ui:draw()
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

        draw_shadowed( 64, 102, 0, 1, 2, function(x,y)
            print_centered_text( 'play again! z/x ????/❎', x, y, 12 )
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


    -- draw debug

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

    -- world

    current_level:draw()

    -- ui

    camera( 0, 0 )

    draw_ui()

    -- debug
    draw_debug_lines()
    -- print( stat(0) )
end

-- creature ai

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
            actor.vel.x = 1
            wait( 0.4 )
            actor.vel.x = 0.8

            standard_attack_warning( actor )
            actor.vel.x = -3
        end,
    slide_right_fast =
        function(actor)
            actor.pos.x = stage_left_appear_pos()
            actor.flipx = false
            actor.vel.x = 1.5
            while deltafromplayer( actor ) < -24 do
                yield()
            end
            actor.vel.x = 0.9
            wait( 0.2 )
            standard_attack_warning( actor )
            actor.vel.x = 4
        end,
    pounce_from_left =
        function(actor)
            local maxpounces = 3    -- todo based on level age
            local restpos = -32

            local numpounces = rand_int( 1, maxpounces )

            --setup
            actor.pos.x = stage_left_appear_pos()
            actor.flipx = false
            local stored_collision_planes = actor.collision_planes_inc

            -- approach
            actor.current_animation_name = 'run'
            actor.vel.x = 1.25
            while deltafromplayer( actor ) < restpos do
                yield()
            end

            -- loop
            for i = 1, numpounces do

                actor.colorshift = 0

                -- wait
                actor.current_animation_name = 'run'
                actor.vel.x = 0.95
                wait( 1 )

                --flash
                actor.current_animation_name = 'coil'
                actor:flash( 0.5 )
                wait( 0.5 )

                --pounce
                actor.collision_planes_inc = stored_collision_planes
                actor.current_animation_name = 'pounce'
                actor:jump()
                actor.vel.x = 2.5

                -- wait to land

                while not actor:grounded() do
                    yield()
                end

                -- fall back
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

-->8
-- liam's code


__gfx__
00000000088088000880000000000000000004000000000000000000777666d000000000000000007000000000000000009900004000000076000000700a0000
00000000878888108788022000220220099909900990002000000020744222d202222222007770006740000004444200097a40004444400066600000a7900000
00700700888888128888122202222222979999929799202200222022642224d20222222207aaaa00044400004477942097aaa00007004400064000000aa90000
00077000888881128888122202222222994999429994222202222222622244d2022222220aaaaa0004442000499988209aa4a400007004000004c00090944000
0007700008881122088112220222222294444422994222220222222206244d220222222209aaa900002220004298822004aa990000070400000c4cd000004400
007007000011122000111220002222209422222094222220022222200664dd2000222220009990000000dd004422222000094900000062000000c2d000000420
00000000000122000001220000022200044420000444200002200000000622200022222000000000000006000222220000000900000002200000cd0000000020
00000000000020000000200000002000002220000022200000222000000020000000200000000000000000000000000000000000000000000000000000000000
d0d0d0d00000b000004000007000000000000000700a0000000b0000000dd0000000000040090009040090090004000000000000000000000000000000000000
0000000d008b80000aa0000067e00000007cc0000a7a9000044b30000000dd000077700099990090099990090041400000000000000000000000000000000000
d00000000878820009a000000eee000007cccd0009a9aa000045300000777d100766660079790090079790900414240000000000000000000000000000000000
0000000d0888820009aa00000eee20000ccccd007a9a4a000004400007dddd100666660099994990099994904144424000000000000000000000000000000000
d000000008822200009aa940002220000cccdd000aa4a490000055000dddd1100d666d0009949990099949900144420000000000000000000000000000000000
0000000d00222000000444000000dd0000f4400000994900000005000011110000ddd00009999990099999900441440000000000000000000000000000000000
d0000000000000000000000000000600000000000004900000000000000000000000000004094090409040900221220000000000000000000000000000000000
0d0d0d0d000000000000000000000000000000000000000000000000000000000000000004094090409004090000000000000000000000000000000000000000
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
800000000088a8a0000000000000000000000000088a8a0000000000000000000000000000000000000000000000000000000000000000000000000000000000
8822800000088882002280000088a8a0000288000088882000000000000000000000000000000000000000000000000000000000000000000000000000000000
08282282002888800882828800088882088288280822880000000000000000000000000000000000000000000000000000000000000000000000000000000000
00082882828228000800088222822280880008282288200000000000000000000000000000000000000000000000000000000000000000000000000000000000
00028882828882200080028282888800000000882828820000000000000000000000000000000000000000000000000000000000000000000000000000000000
00288882882828220000002888288000000000828828822200000000000000000000000000000000000000000000000000000000000000000000000000000000
02888000882808820000000082280000000000822088888200000000000000000000000000000000000000000000000000000000000000000000000000000000
88800000000000800000000002080000000000880000008000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000300030003000000000000000000000000000000000000000000000000000000000000000000000
00000000000053500000000000000000000000000000000003550533035533500000000000000000000000000000000000000000000000000000000000000000
0053530000035a53000053530000000050000053530000000553035505535a530000000000000000000000000000000000000000000000000000000000000000
03535350005353330003535350005350530003535350000053555533535553330000000000005353000000000000000000000000000000000000000000000000
53599353035390005053599353035a53535053599353000035335355353530005535535335535a57000000000000000000000000000000000000000000000000
53900953535900005353900953535333935353900953535053953593539330005335335335335307000000000000000000000000000000000000000000000000
590000935390000053590000935390000953590000935a5353035303530390005335335335339000000000000000000000000000000000000000000000000000
90000009990000009990000009990000009990000009933399099909990990009999999999990330000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00110000261502615026150261502615226152261522615524150241502415024150241522415224152241551d1501d1501d1501d1501d1501d1501d1501d1501d1521d1521d1521d1521d1521d1521d1521d155
00110000241502415024155211502115021150211522115221152211522115221152211522115221152211551a1501a1501a1521a1551d1501d1501d1521d155211502115021152211551d1501d1501d1521d155
001100002615026150221502215026150261502915029150211502115021152211551f1501f1501f1521f1551c1501c1501d1501d1501f1501f15021150211501815018150181501815018152181521815218155
001100002615026150221502215026150261502915029150211502115021152211521f1501f1501f1521f1521a1501a1501a1501a1501a1521a1521a1521a1521c1501c1501c1501c1501c1521c1521c1521c152
001100001d1501d1501d1501d1501d1501d1501d1501d1501d1521d1521d1521d1521d1521d1521d1521d1521d1551d1021d1021d10235115351153c1153c11539115391151d1021d1021d1021d1021d1021d102
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
02 05060f07

