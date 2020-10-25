
class Hexagon
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
      {
        ordinal_x: ordinal_x,
        ordinal_y: ordinal_y,
        offset_x: (ordinal_y.even?) ?
                  (state.world_x_offset + state.tile_w.half.half) :
                  (state.world_x_offset - state.tile_w.half.half),
        offset_y: state.world_y_offset,
        w: state.tile_w,
        h: state.tile_h,
        type: :blank,
        path: "sprites/hexagon-gray.png",
        a: 127,
        angle_anchor_x: 0.5,
        angle_anchor_y: 0.5
      }.associate do |h|
        h.merge(x: h[:offset_x] + h[:ordinal_x] * h[:w],
                y: h[:offset_y] + h[:ordinal_y] * h[:h])
      end.associate do |h|
        h.merge(center: {
                  x: h[:x] + h[:w].half,
                  y: h[:y] + h[:h].half
                }, radius: [h[:w].half, h[:h].half].max)
      end
    end

    state.selected_tile = nil
    state.rotate_mode = false
    state.rotation = 0
  end

  def input
    if inputs.click && !state.rotate_mode
      tile = state.tiles.find { |t| inputs.click.point_inside_circle? t[:center], t[:radius] }
      if tile && tile[:a] == 127
        points = (0..7).map do |i|
          r = i*3.14/4
          {x: tile[:center][:x] + 50 * Math.cos(r), y: tile[:center][:y] + 50 * Math.sin(r)}
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
          x = state.selected_tile[:center][:x]
          y = state.selected_tile[:center][:y]

          state.rotation = Math.atan2(p.y - y, p.x - x)
        end
      end

      if inputs.mouse.button_right
        state.tiles.select { |t| t[:a] == 255 }.each { |t| t[:a] = 127; t[:angle] = 0 }

        state.rotate_mode = false
      end
    end
  end

  def tick
    defaults if args.tick_count == 0
    input
    render
  end

  def render
    outputs.background_color = [0, 0, 0]

    bg_tiles = state.tiles.select { |t| t[:a] == 127 }
    bg_tiles.map do |t|
      point = [t[:offset_x] + t[:ordinal_x] * t[:w],
               t[:offset_y] + t[:ordinal_y] * t[:h]]

      t[:x] = point.x
      t[:y] = point.y
    end

    fg_tiles = state.tiles.select { |t| t[:a] == 255 }
    fg_tiles.map do |t|
      tile = state.selected_tile
      r = state.rotation

      point = [t[:offset_x] + t[:ordinal_x] * t[:w],
               t[:offset_y] + t[:ordinal_y] * t[:h]]

      vx = point.x - tile[:x]
      vy = point.y - tile[:y]
      vm = Math.sqrt(vx*vx + vy*vy)

      old_angle = Math.atan2(vy, vx)
      new_angle = old_angle + r

      new_point = [
        tile[:x] + vm * Math.cos(new_angle),
        tile[:y] + vm * Math.sin(new_angle),
      ]

      t[:angle] = new_angle.to_degrees

      t[:x] = new_point.x
      t[:y] = new_point.y
    end

    outputs.sprites << bg_tiles
    outputs.sprites << fg_tiles
  end
end

$game = Hexagon.new

def tick args
  $game.args = args
  $game.tick
end

$gtk.reset
