pico-8 cartridge // http://www.pico-8.com
version 14
__lua__
-- general utilities

debug_text = ''
function debug_print( text )
    debug_text = text
end

function del_index( table, index )
    del( table, table[ index ])
end

function spritesheet_rectfill( left, top, right, bottom, color )
    for y = top,bottom do
        for x = left,right do
            sset( x, y, color )
        end
    end
end

function rel_color( base, change )
    local brighten_table = { 5, 13, 8, 11, 8, 6, 7, 7, 14, 10, 7, 7, 6, 12, 15, 7 }

    local darken_table = { 0, 0, 0, 0, 0, 0, 5, 6, 2, 4, 9, 3, 13, 1, 8, 14 }

    if change == 0 then 
        return base
    elseif change > 0 then
        return rel_color( brighten_table[base+1], change - 1 )
    else
        return rel_color(   darken_table[base+1], change + 1 )
    end
end

function draw_shadowed( x, y, offsetx, offsety, darkness, fn )
    for i = 0,15 do
        pal( i, rel_color( i, -darkness ))
    end

    fn( x + offsetx, y + offsety )

    pal()

    fn( x, y )
end

function print_centered_text( text, y, color )
    print( text, 64 - #text / 2 * 4, y, color )
end

local hiss_hosts = {}

function play_hiss( host )
    sfx( 9, 3 )
    add( hiss_hosts, host )    
end

function stop_hiss( host )
    del( hiss_hosts, host )

    if #hiss_hosts == 0 then
        sfx( -1, 3 )
    end
end

function stop_all_hiss()
    hiss_hosts = {}
    sfx( -1, 3 )
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
    local newobj = { x = x, y = y ~= nil and y or x }
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

function vector:component( index )
    return index ~= 0 and self.y or self.x
end

function vector:set_component( index, value )
    if index ~= 0 then
        self.y = value
    else
        self.x = value
    end
end

function vector:lerp( to, alpha )
    return vector:new( lerp( self.x, to.x, alpha ), lerp( self.y, to.y, alpha ))
end

-- math

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

function maptoworld( mappos )
    return mappos * vector:new( 8 )
end

function worldtomap( pos )
    return vector:new( flr( pos.x / 8 ), flr( pos.y / 8 ))
end

-- physics

local body = inheritsfrom( nil )
local max_body_speed = 3
local max_body_speed_squared = max_body_speed * max_body_speed

function body:new( level, x, y, radius )
    assert( radius >= 0 )

    local newobj = { 
        level = level,
        alive = true,
        pos = vector:new( x, y ),
        vel = vector:new( 0, 0 ),
        acc = vector:new( 0, 0 ),
        mass = 1.0,
        radius = radius,
        drag = 0.015,
        does_collide_bodies = true,
        does_collide_map = true,
        restitution = 0.95,
        explosion_power = 200,
        min_explosion_particles = 20,
        max_explosion_particles = 20,
        explosion_particle_class = nil,
        explosion_particle_vis_class = nil,
        is_target = false,
        want_dynamics = true,
        lerp_to_location = nil,
        shadowed_amount = 0,
        lerp_to_shadowed_amount = nil,
        explosion_sfx = 3,
        make_collision_sounds = true,

        min_impulse_for_trigger = nil,
        trigger_time = nil,
        trigger_explosion_delay = 2,
    }

    add( level.bodies, newobj )

    return setmetatable( newobj, self )
end

function body:currentdrag()
    -- local grounddrag = is_water( worldtomap( self.pos )) and 0.25 or 0
    -- return clamp( self.drag + grounddrag, 0, 1 )
    return self.drag        -- todo
end

function body:local_map_pos()
    return worldtomap( self.pos )
end

function body:trigger()
    if not self.alive then return end
    if self.trigger_time ~= nil then return end
    self.trigger_time = self.level:time()

    if self.trigger_explosion_delay > 0.1 then
        play_hiss( self )
    end
end

function body:be_swallowed_by_hole( local_map_location, mapsprite )
    local hole_center_per_sprite_index = {}
    hole_center_per_sprite_index[ 110 ] = vector:new( 1, 1 )
    hole_center_per_sprite_index[ 111 ] = vector:new( 0, 1 )
    hole_center_per_sprite_index[ 126 ] = vector:new( 1, 0 )
    hole_center_per_sprite_index[ 127 ] = vector:new( 0, 0 )

    local hole_center_offset = hole_center_per_sprite_index[ mapsprite ]
    local hole_center = local_map_location + hole_center_offset

    self.want_dynamics = false
    self.does_collide_map = false
    self.does_collide_bodies = false
    self.lerp_to_location = maptoworld( hole_center ) + vector:new( 0, 0.8 )
    self.lerp_to_shadowed_amount = -3

    self.level:after_delay( 0.15, function() 
        sfx( 0 )
    end )

    self.level:on_hole_scored()
end

function body:active()
    return self.alive and ( self.vel:length() > 0.02 or self.acc:length() > 0 or self.trigger_time ~= nil )
end

function body:detect_hole_collision()
    if not self.is_target then return end

    local local_map_location = self:local_map_pos()
    local global_map_location = self.level:maplocaltoglobal( local_map_location )
    local mapsprite = mget( global_map_location.x, global_map_location.y )

    if fget( mapsprite, 6 ) then
        -- todo
        self:be_swallowed_by_hole( local_map_location, mapsprite )
    end
end

function body:update()

    if not self.alive then return end

    if self.lerp_to_shadowed_amount then
        self.shadowed_amount = lerp( self.shadowed_amount, self.lerp_to_shadowed_amount, 0.01 )
    end

    if self.want_dynamics then
        local drag = self:currentdrag()

        self.acc = self.acc - self.vel * vector:new( drag, drag )
        self.vel = self.vel + self.acc

        -- clamp velocity to a maximum
        if self.vel:lengthsquared() > max_body_speed_squared then
            self.vel = self.vel:normal() * vector:new( max_body_speed, max_body_speed )
        end

        -- cut off minimal velocity
        local min_velocity = 0.01
        if self.vel:manhattanlength() < min_velocity then
            self.vel = vector:new( 0, 0 )
        end

        self.pos = self.pos + self.vel

        self.acc.x = 0
        self.acc.y = 0

        self:detect_hole_collision()

        -- update trigger
        if self.trigger_time ~= nil and 
            ( self.level:time() - self.trigger_time > self.trigger_explosion_delay ) then
            self:explode()
        end

    else
        if self.lerp_to_location then
            self.pos = self.pos:lerp( self.lerp_to_location, 0.1 )
        end
    end
end

function body:shouldcollidewithmapsprite( mapsprite )
    return fget( mapsprite, 7 )
end

function collision_normal_simple( delta, overlaps )
    local normal_axis = abs( delta.x ) > abs( delta.y ) and 0 or 1
    local axial_dist = delta:component( normal_axis )
    local normal_sign = sign( axial_dist )
    local normal = vector:new( 0, 0 )
    normal:set_component( normal_axis, normal_sign )

    return normal, normal_axis
end

function body:find_collision_normal( rectcenter, rectsize )

    local delta = self.pos - rectcenter

    if delta:manhattanlength() == 0 then 
        return delta, 0, 0
    end

    local axial_distances = vector:new( abs( delta.x ), abs( delta.y ))

    local overlaps = rectsize * vector:new( 0.5 ) + vector:new( self.radius ) - axial_distances

    local normal, normal_axis = collision_normal_simple( delta, overlaps )

    return normal, normal_axis, overlaps:component( normal_axis ) + 0.1
end


function body:resolve_rect_collision( rectul, rectbr )
    -- find the collision normal

    local rectcenter = (rectul + rectbr) * vector:new( 0.5 )
    local rectsize = rectbr - rectul 

    local normal, normal_axis, adjustmentdist = self:find_collision_normal( rectcenter, rectsize )

    -- don't act if we're already going this way
    if normal:dot( self.vel ) > 0 then return end

    local force = self.vel:length()

    -- move the body back out
    self.pos += normal * vector:new( adjustmentdist )
    self.vel:set_component( normal_axis, self.vel:component( normal_axis ) * -self.restitution )

    if self.make_collision_sounds then
        local sound = force >= 1 and 7 or 8
        sfx( sound )
    end
end

function body:resolve_map_collision( levelmapx, levelmapy )
    self:resolve_rect_collision( 
        vector:new( ( levelmapx + 0 ) * 8, ( levelmapy + 0 ) * 8 ), 
        vector:new( ( levelmapx + 1 ) * 8, ( levelmapy + 1 ) * 8 ))
end

function body:explode()
    if not self.alive then return end

    things_exploded += 1

    -- apply a force to all other bodies
    self.level:apply_explosion_force( self.pos, self.explosion_power )

    self.alive = false
    stop_hiss( self )

    -- create chunks

    -- create particles
    if self.explosion_particle_class and self.explosion_particle_vis_class then
        self.level:create_bodies( 
            randinrange( self.min_explosion_particles, self.max_explosion_particles ), 
            self.pos, 
            self.explosion_particle_class, 
            self.explosion_particle_vis_class, 
            0, 5 )
    end

    -- create scorch marks

    -- sfx
    sfx( self.explosion_sfx )
end

function axial_step( left, right, top, bot, vel, fn )
    local stepx = sign_no_zero( vel.x )
    local stepy = sign_no_zero( vel.y )

    local startx = stepx > 0 and left or right
    local endx = stepx > 0 and right or left
    local starty = stepy > 0 and top or bot
    local endy = stepy > 0 and bot or top

    if abs( vel.x ) > abs( vel.y ) then
        for y = starty, endy, stepy do
            for x = startx, endx, stepx do
                fn( x, y )
            end
        end
    else
        for x = startx, endx, stepx do
            for y = starty, endy, stepy do
                fn( x, y )
            end
        end
    end
end

function body:updateworldcollision( level )

    if not self.does_collide_map then return end

    local center = self.pos
    local offset = vector:new( self.radius, 0 )

    -- find the four corners in map space.
    local left = flr(( center.x - self.radius ) / 8 )
    local top  = flr(( center.y - self.radius ) / 8 )
    local right= flr(( center.x + self.radius ) / 8 )
    local bot  = flr(( center.y + self.radius ) / 8 )

    axial_step( left, right, top, bot, self.vel, function( x, y )
        local global_map_location = level:maplocaltoglobal( vector:new( x, y ))

        local mapsprite = mget( global_map_location.x, global_map_location.y )
        if self:shouldcollidewithmapsprite( mapsprite ) then
            self:resolve_map_collision( x, y )
        end
    end)

end

function body:addimpulse( impulse )
    if self.mass > 0 then
        self.acc = self.acc + impulse / vector:new( self.mass, self.mass )

        if self.min_impulse_for_trigger ~= nil and impulse:length() > self.min_impulse_for_trigger then
            self:trigger()
        end
    end
end

-- rendering

local vis = inheritsfrom( nil )

function vis:new( level, body, offset )
    local newobj = { 
        body = body,
        offset = offset
    }

    add( level.visualizations, newobj )

    return setmetatable( newobj, self )
end

function vis:alive()
    return self.body and self.body.alive
end

function vis:draw()
    if not self:alive() then return end
end

local ballvis = inheritsfrom( vis )

function ballvis:new( level, body, basecolor )
    local newobj = vis:new( level, body )
    newobj.basecolor = basecolor
    return setmetatable( newobj, self )
end

function ballvis:draw()
    if not self:alive() then return end

    local base_color_offset = flr( self.body.shadowed_amount )

    local p = self.body.pos + ( self.offset or vector:new( 0 ))
    local r = self.body.radius

    draw_shadowed( p.x, p.y, r/4*0.8, r/4, 2, function( x, y)
        circfill( x, y, r, rel_color( self.basecolor, base_color_offset ))
    end )

    circfill( p.x - 0.1*r, p.y - 0.15*r, r * 0.75, rel_color( self.basecolor, base_color_offset + 1 ))
    circfill( p.x - 0.2*r, p.y - 0.4*r, r * 0.25, rel_color( self.basecolor, base_color_offset + 2 ))
end


-- level
local level = inheritsfrom( nil )
function level:new( mapul )
    local newobj = { 
        bodies = {},
        visualizations = {},
        mapul = mapul,
        mapbr = mapul + vector:new( 16, 14 ),
        paused = false,
        pending_calls = {},
        tick_count = 0,
        cell_heights = {},
        cell_normals = {},
        started = false,
        dead_piggy_count = 0,
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

function level:size()
    return self.mapbr - self.mapul
end

function level:relative_cell_sprite( localcellpos, neighbordir )
    local levelsize = self:size()

    local cellpos = localcellpos + neighbordir
    if cellpos.x < 0 or cellpos.y < 0 or cellpos.x >= levelsize.x or cellpos.y >= levelsize.y then
        return 84 -- out of bounds is all ordinary barrier sprite
    end

    local global_map_location = self:maplocaltoglobal( cellpos )

    return mget( global_map_location.x, global_map_location.y )
end

function level:tidy_barrier_cell( localcellpos )
    local bitfield_to_sprite = {}

    -- bitfield is 1 for full and 0 for empty for n, e, s, w neighbors
    bitfield_to_sprite[ 0b0000 ] = 81
    bitfield_to_sprite[ 0b0001 ] = 82
    bitfield_to_sprite[ 0b0010 ] = 65
    bitfield_to_sprite[ 0b0011 ] = 66
    bitfield_to_sprite[ 0b0100 ] = 80
    bitfield_to_sprite[ 0b0101 ] = 112
    bitfield_to_sprite[ 0b0110 ] = 64
    bitfield_to_sprite[ 0b0111 ] = 68
    bitfield_to_sprite[ 0b1000 ] = 97
    bitfield_to_sprite[ 0b1001 ] = 98
    bitfield_to_sprite[ 0b1010 ] = 113
    bitfield_to_sprite[ 0b1011 ] = 85
    bitfield_to_sprite[ 0b1100 ] = 96
    bitfield_to_sprite[ 0b1101 ] = 100
    bitfield_to_sprite[ 0b1110 ] = 83
    bitfield_to_sprite[ 0b1111 ] = 84

    local nsolid = fget( self:relative_cell_sprite( localcellpos, vector:new( 0, -1 )), 7 ) and 1 or 0
    local esolid = fget( self:relative_cell_sprite( localcellpos, vector:new( 1,  0 )), 7 ) and 1 or 0
    local ssolid = fget( self:relative_cell_sprite( localcellpos, vector:new( 0,  1 )), 7 ) and 1 or 0
    local wsolid = fget( self:relative_cell_sprite( localcellpos, vector:new(-1,  0 )), 7 ) and 1 or 0

    local bits = 
        bor( shl( nsolid, 3 ),
            bor( shl( esolid, 2 ),
                bor( shl( ssolid, 1 ),
                    bor( shl( wsolid, 0 )))))

    local desiredsprite = bitfield_to_sprite[ bits ]

    local global_map_location = self:maplocaltoglobal( localcellpos )

    mset( global_map_location.x, global_map_location.y, desiredsprite )
end

function level:tidy_cell( localcellpos )    
    local mysprite = self:relative_cell_sprite( localcellpos, vector:new( 0 ))

    -- show proper form of barrier cells
    if fget( mysprite, 7 ) then
        self:tidy_barrier_cell( localcellpos )
    end
    if  fget( mysprite, 5 ) then
        self:tidy_grass_cell( localcellpos )
    end
end

function level:tidy()
    local levelsize = self:size()

    -- tidy cells
    for y = 0,levelsize.y do
        for x = 0, levelsize.x do
            self:tidy_cell( vector:new( x, y ))
        end
    end
end

function collidebodies( a, b )
    -- should collide?

    if not a.does_collide_bodies or not b.does_collide_bodies then return end

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
    --  return
    -- end

    -- reposition to not overlap.

    local adjustmentdist = overlapdistance + 1

    a.pos = a.pos - normal * vector:new( adjustmentdist * massproportionb, adjustmentdist * massproportionb )
    b.pos = b.pos + normal * vector:new( adjustmentdist * massproportiona, adjustmentdist * massproportiona )

    -- impulse to bounce velocity.

    local force = a.vel:dot( normal ) * a.mass + b.vel:dot( -normal ) * b.mass

    a:addimpulse( normal * vector:new( -force, -force ))
    b:addimpulse( normal * vector:new(  force,  force ))

    if a.make_collision_sounds and b.make_collision_sounds then
        local sound = force >= 1 and 4 or force >= 0.3 and 5 or force >= 0.1 and 6
        sfx( sound )
    end
end

function level:eachbody( apply )
    for body in all( self.bodies ) do
        if body.alive then
            apply( body )
        end
    end
end

function level:maplocaltoglobal( pos )
    return pos + self.mapul
end

function level:apply_explosion_force( pos, power )
    self:eachbody( function( body ) 
        local delta = body.pos - pos
        local distsquared = delta:lengthsquared()
        if distsquared == 0 then return end

        local normal = delta:normal()

        local adjustedpower = power / distsquared

        body:addimpulse( normal * vector:new( adjustedpower, adjustedpower ) )
    end )
end

function level:create_bodies( count, pos, klass, visklass, minspeed, maxspeed )
    for i = 1,count do
        local body = klass:new( self, pos.x, pos.y )
        local vis = visklass:new( self, body )

        local velangle = rnd()
        local speed = randinrange( minspeed, maxspeed )
        local vel = vector:new(sin( velangle ), cos( velangle ))
        vel *= vector:new( speed )

        body.vel = vel
    end
end

function level:updatecollisions()

    -- body-to-world collision
    self:eachbody( function( body )
        body:updateworldcollision( self )
    end )

    -- body-to-body collision

    for i = 1, #self.bodies - 1 do
        for j = i + 1, #self.bodies do
            collidebodies( self.bodies[ i ], self.bodies[ j ] )
        end
    end
end

function level:update()
    if self.paused then return end

    self.tick_count += 1

    self:update_pending_calls()

    self:eachbody( function( body )
        body:update()
    end )

    for iteration = 1,1 do
        self:updatecollisions()
    end

    -- remove dead bodies
    for body in all( self.bodies ) do
        body:update()
        if not body.alive then
            del( self.bodies, body )
        end
    end    
end

function level:draw()
    -- draw the map
    map( self.mapul.x, self.mapul.y, 0, 0, self.mapbr.x - self.mapul.x, self.mapbr.y - self.mapul.y )

    -- draw visualizations
    for visualization in all( self.visualizations ) do
        if not visualization:alive() then
            del( self.visualizations, visualization )
        end
        visualization:draw()
    end

end

function level:on_hole_scored()
    self.is_hole_scored = true
    self:after_delay( 1.5, function()
        self.is_hole_score_settled = true
    end)
end

function level:settled_state()

    if self.dead_piggy_count > 0 then
        return "lost", "killed_innocents"
    end

    if self.is_hole_score_settled then
        return "won"
    end

    if self.is_hole_scored then return "undecided" end

    if self.paused then return "undecided" end

    if not self.started then return "undecided" end

    local found_active_body = false

    self:eachbody( function( body )
        found_active_body = found_active_body or body:active()
    end)

    if found_active_body then return "undecided" end

    return "lost", "dormant"
end

-- shooter

local default_rot_speed = 0.001

local shooter = {
    active = true,
    angle = 0,
    dist = 20,
    power = 0.05,
    rot_speed = default_rot_speed,
    rot_acc = 0.0004,
}
function shooter:attach( level, ball )
    self.active = true
    self.level = level
    self.ball = ball
    self.updates = 0
    -- level.paused = true
end

function shooter:update()
    if not self.active then return end

    self.updates += 1

    local length_speed = 1

    local angle_delta = 0

    if btn(0) then
        angle_delta = self.rot_speed
    end
    if btn(1) then
        angle_delta = -self.rot_speed
    end
    if btn(2) then
        self.dist -= length_speed
    end
    if btn(3) then
        self.dist += length_speed
    end

    if angle_delta == 0 then
        self.rot_speed = default_rot_speed
    else
        self.angle += angle_delta
        self.rot_speed += self.rot_acc
        self.rot_speed = clamp( self.rot_speed, 0, 0.01 )
    end

    self.dist = clamp( self.dist, self.ball.radius + 6, 40 )

    if btnp( 4 ) then
        self:shoot()
    end
end

function shooter:delta()
    return vector:new( sin( self.angle ) * self.dist, cos( self.angle ) * self.dist )
end

function shooter:impulse()
    return self:delta() * -vector:new( self.power, self.power )
end

function shooter:position()
    return self.ball.pos + self:delta()
end

function shooter:shoot()
    sfx( 11 )

    self.level.started = true
    self.active = false

    self.ball:addimpulse( self:impulse() )

    shots_taken += 1

end

function shooter:draw()
    if not self.active then return end

    local ballpos = self.ball.pos
    local pos = self:position()
    local delt = self:delta()
    local normal = delt:normal()

    local circle_size = self.ball.radius + 3
    circ( ballpos.x, ballpos.y, circle_size, 6 )

    local dest = ballpos + normal * vector:new( circle_size + 1 )
    local dist = (dest - pos):length()

    -- draw dashed line
    local step = 3
    local step2 = step*2
    for i = wrap( self.updates * 0.2, 0, step2 ),dist,step2 do

        local p = pos - normal * vector:new( i, i )

        local adjustedstep = min( i + step, dist )

        local j = adjustedstep

        local q = pos - normal * vector:new( j, j )

        line( p.x, p.y, q.x, q.y, 6 )
    end

    circfill( pos.x, pos.y, 2, 6 )
    circfill( pos.x, pos.y, 1, 7 )

end

-- spritevis
local spritevis = inheritsfrom( vis )
function spritevis:new( level, body, sprite_frames, size )
    local newobj = vis:new( level, body )
    newobj.sprite_size = size or 1
    newobj.sprite_frames = sprite_frames
    newobj.flipx = false
    newobj.frame = 1
    newobj.frame_rate_hz = 8
    newobj.last_frame_change_time = nil
    return setmetatable( newobj, self )
end

function spritevis:current_frame()
    return self.sprite_frames[ self.frame ]
end

function spritevis:draw()
    if not self:alive() then return end

    -- time to change frames?
    local now = self.body.level:time()

    if self.last_frame_change_time == nil then
        self.last_frame_change_time = now
    end        

    if now >= self.last_frame_change_time + ( 1.0 / self.frame_rate_hz ) then
        self.frame += 1
        self.frame = wrap( self.frame, 1, #self.sprite_frames + 1 )
        self.last_frame_change_time = now
    end

    local sprite = self:current_frame()

    if not sprite then return end

    local p = self.body.pos + ( self.offset or vector:new( 0 ))
    local ul = p - vector:new( self.sprite_size * 8 * 0.5 )

    draw_shadowed( ul.x, ul.y, 0, 1, 1, function( x, y )
        spr( sprite, x, y, self.sprite_size, self.sprite_size, self.flipx )
    end )
end

-- particle

local particle = inheritsfrom( body )
function particle:new( level, x, y )
    local newobj = body:new( level, x, y, 0 )
    newobj.drag = 0.05
    newobj.min_impulse_for_trigger = nil
    newobj.does_collide_bodies = false
    newobj.does_collide_map = true
    newobj.make_collision_sounds = false
    return setmetatable( newobj, self )
end

local particle_vis = inheritsfrom( vis )
function particle_vis:new( level, body, color )
    local newobj = vis:new( level, body )
    newobj.color = color
    return setmetatable( newobj, self )
end

function particle_vis:draw()
    if not self:alive() then return end
    pset( self.body.pos.x, self.body.pos.y, self.color )
    -- circfill( self.body.pos.x, self.body.pos.y, 0.5, self.color )
    -- local x = flr( self.body.pos.x )
    -- local y = flr( self.body.pos.y )
    -- rectfill( x, y, x+0.5, y+0.5, self.color )
end

local explosion_particle_vis = inheritsfrom( particle_vis )
function explosion_particle_vis:new( level, body )
    local newobj = particle_vis:new( level, body, 5 )
    return setmetatable( newobj, self )
end

-- flamevis
local flamevis = inheritsfrom( spritevis )
function flamevis:new( level, body )
    local newobj = spritevis:new( level, body, { 6, 8 }, 2 )
    newobj.offset = vector:new( 0, -8 )
    return setmetatable( newobj, self )
end

function flamevis:draw()
    if not self:alive() then return end
    if self.body.trigger_time == nil then return end

    self:superclass().draw(self)
end

-- barrelvis
local barrelvis = inheritsfrom( spritevis )
function barrelvis:new( level, body )
    local newobj = spritevis:new( level, body, { 4 }, 2 )
    newobj.flame = flamevis:new( level, body )
    return setmetatable( newobj, self )
end

-- barrel
local barrel = inheritsfrom( body )
function barrel:new( level, x, y )
    local newobj = body:new( level, x, y, 8 )
    newobj.drag = 0.05
    newobj.min_impulse_for_trigger = 0.25
    newobj.explosion_power = 800
    newobj.explosion_sfx = 1
    newobj.explosion_particle_class = particle
    newobj.explosion_particle_vis_class = explosion_particle_vis
    newobj.mass = 1.5

    barrelvis:new( level, newobj )

    return setmetatable( newobj, self )
end    

-- cueball
local cueball = inheritsfrom( body )
function cueball:new( level, x, y )
    local newobj = body:new( level, x, y, 4 )
    ballvis:new( level, newobj, 6 )

    newobj.min_impulse_for_trigger = nil
    newobj.explosion_particle_class = particle
    newobj.explosion_particle_vis_class = explosion_particle_vis
    newobj.explosion_sfx = 2

    shooter:attach( level, newobj )

    return setmetatable( newobj, self )
end

-- targetball
local targetball = inheritsfrom( body )
function targetball:new( level, x, y )
    local newobj = body:new( level, x, y, 4 )
    ballvis:new( level, newobj, 8 )

    newobj.min_impulse_for_trigger = nil
    newobj.is_target = true
    newobj.mass = 0.75
    return setmetatable( newobj, self )
end

-- heavyball
local heavyball = inheritsfrom( body )
function heavyball:new( level, x, y )
    local newobj = body:new( level, x, y, 6 )
    ballvis:new( level, newobj, 1 )
    newobj.min_impulse_for_trigger = nil
    newobj.mass = 2
    return setmetatable( newobj, self )
end

-- firecracker
local firecracker = inheritsfrom( body )
function firecracker:new( level, x, y )
    local newobj = body:new( level, x, y, 2 )
    ballvis:new( level, newobj, 9 )
    newobj.min_impulse_for_trigger = 0.15
    newobj.trigger_explosion_delay = randinrange( 0.5, 1.0 )
    newobj.mass = 0.5
    newobj.explosion_power = 250
    newobj.explosion_sfx = 3
    newobj.explosion_particle_class = particle
    newobj.explosion_particle_vis_class = explosion_particle_vis
    newobj.min_explosion_particles = 3
    newobj.max_explosion_particles = 3
    return setmetatable( newobj, self )
end

-- steelball
local steelball = inheritsfrom( body )
function steelball:new( level, x, y )
    local newobj = body:new( level, x, y, 3 )
    ballvis:new( level, newobj, 5 )
    newobj.min_impulse_for_trigger = nil
    return setmetatable( newobj, self )
end

-- piggyparticle
local piggyparticlevis = inheritsfrom( particle_vis )
function piggyparticlevis:new( level, body )
    local newobj = particle_vis:new( level, body, rnd() > 0.5 and 8 or 14 )
    return setmetatable( newobj, self )
end

-- cutelilpiggy
local cutelilpiggy = inheritsfrom( body )
function cutelilpiggy:new( level, x, y )
    local newobj = body:new( level, x, y, 3.5 )
    local vis = spritevis:new( level, newobj, { 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 11, 10, 11 }, 1 )
    newobj.vis = vis
    vis.frame = flr( randinrange( 1, #vis.sprite_frames + 1 ))
    vis.flipx = rnd() > 0.75
    newobj.min_impulse_for_trigger = 0.5
    newobj.trigger_explosion_delay = 0
    newobj.explosion_power = 0
    newobj.popped = false
    return setmetatable( newobj, self )
end

function cutelilpiggy:explode()
    if not self.alive or self.popped then return end

    self.popped = true

    sfx( 10 )

    self.level:create_bodies( 
        8, 
        self.pos, 
        particle, 
        piggyparticlevis, 
    0, 5 )

    self.level.dead_piggy_count += 1

    self.vis.sprite_frames = {12}
    self.vis.frame = 1
    self.want_dynamics = false
    self.does_collide_bodies = false

    things_exploded += 1

    piggies_killed += 1
end

function level:tidy_grass_cell( localcellpos )

    local mysprite = self:relative_cell_sprite( localcellpos, vector:new( 0 ))

    local global_map_location = self:maplocaltoglobal( localcellpos )
    local cell_worldspace = maptoworld( localcellpos ) + vector:new( 4 )

    if mysprite == 1 then
        self.cue_ball = cueball:new( self, cell_worldspace.x, cell_worldspace.y )
    elseif mysprite == 2 then
        targetball:new( self, cell_worldspace.x, cell_worldspace.y )
    elseif mysprite == 3 then
        barrel:new( self, cell_worldspace.x, cell_worldspace.y )
    elseif mysprite == 18 then
        heavyball:new( self, cell_worldspace.x, cell_worldspace.y )
    elseif mysprite == 19 then
        firecracker:new( self, cell_worldspace.x, cell_worldspace.y )
    elseif mysprite == 34 then
        steelball:new( self, cell_worldspace.x, cell_worldspace.y )
    elseif mysprite == 35 then
        cutelilpiggy:new( self, cell_worldspace.x, cell_worldspace.y )
    end

    local bitfield_to_sprite = {}
   -- bitfield is 1 for full and 0 for empty for nw, n, w neighbors
    bitfield_to_sprite[ 0b000 ] = nil
    bitfield_to_sprite[ 0b001 ] = 102
    bitfield_to_sprite[ 0b010 ] = 72
    bitfield_to_sprite[ 0b011 ] = 70
    bitfield_to_sprite[ 0b100 ] = 87
    bitfield_to_sprite[ 0b101 ] = 86
    bitfield_to_sprite[ 0b110 ] = 71
    bitfield_to_sprite[ 0b111 ] = 70

    local nwsolid = fget( self:relative_cell_sprite( localcellpos, vector:new( -1, -1 )), 7 ) and 1 or 0
    local nsolid = fget( self:relative_cell_sprite( localcellpos, vector:new( 0, -1 )), 7 ) and 1 or 0
    local wsolid = fget( self:relative_cell_sprite( localcellpos, vector:new(-1,  0 )), 7 ) and 1 or 0

    local bits = 
        bor( shl( nwsolid, 2 ),
            bor( shl( nsolid, 1 ),
                bor( shl( wsolid, 0 ))))

    local desiredsprite = bitfield_to_sprite[ bits ]

    if desiredsprite then
        mset( global_map_location.x, global_map_location.y, desiredsprite )
    end
end

-- levels
local current_level = nil
local current_level_number = 1
local max_level = 10

local pig_death_messages = {
    "don't you kill those piggies",
    "mustn't kill pigs",
    "pigs are people too",
    "the pigganity!",
    "all right bacon! wait...? no!",
    "no killing the pigs",
    "do not feed the animals...bombs",
    "take it easy on the piggies",
    "you meant to do that",
    "piggicide!",
    "piggies don't deserve it!",
    "ah but they're so sweet",
    "oh but they're so innocent",
    "that was my favorite one!",
    "you're the monster",
    "it just gets worse and worse",
    "the more there are...",
    "...the worse it gets",
    "pigs! pigs!!",
    "how could you?",
    "how dare you?",
    "sweet, sweet piggies",
    "you sick, sick person",
    "so adorable!",
}

local current_pig_death_message_num = 1


function goto_level( num )
    stop_all_hiss()

    -- debug_print( "playing level " .. num)

    if num <= max_level then
        current_level_number = num
        local zeroindexed = current_level_number - 1
        local offset = vector:new( zeroindexed % 8, flr( zeroindexed / 8 ))
        current_level = level:new( offset * vector:new( 16, 14 ))
        current_level:tidy()
    else
        -- end of game
        game_state = "end"
        current_level = nil
    end
end


-- init
function tidy_sprites()
    function tidy_creationgrass( sprite )
        local left = ( sprite % 16 ) * 8
        local top  = ( sprite / 16 ) * 8
        spritesheet_rectfill( left, top, left + 7, top + 7, 3 )
    end

    tidy_creationgrass( 1 )
    tidy_creationgrass( 2 )
    tidy_creationgrass( 3 )
    tidy_creationgrass( 18 )
    tidy_creationgrass( 19 )
    tidy_creationgrass( 34 )
    tidy_creationgrass( 35 )
end

tidy_sprites()

local title_level = nil
function start_title()
    music( 0 )
    game_state = "title"
    title_level = level:new( vector:new( 32, 14 ))
    title_level:tidy()
end

start_title()

function start_game()
    shots_taken = 0
    piggies_killed = 0
    things_exploded = 0
    game_state = "playing"
    goto_level( 1 )
end

function draw_game_logo()
    draw_shadowed( 0, 0, 0, 1, 1, function(x,y)
        print_centered_text( "exploding golf", 26 + y, 10 )
    end)
    draw_shadowed( 0, 0, 0, 1, 1, function(x,y)
        print_centered_text( "with loveable piggies", 36 + y, 15 )
    end)
end

function draw_title()

    camera( 0, -8 )
    title_level:draw()
    camera()

    draw_game_logo()

    draw_shadowed( 0, 0, 0, 1, 2, function(x,y)
        print_centered_text( "\x8e/\x97 play", 94 + y, 12 )
    end)
end

function update_title()

    title_level:update()

    if btnp( 4 ) or btnp( 5 ) then
        title_level = nil
        start_game()
    end
end

function draw_end_of_game()
    draw_game_logo()
    draw_shadowed( 0, 10, 0, 1, 2, function(x,y)
        print_centered_text( "you did it!", 40 + y, 8 )
        print_centered_text( "levels solved: " .. max_level, 54 + y, 13 )
        print_centered_text( "shots taken: " .. shots_taken, 61 + y, 13 )
        print_centered_text( "piggies accidentally murdered: " .. piggies_killed, 68 + y, 13 )
        print_centered_text( "things exploded: " .. things_exploded, 75 + y, 13 )
        print_centered_text( "thanks for playing!", 89 + y, 8 )
        print_centered_text( "\x8e/\x97 play again", 120, 1 )
    end)
end

function update_end_of_game()

    if btnp( 4 ) or btnp( 5 ) then
        start_game()
    end
end

function confirm_winloss_state( old_level_state, old_loss_reason )
    
    local level_state, loss_reason = current_level:settled_state()

    if old_level_state == level_state or ( old_loss_reason == "killed_innocents" ) then
        local next_level_number = current_level_number + ( level_state == "won" and 1 or 0 )

        if old_loss_reason == "killed_innocents" then
            -- change the pig death message
            current_pig_death_message_num = flr( randinrange( 1, #pig_death_messages + 1 ))
        end
        
        goto_level( next_level_number )

    else
        -- state changed. reconfirm.
        if level_state == 'undecided' then
            -- something has awakened the level again. go back to playing.
            current_level.is_ending = false
        else
            current_level:after_delay( 0.75, function() 
                confirm_winloss_state( level_state )
            end)
        end
    end
end

-- update 
function _update60()

    if game_state == "title" then
        update_title()
        return
    elseif game_state == "end" then
        update_end_of_game()
        return
    end

    local level_state, loss_reason = current_level:settled_state()
    -- debug_print( level_state .. ':' .. ( loss_reason or "" ) )


    if shooter.active == false and ( level_state ~= "won" and btnp(4) ) then
        -- reset
        goto_level( current_level_number )
        return
    end    

    if not shooter.active and current_level.cue_ball ~= nil and btnp(5) then
        current_level.cue_ball:explode()
    end

    if not current_level.is_ending and ( level_state ~= "undecided" ) then
        current_level.is_ending = true
        current_level:after_delay( 0.75, function() 
            confirm_winloss_state( level_state, loss_reason )
        end)
    end

    shooter:update()
    current_level:update()    
end

-- draw
function _draw()
    cls()

    if game_state == "title" then
        draw_title()
        return
    elseif game_state == "end" then
        draw_end_of_game()
        return
    end


    local heading = "level " .. current_level_number .. " / " .. max_level
    print_centered_text( heading, 1, 5 )

    local level_state, loss_reason = current_level:settled_state()

    if level_state ~= "won" then
        if shooter.active then
            print( '\x8b\x91\x94\x83 to aim      \x8e to shoot', 0, 128 - 6, 12 )
        else
            print( '\x8e to reset        \x97 to explode', 0, 128 - 6, 12 )
        end
    end

    camera( 0, -8 )

    current_level:draw()
    shooter:draw()

    camera()

    if loss_reason == "killed_innocents" then

        local message = pig_death_messages[ current_pig_death_message_num ]
        draw_shadowed( 0, 63, 0, 1, 2, function(x,y)
            print_centered_text( message, y, 14 )
        end )
    end

    if current_level_number == 1 and shooter.active then
        draw_shadowed( 70, 55, 0, 1, 2, function(x,y)
            print( "sink this ball", x, y, 14 )
        end )
    end


    -- debug text
    print( debug_text, 8, 8, 8 )
end

__gfx__
00000000333333333333333333333333000009994540000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000333333333333333333333333000991222424900000000000000000000000000090000000e0000e0ee000e00e00000000000000000000000000000000
00700700333333333333333333333333005121224244490000000009000000000000000000000000eeeeeeeeeeeeeeee00000000000000000000000000000000
00077000333773333338833333399333091212242424245000000000000000000000000000000000eeeee1e1eeeee1e10000e000000000000000000000000000
00077000333773333338833333399333511121224244444400000000000000000000000000000000eeeeee8eeeeeee8e800e6100000000000000000000000000
00700700333333333333333333333333411212242442424900000000900000000000000900000000eeeeeeeeeeeeeeee08688e8e000000000000000000000000
00000000333333333333333333333333291121224244444100000000000000000000000000000000e080e080e080e080eee688e8000000000000000000000000
00000000333333333333333333333333229112122424492100000009000000000000000000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333242941212229422100000000900000000000000900000000000000000000000000000000000000000000000000000000
33666666666666333333333333333333124429999992242100000009900000000000500990000000000000000000000000000000000000000000000000000000
36d6dddddddd6d633311113333333333142442222222422100005098890000000000009889000000000000000000000000000000000000000000000000000000
36ddddddddddddd1331c113333398333024224444242242100000989899500000000099898950500000000000000000000000000000000000000000000000000
36ddddddddddddd13311113333333333012442222222221100004998a89050000000498a89900000000000000000000000000000000000000000000000000000
3dddddddddddddd1331111333333333300124444242421100005498a8894000000054988a8940000000000000000000000000000000000000000000000000000
36ddddddddddddd1333333333333333300011242424111000000544aa44500000000544aa4450000000000000000000000000000000000000000000000000000
3dddddddddddddd13333333333333333000001111111000000000155551000000000015555100000000000000000000000000000000000000000000000000000
36dd5ddd5ddd5dd1333333333333333300000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
3ddd6ddd6ddd6dd1333333333333333300000000000000000000000000000000000000000000000000000000cbcccccccbcbcccccbcbcbcccbcbcbcccbcbcbcc
36ddddddddddddd1333333333333333300000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
3dddddddddddddd13337533333eeeee300000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccbcccccccbcbcccc
35dddddddddddd513335533333eeeee300000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
315d5dddddd5d5113333333333eeeee300000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
33111111111111133333333333e3e3e300000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
3331111111111133333333333333333300000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003338383333383833333333333338383333383833
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333833333338333333333333333833333338333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003338383333383833333333333338383333383833
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
36666666366666636666666300000000666666660000000000000000000000003000000000000000000000000000000000000000000000000000000000000000
64444444644444464444444600000000444445440000000000303030303030303530303000000000000000000000000000000000000000000000000000000000
64444444644444464454444600000000444444440000000003035353535353533353535300000000000000000000000000000000000000000000000000000000
64444444644445464444444600000000444444440000000000353533353335333333353300000000000000000000000000000000000000000000000000000000
64444444644444464444444600000000444444440000000003533333333333333333333300000000000000000000000000000000000000000000000000000000
64544444644444464444444600000000444444440000000000353333333333333333333300000000000000000000000000000000000000000000000000000000
64444444654444464444444600000000444444440000000003533333333333333333333300000000000000000000000000000000000000000000000000000000
64444444644444464444444600000000444444440000000000333333333333333333333300000000000000000000000000000000000000000000000000000000
36666666366666636666666364444444444444444444444603533333035333330000000000000000000000003333111111111111111133330000000000000000
64444444644444464544444664444444444445444444444600353333303333330000000000000000000000003311cccccccccccccccc11330000000000000000
644544446445444644444446654444444444444444444446035333335353333300000000000000000000000031c77777ccccc777c77ccc130000000000000000
64444444644444464444444664444444444444444444444600333333333333330000000000000000000000003c7cccccc7777cccccccc7c30000000000000000
64444444644444464444444664444444444444444444444603533333333333330000000000000000000000001cccccccccccccccccccc7c10000000000000000
6444444464444446444454466444444444444444444444560035333333333333000000000000000000000000c7cccc66cccccc6666ccc7cc0000000000000000
6444445464444446444444466444444444454444444444460353333333333333000000000000000000000000c7ccc6cccc6666cccc6cc7cc0000000000000000
3666666636666663666666636444444444444444444444460033333333333333000000000000000000000000c7ccc6cccccccccccc6c7ccc0000000000000000
6444444464444446444444460000000044444444000000003333333300000000000000000000000000000000c7ccc6cccccccccccccc7ccc3333333333333333
6444444464444456444444460000000044444444000000000533333300000000000000000000000000000000c7ccccccccccccccc6cc7ccc3333355555533333
6444444464444446444445460000000044444444000000000353333300000000000000000000000000000000cccccc6cccccccccc6ccc7cc3335510010155333
6444444464444446444444460000000044444444000000000033333300000000000000000000000000000000cc7ccc6cccccccccc6cccc7c3351000005051533
6444444464544446444444460000000044444444000000000353333300000000000000000000000000000000cc7ccc6cccccccccc6cccc7c3500000010505053
6444454464444446444444460000000044444444000000000035333300000000000000000000000000000000cc7cc6cccccccccccc6ccc7c3000000005550003
6444444464444446444444460000000044544444000000000353333300000000000000000000000000000000c7ccc6cccccccccccc6ccc7c3000000010515003
3666666636666663666666630000000066666666000000000033333300000000000000000000000000000000cccc6ccccccccccccc6cc7cc3000000005550003
6666666664444446444444440000000000000000000000000000000000000000000000000000000000000000c7cccccccccccccccc6ccccc3000000010515003
4444444464444446444445440000000000000000000000000000000000000000000000000000000000000000cccc6ccccccccccccc6ccc7c3000000005550003
4444444464444446444884440000000000000000000000000000000000000000000000000000000000000000cc7cc66ccccccccccc6ccc7c3000000010515003
4444444464444446448448440000000000000000000000000000000000000000000000000000000000000000bc7ccccc6ccccccc66ccc7cb33000000050500b3
44444444644444464484484400000000000000000000000000000000000000000000000000000000000000003cc76cccc6667cc6ccccc7c333b0000010510b33
44544444644445464448844400000000000000000000000000000000000000000000000000000000000000003bcccc66ccccccccc7cc7cb3333bb000050bb333
444444446444444644454444000000000000000000000000000000000000000000000000000000000000000033bbccccccccccccccccbb3333333bbbbbb33333
666666666444444644444444000000000000000000000000000000000000000000000000000000000000000033333bb3bbb3b3b3bbbb33333333333333333333
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3

__gff__
0022222200000000000000000000000002022222000000000000000000000000020222220000000000000020212223240000000000000000000000202122232480808000800000000000000000000000808080808080000000000020202000008080800080000000000000202020404080808000000000000000002020204040
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
5464646464646464646464646464645454646464646464646464646464646454546464646464646464646464646464545464646464646464646464646464645454646464646464646464646464646454546464646464646464646464646464545464646464646464646464646464645454646464646464646464646464646454
553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d727272723d3d3d3d3d53557272723d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d723d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d233d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d727272723d6e6f3d3d53557272723d3d3d3d3d3d3d3d3d233d53553d3d3d3d3d3d3d3d3d3d3d3d233d53553d233d3d3d3d3d3d3d723d6e6f3d53553d3d3d3d3d3d3d3d3d3d3d3d233d53553d233d3d3d3d3d3d3d3d3d3d233d53
553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d033d3d3d3d3d3d53553d3d3d3d3d727272723d7e7f3d3d53557272723d3d3d3d3d013d233d3d3d53553d3d3d013d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d723d7e7f3d53553d3d6e6f3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d013d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d413d023d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d727272723d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d233d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d723d023d3d53553d3d7e7f3d3d3d3d3d3d033d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d727272723d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d233d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d723d3d3d3d53553d3d3d3d02723d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d7272723d3d023d3d53553d3d013d3d727272723d3d023d3d53553d033d3d3d3d3d727272727272725355727272727272723d3d3d3d133d7253553d3d3d3d3d3d223d3d723d3d3d3d53553d3d3d3d7272723d3d3d3d3d3d3d53553d3d3d3d3d3d023d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d7272723d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d72727272535572723d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d723d3d3d3d3d3d3d3d3d53553d3d3d3d3d7272723d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d3d723d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d72727272535572723d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d723d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d723d3d3d3d3d3d3d53553d3d233d3d3d13133d3d3d233d3d53
553d3d3d3d013d3d3d3d713d3d3d3d53553d233d3d3d3d3d723d3d6e6f3d3d53553d3d3d3d3d033d3d3d033d3d3d3d53553d3d3d3d3d3d3d3d3d3d72727272535572723d3d3d3d6e6f3d3d3d3d3d3d53553d3d013d723d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d6e6f3d53553d3d3d3d013d3d723d3d7e7f3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d6e6f023d3d3d3d72727272535572723d3d3d3d7e7f3d023d3d3d3d53553d3d3d3d723d3d3d3d3d3d3d3d3d53553d3d033d3d3d3d3d3d3d3d3d3d3d53557272723d3d3d6e6f3d3d3d72727253
553d3d3d3d3d3d3d3d3d713d7e7f3d53553d3d233d3d3d3d723d3d3d3d3d3d53553d233d3d3d723d3d3d3d3d3d3d3d53553d3d3d7e7f3d3d3d3d3d72727272535572723d233d3d3d3d3d3d3d3d3d3d53553d233d3d7272727272727272727253553d233d3d3d3d3d3d3d3d3d3d013d53557272723d3d3d7e7f3d3d3d72727253
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d3d723d3d3d3d3d3d53553d3d3d3d3d723d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d72727272535572723d3d3d3d3d3d3d3d3d3d727253553d3d3d3d7272727272727272727253553d3d3d3d3d3d3d3d3d3d3d3d3d3d53557272723d3d3d3d3d3d3d3d72727253
5444444444444444444454444444445454444444444444444444444444444454544444444444444444444444444444545444444444444444444444444444445454444444444444444444444444444454544444444444444444444444444444545444444444444444444444444444445454444444444444444444444444444454
5464646464646464646464646464645454646464646464646464646464646454546464646464646464646464646464543d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d723d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d233d233d3d3d3d3d3d3d3d3d3d53553d233d3d3d3d3d3d3d3d3d3d233d53553d3d233d3d3d3d3d233d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d233d3d3d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d233d233d3d3d3d023d3d3d3d3d53553d3d3d3d3d3d3d033d3d3d3d3d3d53553d3d3d233d3d3d3d3d3d3d233d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d013d3d3d3d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d3d3d3d3d3d3d3d033d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d6e6f3d3d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d3d3d3d3d3d3d3d3d3d3d3d3d3d5355723d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d7e7f3d3d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d3d3d3d3d727272723d3d3d3d3d53553d3d3d3d3d133d723d3d013d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d3d013d3d727272723d3d3d3d3d53553d3d3d6e6f3d3d723d3d3d3d3d3d53553d3d3d3d233d3d3d023d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d3d3d3d3d727272723d6e6f3d3d53553d023d7e7f3d3d723d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d3d3d3d3d727272723d7e7f3d3d53553d3d3d3d3d3d3d723d3d3d3d3d3d53553d3d233d3d3d3d3d3d3d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
553d3d3d3d3d727272723d3d3d3d235355723d3d3d3d3d3d723d3d3d3d3d3d53553d3d3d3d3d3d233d3d3d3d3d3d3d533d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
5444444444444444724444444444445454724444444444444444444444444454544444444444444444444444444444543d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
__sfx__
000100000d07011050160401602016000160000000000000210000000021000170002200016000160001600000000000002205016020160201601000000000000000000000210001600019020160101601016010
00040000346701f650156400c64009630076300563004620026200162001610016100161001600016000160001600016000160001600016000060000600006000060000600006000060000600006000060000600
000200002d6502b6502765025650226501f6501c650166500d6500465001640016300162001610016100161000600006000060000600006000060000600006000060000600006000060000600006000060000600
000100003b6503665030650256501a650166500d65008650056500365001640016300162001610016100161000600006000060000600006000060000600006000060000600006000060000600006000060000600
000100001947018460304502c4202c4202c4101743016430204000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
0001000019460184402a4302641026410264101741016410204000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
000100001943018410284102640026400264001740016400204000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
00010000120500f0500b0500805004050040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000120300f0200b0200801004010040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020506166101a6101c6101a61015610136101360013600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000100000745008450084500b45010450174502245031450394503145038450304500040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
00010000157701577015770157700d7700d7700d7600d750157401574015730157300d7200d7100d7100d710157101571015710157100d7100d7100d7100d7100070000700007000070000700007000070000700
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000c0500000010000000001005000000000050c0550e0501005000000000000000004050000000000005050000000000000000090500000000000050550705009050000000000000000070600000000000
00100000006350000000615000003c6150000000615000000063500605006153c61500605006153061500000006350000000615000003c615000000061500000006350060500615006053c605006153063500000
001000001f55500000000001f55200000000001f555000001f5570000000000000001c550000001a550185501a550000001c55015550155570000000000000000000000000000000000000000000000000000000
001000002355500000000001f55200000000001f555000001f5570000000000000001c550000001a550185501a550000001855011550115570000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000005055050050505505005050550700507055070050705507005070550900509055000000b0550000000000000000905500000090550000009055000000b055000000b0550000000055000000705500000
001000000063500000000000000000625000000000000000006350000000000000000062500000000000000000635000000000000000006350000000000000000064500000006550000000665000000067500000
001000002153500000215350000021535000002353500000235450000023535000002453500000265350000000000000002453500000245350000024535000002654500000265550000028565000002957500000
001000001851500000185150000018515000001a515000001a515000001a515000001c515000001d5150000000000000001c515000001c515000001c515000001d525000001d535000001d545000001d55500000
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
00 14154344
00 14154344
00 14151644
00 14151744
02 191a1b1c
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

