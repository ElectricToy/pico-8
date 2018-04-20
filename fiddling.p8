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

