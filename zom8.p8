pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
-- main

map_width=32
map_height=32
m={}
spawners={}
walls={}
barriers={}
vending={}
z_id=0
cost = 500

text_frames=0
msg={text='',dx=0}
coinmsg=false

shakestart=false

function _init()
    pal(10, 1+128, 1)
    pal(12, 5+128, 1)

    --player init
	p=make_player(6,7)
    crs=make_cursor()
    crs:update_cursor(p)

	cam=make_camera()

    --enemies init
    zombies={}

    --map init
    m=make_map()
    walls=make(7)
    barriers=make(8)
    vending=make_vending()

    --projectile init
    proj={}

    -- particles init
    particles={}

    --spawner init
    spawners=make(6)

    frict=0.9
end

function _draw()

    cls()
	
	map(0,0)
	
	--player
    p:draw()
    crs:draw_cursor()

    --map
    -- print_map(m)
    cam:draw()

    --zombie
	for zombie in all(zombies) do
		zombie:draw()
	end

    print_3D_map(m, p)

    crs:draw_box_barrier(barriers, p)
    crs:draw_box_wall(walls, p)
    crs:draw_box_vending(vending, p)

    if(text_frames > 0)then
        draw_ui_prompt(msg.text, p.x*8 + msg.dx, p.y*8 + 58)
    end

    -- projectile
    for projectile in all(proj) do
        projectile:draw()
    end

    -- particles
    for particle in all(particles) do
        particle:draw()
    end

    --debug
    p:ui()
	-- -- print(p.x,p.x*8-62,p.y*8-62,8)
	-- -- print(p.y,p.x*8-62,p.y*8-56,8)
	-- print(p.dx,p.x*8-62,p.y*8-50,8)
	-- print(p.dy,p.x*8-62,p.y*8-44,8)
end

