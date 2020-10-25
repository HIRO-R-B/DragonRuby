# Contributors: Hiro_r_b#7841
#               mikemar10#9709

class Primitive
  attr_accessor :x, :y, :r, :g, :b, :a

  def initialize(x: 0, y: 0, r: 255, g: 255, b: 255, a: 255, **kw)
    @x = x
    @y = y
    @r = r
    @g = g
    @b = b
    @a = a
    kw.each do |name, val|
      singleton_class.class_eval { attr_accessor "#{name}" }
      send("#{name}=", val)
    end
  end
end

class Solid < Primitive
  def initialize(w: 0, h: 0, **kw)
    super(primitive_marker: :solid, w: w, h: h, r: 0, g: 0, b: 0, **kw)
  end
end

class Sprite < Primitive
  def initialize(path:, w: 0, h: 0, **kw)
    super(primitive_marker: :sprite, w: w, h: h, path: path, **kw)
  end

  def draw_override(ffi_draw)
    ffi_draw.draw_sprite_3(@x, @y, @w, @h,
                           @path,
                           nil,
                           @a, @r, @g, @b,
                           nil, nil,
                           nil, nil, nil, nil,
                           nil, nil,
                           nil, nil, nil, nil)
  end
end

# mikemar10
class Hexagon
  attr_accessor :x, :y, :w, :h, :r, :g, :b, :a, :angle # Added Alpha
  attr_reader :radius

  def self.rt_name
    @rt_name ||= [*('a'..'z')].shuffle[0, 6].join
  end

  def self.rt
    @rt ||= $gtk.args.render_target(rt_name()).solids << Solid.new(0, 0, 25, 25, 255, 255, 255, 255)
  end

  def initialize x, y, radius, r = 0, g = 0, b = 0, a = 127, angle = 0, opts = {}
    @x = x; @y = y
    @radius = radius
    @r = r; @g = g; @b = b; @a = a
    @angle = angle
    @opts = opts

    Hexagon.rt()
  end

  def width
    @radius
  end

  def height
    @height ||= @radius * Math.sqrt(3)
  end

  def radius= radius
    @radius = radius
    @height = nil
    prepare_render_target
  end

  def output
    3.map_with_index do |n|
      {x: x - width / 2,
       y: y - height / 2,
       w: 1280,
       h: 720,
       path: Hexagon.rt_name(),
       angle: 60 * n + @angle,
       r: @r,
       g: @g,
       b: @b,
       a: @a,
       angle_anchor_x: width / 2 / 1280.0,
       angle_anchor_y: height / 2 / 720.0
      }
    end
  end
end

