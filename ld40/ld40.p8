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
    return mappos * vector:new( 8, 8 )
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

function body:be_swallowed_by_hole( local_map_location, mapsprite )
    local hole_center_per_sprite_index = {}
    hole_center_per_sprite_index[ 110 ] = vector:new( 1, 1 )
    hole_center_per_sprite_index[ 111 ] = vector:new( 0, 1 )
    hole_center_per_sprite_index[ 126 ] = vector:new( 1, 0 )
    hole_center_per_sprite_index[ 127 ] = vector:new( 0, 0 )

    local hole_center_offset = hole_center_per_sprite_index[ mapsprite ]
    local hole_center = local_map_location + hole_center_offset

    self.want_dynamics = false
    self.lerp_to_location = maptoworld( hole_center ) + vector:new( 0, 0.8 )
    self.lerp_to_shadowed_amount = -3

    self.level:after_delay( 0.15, function() 
        sfx( 0 )
    end )
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
    else
        if self.lerp_to_location then
            self.pos = self.pos:lerp( self.lerp_to_location, 0.05 )
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

function body:collision_normal_with_velocity( lastposition, radius, rectcenter, rectsize, delta )
    -- local epsilon = 0.01

    -- local totalDimensions = rectsize * vector:new( 0.5 ) + radius
    
    -- -- Consider the objects at their last positions.
    -- -- How was that overlapping this in the last position?
    -- local deltalast = lastposition - rectcenter
    -- local axialDistancesLast = vector:new( abs( deltaLast.x ), abs( deltaLast.y ))
    
    -- -- Positive values indicate overlap.
    -- local overlapsLast = totalDimensions - axialDistancesLast
    
    -- if overlapsLast.x > 0 then
    -- {
    --     -- Overlapping in X.
        
    --     if overlapsLast.y > 0 then
    --     {
    --         -- In the last position these objects were not clear of each other,
    --         -- so we can't use this method.
    --         --
    --         -- Use the "simple" method of colliding based on thinnest overlap distance.
    --         --
    --         return collision_normal_simple( delta )
    --     }
    --     else
    --     {
    --         -- Was overlapping in x, not y. Therefore the hitNormal must be vertical.
    --         -- 
    --         return vector:new( 0, sign( deltalast.y )), 1
    --     }
    -- }
    -- else if( overlapsLast.y > 0 )
    -- {
    --     // Was overlapping in y, not x. Therefore the hitNormal must be horizontal.
    --     //
    --     outNormalAxis = 0;
    --     outHitNormal.set( sign( deltaLast.x ), 0 );
    -- }
    -- else
    -- {
    --     // No overlap in the last position (corners were closest).
    --     // Decide which edge the objects collided on by comparing the velocity to the
    --     // delta between their closest corners.
    --     //
        
    --     vec2 deltaLastSign = deltaLast;
    --     deltaLastSign.x = sign( deltaLastSign.x );
    --     deltaLastSign.y = sign( deltaLastSign.y );
        
    --     const vec2 thisClosestCorner = m_lastPosition + deltaLastSign * m_dimensions * 0.5f;
    --     const vec2 thatClosestCorner = rectCenter + deltaLastSign.getInverse() * rectSize * 0.5f;
        
    --     const vec2 deltaCorners = thisClosestCorner - thatClosestCorner;
        
    --     if( deltaCorners.isZero( EPSILON )) // TODO arbitrary epsilon
    --     {
    --         // Corners were basically touching--too close to call.
    --         // Use the simple method.
    --         //
    --         return findCollisionNormalSimple( overlaps, delta, outHitNormal, outNormalAxis );
    --     }
        
    --     vec2 deltaCornersPerpendicular = deltaCorners;
    --     deltaCornersPerpendicular.quickRot90();
        
    --     // Calculate the relative velocity of other.
    --     //
    --     const vec2 thisVel = m_position - m_lastPosition;
    --     const vec2 thatVel( 0, 0 );     // TODO If the other object were a body, we would use its actual velocity.
        
    --     const vec2 thatVelRel = thatVel - thisVel;
        
    --     if( thatVelRel.isZero( EPSILON ))   // TODO arbitrary epsilon
    --     {
    --         // No velocity to speak of. Use primitive resolution method. (This should be unusual.)
    --         //
    --         return findCollisionNormalSimple( overlaps, delta, outHitNormal, outNormalAxis );
    --     }
        
    --     // Determine how the corners moved relative to their axis of intersection.
    --     //
    --     const float dotProduct = deltaCorners.dot( thatVelRel );
        
    --     outHitNormal = deltaCorners;
        
    --     if( dotProduct > 0 )
    --     {
    --         outNormalAxis = outHitNormal.getMajorAxis();
    --         outHitNormal.snapToMajorAxis();
    --     }
    --     else
    --     {
    --         outNormalAxis = outHitNormal.getMinorAxis();
    --         outHitNormal.snapToMinorAxis();
    --     }

    --     outHitNormal.normalize();
        
    --     if( outHitNormal.isZero( EPSILON ))
    --     {
    --         // Very low velocity along the hit normal. Use simple method.
    --         //
    --         return findCollisionNormalSimple( overlaps, delta, outHitNormal, outNormalAxis );
    --     }
    -- }
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

    -- move the body back out
    self.pos += normal * vector:new( adjustmentdist )
    self.vel:set_component( normal_axis, self.vel:component( normal_axis ) * -self.restitution )