function _update()

    if text_frames > 0 then
        text_frames-=1
    elseif text_frames == 0 then
        coinmsg=false
    end

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
            projectile_collide(zombie, projectile, p)
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

    -- particle
    for particle in all(particles) do
        particle:update()
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
        shielded=false,
        invincible_frames=30,

        sp=17,
        sp_frames=0,
        sp_flip=false,
        facing=1,

        shotgun_frames=0,

        coins=0,

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
                make_particles(c.x, c.y, 13)
                start_wall_timer(walls, c.x, c.y)
                shakestart = true
            elseif btnp(🅾️) and c.boxed_barrier then
                if (self.coins >= cost) then
                    bar = in_set(barriers, c.x, c.y)
                    destroy_barrier(bar)
                    self.coins -= cost
                    cost += 500
                    shakestart = true
                else
                    coinmsg = true
                    set_msg('< not enough coins! >', -40)
                end
            elseif btnp(🅾️) and c.boxed_vending then
                vend = in_set(vending, c.x, c.y)
                if(self.coins >= vend.cost) then
                    make_particles(vend.x1, vend.y1, 9)
                    if(vend.perk == 1) then
                        self.health += 1
                    elseif(vend.perk == 2) then
                        self.shotgun_frames = 300
                    elseif(vend.perk == 3) then
                        self.invincible_frames = 300
                        self.invincible = true
                        self.shielded = true
                    end
                    self.coins -= vend.cost
                else
                    coinmsg = true
                    set_msg('< not enough coins! >', -40)
                end
            elseif btnp(🅾️) then
                if self.facing == 1 then -- right
                    make_projectile(self, 1, 0)
                    if(self.shotgun_frames > 0) then
                        make_projectile(self, 1, 0.3)
                        make_projectile(self, 1, -0.3)
                    end
                elseif self.facing == 2 then -- down
                    make_projectile(self, 0, 1)
                    if(self.shotgun_frames > 0) then
                        make_projectile(self, -0.3, 1)
                        make_projectile(self, 0.3, 1)
                    end
                elseif self.facing == 3 then -- left
                    make_projectile(self, -1, 0)
                    if(self.shotgun_frames > 0) then
                        make_projectile(self, -1, 0.3)
                        make_projectile(self, -1, -0.3)
                    end
                else -- up
                    make_projectile(self, 0, -1)
                     if(self.shotgun_frames > 0) then
                       make_projectile(self, 0.3, -1)
                       make_projectile(self, -0.3, -1)
                    end
                end
            end

            -- ensures player doesnt exceed max dx or dy in any direction
            self.dx=mid(-self.max_dx, self.dx, self.max_dx)
			self.dy=mid(-self.max_dy, self.dy, self.max_dy)
        end,

        draw=function(self)
            -- drawing self sprite
            self.sp_frames+=1
            if(self.sp_frames == 30) then
                self.sp_frames = 0
            end

            self.sp = 19
            -- facing up or down
            if(abs(self.dx) < 0.1 and abs(self.dy) < 0.1) then  
                self.sp = 17
            end

            if(self.facing == 4) then
                self.sp += 4
            end
            if (self.sp_frames >= 15) then
                self.sp += 1
            end

            if self.invincible and not self.shielded then
                self.sp = 25
            elseif self.invincible and self.shielded then
                print('<', self.x*8-8,self.y*8-2,7)
                print('<', self.x*8-7,self.y*8-2,7)
                print('>', self.x*8+4,self.y*8-2,7)
                print('>', self.x*8+5,self.y*8-2,7)
            end

            -- facing left or right
            self.sp_flip = self.facing == 3 or (self.dx < 0 and self.facing == 4)

            spr(self.sp,(self.x*8)-4,(self.y*8)-4, 1, 1, self.sp_flip)
        end,

        update=function(self)
            -- invincibility
            if self.invincible then
                self.invincible_frames -= 1
                
                if self.invincible_frames <= 0 then
                    self.invincible = false
                    self.shielded = false
                    self.invincible_frames = 30
                end
            end

            if self.shotgun_frames > 0 then
                self.shotgun_frames -= 1
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
        end,

        ui=function(self)
            rectfill(self.x*8-64, self.y*8-51, self.x*8+66, self.y*8-62, 0)
            print('< health:', self.x*8-58,self.y*8-59,7)
            draw_health(self, -20, 1, -59, -55)
            end_bracket = print('coins:'..self.coins,self.x*8+10,self.y*8-59,7)  
            print(' >', end_bracket,self.y*8-59,7)
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

            self.sp = 33
            if (self.dy < 0) then
                self.sp = 35
            end
            
            if(self.sp_frames >= 15) then
               self.sp += 1
            end

            if self.hit then
                self.sp = 37
            end

            -- Setting up facing
            self.sp_flip = self.dx < 0

			spr(self.sp,(self.x*8)-4,(self.y*8)-4, 1, 1, self.sp_flip)

            -- Drawing health
            draw_health(self, -2, 0, -6, -7)
		end,

        lose_health=function(self, pl)
            self.health-=1
            self.hit=true

            if self.health == 0 then
                pl.coins+=200
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
        shake=2,
        shakex=0,
        shakey=0,
        dirx=0,
        diry=0,
		
		update=function(self,x,y)
			self.cx=x*8-62
			self.cy=y*8-62
		end,
		
		draw=function(self)
            if(shakestart) then
                self.dirx = rnd()
                self.diry = rnd()
                self.shakex=5+rnd(10)
                self.shakey=5+rnd(10)

                if(self.dirx < 0.5) self.shakex *= -1
                if(self.diry < 0.5) self.shakey *= -1

                shakestart = false
            end

            self.shakex*=self.shake
            self.shakey*=self.shake

			camera(self.cx+self.shakex,self.cy+self.shakey)

            self.shake = self.shake*0.80
            if (self.shake<0.10) then 
                self.shake = 2
                self.shakex = 0
                self.shakey = 0
            end
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
         boxed_vending=false,

         draw_cursor=function(self)
            spr(49,self.px,self.py)
         end,

         update_cursor=function(self,p)
            self.x=p.x
            self.y=p.y
            self.px=(p.x*8)
            self.py=(p.y*8)

            if p.facing == 1 then -- right
                self.px+=4
                self.py-=4
                self.x+=1
            elseif p.facing == 2 then -- down
                self.px-=4
                self.py+=5
                self.y+=1
            elseif p.facing == 3 then -- left
                self.px-=13
                self.py-=4
                self.x-=1
            elseif p.facing == 4 then-- up
                self.px-=4
                self.py-=12
                self.y-=1
            end

            local spr_under = mget(self.x, self.y)

            self.boxed_wall = spr_under == 7
            self.boxed_barrier = spr_under == 8 
            self.boxed_vending = spr_under >= 50 and spr_under <= 52
         end,

         draw_box_wall=function(self, w, p)
            if(self.boxed_wall) then
                wall = in_set(w, flr(self.x), flr(self.y))
                rect(wall.x1 * 8, wall.y1 * 8, wall.x2 * 8 - 1, wall.y2 * 8 - 1, 7)
                if(not coinmsg) then
                    set_msg('< build wall? >', -30)  
                end
            end      
         end,

         draw_box_vending=function(self, v, p)
            if(self.boxed_vending) then
                vend = in_set(v, flr(self.x), flr(self.y))
                rect(vend.x1 * 8, vend.y1 * 8, vend.x2 * 8 - 1, vend.y2 * 8 - 1, 7)
                if(not coinmsg) then
                    set_msg('< '..vend.msg..' -> cost:'..vend.cost..' >', vend.text_offset)
                end
            end      
         end,

         draw_box_barrier=function(self,b,p)
            if(self.boxed_barrier) then
                bar = in_set(b, flr(self.x), flr(self.y))
                rect(bar.x1 * 8, bar.y1 * 8, bar.x2 * 8, bar.y2 * 8,7)
                if(not coinmsg) then
                    set_msg('< break barrier? -> cost:'..cost..' >', -58)  
                end
            end
         end
    }
    return crs
