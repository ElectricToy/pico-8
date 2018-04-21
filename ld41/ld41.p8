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

    return  edges_overlap( recta.x, recta.x + recta.w, rectb.x, rectb.x + rectb.w )
        and edges_overlap( recta.y, recta.y + recta.h, rectb.y, rectb.y + rectb.h )
end

local shadow_y_divisor = 6

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

    for call in all( self.pending_calls ) do
        if now >= call.deadline then
            call.fn()
            del( self.pending_calls, call )
        end
    end
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
    self:update_coins()

    self:update_collision()

    -- update actors and remove dead ones
    for actor in all( self.actors ) do
        actor:update( deltatime )
        if not actor.active then
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

local frame = inheritsfrom( nil )
function frame:new( sprite )
    local newobj = { 
        sprite = sprite
    }
    return setmetatable( newobj, self )
end

local animation = inheritsfrom( nil )
function animation:new( min, count, ssizex, ssizey )
    count = count or 1
    local newobj = { 
        frames = {},
        current_frame=1,
        frame_rate_hz=10,
        ssizex = ssizex or 1,
        ssizey = ssizey or ssizex or 1,
    }

    for i = 0, count - 1 do
        newobj.frames[ i + 1 ] = frame:new( min + i * newobj.ssizex )
    end

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
        active = true,
        pos = vector:new( x or 0, y or x or 0 ),
        vel = vector:new( 0, 0 ),
        offset = vector:new( 0, 0 ),
        collision_size = vector:new( wid or 0, hgt or 0 ),
        collision_planes_inc = 1,
        collision_planes_exc = 15,
        do_dynamics = false,
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
    return self:collision_ul() + self.collision_size * 0.5
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

        local footheight = self:collision_br().y
        if self.does_collide_with_ground and footheight >= 0 then
            self.pos.y = -self.collision_size.y
            self.vel.y = 0
        end
    end

    -- die if too far left
    if self.pos.x < self.level.player.pos.x - 96 then
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

function actor:grounded()
    -- todo platforms
    return self:collision_br().y >= -0.1
end

function actor:jump( amount )
    if not self:grounded() then return end

    self.vel.y = -self.jumpforce * ( amount or 1.0 )
end

function actor:draw()
    local anim = self:current_animation()
    if anim ~= nil then 
        local drawpos = self.pos + self.offset
        local frame = anim:frame()
        spr( frame.sprite, drawpos.x, drawpos.y, anim.ssizex, anim.ssizey )

        --draw shadow
        if self.want_shadow then
            draw_color_shifted( -4, function()
                spr( frame.sprite, drawpos.x, (-drawpos.y)/shadow_y_divisor+6, anim.ssizex, anim.ssizey, false, true )
            end )
        end
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
    -- newobj.vel.x = 1     -- todo!!!
    newobj.animations[ 'run' ] = animation:new( 32, 6 ) 
    newobj.current_animation_name = 'run'
    newobj.collision_planes_exc = 0

    newobj.leg_anim = animation:new( 48, 6 )

    newobj.coins = 0
    newobj.max_health = 6
    newobj.health = newobj.max_health

    newobj.reach_distance = 12
    
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
    return self.health <= 0
end

function player:die()
    if self:dead() then return end

    -- todo
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

        local legpos = self.pos + self.offset + vector:new( 0, 8 )

        local leganim = self.leg_anim:frame()
        spr( leganim.sprite, legpos.x, legpos.y )

        draw_color_shifted( -4, function()
            spr( leganim.sprite, legpos.x, (-legpos.y)/shadow_y_divisor, 1, 1, false, true )
        end )
    end
end

function player:on_collision( other )
    if other.damage > 0 then
        self:take_damage( other.damage )
    end
end

-- stone

local stone = inheritsfrom( actor )
function stone:new( level, x, y )
    local newobj = actor:new( level, x, y, 0, 0 )
    newobj.animations[ 'idle' ] = animation:new( 164, 1, 3, 2 ) 
    newobj.current_animation_name = 'idle'
    newobj.offset.x = -4
    newobj.offset.y = -4
    newobj.collision_size.x = 16
    newobj.collision_size.y = 12

    return setmetatable( newobj, self )        
