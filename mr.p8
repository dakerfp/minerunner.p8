pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- minerunner
-- by dakerfp
-- version 1.0

lastb=0
function mouse()
	x=stat(32)
	y=stat(33)
	b=stat(34)
	bp=band(bxor(lastb,b),b) -- btnp
	lastb=b
	return x,y,b,bp
end


-->8
-- constants
row_width=16
s_0=32
s_unr=17
s_flag=18
s_mine=4
v0=0.02
vacc=0.002
highest_score=0

sfx_explosion=1
sfx_click=2
sfx_restart=3
sfx_reveal=4
sfx_speed=5
sfx_flag=6

-- game state
rows={}
explosion=nil
vel=v0
dy=0
life=100
score=0
t=0

function create_blank_row()
	row={}
	for i=1,row_width do
		add(row,{s=s_unr,v=s_0})
	end
	return row
end

function create_row(bombs)
	bombs=bombs or 1
	row=create_blank_row()
	for b=1,bombs do
		bi=flr(rnd(row_width))+1
		row[bi]={s=s_unr,v=s_mine}
	end
	return row
end

function has_mine(x,y)
	if (x<1 or x>row_width) return 0
	if (y<1 or y>#rows) return 0
	return (rows[y][x].v==s_mine) and 1 or 0
end

function count_mines(x,y)
		return has_mine(x-1,y-1) +
			has_mine(x-1,y) +
			has_mine(x-1,y+1) +
			has_mine(x,y-1) +
			has_mine(x,y+1) +
			has_mine(x+1,y-1) +
			has_mine(x+1,y) +
			has_mine(x+1,y+1)
end

function update_row_count(y)
	for x=1,row_width do
		if rows[y][x].v != s_mine then
			rows[y][x].v=s_0+count_mines(x,y)
			if rows[y][x].s != s_unr then
				v=rows[y][x].v
				rows[y][x].s=v
				mset(x-1,y-1,v)
			end
		end
	end
end

function update_all_map()
	for y=1,#rows do
		row=rows[y]
		for x=1,row_width do
			mset(x-1,y-1,row[x].s)
		end
	end
end

function score_for_row(r)
	for i=1,#r do
		c=r[i]
		if c.s==s_unr then
			if c.v!=s_mine then
				life-=1
			end
		elseif c.s==c_flag then
			if c.v==s_mine then
				score+=10
			else
				life-=1
				score-=10
			end
		end
	end
end

function rotate_row(r)
	-- rotate
	-- check life for deleted row
	score_for_row(rows[1])
	nrows={} -- delete rows[1]
	for y=2,#rows do
		add(nrows,rows[y])
	end
	rows=nrows
	add(rows,r)
	-- update last two rows
	for y=#rows-5,#rows do
		update_row_count(y)
	end
	-- update map
	for y=1,#rows do
		row=rows[y]
		for x=1,#row do
			mset(x-1,y-1,row[x].s)
		end
	end
end

function reveal(x,y)
	if (x<1 or x>row_width) return s_unr
	if (y<1 or y>#rows) return s_unr
	if rows[y][x].s == s_unr then
		rows[y][x].s=rows[y][x].v
		if rows[y][x].v == s_0 then
			reveal(x-1,y-1)
			reveal(x-1,y)
			reveal(x-1,y+1)
			reveal(x,y-1)
			reveal(x,y+1)
			reveal(x+1,y-1)
			reveal(x+1,y)
			reveal(x+1,y+1)
		end
		sfx(sfx_reveal,0)
	end
	mset(x-1,y-1,rows[y][x].s)
	return rows[y][x].s
end

function init_game_session()
	music(5)
	vel=v0
	dy=0
	rows={}
	score=0
	life=100
	explosion=nil
	t=0
	for y=1,10 do
		add(rows,create_blank_row())
	end
	for y=1,9 do
		add(rows,create_row(1))
	end
	for y=1,#rows do
		update_row_count(y)
	end
	update_all_map()
end

function _init()
	poke(0x5f2d, 1)
	cartdata("mine_runner")
	highest_score=dget(0)
	_update=update_intro
	music(0)
end

function map_to_grid(mx,my)
	x=flr((mx+1)/8)+1
	y=flr((my-dy)/8)+1
	x=mid(1,x,row_width)
	y=mid(1,y,#rows)
	return x,y
end

mx,my,mb=0,0,0
function update_game_loop()
	-- check for game over
	if life<=0 then
		sfx(sfx_explosion)
		music(-1,5000)
		_update=update_game_over
		return
	end

	-- time
	t+=1/30 -- in secs
	if t > 60 then -- every minute
		vel+=vacc
		t=0
	end
	-- read mouse
	mx,my,mb,mbp=mouse()
	-- left click: reveal
	if (band(mbp,1)==1) then
		sfx(sfx_click,2)
		x,y=map_to_grid(mx,my)
		if reveal(x,y)==s_mine then
			life-=100
		end
	end
	-- right click: set/unset flag
	if (band(mbp,2)==2) then
		sfx(sfx_flag,2)
		x,y=map_to_grid(mx,my)
		if rows[y][x].s == s_unr then
			rows[y][x].s=s_flag
			mset(x-1,y-1,s_flag)
		elseif rows[y][x].s == s_flag then
			rows[y][x].s=s_unr
			mset(x-1,y-1,s_unr)
		end
	end
	-- middle button: speed
	if (band(mb,4)==4) then
		dy-=0.5
		score+=0.5*2 -- double score when you speed
		if (band(mbp,4)==4) sfx(sfx_speed,1)
	else
		dy-=vel
		score+=vel
		sfx(-1,1)
	end
	if dy < -8 then
		complexity=flr(rnd(3))+1
		r=create_row(complexity)
		rotate_row(r)
		dy+=8
	end
	life=max(life,0)
end

show_help=false
function update_intro()
	show_help=btn(🅾️)
	if btnp(❎) then
		init_game_session()
		_update=update_game_loop
	end
end

restart=false
new_high_score=false
function update_game_over()
	show_help=btn(🅾️)
	mx,my,_,bp=mouse()
	-- explosion
	if explosion==nil then
		restart=false
 		explosion={x=mx,y=my,t=0.001,v=0.025}
	if score > highest_score then
		 highest_score=score
		 dset(0,score)
		 new_high_score=true
		end
	end
 	if explosion.t>0 and explosion.t<1 then -- animating
		explosion.t+=explosion.v
		explosion.t=mid(0,explosion.t,1)
	elseif not restart then
		if (band(bp,1)!=1) return
		init_game_session() -- nils explosion
		new_high_score=false
 	explosion={x=mx,y=my,
	 	t=0.999,v=-0.03}
		restart=true
		sfx(sfx_restart)
	elseif restart then
		explosion=nil
		restart=false
		_update=update_game_loop
	end
end

-->8

function draw_text(txt,x,y,c)
	for i=1,#txt	do
		print(txt[i],x,y,c)
		y+=8
	end
end

function draw_help()
	x=8
	y=8
	cls(3)
	txt={
		"-if you reveal bomb you lose",
		"-every unrevealed blank tile",
		" left behinds consumes hp",
		"-flag bombs and speed up",
		" to win more points",
		"-click left mouse button:",
		" to reveal tile",
		"-click right mouse button:",
		" to add flag over a tile",
		"-hold middle mouse button:",
		" to speed up the map"}
	draw_text(txt,x,y,9)
	print("@dakerfp",95,121,9)
end

function _draw()
	cls(3)

	if show_help and (_update==update_intro or _update==update_game_over) then
		draw_help()
		return
	end

	if _update==update_intro then
		map(0,0,0,0,16,16)
		spr(43,20,20)
		spr(44,30,20)
		rectfill(43,69,83,75,7)
		print("minerunner",44,70,9)
		rectfill(29,96,99,102,3)
		rectfill(29,104,99,110,3)
		draw_text({"press ❎ to start","press 🅾️ for help"},30,97,9)
		return
	end
	
	map(0,0,0,dy,16,#rows)
	x,y=map_to_grid(mx,my)
	rectfill(0,0,128,8,3)
	rectfill(69,1,121,7,2)
	rectfill(70,2,70+life/2,6,8)
	
	-- draw explosion
	e=explosion
	if e!=nil then
		r=e.t*e.t
		circfill(e.x,e.y,r*208,9)
		circfill(e.x,e.y,r*180,8)
		if e.t>=0.5 then -- almost finish animation
			print("game over",46,60,9)
			if e.t>=1 then
				print("click to restart",34,74,9)
			end
			if new_high_score then
				print("you've got a new high score!",10,86,7)
			else
				print("current high score: "..tostr(flr(highest_score)),13,86,9)
			end
		end
	end
	print("score: "..tostr(flr(score)),2,2,9)
	spr(1,mx-2,my) -- mouse
end
__gfx__
00000000010000000000000000000000bbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000171000000000000000000000b5b55b530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700177100000000000000000000bb5555bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000177710000000000000000000b55a85530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000177771000000000000000000b558a55b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700177110000000000000000000bb5555b30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011710000000000000000000b5b55b5b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000b3b3b3b30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbb333333335833333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbb33333333b5888833b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbb333333333588888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbb33333333b3588888b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbb333333333588833300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbb33333333b3353333b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbb333333333353333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b3b3b3b33b3b3b3b3b5b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000000000000000000000000000
bbbbbbb3bbeebbb3bbcccbb3bb111bb3bb8b8bb3bb999bb3bb222bb3bb444bb3bb000bb300000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbebbbbbbbbcbbbbbbb1bbbbb8b8bbbbb9bbbbbbb2bbbbbbbbb4bbbbb0b0bbb00000000000000000000000000000000000000000000000000000000
bbbbbbb3bbbebbb3bbcccbb3bbb11bb3bb888bb3bb999bb3bb222bb3bbbb4bb3bb000bb300000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbebbbbbbcbbbbbbbbb1bbbbbbb8bbbbbbb9bbbbb2b2bbbbbbb4bbbbb0b0bbb00000000000000000000000000000000000000000000000000000000
bbbbbbb3bbeeebb3bbcccbb3bb111bb3bbbb8bb3bb999bb3bb222bb3bbbb4bb3bb000bb300000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000000000000000000000000000
b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b300000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000007777777777700007777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77000077000770007770007770000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77700777000770007777007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777000770007707707770000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77077077000770007700777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77000077000770007700077777000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77000077000770007700007777000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77000077777777777700007777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010102121211010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010102112212223232210101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010102121211212121222212110101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010221111111111111111122121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2122111111111111111111111111122100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
002204001d3202332015320093200332003320053200832003320033200332001320013200532009320063200532005320083200b320033200332008320113201032006320033200332005320083200632004320
000a0000076100861008620096300b6300e630246703d6703a6503865013650106500e6500c6500a6500765007650056500465002640016400163001630016300163001630016300162001620016100161001600
000500000f6500f610026000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001c0500f0500a050090500805007050060500505004050020500205000000090500a050090500000000000090500b05008050000000000004050020500105001050000000000000000000000000000000
001000000a3201b310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000040311005110031100511000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000046500b5500d5500b75000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0118000014755127550f7550d75514755127550f7550d75514755127550f7550d75514755127550f7550d75514755127550f7550d75514755127550f7550d75514755127550f7550d75514755127550f7550d755
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01200000180501a0501c0501d0501a0501c0501d0501f050180501a0501c0501d0501a0501c0501d0501f050180501a0501c0501d0501c0501d0501f0502105023050210501f0501d0501a0501d0501f0501f050
01200000181500d1001a1500000018150000001a1500000018150000001a1500000018150000001c1500000018150000001a1500000018150000001a1500000018150000001a1500000018150000001c15000000
0020000018623000001c6230000018623000001c623000001862300000186230000018623186331862300000186230000018623000001a623000001862300000186230000018623000001a6231a6131a62300000
__music__
02 0b0c0d44
00 41424344
00 41424344
00 41424344
00 41424344
03 07424344

