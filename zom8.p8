pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
-- main

map_width=16
map_height=16
m={}
z_id=0

function _init()
    --player init
	p=make_player(3,3)
	cam=make_camera()

    --enemies init
    zombies={}
    -- make_zombie(4,4)

    --map init
    m=make_map()

    --projectile init
    proj={}

    frict=0.9
end

function _draw()

    cls()
	
	map(0,0)
	
	--player
    p:draw()

    --map
    -- print_map(m)
    cam:draw()
    draw_cursor(p)
    print_3D_map(m)

    --zombie
	for zombie in all(zombies) do
		zombie:draw()
	end

    -- projectile
    for projectile in all(proj) do
        projectile:draw()
    end

    --debug
	print(p.x,p.x*8-62,p.y*8-62,8)
	print(p.y,p.x*8-62,p.y*8-56,8)
	print(p.dx,p.x*8-62,p.y*8-50,8)
	print(p.dy,p.x*8-62,p.y*8-44,8)
end

function _update()
    p:control()
    p:update()
    
    -- map
    m=make_map()
    distmap()

    cam:update(p.x, p.y)

    --zombie
	for zombie in all(zombies) do
        enemy_collide(p, zombie)
        zombie:getPath()
		zombie:control()
	end

    for projectile in all(proj) do
        projectile:update()
    end
end
-->8
-- player and zombies

function make_player(x, y)
    -- everything is in a table
    -- units are in tiles, where each tile is 8x8 pixels
    pl={
        -- fields
        sp=1,
        x=x,
        y=y,
        w=0.45,
        h=0.45,
        dx=0,
        dy=0,
        max_dx=0.4,
        max_dy=0.4,
        accel=0.1,

        invincible=false,
        invincible_frames=30,

        facing=1,

        -- functions
        control=function(self)
            if btn(⬅️) then
                self.dx-=self.accel
            end
            if btn(➡️) then
                self.dx+=self.accel
            end
            if btn(⬆️) then
                self.dy-=self.accel
            end
            if btn(⬇️) then
                self.dy+=self.accel
            end

            if btnp(❎) then
                self.facing+=1
                if self.facing > 4 then
                    self.facing = 1
                end
            end

            if btnp(🅾️) then
                if p.facing == 1 then -- right
                    make_projectile(p, 1, 0)
                elseif p.facing == 2 then -- down
                    make_projectile(p, 0, 1)
                elseif p.facing == 3 then -- left
                    make_projectile(p, -1, 0)
                else -- up
                    make_projectile(p, 0, -1)
                end
            end

            -- ensures player doesnt exceed max dx or dy in any direction
            self.dx=mid(-self.max_dx, self.dx, self.max_dx)
			self.dy=mid(-self.max_dy, self.dy, self.max_dy)
        end,

        draw=function(self)
            -- drawing self sprite
            spr(self.sp,(self.x*8)-4,(self.y*8)-4)
        end,

        update=function(self)
            -- invincibility
            if self.invincible then
                self.invincible_frames -= 1
                
                if self.invincible_frames <= 0 then
                    self.invincible = false
                    self.invincible_frames = 30
                end
            end

            -- wall collide
            if not solid_area(self.x+self.dx,self.y,self.w,self.h) then
                self.x+=self.dx
            else
                self.dx*=-0.5
                self.x+=self.dx
            end
					
            if not solid_area(self.x,self.y+self.dy,self.w,self.h) then
                self.y+=self.dy
            else
                self.dy*=-0.5
                self.y+=self.dy
            end

            self.dx*=frict
			self.dy*=frict
        end
    }

    return pl
end