end

-- coin

local coin = inheritsfrom( actor )
function coin:new( level, x, y )
    local newobj = actor:new( level, x, y, 4, 4 )
    newobj.animations[ 'idle' ] = animation:new( 20 ) 
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
    if self.pos.x < self.level.player.pos.x - 96 then
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

function level:update_props()
    
    if pctchance( 1 ) then
        stone:new( self, self.player.pos.x + 96, 0 )
    end
end

function level:update_coins()
    if pctchance( 2 ) then
        coin:new( self, self.player.pos.x + 96, randinrange( -48, -4 ) )
    end
end

-->8
--jeff's code

--level creation
local current_level = level:new()
current_level.player = player:new( current_level )

function player_run_distance()
    return ( current_level.player.pos.x - 0 ) / 100
end

--main loops
local buttonstates = {}
function _update60()

    function update_input()
        local player = current_level.player
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

        if wentdown(4) then
            player:jump()
        end

        if wentdown(5) then
            player:grab()
        end

        local move = 0
        if isdown( 0 ) then
            move += -1
        end
        if isdown( 1 ) then
            move += 1
        end
        player.vel.x = move
    end

    update_input()
    current_level:update()
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
        end )
    end
end

function _draw()

    -- world

    current_level:draw()

    -- ui

    camera( 0, 0 )

    draw_ui()

    print( debug_text, 8, 8, 8 )
    print( '', 0, 16 )

end