end

function draw_health(e, x1, width, y1, y2)
    incrementor=x1
    iterator=0

    while (iterator < e.health) do
        rectfill((e.x*8)+incrementor,(e.y*8)+y1,(e.x*8)+incrementor+width,(e.y*8)+y2,8)

        iterator+=1
        incrementor+=2+width
    end
end

function draw_ui_prompt(str, x, y)
    rectfill(p.x*8-64, p.y*8+55, p.x*8+66, p.y*8+66, 0)
    print(str, x, y, 7)
end

function set_msg(t, disx)
    text_frames = 50
    msg.text = t
    msg.dx = disx
end

function make_particles(mainx, mainy, colour)
    local numparticles = flr(rnd(6)) + 1
    for i=0, numparticles do
        local dx = rnd(0.4) + 0.05
        local dxdir = rnd()
        if(dxdir < 0.5) then
            dx*=-1
        end
        add(particles, make_particle(mainx, mainy, dx, -rnd(1)+0.1,colour))
    end
end

function make_particle(mainx, mainy, ddx, ddy, col)
    local particle = {x = mainx,
                y = mainy,
                inity = mainy,
                dx = ddx,
                dy = ddy,
                colour = col,
                accely = 0.1,

                draw=function(self)
                    circfill(self.x*8, self.y*8, 1, self.colour)
                end,

                update=function(self)
                    self.dy += self.accely

                    self.x += self.dx
                    self.y += self.dy

                    if(self.y*8 >= self.inity*8 + 8) then
                        del(particles, self)
                    end

                end
                }
    return particle
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
        offset=rnd(0.30)-0.15,
        
        draw=function(self)
            spr(self.sp,(self.x*8)-4,(self.y*8)-4)
        end,
        
        update=function(self)
            -- wall colission, destroy self
            if not solid_area(self.x+self.dx,self.y,self.w,self.h) then
                self.x+=self.dx
                self.y+=self.offset
            else 
                del(proj, self)
            end
            
            if not solid_area(self.x,self.y+self.dy,self.w,self.h) then
                self.y+=self.dy
                self.x+=self.offset
            else
                del(proj, self)
            end

        end}
    )
end

function make(spr)
    arr={}
    for j=0, map_height do
        for i=0, map_width do
            if(spr == 6 and mget(j,i) == 6) then
                add(arr, get_spawner(j,i))
            elseif(spr == 7 and mget(j,i) == 7) then
                add(arr, get_wall(j,i))
            elseif(spr == 8 and mget(j,i) == 8 and in_set(arr,j,i) == nil) then
                add(arr, get_barrier(j,i))
            end
        end
    end
    return arr
end

function get_spawner(j, i)
    spawner={x=j, 
            y=i,
            timer= 90 + flr(rnd(200)),
            
            spawn_zombie=function(self)
                if(self.timer > 0) then
                    self.timer -= 1
                elseif(self.timer == 0 and m[self.y][self.x] > 0) then
                    self.timer = 90 + flr(rnd(200))
                    make_zombie(self.x, self.y)
                end
            end}
    return spawner
end

function get_wall(j, i)
    wall={x1=j,
          y1=i,
          x2=j+1,
          y2=i+1,
          timer=-1,
        
          degrade=function(self)
            if(self.timer > 0) then
                self.timer -= 1
            elseif(self.timer == 0) then
                mset(self.x1,self.y1,7)
                make_particles(self.x1, self.y1, 13)
                self.timer = -1
            end
        end}
    return wall
end

function start_wall_timer(w, bx, by)
    for wall in all(w) do
        if (wall.x1 == flr(bx)) and (wall.y1 == flr(by)) then
            wall.timer = 250 + flr(rnd(300))
        end
    end
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

function destroy_barrier(barrier)
   for j=barrier.x1, barrier.x2 - 1 do
        for i=barrier.y1, barrier.y2 - 1 do
            mset(j,i,5)
        end
    end
    make_particles(bar.x1,(bar.y1+bar.y2)/2,13)
    make_particles(bar.x2,(bar.y1+bar.y2)/2,13)
    del(barriers, barrier)