end

function body:resolve_map_collision( levelmapx, levelmapy )
    self:resolve_rect_collision( 
        vector:new( ( levelmapx + 0 ) * 8, ( levelmapy + 0 ) * 8 ), 
        vector:new( ( levelmapx + 1 ) * 8, ( levelmapy + 1 ) * 8 ))
end

function body:explode()
    -- apply a force to all other bodies
    self.level:apply_explosion_force( self.pos, self.explosion_power )

    self.alive = false

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
    end
end

-- rendering

local vis = inheritsfrom( nil )

function vis:new( level, body )
    local newobj = { 
        body = body,
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

    local p = self.body.pos
    local r = self.body.radius

    draw_shadowed( p.x, p.y, r/4*0.8, r/4, 2, function( x, y)
        circfill( x, y, r, rel_color( self.basecolor, base_color_offset ))
    end )

    circfill( p.x - 0.1*r, p.y - 0.15*r, r * 0.75, rel_color( self.basecolor, base_color_offset + 1 ))
    circfill( p.x - 0.2*r, p.y - 0.4*r, r * 0.25, rel_color( self.basecolor, base_color_offset + 2 ))
end


-- init
local level = inheritsfrom( nil )
function level:new( mapul )
    local newobj = { 
        bodies = {},
        visualizations = {},
        mapul = mapul,
        mapbr = mapul + vector:new( 16, 14 ),
        tidied = false,
        paused = true,
        pending_calls = {},
        tick_count = 0,
        cell_heights = {},
        cell_normals = {},
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
    if not self.tidied then
        self.tidied = true
        self:tidy()
    end

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

-- particle

local particle = inheritsfrom( body )
function particle:new( level, x, y )
    local newobj = body:new( level, x, y, 0 )
    newobj.drag = 0.05
    newobj.does_collide_bodies = false
    newobj.does_collide_map = false
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
    pset( self.body.pos.x, self.body.pos.y, self.basecolor )
    -- circfill( self.body.pos.x, self.body.pos.y, 0.5, self.basecolor )
    -- local x = flr( self.body.pos.x )
    -- local y = flr( self.body.pos.y )
    -- rectfill( x, y, x+0.5, y+0.5, self.basecolor )
end

local explosion_particle_vis = inheritsfrom( particle_vis )
function explosion_particle_vis:new( level, body )
    local newobj = particle_vis:new( level, body, 5 )
    return setmetatable( newobj, self )
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
    level.paused = true
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

    if btnp(4) then
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
    self.level.paused = false
    self.active = false

    self.ball:addimpulse( self:impulse() )
end

function shooter:draw()
    if not self.active then return end

    local ballpos = self.ball.pos
    local pos = self:position()
    local delt = self:delta()
    local normal = delt:normal()

    local circle_size = self.ball.radius + 3
    circ( ballpos.x, ballpos.y, circle_size, 5 )

    local dest = ballpos + normal * vector:new( circle_size, circle_size )
    local dist = (dest - pos):length()

    -- draw dashed line
    local step = 3
    local step2 = step*2
    for i = wrap( self.updates * 0.2, 0, step2 ),dist,step2 do

        local p = pos - normal * vector:new( i, i )

        local adjustedstep = min( i + step, dist - 1 )

        local j = adjustedstep

        local q = pos - normal * vector:new( j, j )

        line( p.x, p.y, q.x, q.y, 5 )
    end

    circfill( pos.x, pos.y, 2, 5 )
    circfill( pos.x, pos.y, 1, 6 )

end

-- levels
local level_creation_fns = {
    function()

        local newlevel = level:new( vector:new( 0, 0 ))

        local cue_ball = body:new( newlevel, 5*8, 9*8, 4 )
        local cue_ball_vis = ballvis:new( newlevel, cue_ball, 6 )

        cue_ball.explosion_particle_class = particle
        cue_ball.explosion_particle_vis_class = explosion_particle_vis
        cue_ball.explosion_sfx = 2

        local target_ball = body:new( newlevel, 13*8, 4*8, 4 )
        local target_ball_vis = ballvis:new( newlevel, target_ball, 8 )
        target_ball.is_target = true

        shooter:attach( newlevel, cue_ball )

        return newlevel
    end,

    function()

        local newlevel = level:new( vector:new( 16, 0 ))
        
        local cue_ball = body:new( newlevel, 6*8, 10*8, 4 )
        local cue_ball_vis = ballvis:new( newlevel, cue_ball, 6 )

        cue_ball.explosion_particle_class = particle
        cue_ball.explosion_particle_vis_class = explosion_particle_vis
        cue_ball.explosion_sfx = 2

        local target_ball = body:new( newlevel, 12.5*8, 6*8, 4 )
        local target_ball_vis = ballvis:new( newlevel, target_ball, 8 )
        target_ball.is_target = true

        shooter:attach( newlevel, cue_ball )

        return newlevel
    end
}

local current_level = level_creation_fns[2]()

-- update 
function _update60()

    -- todo debugging

    if btnp(5) then
        current_level.bodies[1]:explode()
    end

    shooter:update()
    current_level:update()

end

-- draw
function _draw()
    cls()

    current_level:draw()

    shooter:draw()

    -- debug text
    print( debug_text, 8, 8, 8 )
end

__gfx__
00000000000000000000000000000000000009994540000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000991222424900000000000000000000000000090000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000005121224244490000000009000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000091212242424245000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000511121224244444400000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000411212242442424900000000900000000000000900000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000291121224244444100000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000229112122424492100000009000000000000000000000000000000000000000000000000000000000000000000000000
33333333333333330000000000000000242941212229422100000000900000000000000900000000000000000000000000000000000000000000000000000000
33666666666666330000000000000000124429999992242100000009900000000000500990000000000000000000000000000000000000000000000000000000
36d6dddddddd6d630000000000000000142442222222422100005098890000000000009889000000000000000000000000000000000000000000000000000000
36ddddddddddddd10000000000000000024224444242242100000989899500000000099898950500000000000000000000000000000000000000000000000000
36ddddddddddddd10000000000000000012442222222221100004998a89050000000498a89900000000000000000000000000000000000000000000000000000
3dddddddddddddd1000000000000000000124444242421100005498a8894000000054988a8940000000000000000000000000000000000000000000000000000
36ddddddddddddd1000000000000000000011242424111000000544aa44500000000544aa4450000000000000000000000000000000000000000000000000000
3dddddddddddddd10000000000000000000001111111000000000155551000000000015555100000000000000000000000000000000000000000000000000000
36dd5ddd5ddd5dd1000000000000000000000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
3ddd6ddd6ddd6dd1000000000000000000000000000000000000000000000000000000000000000000000000cbcccccccbcbcccccbcbcbcccbcbcbcccbcbcbcc
36ddddddddddddd1000000000000000000000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
3dddddddddddddd1000000000000000000000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccbcccccccbcbcccc
35dddddddddddd51000000000000000000000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
315d5dddddd5d511000000000000000000000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
3311111111111113000000000000000000000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
3331111111111133000000000000000000000000000000000000000000000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003b3333333b3b33333b3b3b333b3b3b333b3b3b33
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333b3333333b3b3333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333333333333333333333333333333333
36666666366666636666666300000000666666660000000033533535333333333535353533b33b3b333333333b3b3b3b00000000000000000000000000000000
6444444464444446444444460000000044444544000000003333535333533535535353533333b3b333b33b3bb3b3b3b300000000000000000000000000000000
644444446444444644544446000000004444444400000000333533353533333335353535333b333b333333333b3b3b3b00000000000000000000000000000000
6444444464444546444444460000000044444444000000003533355333353535535353533b333bb3333b3b3bb3b3b3b300000000000000000000000000000000
6444444464444446444444460000000044444444000000003353533533333353353535353333b33b333333b33b3b3b3b00000000000000000000000000000000
645444446444444644444446000000004444444400000000333333533535353553535353333333b33b3b3b3bb3b3b3b300000000000000000000000000000000
644444446544444644444446000000004444444400000000333535353333535335353535333b3b3b3333b3b33b3b3b3b00000000000000000000000000000000
6444444464444446444444460000000044444444000000003533535335353535535353533b33b3b33b3b3b3bb3b3b3b300000000000000000000000000000000
36666666366666636666666364444444444444444444444633333333333333330000000033333333333333333333111111111111111133330000000000000000
644444446444444645444446644444444444454444444446533353335353353300000000b333b333b3b33b333311cccccccccccccccc11330000000000000000
6445444464454446444444466544444444444444444444463335333533333353000000003333333b3333333331c77777ccccc777c77ccc130000000000000000
6444444464444446444444466444444444444444444444463533353353535333000000003b333b33b3b3b3333c7cccccc7777cccccccc7c30000000000000000
644444446444444644444446644444444444444444444446533533533533333300000000b33b33b33b3333331cccccccccccccccccccc7c10000000000000000
6444444464444446444454466444444444444444444444563533533553535353000000003b33b33bb3b3b3b3c7cccc66cccccc6666ccc7cc0000000000000000
644444546444444644444446644444444445444444444446535353533535333300000000b3b3b3b33b3b3333c7ccc6cccc6666cccc6cc7cc0000000000000000
3666666636666663666666636444444444444444444444463535353553535353000000003b3b3b3bb3b3b3b3c7ccc6cccccccccccc6c7ccc0000000000000000
6444444464444446444444460000000044444444000000003535335353535353000000003b3b33b3b3b3b3b3c7ccc6cccccccccccccc7ccc3333333333333333
644444446444445644444446000000004444444400000000535353333535333300000000b3b3b3333b3b3333c7ccccccccccccccc6cc7ccc3333355555533333
6444444464444446444445460000000044444444000000003533333353535353000000003b333333b3b3b3b3cccccc6cccccccccc6ccc7cc3335510010155333
644444446444444644444446000000004444444400000000533535333533333300000000b33b33333b333333cc7ccc6cccccccccc6cccc7c3351000005051533
6444444464544446444444460000000044444444000000003553335353535333000000003bb333b3b3b3b333cc7ccc6cccccccccc6cccc7c3500000010505053
644445446444444644444446000000004444444400000000533353333333335300000000b333b33333333333cc7cc6cccccccccccc6ccc7c3000000005550003
6444444464444446444444460000000044544444000000003535333353533533000000003b3b3333b3b33b33c7ccc6cccccccccccc6ccc7c3000000010515003
366666663666666366666663000000006666666600000000535335333333333300000000b3b33b3333333333cccc6ccccccccccccc6cc7cc3000000005550003
666666666444444644444444000000000000000000000000535353533535353500000000b3b3b3b33b3b3b3bc7cccccccccccccccc6ccccc3000000010515003
4444444464444446444445440000000000000000000000003535353533335353000000003b3b3b3b3333b3b3cccc6ccccccccccccc6ccc7c3000000005550003
444444446444444644488444000000000000000000000000533533533535353500000000b33b33b33b3b3b3bcc7cc66ccccccccccc6ccc7c3000000010515003
4444444464444446448448440000000000000000000000003533533533333353000000003b33b33b333333b3bc7ccccc6ccccccc66ccc7cb33000000050500b3
44444444644444464484484400000000000000000000000033533353333535350000000033b333b3333b3b3b3cc76cccc6667cc6ccccc7c333b0000010510b33
445444446444454644488444000000000000000000000000533353333533333300000000b33333333b3333333bcccc66ccccccccc7cc7cb3333bb000050bb333
444444446444444644454444000000000000000000000000333533353353353500000000333b333b33333b3b33bbccccccccccccccccbb3333333bbbbbb33333
666666666444444644444444000000000000000000000000333333333333333300000000333333333333333333333bb3bbb3b3b3bbbb33333333333333333333
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
0000000000000000000000000000000002020000000000000000000000000000020200000000000000000020212223240000000000000000000000000102030480808000800000000000000000000000808080808080000000000020202000008080800080000000000000202020404080808000000000000000002020204040
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
5464646464646464646464646464645454646464646464646464646464646454546464646464646464646464646464545464646464646464646464646464645454646464646464646464646464646454546464646464646464646464646464545464646464646464646464646464645454646464646464646464646464646454
553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d413d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d7272723d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d7272723d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d3d723d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d3d723d3d6e6f3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d6e6f3d53553d3d3d3d3d3d3d723d3d7e7f3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d7e7f3d53553d3d3d3d3d3d3d723d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
553d3d3d3d3d3d3d3d3d713d3d3d3d53553d3d3d3d3d3d3d723d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53553d3d3d3d3d3d3d3d3d3d3d3d3d3d53
5444444444444444444454444444445454444444444444444444444444444454544444444444444444444444444444545444444444444444444444444444445454444444444444444444444444444454544444444444444444444444444444545444444444444444444444444444445454444444444444444444444444444454
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
__sfx__
000100001007011050160401602016000160000000000000210000000021000170002200016000160001600000000000002205016020160201601000000000000000000000210001600019020160101601016010
00040000206501f6501e6501e6501b65018650126500b650066500465002640016300162001610016100161000600006000060000600006000060000600006000060000600006000060000600006000060000600
000200002d6502b6502765025650226501f6501c650166500d6500465001640016300162001610016100161000600006000060000600006000060000600006000060000600006000060000600006000060000600
000100003b6503665030650256501a650166500d65008650056500365001640016300162001610016100161000600006000060000600006000060000600006000060000600006000060000600006000060000600
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
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

