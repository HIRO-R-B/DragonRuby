# Contributors: Hiro_r_b#7841
#               mikemar10#9709

class Primitive
  attr_accessor :x, :y, :r, :g, :b, :a

  def initialize(x: 0, y: 0, r: 255, g: 255, b: 255, a: 255, **kw)
    @x = x; @y = y;
    @r = r; @g = g; @b = b; @a = a
    kw.each do |name, val|
      singleton_class.class_eval { attr_accessor "#{name}" }
      send("#{name}=", val)
    end
  end
end

class Solid < Primitive
  def initialize(w: 0, h: 0, **kw)
    super(primitive_marker: :solid, w: w, h: h, **kw)
  end
end

class Sprite < Primitive
  def initialize(path:, w: 0, h: 0, **kw)
    super(primitive_marker: :sprite, w: w, h: h, path: path, **kw)
  end

  def draw_override(ffi_draw)
    ffi_draw.draw_sprite_3(@x, @y, @w, @h,
                           @path,
                           @angle,
                           @a, @r, @g, @b,
                           nil, nil,
                           nil, nil, nil, nil,
                           @angle_anchor_x, @angle_anchor_y,
                           nil, nil, nil, nil)
  end
end

# Altered variant of mikemar10's procedural hexagons
class Hexagon
  attr_accessor :x, :y, :r, :g, :b, :a, :angle,
                :ord_x, :ord_y, :off_x, :off_y, :center
  attr_reader :radius

  def self.sqrt3
    @sqrt3 ||= Math.sqrt(3)
  end
  def self.rt_name
    @rt_name ||= [*('a'..'z')].shuffle[0, 6].join
  end

  def self.rt
    @rt ||= $gtk.args.render_target(rt_name()).tap do |target|
      target.width = 25
      target.height = 25
      target.solids << Solid.new(w: 25, h: 25)
    end
  end

  def initialize(x:, y:, radius:, r:, g:, b:, a:, angle:,
                 ord_x:, ord_y:, off_x:, off_y:, center:)
    @x = x; @y = y
    @radius = radius
    @height = radius * Hexagon.sqrt3
    @r = r; @g = g; @b = b; @a = a
    @angle = angle
    @ord_x = ord_x; @ord_y = ord_y
    @off_x = off_x; @off_y = off_y
    @center = center

    @sprites = 3.map_with_index do |n|
      Sprite.new(
        x: x + @radius / 2,
        y: y,
        w: @radius,
        h: @height,
        path: Hexagon.rt_name(),
        angle: 30 + 60 * n + @angle,
        r: @r,
        g: @g,
        b: @b,
        a: @a,
        angle_anchor_x: 0.5,
        angle_anchor_y: 0.5)
    end
  end

  def radius= radius
    @height = radius * Hexagon.sqrt3
    @radius = radius
  end

  def w
    @radius * 2
  end

  def h
    @height
  end

  def draw_override(ffi_draw)
    i = 0
    while i < 3
      s = @sprites[i]
      s.x = @x + @radius / 2
      s.y = @y
      s.w = @radius
      s.h = @height
      s.angle = 30 + 60 * i + @angle
      s.r = @r
      s.g = @g
      s.b = @b
      s.a = @a

      i += 1

      s.draw_override(ffi_draw)
    end
  end
end

