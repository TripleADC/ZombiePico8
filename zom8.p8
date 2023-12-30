pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
-- main

map_width=16
map_height=16
m={}
spawners={}
walls={}
barriers={}
z_id=0

function _init()
    --player init
	p=make_player(6,7)
    crs=make_cursor()
    crs:update_cursor(p)

	cam=make_camera()

    --enemies init
    zombies={}

    --map init
    m=make_map()
    walls=make_walls()
    barriers=make_barriers()

    --projectile init
    proj={}

    --spawner init
    spawners=make_zombie_spawners()

    frict=0.9
end

function _draw()

    cls()

    pal(10, 1+128, 1)
    pal(12, 5+128, 1)
	
	map(0,0)
	
	--player
    p:draw()
    crs:draw_cursor()
    crs:draw_box_wall()

    --map
    -- print_map(m)
    cam:draw()
    print_3D_map(m)

    crs:draw_box_barrier(barriers)

    --zombie
	for zombie in all(zombies) do
		zombie:draw()
	end

    -- projectile
    for projectile in all(proj) do
        projectile:draw()
    end

    --debug
    -- print(p.health,p.x*8-62,p.y*8-62,8)
	-- -- print(p.x,p.x*8-62,p.y*8-62,8)
	-- -- print(p.y,p.x*8-62,p.y*8-56,8)
	-- print(p.dx,p.x*8-62,p.y*8-50,8)
	-- print(p.dy,p.x*8-62,p.y*8-44,8)
end

function _update()
    p:control(crs)
    p:update()
    crs:update_cursor(p)
    
    -- map
    m=make_map()
    distmap()

    cam:update(p.x, p.y)

    --zombie
	for zombie in all(zombies) do
        -- player collide
        enemy_collide(p, zombie)

        -- projectile collide
        for projectile in all(proj) do
            projectile_collide(zombie, projectile)
        end
        
        -- actions
        zombie:getPath()
		zombie:control()
	end

    -- projectiles
    for projectile in all(proj) do
        projectile:update()
    end

    -- spawners
    for spawner in all(spawners) do
        spawner:spawn_zombie()
    end

    -- walls
    for wall in all(walls) do
        wall:degrade()
    end
end
-->8
-- player and zombies

function make_player(x, y)
    -- everything is in a table
    -- units are in tiles, where each tile is 8x8 pixels
    pl={
        -- fields
        x=x,
        y=y,
        w=0.45,
        h=0.45,
        dx=0,
        dy=0,
        max_dx=0.4,
        max_dy=0.4,
        accel=0.1,
        
        health=3,

        invincible=false,
        invincible_frames=30,

        sp=17,
        sp_frames=0,
        sp_flip=false,

        facing=1,

        -- functions
        control=function(self, c)
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

            if btnp(🅾️) and c.boxed_wall then
                mset(c.x, c.y, 2)
                start_wall_timer(walls, c.x, c.y)
            elseif btnp(🅾️) and c.boxed_barrier then
                bar = in_barriers(barriers, c.x, c.y)
                destroy_barrier(bar)
            elseif btnp(🅾️) and not c.boxed_wall then
                if self.facing == 1 then -- right
                    make_projectile(self, 1, 0)
                elseif self.facing == 2 then -- down
                    make_projectile(self, 0, 1)
                elseif self.facing == 3 then -- left
                    make_projectile(self, -1, 0)
                else -- up
                    make_projectile(self, 0, -1)
                end
            end

            -- ensures player doesnt exceed max dx or dy in any direction
            self.dx=mid(-self.max_dx, self.dx, self.max_dx)
			self.dy=mid(-self.max_dy, self.dy, self.max_dy)
        end,

        draw=function(self)
            -- drawing self sprite
            self.sp_frames=mid(0, self.sp_frames+1, 30)

            -- facing up or down
            if(abs(self.dx) < 0.1 and abs(self.dy) < 0.1) then  
                self.sp = 17
            else
                self.sp = 19
            end

            if(self.facing == 4) then
                self.sp += 4
            end
            if (self.sp_frames >= 15) then
                self.sp += 1
            end

            if self.invincible then
                self.sp = 25
            end

            -- facing left or right
            if(self.facing == 3 or (self.dx < 0 and self.facing == 4)) then
                self.sp_flip = true
            else
                self.sp_flip = false
            end

            spr(self.sp,(self.x*8)-4,(self.y*8)-4, 1, 1, self.sp_flip)

            -- Drawing health
            draw_health(self)
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
        end,

        lose_health=function(self)
            self.health-=1
            self.invincible=true
        end
    }

    return pl