class HexagonRotate
  attr_gtk

  def defaults
    state.tile_size       = 80
    state.tile_w          = Math.sqrt(3) * state.tile_size.half
    state.tile_h          = state.tile_size * 3/4
    state.tiles_x_count   = 1280.idiv(state.tile_w) - 1
    state.tiles_y_count   = 720.idiv(state.tile_h) - 1
    state.world_width_px  = state.tiles_x_count * state.tile_w
    state.world_height_px = state.tiles_y_count * state.tile_h
    state.world_x_offset  = (1280 - state.world_width_px).half
    state.world_y_offset  = (720 - state.world_height_px).half
    state.tiles           = state.tiles_x_count.map_with_ys(state.tiles_y_count) do |ordinal_x, ordinal_y|
      h = {
        ord_x: ordinal_x,
        ord_y: ordinal_y,
        off_x: (ordinal_y.even?) ?
               (state.world_x_offset + state.tile_w.half.half) :
               (state.world_x_offset - state.tile_w.half.half),
        off_y: state.world_y_offset,
        w: state.tile_w,
        h: state.tile_h
      }

      x = h[:off_x] + h[:ord_x] * h[:w]
      y = h[:off_y] + h[:ord_y] * h[:h]

      h[:center] = {
        x: x + h[:w].half,
        y: y + h[:h].half
      }
      h[:radius] = [h[:w].half, h[:h].half].max

      Hexagon.new(
        x,                   # x
        y,                   # y
        h[:radius],          # radius
        255.randomize(:int), # r
        255.randomize(:int), # g
        255.randomize(:int), # b
        127,                 # a
        0,                   # angle
        h                    # opts
      )
      # {
      #   ordinal_x: ordinal_x,
      #   ordinal_y: ordinal_y,
      #   offset_x: (ordinal_y.even?) ?
      #             (state.world_x_offset + state.tile_w.half.half) :
      #             (state.world_x_offset - state.tile_w.half.half),
      #   offset_y: state.world_y_offset,
      #   w: state.tile_w,
      #   h: state.tile_h,
      #   type: :blank,
      #   path: 2.randomize(:int) == 0 ? 'sprites/hexagon-gray.png' : 'sprites/hexagon-blue.png',
      #   a: 127,
      #   angle_anchor_x: 0.5,
      #   angle_anchor_y: 0.5
      # }.associate do |h|
      #   h.merge(x: h[:offset_x] + h[:ordinal_x] * h[:w],
      #           y: h[:offset_y] + h[:ordinal_y] * h[:h])
      # end.associate do |h|
      #   h.merge(center: {
      #             x: h[:x] + h[:w].half,
      #             y: h[:y] + h[:h].half
      #           }, radius: [h[:w].half, h[:h].half].max)
      # end
    end

    state.selected_tile = nil
    state.rotate_mode = false
    state.rotation = 0
    state.snap_angles = (0..8).map { |i| i * Math::PI/3 }
  end

  def nearest_angle angle, angles
    angles.min_by { |x| (angle-x).abs }
  end

  def input

    if inputs.click && !state.rotate_mode
      tile = state.tiles.find { |t| inputs.click.point_inside_circle? t[:center], t[:radius] }
      if tile && tile[:a] == 127
        points = (0..7).map do |i|
          r = i*Math::PI/3
          { x: tile[:center].x + 50 * Math.cos(r),
            y: tile[:center].y + 50 * Math.sin(r) }
        end

        tiles = state.tiles.select do |t|
          points.any? do |p|
            p.point_inside_circle? t[:center], t[:radius]
          end
        end

        tiles.each do |t|
          t[:a] = t[:a] == 255 ? 127 : 255
        end

        state.rotate_mode = true
        state.selected_tile = tile
      end
    else
      if state.rotate_mode && inputs.mouse.button_left
        p = inputs.mouse.point
        tiles = state.tiles.select { |t| t[:a] == 255 }

        if tiles.any? { |t| p.point_inside_circle? t[:center], t[:radius] }
          point = { x: state.selected_tile[:center].x,
                    y: state.selected_tile[:center].y }

          state.rotation = point.angle_to(p).to_radians
        end
      end

      if inputs.mouse.button_right
        tiles = state.tiles.select { |t| t[:a] == 255 }
        paths = tiles.map { |t| t[:path] }
        paths = tiles.map_with_index  do |t, i|
          point = { x: t.x + t[:w].half,
                    y: t.y + t[:h].half }

          tile = state.tiles.find { |tile| point.point_inside_circle?(tile[:center], tile[:radius] * 0.8) }

          tile[:path] = paths[i]
        end

        tiles.each { |t| t[:a] = 127; t[:angle] = 0 }

        state.rotate_mode = false
        state.rotation = 0
      end
    end
  end

  def update
    state.rotation = state.rotation.towards(nearest_angle(state.rotation, state.snap_angles), 0.08)
  end

  def render
    outputs.background_color = [0, 0, 0]

    outputs.sprites << state.tiles.map do |t|
      t.output
    end

    # bg_tiles = state.tiles.select { |t| t[:a] == 127 }
    # bg_tiles.map do |t|
    #   point = [t[:offset_x] + t[:ordinal_x] * t[:w],
    #            t[:offset_y] + t[:ordinal_y] * t[:h]]

    #   t[:x] = point.x
    #   t[:y] = point.y
    # end

    # fg_tiles = state.tiles.select { |t| t[:a] == 255 }
    # fg_tiles.map do |t|
    #   tile = state.selected_tile
    #   r = state.rotation

    #   point = [t[:offset_x] + t[:ordinal_x] * t[:w],
    #            t[:offset_y] + t[:ordinal_y] * t[:h]]

    #   vx = point.x - tile[:x]
    #   vy = point.y - tile[:y]
    #   vm = Math.sqrt(vx*vx + vy*vy)

    #   old_angle = Math.atan2(vy, vx)
    #   new_angle = old_angle + r

    #   new_point = [
    #     tile[:x] + vm * Math.cos(new_angle),
    #     tile[:y] + vm * Math.sin(new_angle),
    #   ]

    #   t[:angle] = new_angle.to_degrees

    #   t[:x] = new_point.x
    #   t[:y] = new_point.y + 10
    # end

    # outputs.sprites << bg_tiles
    # outputs.sprites << fg_tiles

    # tiles = state.tiles.select { |t| t[:a] == 255 }
    # tiles.each do |t|
    #   point = { x: t.x + t[:w].half,
    #             y: t.y + t[:h].half }

    #   tile = state.tiles.find { |tile| point.point_inside_circle?(tile[:center], tile[:radius] * 0.8) }

    #   outputs.primitives << [point.x, point.y, 10, 10].solid
    #   outputs.primitives << [tile[:center].x, tile[:center].y, 10, 10, 255, 0, 0].solid if tile
    # end

    # outputs.labels << [0, 720, "Angle: #{nearest_angle(state.rotation, state.snap_angles)}", 0, 0, 255, 255, 255]
    # outputs.labels << [0, 700, "Rot: #{state.rotation}", 0, 0, 255, 255, 255]
    outputs.labels << [0, 720, "Angle: #{gtk.current_framerate}", 0, 0, 255, 255, 255]
  end

  def tick
    defaults if args.tick_count.zero?
    # input
    # update
    render
  end
end

$game = HexagonRotate.new
def tick args
  $game.args = args
  $game.tick
end
$gtk.reset