function make_zombie(x, y)
    add(zombies,{
        id=z_id,
		sp=4,
		x=x,
		y=y,
		w=0.45,
		h=0.45,
		dx=0,
		dy=0,
		max_dx=0.15,
		max_dy=0.15,
		accel=0.075,
        pathToP={},
		
        getPath=function(self)
            self.pathToP = pathfind(self)
        end,

		control=function(self)
            if #self.pathToP > 0 then
                local nextTile = self.pathToP[#self.pathToP]  -- Get the next tile in the path

                if flr(self.x) < nextTile.x then
                    self.dx += self.accel
                elseif flr(self.x) > nextTile.x then
                    self.dx -= self.accel
                end

                if flr(self.y) < nextTile.y then
                    self.dy += self.accel
                elseif flr(self.y) > nextTile.y then
                    self.dy -= self.accel
                end

                -- ensures player doesnt exceed max dx or dy in any direction
                self.dx=mid(-self.max_dx, self.dx, self.max_dx)
                self.dy=mid(-self.max_dy, self.dy, self.max_dy)

                -- Check if the zombie has reached the next tile
                if flr(self.x) == nextTile.x and flr(self.y) == nextTile.y then
                    del(path)  -- Remove the reached tile from the path
                else
                    zombie_collide(self)
                    --map collide	
                    if not solid_area(self.x+self.dx,self.y,self.w,self.h) then
                        self.x+=self.dx
                    end
                    
                    if not solid_area(self.x,self.y+self.dy,self.w,self.h) then 
                        self.y+=self.dy
                    end
                end
            end
		end,
		
		draw=function(self)
            for t in all(self.pathToP) do
                print("p", t.x*8, t.y*8, 7)
            end

			spr(self.sp,(self.x*8)-4,(self.y*8)-4)
		end
		})
    z_id+=1
end

function make_camera()
	cam={
		cx=0,
		cy=0,
		
		update=function(self,x,y)
			self.cx=x*8-62
			self.cy=y*8-62
		end,
		
		draw=function(self)
			camera(self.cx,self.cy)
		end
		}
		
	return cam
end

function draw_cursor(p)
    -- drawing the cursor
    if p.facing == 1 then -- right
        spr(49,(p.x*8)+4,(p.y*8)-4)
    elseif p.facing == 2 then -- down
        spr(49,(p.x*8)-4,(p.y*8)+4)
    elseif p.facing == 3 then -- left
        spr(49,(p.x*8)-12,(p.y*8)-4)
    else -- up
        spr(49,(p.x*8)-4,(p.y*8)-12)
    end
end

function make_projectile(p, pdx, pdy)
    add(proj,{
		sp=49,
		x=p.x,
		y=p.y,
		w=0.45,
		h=0.45,
		dx=pdx,
		dy=pdy,
        
        draw=function(self)
            spr(self.sp,(self.x*8)-4,(self.y*8)-4)
        end,
        
        update=function(self)
            -- wall colission, destroy self
            if not solid_area(self.x+self.dx,self.y,self.w,self.h) then
                self.x+=self.dx
            else
                del(proj, self)
            end
					
            if not solid_area(self.x,self.y+self.dy,self.w,self.h) then
                self.y+=self.dy
            else
                del(proj, self)
            end

        end}
    )
end

-->8
-- map
key_direction = {
  [0] = {x = -1, y = 0},
  [1] = {x = 1, y = 0},
  [2] = {x = 0, y = -1},
  [3] = {x = 0, y = 1},
  [4] = {x = 0, y = 0}
}

function make_map()
    m={}
    for j=0, map_height do
        -- adding new row
        m[j]={}
        for i=0, map_width do
            m[j][i]=0
        end
    end
    return m
end

-- for debug
function print_map(m)
    for j=0, map_height do
        -- adding new row
        for i=0, map_width do
            print(m[j][i],i*8,j*8,2)
        end
    end
end

function print_3D_map(m)
    for j=0, map_height do
        -- adding new row
        for i=0, map_width do
            if solid(i, j) then
                spr(3,i*8,j*8)
            end
        end
    end
end

function pathfind(t)
    local min = m[flr(t.y)][flr(t.x)]
    local save_ax = flr(t.x)
    local save_ay = flr(t.y)

    -- base case
    if min <= 1 then
        return {x = t.x, y = t.y}
    end 

    for i=0, 3 do
        -- check adjacent tiles in the cardinal directions
        local d = key_direction[i]
        
        -- True "position" of tile in m[x][y] looking in every direction
        local ax = flr(t.x) + d.x    -- d.x looks left or right
        local ay = flr(t.y) + d.y    -- d.y looks up or down

        -- if the adjacent tile is passable and hasn't yet been traversed (i.e. distance is 9999)
        if not solid(ax, ay) and m[ay][ax] <= min then 
            min = m[ay][ax]
            save_ax = ax
            save_ay = ay
        end
    end

    local tile = {
        x = save_ax,
        y = save_ay
    }

    local path = pathfind(tile)

    add(path, tile)

    return path
end

function distmap()
    local queue = {}
    local toAdd = {}
    
    -- adding the players x, y to the queue
    add(queue, {
        x = flr(p.x),
        y = flr(p.y)
    })

   toAdd = goQueue(queue)

   while #toAdd > 0 do
        toAdd = goQueue(toAdd)
   end 

   m[flr(p.y)][flr(p.x)] = 0
end

function goQueue(queue)
     local toAdd = {}

    for t in all(queue) do
        -- note the distance of the current tile
        local curr_tile_dist = m[t.y][t.x]

        for i=0, 3 do
            -- check adjacent tiles in the cardinal directions
            local d = key_direction[i]
            
            -- True "position" of tile in m[x][y] looking in every direction
            local ax = t.x + d.x    -- d.x looks left or right
            local ay = t.y + d.y    -- d.y looks up or down

            -- if the adjacent tile is passable and hasn't yet been traversed (i.e. distance is 9999)
            if not solid(ax, ay) and m[ay][ax] == 0 then
                -- set the distance of the adjacent tile to the current tile's distance + 1
                m[ay][ax] = curr_tile_dist + 1

                -- and add the adjacent tile to the frontier
                add(toAdd, {
                    x = flr(ax),
                    y = flr(ay)
                })
            end
        end

        -- after all adjacent tiles have been checked, remove the tile from the frontier
        del(queue, t) 
    end

    return toAdd
end

-->8
-- enemy collisions
function enemy_collide(p, z)
    if not p.invincible and detect_collide(p, z, 0.5) then
        p.invincible = true

        -- both going same direction, repel one
        local a = (p.dx > 0 and z.dx > 0) or (p.dx < 0 and z.dx < 0)
        local b = (p.dy > 0 and z.dy > 0) or (p.dy < 0 and z.dy < 0)

        if a and b then
            z.dx*=-1
            z.dy*=-1
        else
            p.dx *= -1
            p.dy *= -1

            if z.dx != 0 and z.dy != 0 then
                z.dx=0
                z.dy=0
            end
        end
    end
end

function detect_collide(p, z, offset)
    local a = (((p.y <= z.y+z.h+offset) and (z.y+z.h+offset <= p.y+p.h+offset)) or ((z.y <= p.y+p.h+offset) and (p.y+p.h+offset <= z.y+z.h+offset)))
    return (((p.x <= z.x) and (z.x <= p.x+p.w+offset)) and a or 
             (((z.x <= p.x) and (p.x <= z.x+z.w+offset)) and a))
end

function zombie_collide(z)
    for zombie in all(zombies) do
        if detect_zombie_collide(zombie, z) then
            -- both going same direction, repel one
            local a = (zombie.dx > 0 and z.dx > 0) or (zombie.dx < 0 and z.dx < 0)
            local b = (zombie.dy > 0 and z.dy > 0) or (zombie.dy < 0 and z.dy < 0)

            if a and b then
                z.dx*=-1
                z.dy*=-1
            else
                if zombie.dx != 0 and zombie.dy != 0 then
                    z.dx=0
                    z.dy=0
                end
            end
        end
    end
end

function detect_zombie_collide(z1, z2)
   return z1.id != z2.id and detect_collide(z1, z2, 0.5)
end

-- wall collision
--cr: zep tutorial
function solid(x,y)
	return fget(mget(x,y),0)
end

function solid_area(x,y,w,h)
 return 
  solid(x-w,y-h) or
  solid(x+w,y-h) or
  solid(x-w,y+h) or
  solid(x+w,y+h)
end

__gfx__
000000008888888866666666ddddddddbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000008888888866666666ddddddddbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007008888888866666666ddddddddbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770008888888866666666ddddddddbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770008888888866666666ddddddddbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007008888888866666666ddddddddbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000008888888866666666ddddddddbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000008888888866666666ddddddddbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0202020202020202020202020202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000020202020202000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000020202020202000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020202020202000000020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020202020202000000020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000202000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000202000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000202000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000202000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020202020202020202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
