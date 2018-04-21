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
    return ( time * hertz ) % 1 <= ( cutoff or 0.5 )
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
    local newobj = { x = x or 0, y = y or x or 0 }
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

function lerp( a, b, alpha )
    return a + (( b - a ) * alpha )
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

    -- todo!!! working here

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
    -- todo!!!
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

function level:viewspan()
    local cam = self:camera_position()
    return cam.x, cam.x + 128
end

function level:live_actor_span()
    local left, right = self:viewspan()
    return left - 16, right + 32
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

function level:draw()

    local cam = self:camera_position()

    cls( 3 )

    -- draw background
    camera( 0, cam.y )

    fillp( 0b1010010110100101 )
    rectfill( 0, cam.y, 128, 0, dither_color( 12, 13 ) )

    camera( cam.x, cam.y )

    -- draw mapsegments

    for segment in all( self.mapsegments ) do
        segment:draw()
    end

    -- draw actors
    self:eachactor( function( actor )
        actor:draw()
    end )
end

-- animation

local animation = inheritsfrom( nil )
function animation:new( min, count, ssizex, ssizey )
    count = count or 1
    local newobj = { 
        frames = {},
        current_frame=1,
        frame_rate_hz=10,
        ssizex = ssizex or 1,
        ssizey = ssizey or ssizex or 1,
        style = 'loop',
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
function actor:new( level, x, y, wid, hgt )
    local newobj = { 
        level = level,
        active = true,
        alive = true,
        pos = vector:new( x or 0, y or x or 0 ),
        vel = vector:new( 0, 0 ),
        depth = 0,
        offset = vector:new( 0, 0 ),
        collision_size = vector:new( wid or 0, hgt or 0 ),
        collision_planes_inc = 1,
        collision_planes_exc = 15,
        do_dynamics = false,
        landed_tick = nil,
        does_collide_with_ground = true,
        gravity_scalar = 1.0,
        jumpforce = 3,
        animations = {},
        current_animation_name = nil,
        want_shadow = false,
        damage = 1,
    }

    add( level.actors, newobj )

    return setmetatable( newobj, self )
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

    -- die if too far left
    local liveleft, liveright = self.level:live_actor_span()
    if self.pos.x < liveleft then
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
    return self.landed_tick ~= nil
end

function actor:jump( amount )
    if self:dead() or not self:grounded() then return end

    self.vel.y = -self.jumpforce * ( amount or 1.0 )
    self.landed_tick = nil
end

function actor:draw()
    local anim = self:current_animation()
    if anim ~= nil then 
        local drawpos = self.pos + self.offset
        local frame = anim:frame()
        spr( frame, drawpos.x, drawpos.y, anim.ssizex, anim.ssizey )

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
    newobj.do_dynamics = true
    newobj.want_shadow = true
    newobj.depth = -100
    newobj.vel.x = 1    -- player run speed
    newobj.animations[ 'run' ] = animation:new( 32, 6 ) 
    newobj.current_animation_name = 'run'
    newobj.collision_planes_exc = 0

    newobj.leg_anim = animation:new( 48, 6 )

    newobj.coins = 0
    newobj.max_health = 1
    newobj.health = newobj.max_health

    newobj.reach_distance = 12

    local death_anim = animation:new( 224, 7, 2, 2 )
    death_anim.style = 'stop'
    death_anim.frames = { 224, 226, 228, 230, 232, 234, 236 }
    newobj.animations[ 'death' ] = death_anim
    
    return setmetatable( newobj, self )
end

function player:add_coins( amount )
    self.coins += amount
end

function player:update( deltatime )
    self:superclass().update( self, deltatime )
    self.leg_anim:update( deltatime )
end

function player:dead()
    return not self.alive
end

function player:die()
    if self:dead() then return end

    self.alive = false
    self.animations[ 'death' ].current_frame = 1
    self.current_animation_name = 'death'
    self.vel.x = 0
    debug_print( "dead!" )
end

function player:add_health( amount )
    if self:dead() then return end
    self.health = clamp( self.health + amount, 0, self.max_health )
    if self.health == 0 then
        self:die()
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
    if self.invulnerable or self:dead() then return end

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
    end
end

function player:draw()
    if not self.invulnerable or flicker( self.level:time(), 8 ) then
        self:superclass().draw( self )

        -- draw legs
        if self.alive then
            local legpos = self.pos + self.offset + vector:new( 0, 8 )

            local leganim = self.leg_anim:frame()
            spr( leganim, legpos.x, legpos.y )

            -- draw_color_shifted( -4, function()
            --     spr( leganim, legpos.x, (-legpos.y)/shadow_y_divisor, 1, 1, false, true )
            -- end )
        end
    end
end

function player:on_collision( other )
    if other.damage > 0 then
        self:take_damage( other.damage )
    end
end

-- creature
local creature = inheritsfrom( actor )
function creature:new( level, x, y, wid, hgt )
    local newobj = actor:new( level, x, y, wid, hgt )
    newobj.do_dynamics = true
    newobj.depth = -10
    newobj.want_shadow = true
    newobj.current_animation_name = 'run'
    return setmetatable( newobj, self )
end

-- stone

local stone = inheritsfrom( actor )
function stone:new( level, x, y )
    local newobj = actor:new( level, x, y, 0, 0 )
    newobj.animations[ 'idle' ] = animation:new( 164, 1, 3, 2 ) 
    newobj.current_animation_name = 'idle'
    newobj.offset.x = -4
    newobj.offset.y = -6
    newobj.collision_size.x = 16
    newobj.collision_size.y = 12

    return setmetatable( newobj, self )        
end

-- coin

local coin = inheritsfrom( actor )
function coin:new( level, x, y )
    local newobj = actor:new( level, x, y, 4, 4 )
    newobj.animations[ 'idle' ] = animation:new( 5 ) 
    newobj.current_animation_name = 'idle'
    newobj.collision_planes_inc = 1
    newobj.may_player_pickup = true
    newobj.damage = 0

    newobj.value = 1

    return setmetatable( newobj, self )    
end

function coin:update( deltatime )
    self:superclass().update( self, deltatime )

    -- die if too far left
    local liveleft, liveright = self.level:live_actor_span()
    if self.pos.x < liveleft then
        self.active = false
    end
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

function level:create_props()
    local liveleft, liveright = self:live_actor_span()
    if pctchance( 1 ) then
        stone:new( self, liveright - 2, -8 )
    end
end

function level:create_coins()
    local liveleft, liveright = self:live_actor_span()
    if pctchance( 2 ) then
        coin:new( self, liveright - 2, randinrange( -48, -4 ) )
    end
end

function level:update_creatures()
    local liveleft, liveright = self:live_actor_span()

    -- create new creature if desired
    -- todo
    if pctchance( 0.5 ) then
        local creat = creature:new( self, liveright - 2, -16, 16, 7 )
        creat.animations[ 'run' ] = animation:new( 64, 3, 2, 1 ) 
    end
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
        if farleft then
            -- debug_print( 'will delete segment ' .. segment.worldx )
        end
        return farleft
    end )

    -- create new segments to fill screen.

    firstopenleft = right
    if #self.mapsegments > 0 then
        firstopenleft = max( firstopenleft, self.mapsegments[ #self.mapsegments ].worldx + maptoworld( mapsegment_tile_size.x ) )
    end
    for worldcellx = world_to_mapsegment_cell_x( firstopenleft ), world_to_mapsegment_cell_x( right ) do
        local segment = mapsegment:new( flr( randinrange( 0, 6 ) ), maptoworld( worldcellx * mapsegment_tile_size.x ) )
        add( self.mapsegments, segment )
    end

end

-->8
--jeff's code

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
local game_state = 'title'
local current_level = nil

function restart_world()
    current_level = level:new()
    current_level.player = player:new( current_level )

    game_state = 'playing'
end

function player_run_distance()
    return ( current_level.player.pos.x - 0 ) / 100
end

tidy_map()
restart_world()

--main loops
local buttonstates = {}
function _update60()

    -- convenient button processing

    local lastbuttonstates = shallowcopy( buttonstates )

    for i = 0,5 do
        buttonstates[ i ] = btn( i )
    end

    function wentdown( btn )
        return buttonstates[ btn ] and not lastbuttonstates[ btn ]
    end

    function isdown( btn )
        return buttonstates[ btn ]
    end

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
            game_state = 'gameover'
        else
            update_input()
        end

    else -- game over, title

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

    local player = current_level.player

    -- draw player health

    local healthstepx = 8
    local health_left = 124 - ( player.max_health / 2 ) * healthstepx
    local health_top = 10
    for i = 0, player.max_health / 2 do
        local healthx = i * healthstepx

        local equivalent_health = i * 2

        local sprite = 0

        if equivalent_health + 1 < player.health then sprite = 1 
        elseif equivalent_health < player.health then sprite = 2 end

        if sprite > 0 then
            spr( sprite, health_left + healthx, health_top )
        end
    end

    -- draw player distance

    local dist = player_run_distance()
    draw_shadowed( 124, 2, 0, 1, 2, function(x,y)
        print_rightaligned_text( '' .. player.coins, x, y, 10 )
    end )

    -- draw player coins

    draw_shadowed( 124, 2, 0, 1, 2, function(x,y)
        print_rightaligned_text( '' .. player.coins, x, y, 10 )
    end )

    -- draw debug

    if true then
        draw_shadowed( 124, 120, 0, 1, 2, function(x,y)
            print_rightaligned_text( 'actors: ' .. #current_level.actors, x, y, 6 )
            print_rightaligned_text( 'segmts: ' .. #current_level.mapsegments, x, y - 8, 6 )
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
end

__gfx__
000000000880880008800000000004000000000000000000700000000000000000990000400000007600000007607600700a0000000000000000000000000000
0000000087888820878800000999099009900000007770006740000004444200097a400044444000666000007d666d60a7900000000000000000000000000000
007007008888882088882000979999909799000007aaaa00044400004477942097aaa00007004400064000006dddd1d00aa90000000000000000000000000000
00077000888882208888200099499940999400000aaaaa0004442000499988209aa4a400007004000004c0001766661090944000000000000000000000000000
000770000888220008822000944444009940000009aaa900002220004298822004aa990000070400000c4cd006dd1d0000004400000000000000000000000000
0070070000222000002200009400000094000000009990000000dd004422222000094900000062000000c2d006111d0000000420000000000000000000000000
000000000002000000020000044400000444000000000000000006000222220000000900000002200000cd0000ddd00000000020000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
044444400000b000004000007000000000000000700a0000000b0000000dd0000000000000000000000000000000000000000000000000000000000000000000
44444444008b80000990000067e00000007cc0000a7a9000044b30000000dd000077700000000000000000000000000000000000000000000000000000000000
4111414108788200049000000eee000007cccd0009a9aa000045300000777d100766660000000000000000000000000000000000000000000000000000000000
1176176108888200049900000eee20000ccccd007a9a4a000004400007dddd100666660000000000000000000000000000000000000000000000000000000000
416616610882220000499420002220000cccdd000aa4a490000055000dddd1100d666d0000000000000000000000000000000000000000000000000000000000
4f11f11400222000000222000000dd0000f4400000994900000005000011110000ddd00000000000000000000000000000000000000000000000000000000000
4ff777f0000000000000000000000600000000000004900000000000000000000000000000000000000000000000000000000000000000000000000000000000
40f77ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00044400044440000044000000044400044440000004400000044400044440000044000000044400044440000004400011111111111010100000000000000000
00444f004444f0ff4444400000444f004444f0440444440000444f004444f0ff4444400000444f004444f0dd0444440011111111010101010000000000000000
0444ff00444ff0ff4444f0000444ff00444ff04404444f000444ff00444ff0f74444f0000444ff00444ff0d104444f0011111110101010000000000000000000
044fff0000fff00f044ff000044fff0000fff0040044ff00044fff0000fff006044ff000044fff0000fff0010044ff0011110101000000000000000000000000
000fff0044ffffff00fff000000fff00fffff444000fff0000076600d176676600fff00000076600767661110007660011101010000000000000000000000000
004fff0040ff400000fff0f000ffff00f04ff000000fff040016760010666000007660f000766600606660000006760d11110000000000000000000000000000
004fff0040fff00000fffff000ffff00f0fff000000fff4400166600106660000067667000f66600f06660000006661d11101000000000000000000000000000
000fff0000fff00000fff000000fff0000fff000000fff0000066600006660000066600000066600006660000006660011010000000000000000000000000000
000eee0000eee00000eee200000eee0000eee000000eee00000ddd0000ddd00000ddd100000ddd0000ddd000000ddd0010100000000000000000000000000000
000eee2000eee20000eeee20000eeee000eeee00002eeee0000766d0007661000076661000076660007666000017666011000000000000000000000000000000
000ee82008ee222000eeee80000ee880022ee880002eee80000666d0076611d00066666000066660011666600016666010100000000000000000000000000000
00088840088e0244fff888800002e8f0022288ff4442e880000666d007660ddddd76666000017660011167661111676001000000000000000000000000000000
0044f4400f80044000ffff4000fffff004200ff0004448f0001176d006600dd0006666d000ddd6600d10066000ddd66010000000000000000000000000000000
0000f000ff00440000000040000040004400ff00000000f000006000d6001100000000d0000010001d00dd000000006001000000000000000000000000000000
0000f000f000400000000040000040004000f000000000f00000d000d000100000000010000010001000d000000000d010000000000000000000000000000000
0000ff00f0000000000000440000440040000000000000ff0000dd00d0000000000000110000110010000000000000dd01000000000000000000000000000000
80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888000088a8a0000888000088a8a0000088800088a8a0000777000077777000000000000000000000000000000000000000000000000000000000000000000
08888888008888820888888800888882088888880088888207777777007777770000000000000000000000000000000000000000000000000000000000000000
00088888888888000800088888888800880008888888880007000777777777000000000000000000000000000000000000000000000000000000000000000000
00028888888882220080028888888000000000888888822200700777777770000000000000000000000000000000000000000000000000000000000000000000
00288888888888820000002888888000000000888888888200000077777770000000000000000000000000000000000000000000000000000000000000000000
02888000888880820000000082280000000000822088008200000000777700000000000000000000000000000000000000000000000000000000000000000000
88800000000000800000000002080000000000880000008000000000070700000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b000000000b00000b0000dddd0000111111110111111111111000011110000000000000000000000000000000000000000000000000000000000000000000
0b3bb0000000bb3b000bb0006666ddddbb33bb331bb3bb33bb3331001bb331000000000000000000000000000000000000000000000000000000000000000000
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
000000bbbb3bbbb333bbbbbbb00b000000d611dd11dd11d4444000040066411dddddddd000000000000000000000000000000000000000000000000000000000
000000bbb3bbb3333bbbbbb3330bbbbb4066644ddddddd44d44ddd444446ddddddddddd000000000000000000000000000000000000000000000000000000000
00000bbbbbb3333bbbbbb33000bbbb0044466d41ddddd144d14dd4400441dddddddddddd00000000000000000000000000000000000000000000000000000000
0000bb3bbbbbbbbbbbbb3300bbbbb00004441d11ddddd11dd11d14d00611dddddddddddd00000000000000000000000000000000000000000000000000000000
000bb33bb3333bbbb3333333bb33003000611ddddddddddddddd11dd0666dddddddddddd00000000000000000000000000000000000000000000000000000000
00bb3bb3333bbb3333333bbbb33bb30b0666dddddddddddddddddddd006dddddddddddd000000000000000000000000000000000000000000000000000000000
bbbbbbbbb3bbbbbb33bbbbbbbbbbb33b0000dddddddddddddd00000000000dddddddd00000000000000000000000000000000000000000000000000000000000
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
00000440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00004444400000000000000044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00044444f00000000000004444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000444ff00000000000000444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000fff00000000000004444444f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0444fff0000000000000000044fff0ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ffffff00000000004442ffff0ff000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000fff0000000000000040ffffffff000ff440000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00eee0000000000000000eefff000000f44400000044000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00eeee00000000000400eeeef0000000ff00000000444400000000000044000000000000fff00000000000000000000000000000000000000000000000000000
022ee8800000000004488eee000000004ff8800000444ff000000000004440000000000eeff00000000000000000000000000000000000000000000000000000
022288ff00000000004f8ee20000000004f8eeefff444ff000000000000444000000000eefff4000000000eeeff0000000000000000000000000000000000000
04200ff00000000000ff8e20000000000448eeefff4440f0044000eeff044400000000eeefff440000000eeeefff44000000000eef0f44000000000000000000
4400ff00000000000ff02200000000000002eeeffffffff0ff40eeeeffff4400000000eeeeff44000fff88eeffffff00000088eeeffff4000000000000000000
4000f000000000000f000000000000000000000000ff40000ff488eeffff444000040088e0fff4400000282244fff4ff00fff8eeefffff400000000000000000
40000000000000000f00000000000000000000000000000000fff880000fffff00fffff88000ffff0ffff20000444400444448e2244fffff0000000000000000
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
00010000146200f6200e6200f6201562016620136200c6200162018600156000e60001600221002510013000291002d1002e100100001d1001f1000d000201002110021100210002210022100221001300022100
001100000935509345093550934509355093450935509345053550534505355053450535505345053550534502355023450235502345023550234502355023450235502345023550234502355023450235502345
011100001825518235182551823518255182351825518235182551823518255182351825518235182551823515255152351525515235152551523515255152351525515235152551523515255152351525515235
00110000073550734507355073450735507345073550734500355003450035500345003550034500355003450a3550a3450a3550a3450a3550a3450a3550a3450c3550c3450c3550c3450c3550c3450c3550c345
011100001625516235162551623516255162351625516235132551323513255132351325513235132551323511255112351125511235112551123511255112351525515235152551523515255152351525515235
011100000535505345053550534505355053450535505345053550534505355053450535505345053550534505355053450535505345053550534505355053450535505345053550534505355053450535505345
001100001525515235152551523515255152351525515235152551523515255152351525515235152551523515255152351525515235152551523515255152351525515235152551523515255152351525515235
011100001805318053000002400030643000000000018053180530000018053000003063330603306033061318053180530000024000306430000000000180531805300000180530000030633306330000000000
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
000200000c6600c6600c6600c6200c6600c6600c6600c6600c6600c6600c6500464005630066200b610246201d62016620126200f6200b61007610046100261001600016002d6002a6002860026600246000c050
__music__
01 01024344
00 01024542
00 03044544
00 05064344
03 01024307
02 01024307