class HexagonRotate
  attr_gtk

  def defaults
    Hexagon.rt()

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
      ord_x = ordinal_x
      ord_y = ordinal_y
      off_x = (ordinal_y.even?) ?
              (state.world_x_offset + state.tile_w.half.half) :
              (state.world_x_offset - state.tile_w.half.half)
      off_y = state.world_y_offset
      w     = state.tile_w
      h     = state.tile_h

      x = off_x + ord_x * w
      y = off_y + ord_y * h

      center = {
        x: x + w.half,
        y: y + h.half
      }
      radius = [w.half, h.half].max
      r, g, b = [255, 127, 127].shuffle

      Hexagon.new(
        x: x,
        y: y,
        radius: radius,
        r: r,
        g: g,
        b: b,
        a: 127,
        angle: 0,
        ord_x: ord_x,
        ord_y: ord_y,
        off_x: off_x,
        off_y: off_y,
        center: center
      )
    end

    state.selected_tile = nil
    state.rotate_mode = false
    state.rotation = 0
    state.rot_ini = nil
    state.rot_grab_ini = nil
    state.rot_grab_cur = 0
    state.snap_angles = (0..8).map { |i| i * Math::PI/3 }
    state.force = 0.1
  end

  def nearest_angle angle, angles
    angles.min_by { |x| (angle-x).abs }
  end

  def input
    if inputs.click && !state.rotate_mode
      tile = state.tiles.find { |t| inputs.click.point_inside_circle? t.center, t.radius }
      if tile && tile.a == 127
        points = (0..7).map do |i|
          r = i*Math::PI/3
          { x: tile.center.x + 50 * Math.cos(r),
            y: tile.center.y + 50 * Math.sin(r) }
        end

        tiles = state.tiles.select do |t|
          points.any? do |p|
            p.point_inside_circle? t.center, t.radius
          end
        end

        tiles.each do |t|
          t.a = t.a == 255 ? 127 : 255
        end

        state.rotate_mode = true
        state.selected_tile = tile
      end
    else
      if state.rotate_mode
        if inputs.mouse.button_left
          p = inputs.mouse.point
          tiles = state.tiles.select { |t| t.a == 255 }

          if tiles.any? { |t| p.point_inside_circle? t.center, t.radius }
            point = { x: state.selected_tile.center.x,
                      y: state.selected_tile.center.y }

            state.rot_ini ||= state.rotation
            state.rot_grab_ini ||= point.angle_to(p).to_radians
            state.rot_grab_cur = point.angle_to(p).to_radians

            state.rotation = state.rot_grab_cur - state.rot_grab_ini + state.rot_ini
            state.force = 0.1
          end
        else
          state.rot_grab_ini = nil
          state.rot_ini = nil
          state.force = 0.05
        end

        if inputs.mouse.button_right
          tiles = state.tiles.select { |t| t.a == 255 }

          colors = tiles.map { |t| [t.r, t.g, t.b] }
          tiles.map_with_index  do |t, i|
            point = { x: t.x + t.w.half,
                      y: t.y + t.h.half }

            tile = state.tiles.find { |tile| point.point_inside_circle?(tile.center, tile.radius * 0.8) }

            tile.r, tile.g, tile.b = colors[i]
          end

          tiles.each { |t| t.a = 127; t.angle = 0 }

          state.rotate_mode = false
          state.rotation = 0
        end
      end
    end
  end

  def update
    state.rotation = state.rotation.towards(nearest_angle(state.rotation, state.snap_angles), state.force)
    state.rotation %= 2 * Math::PI
  end

  def render
    outputs.background_color = [0, 0, 0]

    bg_tiles = state.tiles.select { |t| t.a == 127 }
    bg_tiles.each do |t|
      point = { x: t.off_x + t.ord_x * t.w,
                y: t.off_y + t.ord_y * t.h }

      t.x = point.x
      t.y = point.y
    end

    fg_tiles = state.tiles.select { |t| t.a == 255 }
    fg_tiles.map do |t|
      tile = state.selected_tile
      r = state.rotation

      point = { x: t.off_x + t.ord_x * t.w,
                y: t.off_y + t.ord_y * t.h }

      vx = point.x - tile.x
      vy = point.y - tile.y
      vm = Math.sqrt(vx*vx + vy*vy)

      old_angle = Math.atan2(vy, vx)
      new_angle = old_angle + r

      new_point = [
        tile.x + vm * Math.cos(new_angle),
        tile.y + vm * Math.sin(new_angle),
      ]

      t.angle = new_angle.to_degrees

      t.x = new_point.x
      t.y = new_point.y + 10
    end

    outputs.sprites << bg_tiles
    outputs.sprites << fg_tiles

    # ## DEBUG ## vvvvvvvvvvvvvvvvvvvvvv
    # tiles = state.tiles.select { |t| t.a == 255 }
    # tiles.each do |t|
    #   point = { x: t.x + t.w.half,
    #             y: t.y + t.h.half }

    #   tile = state.tiles.find { |tile| point.point_inside_circle?(tile.center, tile.radius * 0.8) }

    #   outputs.primitives << [point.x, point.y, 10, 10].solid
    #   outputs.primitives << [tile.center.x, tile.center.y, 10, 10, 255, 0, 0].solid if tile
    # end

    # tile = state.tiles.find { |t| inputs.mouse.position.point_inside_circle? t.center, t.radius }
    # outputs.primitives << [tile.x, tile.y, 10, 10, 255, 255, 255].solid if tile
    # outputs.primitives << [tile.center.x, tile.center.y, 10, 10, 255, 255, 255].solid if tile
    # outputs.labels << [0, 700, "Angle: #{nearest_angle(state.rotation, state.snap_angles)}", 0, 0, 255, 255, 255]
    # outputs.labels << [0, 680, "Rot: #{state.rotation}", 0, 0, 255, 255, 255]
    # outputs.labels << [0, 720, "FPS: #{gtk.current_framerate}", 0, 0, 255, 255, 255]
    # ## DEBUG ## ^^^^^^^^^^^^^^^^^^^^^^^
  end

  def tick
    defaults if args.tick_count.zero?
    input
    update
    render
  end
end

$game = HexagonRotate.new
def tick args
  $game.args = args
  $game.tick
end
$gtk.reset