end

function make_zombie(x, y)
    add(zombies,{
        id=z_id,
		x=x,
		y=y,
		w=0.4,
		h=0.4,
		dx=0,
		dy=0,
		max_dx=0.15,
		max_dy=0.15,
		accel=0.075,

        health=2,
        hit=false,

        sp=4,
        sp_frames=0,
        sp_flip=false,

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
                    if not solid_area(self.x+self.dx,self.y,self.w-0.3,self.h-0.3) then
                        self.x+=self.dx
                    end
                    
                    if not solid_area(self.x,self.y+self.dy,self.w-0.3,self.h-0.3) then 
                        self.y+=self.dy
                    end
                end
            end
		end,
		
		draw=function(self)
            -- for t in all(self.pathToP) do
            --     print("p", t.x*8, t.y*8, 7)
            -- end

            -- Drawing sprites
            self.sp_frames+=1
            if(self.sp_frames == 30) then
                self.sp_frames = 0
                self.hit = false
            end

             if (self.dy < 0) then
                self.sp = 35
            elseif (self.dy >= 0) then
                self.sp = 33
            end
            
            if(self.sp_frames >= 15) then
               self.sp += 1
            end

            if self.hit then
                self.sp = 37
            end

            -- Setting up facing
            if self.dx < 0 then 
                self.sp_flip=true
            else
                self.sp_flip=false
            end

			spr(self.sp,(self.x*8)-4,(self.y*8)-4, 1, 1, self.sp_flip)

            -- Drawing health
            draw_health(self)
		end,

        lose_health=function(self)
            self.health-=1
            self.hit=true

            if self.health == 0 then
                del(zombies, self)
            end
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

function make_cursor(p)
    crs={x=0,
         y=0,
         px=0,
         py=0,
         boxed_wall=false,
         boxed_barrier=false,

         draw_cursor=function(self)
            spr(49,self.px,self.py)
         end,

         update_cursor=function(self,p)
            self.x=p.x
            self.y=p.y

            if p.facing == 1 then -- right
                self.px=(p.x*8)+4
                self.py=(p.y*8)-4
                self.x+=1
            elseif p.facing == 2 then -- down
                self.px=(p.x*8)-4
                self.py=(p.y*8)+4
                self.y+=1
            elseif p.facing == 3 then -- left
                self.px=(p.x*8)-12
                self.py=(p.y*8)-4
                self.x-=1
            elseif p.facing == 4 then-- up
                self.px=(p.x*8)-4
                self.py=(p.y*8)-12
                self.y-=1
            end

            if(mget(self.x, self.y) == 7) then
                self.boxed_wall = true
            else
                self.boxed_wall = false
            end  

            if(mget(self.x, self.y) == 8) then
                self.boxed_barrier = true
            else
                self.boxed_barrier = false
            end          
         end,

         draw_box_wall=function(self)
            if(self.boxed_wall) then
                rect(self.px, self.py, self.px + 8, self.py+8, 7)
            end      
         end,

         draw_box_barrier=function(self,b)
            bar = in_barriers(b, flr(self.x), flr(self.y))
            if(self.boxed_barrier and bar != nil) then
                rect(bar.x1 * 8, bar.y1 * 8, bar.x2 * 8, bar.y2 * 8,7)
            end
         end
    }
    return crs
end

function draw_health(e)
    incrementor=-2
    iterator=0

    while (iterator < e.health) do
        rectfill((e.x*8)+incrementor,(e.y*8)-7,(e.x*8)+incrementor,(e.y*8)-6,8)

        iterator+=1
        incrementor+=2
    end
end

function make_projectile(p, pdx, pdy)
    add(proj,{
		sp=49,
		x=p.x,
		y=p.y,
		w=0.25,
		h=0.25,
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

function make_zombie_spawners()
    spawn={}
    for j=0, map_height do
        for i=0, map_width do
            if(mget(j,i) == 6) then
                add(spawn, {x=j,
                            y=i,
                            timer= 90 + flr(rnd(200)),
                            
                            spawn_zombie=function(self)
                                if(self.timer > 0) then
                                    self.timer -= 1
                                elseif(self.timer == 0 and m[self.y][self.x] > 0) then
                                    self.timer = 90 + flr(rnd(200))
                                    make_zombie(self.x, self.y)
                                end
                            end})
            end
        end
    end
    return spawn
end

function make_walls()
    w={}
    for j=0, map_height do
        for i=0, map_width do
            if(mget(j,i) == 7) then
                add(w, {x=j,
                        y=i,
                        timer=-1,
                        
                        degrade=function(self)
                            if(self.timer > 0) then
                                self.timer -= 1
                            elseif(self.timer == 0) then
                                mset(self.x,self.y,7)
                                self.timer = -1
                            end
                        end})
            end
        end
    end
    return w
end

function start_wall_timer(w, bx, by)
    for wall in all(w) do
        if (wall.x == flr(bx)) and (wall.y == flr(by)) then
            wall.timer = 250 + flr(rnd(300))
        end
    end
end

function make_barriers()
    b={}
    for j=0, map_height do
        for i=0, map_width do
            if(mget(j,i) == 8 and in_barriers(b,j,i) == nil) then
                add(b, get_barrier(j,i))
            end
        end
    end
    return b
end

function get_barrier(x1, y1)
    x2 = x1
    y2 = y1

    while(mget(x2+1,y2) == 8) do
        x2+=1
    end

    while(mget(x2,y2+1) == 8) do
        y2+=1 
    end

    bar={x1 = x1,
         y1 = y1,
         x2 = x2+1,
         y2 = y2+1
    }

    return bar
end

function in_barriers(b,x,y)
    for barrier in all(b) do
        if(barrier.x1 <= x and x <= barrier.x2) and (barrier.y1 <= y and y <= barrier.y2) then 
            return barrier
        end
    end
    return nil
end

function destroy_barrier(barrier)
   for j=barrier.x1, barrier.x2 - 1 do
        for i=barrier.y1, barrier.y2 - 1 do
            mset(j,i,5)
        end
    end
    del(barriers, barrier)
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
    if min <= 0 then
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
        p:lose_health()

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

function projectile_collide(z, p)
    if detect_collide(p, z, 0.5) then
        z:lose_health()
        del(proj, p)
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
000000008888888866666666ddddddddbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaa6666666600000000000000000000000000000000000000000000000000000000
000000008888888866666666ddddddddbbbbbbbbccccacccaccccccaa7cccc7a6666666600000000000000000000000000000000000000000000000000000000
007007008888888866666666ddddddddbbbbbbbbccccacccac7777caac7cc7ca6666666600000000000000000000000000000000000000000000000000000000
000770008888888866666666ddddddddbbbbbbbbaaaaaaaaac7777caacc77cca6666666600000000000000000000000000000000000000000000000000000000
000770008888888866666666ddddddddbbbbbbbbacccccccac7777caacc77cca6666d66600000000000000000000000000000000000000000000000000000000
007007008888888866666666ddddddddbbbbbbbbacccccccac7777caac7cc7ca6666666600000000000000000000000000000000000000000000000000000000
000000008888888866666666ddddddddbbbbbbbbaaaaaaaaaccccccaa7cccc7a6666666600000000000000000000000000000000000000000000000000000000
000000008888888866666666ddddddddbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaa6666666600000000000000000000000000000000000000000000000000000000
00000000000000000011110000111100000000000000000000111100001111000000000000000000000000000000000000000000000000000000000000000000
0000000000111100001fff00001fff00001111000011110000111f00001111000011110000888800000000000000000000000000000000000000000000000000
00000000001fff0000f1f10000f1f100001fff0000111f0000111f0000111f0000111f0000888800000000000000000000000000000000000000000000000000
0000000001f1f11000ffff0000ffff0000f1f10001111f1000ffff0000ffff0000111f0008878780000000000000000000000000000000000000000000000000
0000000001ffff10001221000112211001ffff1001111110001111000111111001ffff1008888880000000000000000000000000000000000000000000000000
000000000f1221f000f22f00f01221f00f12210f0f1111f000111100f01111f00f11110f08888880000000000000000000000000000000000000000000000000
00000000002222000022220000222200002222000022220000222200002222000022220000888800000000000000000000000000000000000000000000000000
00000000001001000010010000100010010001000010010000100100001000100100010000800800000000000000000000000000000000000000000000000000
0000000000000000003bbb0000000000003bbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000003bbb00003bbb00003bbb00003bbb000088880000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000003bbb0000313100003bbb00003333000088880000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000013131100033330001333310003333000887878000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000013333100011b11b013333100b11111b0888888000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000b1110b001111000011110b001111000088880800000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000001133000011330000113300001133000088880000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000003000100300010000300010030001000080008000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000010001000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0202020202020202020202020202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050507050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205060502050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050502050505020202020202050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202050505020202020202050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505080808050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505080808050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505080808050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020202020202020808080202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020202020202020808080202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050502050505050202050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205060502050505050202050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050507050505050202050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202050505050808050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050808050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050808050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020202020202020202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