__gfx__
00000000088088000880000000000400000000000000000070000000000000000099000040000000760000000760760000000000000000000000000000000000
0000000087888820878800000999099009900000007770006740000004444200097a400044440000666000007d666d6000000000000000000000000000000000
007007008888882088882000979999909799000007aaaa00044400004477942097aaa00070044000064000006dddd1d000000000000000000000000000000000
00077000888882208888200099499940999400000aaaaa0004442000499988209aa4a400070040000004c0001766661000000000000000000000000000000000
000770000888220008822000944444009940000009aaa900002220004298822004aa990000704000000c4cd006dd1d0000000000000000000000000000000000
0070070000222000002200009400000094000000009990000000dd004422222000094900000620000000c2d006111d0000000000000000000000000000000000
000000000002000000020000044400000444000000000000000006000222220000000900000022000000cd0000ddd00000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
044444400000b000004000007000000000000000700a0000000b0000000dd0000000000000000000000000000000000000000000000000000000000000000000
44444444008b80000990000067e00000007cc0000a7a9000044b30000000dd000077700000000000000000000000000000000000000000000000000000000000
4111414108788200049000000eee000007cccd0009a9aa000045300000777d100766660000000000000000000000000000000000000000000000000000000000
1176176108888200049900000eee20000ccccd007a9a4a400004400007dddd100666660000000000000000000000000000000000000000000000000000000000
416616610882220000499420002220000cccdd000aa4a490000055000dddd1100d666d0000000000000000000000000000000000000000000000000000000000
4f11f11400222000000222000000dd0000f4400000994a00000005000011110000ddd00000000000000000000000000000000000000000000000000000000000
4ff777f0000000000000000000000600000000000004900000000000000000000000000000000000000000000000000000000000000000000000000000000000
40f77ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00044400044440000044000000044400044440000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444f004444f0ff4444400000444f004444f0440444440000000000000000000000000000000000000000000000000000000000000000000000000000000000
0444ff00444ff0ff4444f0000444ff00444ff04404444f0000000000000000000000000000000000000000000000000000000000000000000000000000000000
044fff0000fff00f044ff000044fff0000fff0040044ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000
000fff0044ffffff00fff000000fff00fffff444000fff0000000000000000000000000000000000000000000000000000000000000000000000000000000000
004fff0040ff400000fff0f000ffff00f04ff000000fff0400000000000000000000000000000000000000000000000000000000000000000000000000000000
004fff0040fff00000fffff000ffff00f0fff000000fff4400000000000000000000000000000000000000000000000000000000000000000000000000000000
000fff0000fff00000fff000000fff0000fff000000fff0000000000000000000000000000000000000000000000000000000000000000000000000000000000
000eee0000eee00000eee200000eee0000eee000000eee0000000000000000000000000000000000000000000000000000000000000000000000000000000000
000eee2000eee20000eeee20000eeee000eeee00002eeee000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ee82008ee222000eeee80000ee880022ee880002eee8000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088840088e0244fff888800002e8f0022288ff4442e88000000000000000000000000000000000000000000000000000000000000000000000000000000000
0044f4400f80044000ffff4000fffff004200ff0004448f000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000f000ff00440000000040000040004400ff00000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000f000f000400000000040000040004000f000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ff00f0000000000000440000440040000000000000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000
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
000b000000000b00000b0000dddd0000222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b3bb0000000bb3b000bb0006666ddddaa99aa990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00b3bb00000bb3b000b3b00066666666222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b3b33bb000b333bb0b3b3b006666666699aa99aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b3bb33b0b0bbb300033b0006666666699aa99aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00b33b0000b33300003b000066666666aa99aa990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b3bb300bb3bbbbb0bb5000066666666998899880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00b3bbb000b333b00004000066666666111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb3b300000005b300000000066666666022220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b33bb00000bb30000000000666666662aa99a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bb30000bb33bbb00000000666666662a9222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005bbb0000bb3300000000066666666292aa9810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005000000b35bbb0000000066666666292aa9810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000000500000000000666666662a299a910000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000000400000000000dddd6666092889910000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000004000000000000000dddd000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000bbb00000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000b00000bbbbbbbb0000000004000400000004400000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000b00bb0000bb33bbb000000000044400440000044000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000bbb33000bbbbbbb000000000000444d446640440000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000bb33030bbbb3300000000000004d446444644440000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000bb33000bbb33030bbbbbbb04400d6442644644600400000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb3300bbb33000bbbbb0000044464622d22d44d00400000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb3bbbbb3300bbbbbb0000000444444dddd44dd00440000000000000000000000000000000000000000000000000000000000000000000000000000
0000000bbb33bbbb3333bbbbbb0b0000000442d442dd24dd40440000000000000000000000000000000000000000000000000000000000000000000000000000
000000bbbb3bbbb333bbbbbbb00b000000d622dd22dd22d444400004000000000000000000000000000000000000000000000000000000000000000000000000
000000bbb3bbb3333bbbbbb3330bbbbb4066644ddddddd44d44ddd44000000000000000000000000000000000000000000000000000000000000000000000000
00000bbbbbb3333bbbbbb33000bbbb0044466d42ddddd244d24dd440000000000000000000000000000000000000000000000000000000000000000000000000
0000bb3bbbbbbbbbbbbb3300bbbbb00004442d22ddddd22dd22d24d0000000000000000000000000000000000000000000000000000000000000000000000000
000bb33bb3333bbbb3333333bb33003000622ddddddddddddddd22dd000000000000000000000000000000000000000000000000000000000000000000000000
00bb3bb3333bbb3333333bbbb33bb30b0666dddddddddddddddddddd000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbb3bbbbbb33bbbbbbbbbbb33b0000dddddddddddddd000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00010000146200f6200e6200f6201562016620136200c6200162018600156000e60001600221002510013000291002d1002e100100001d1001f1000d000201002110021100210002210022100221001300022100
001000000c0530c0530c0550c0530c0530c0550c0530c0530f0530f0530f0550f0530f0530f0550f0530f05311053110531105511053110531105511053110531305313053130551305313053130551305313053
011000001865300003000031865300003000031865300003186530000300003186530000300003186530000318653000030000318653000030000318653000031865300003186501865318650000031865300003
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110000030050300502e0502e050290502b0502905027050270502705024050240500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002b0512b0511f0511f05127051270512705124051240512405124051240510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 01424344
02 01444502
00 01040544

