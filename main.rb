require 'app/draw_order.rb'

def tick(args)
  o = args.outputs
  s = args.state
  $init ||= 0
  $n ||= 0
  if $init.elapsed? 4.seconds
    $init = args.tick_count
    $n = ($n + 1) % 4
  end

  case $n
  when 0
    o.draw_order = [:static_layers_1, :static_layers_peanut, :static_solids, :labels]
  when 1
    o.draw_order = [:layers_tomato, :layers_potato, :layers_2, :labels]
  when 2
    o.draw_order = [:layers, :static_layers_2, :primitives, :labels]
  when 3
    o.draw_order = nil
  end

  if args.tick_count == 0
    s.t = 0
    s.a = [0, 0,  200, 720,  25,  50,   0].solid
    s.b = [0, 0,  200, 720,   0,  25,  50].solid
    s.c = [0, 0, 1280, 200,  50,   0,  25].solid
    s.d = [0, 0, 1280, 200,  20,  20,  20].solid

    o.static_solids << s.a
    o.static_solids << s.b
    o.static_layers[1]       << s.c
    o.static_layers[2]       << [540, 560, 200, 200, 'sprites/circle-yellow.png'].sprite
    o.static_layers[:peanut] << s.d
    o.static_primitives << [0, 0, 1280, 200, 0, 50, 50].solid
  end

  o.layers[1] << [540, 310, 100, 100, 'dragonruby.png'].sprite
  o.layers[2] << [640, 310, 100, 100, 'dragonruby.png'].sprite

  o.layers[:potato] << [490, 360, 200, 200, 'sprites/circle-orange.png'].sprite
  o.layers[:tomato] << [590, 360, 200, 200, 'sprites/circle-red.png'].sprite

  o.primitives << [540, 460, 200, 200, 'dragonruby.png'].sprite

  y = Math.sin(s.t).abs
  s.a[0] = 1080 * y
  s.b[0] = 1080 - 1080 * y
  s.c[1] = 520 * y
  s.d[1] = 520 - 520 * y

  s.t += 0.005
  v = o.draw_order
  o.labels << [640, 100, "#{v ? v : 'nil'}", 4, 1, 50, 127, 50]
  o.labels << [0, 720, $gtk.current_framerate, 0, 0, 255, 0, 0]
end
