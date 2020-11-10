# Just Fun Stuff
Lunar Lander Minigame in 554 Chars
```ruby
def tick a
(w=24;h=300;$l=p
$v=20*(60*rand).to_i
$m=(0..64).map{|x|o=h;h-=(x==$v/20?($h=h-3;0):s=2*w*rand-w);[x*20,o,20*(x+1),h]}
$x,$y=$r=180,700;$b=1;$n=0;$g=2e-3)if(k=a.inputs.keyboard).z||a.tick_count==0
!$l&&k.up&&($b+=$r.cos*8e-3;$n+=$r.sin*8e-3;t=1)
$r-=k.left_right
$x+=$b;$y+=$n-=$g
$l||=$y<$m[($x/20).to_i][3]?$x>$v&&$x<$v+20?1:0:p
r=a.render_target(:r)
r.width=r.height=2
r.solids<<[[0,0,1,3,t ?255:[100]*3],[1,0,1,3,[0]*3]]
a.lines<<$m
a.sprites<<[$x,$y,10,10,:r,$r]
a.solids<<[[0,0,2e3,720,$l ?$l<1?255:[0,255]:[255]*3],[$v,$h,20,2,255]]
end
```