end

function in_set(b,x,y)
    for m in all(b) do
        if(m.x1 <= x and x <= m.x2) and (m.y1 <= y and y <= m.y2) then 
            return m
        end
    end
    return nil
end

function make_vending()
    arr={}
    for j=0, map_height do
        for i=0, map_width do
            if(mget(j,i) == 50) then
                add(arr, get_vending(j,i,1,500,'+1 health?',-50))
            elseif(mget(j, i) == 51) then
                add(arr, get_vending(j,i,2,1000,'temp shotgun?',-57))
            elseif(mget(j, i) == 52) then
                add(arr, get_vending(j,i,3,1000,'invul shield?',-59))
            end
        end
    end
    return arr
end

function get_vending(j,i,pe,c,m,off)
    vending={x1=j,
             y1=i,
             x2=j+1,
             y2=i+1,
             perk=pe,
             cost=c,
             msg=m,
             text_offset=off
    }
    return vending
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

function print_3D_map(m, p)
    for j=0, map_height do
        -- adding new row
        for i=0, map_width do
            if(p.x - 9 <= i and i <= p.x + 9) and (p.y - 9 <= j and j <= p.y + 9) then
                if ((m[j][i] == 0 or m[j][i] > 10) and not (j == flr(p.y) and i == flr(p.x))) and not surround_light(i, j, m) then
                    spr(11, i*8, j*8)
                end
                if m[j][i] == 11 then 
                    spr(10, i*8, j*8)
                end
                if solid(i, j) and not fget(mget(i, j),1) then
                    spr(3,i*8,j*8)
                end
            end
        end
    end
end

function surround_light(x, y, m)
    if(x == 0 or y == 0 or x == map_width or y == map_height) then
        return false
    end
    for i = 0, 3 do
        -- check adjacent tiles in the cardinal directions
        local tileval = m[y + key_direction[i].y][x + key_direction[i].x]

        if(tileval > 0 and tileval <= 10) then
            return true
        end
    end 
    return false
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

        -- to reduce lag
        if curr_tile_dist > 20 then
            break
        end

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

function projectile_collide(z, pr, pl)
    if detect_collide(pr, z, 0.5) then
        z:lose_health(pl)
        del(proj, pr)
        make_particles(z.x, z.y, 8)
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
000000008888888866666666ddddddddbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaa66666666aaaaaaaaa0a0a0a0aaaaaaaaadadadad000000000000000000000000
000000008888888866666666ddddddddbbbbbbbbccccacccaccccccaa7cccc7a66666666acc77cca0a0a0a0aaaaaaaaadadadada000000000000000000000000
007007008888888866666666ddddddddbbbbbbbbccccacccac7777caac7cc7ca66666666acc77ccaa0a0a0a0aaaaaaaaadadadad000000000000000000000000
000770008888888866666666ddddddddbbbbbbbbaaaaaaaaac7777caacc77cca66666666a777777a0a0a0a0aaaaaaaaadadadada000000000000000000000000
000770008888888866666666ddddddddbbbbbbbbacccccccac7777caacc77cca66666666a777777aa0a0a0a0aaaaaaaaadadadad000000000000000000000000
007007008888888866666666ddddddddbbbbbbbbacccccccac7777caac7cc7ca6666d666acc77cca0a0a0a0aaaaaaaaadadadada000000000000000000000000
000000008888888866666666ddddddddbbbbbbbbaaaaaaaaaccccccaa7cccc7a66666666acc77ccaa0a0a0a0aaaaaaaaadadadad000000000000000000000000
000000008888888866666666ddddddddbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaa66666666aaaaaaaa0a0a0a0aaaaaaaaadadadada000000000000000000000000
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
00000000000000006111166661111666611116660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006111168661111696611116760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006111168661111696611116760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000660006111168661111696611116760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000660006111168661111696611116760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006666666666666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006111111661111116611111160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006666666666666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
20202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000
__gff__
0000010001000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0202020202020202020202020202020202020202020202020202020202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050507050505050505050505050508080805050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205060502050505050505050505050508080805050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050502050505050505020202050502020205050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202050505050505020202050502020205050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205340505050505050505330205050502020205050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050205050502020205050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050502020205050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020202020202020808020202020205050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020202020202020808020202020205050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050502050505050202050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205060502050505050202050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050507050505050202050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202050505050202050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050808050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050808050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0208080808080808020202050505050505050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050205050505050505050505050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505053205050505050505050505050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050505050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050505050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050505050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050505050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050905050505050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205050505050505050505050505050205050505050505050505050505050502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
