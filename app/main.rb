=begin
Slay The Lich
  It's the final battle between the hero and the Lich King
  The hero must kill the Lich King in 20 seconds before he ends the world
  Use the arrow keys (←↑→↓) [or dpad] to break the barriers guarding the lich
  and strike the final blow

vv DEBUG BARS vv
#| DEBUG << |#===============# [Place notes here]
#| DEBUG >> |#===============# [Notes!]

CODE INBETWEEN THOSE BARS ARE FOR TESTING
- EXACT SIZE FOR EASY SEARCHING!

=end

class Numeric
  def frame_index *opts
    frame_count_or_hash, hold_for, repeat, tick_count_override = opts
    if frame_count_or_hash.is_a? Hash
      frame_count         = frame_count_or_hash[:count]
      hold_for            = frame_count_or_hash[:hold_for]
      repeat              = frame_count_or_hash[:repeat]
      tick_count_override = frame_count_or_hash[:tick_count_override]
    else
      frame_count = frame_count_or_hash
    end

    tick_count_override ||= Kernel.tick_count
    animation_frame_count = frame_count
    animation_frame_hold_time = hold_for
    animation_length = animation_frame_hold_time * animation_frame_count
    return nil if Kernel.tick_count < self

    if !repeat && (self + animation_length) < (tick_count_override + 1)
      return nil
    else
      return self.elapsed_time.idiv(animation_frame_hold_time) % animation_frame_count
    end
  rescue Exception => e
  end
end

class SlayTheLich
  attr_gtk

  def initialize
    @mode = :normal # :jujule
  end

  class Primitive
    attr_accessor :x, :y, :r, :g, :b, :a

    def initialize(x: 0, y: 0, r: 255, g: 255, b: 255, a: 255, **hash)
      @x, @y, @r, @g, @b, @a = x, y, r, g, b, a
      hash.each do |name, val|
        singleton_class.class_eval { attr_accessor "#{name}" }
        send("#{name}=", val)
      end
    end
  end

  class Solid < Primitive
    def initialize(w: 0, h: 0, **hash)
      super(w: w, h: h, r: 0, g: 0, b: 0, **hash,
            primitive_marker: :solid)
    end
  end

  class Label < Primitive
    def initialize(text: '', s_e: 16, a_e: 1, font: 'fonts/lowrez.ttf', **hash)
      super(text: text, size_enum: s_e, alignment_enum: a_e, font: font, **hash,
            primitive_marker: :label)
    end
  end

  class Sprite < Primitive
    def initialize(w: 0, h: 0, path: '', **hash)
      super(w: w, h: h, path: path, **hash,
            primitive_marker: :sprite)
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

  def font name
    "fonts/#{name}.ttf"
  end

  def png name
    "sprites/slaythelich/#{name}.png"
  end

  def wav name
    "sounds/#{name}.wav"
  end

  def ogg name
    "sounds/#{name}.ogg"
  end

  def defaults
    outputs.clear

    @bg_color = [0, 0, 0]

    @scale_x = 105 / 32
    @scale_y = 45 / 14

    @start_at = nil
    @game_at  = nil
    @win_at   = nil
    @lose_at  = nil
    @reset_at = nil

    @time = 20.seconds

    @n_orbs = @mode == :jujule ? 20 : 10

    #| STATICS << |#============================================#| STATICS << |#
    @timer_bar = Solid.new(w: 1280, r: 21, g: 9, b: 29)

    @background = Sprite.new(x: 640 - 256 * @scale_x / 2,
                             w: 256 * @scale_x,
                             h: 224 * @scale_y,
                             path: png('bg_0'))

    @slash = Sprite.new(x: 640 - 128 * @scale_x / 2,
                        y: 168,
                        w: 128 * @scale_x,
                        h: 128 * @scale_y,
                        path: png('slash_0'),
                        a: 0,
                        live: false,
                        init_tick: 0)

    @box = Label.new(x: 640, y: 160, text: '[ ]', font: nil)
    combo = new_combo(1)
    @lock = Label.new(x: 615, y: 160,
      text: combo_to_str(combo),
      a_e: 0, font: nil,
      combo: combo)
    @timer = Label.new(x: 640, y: 48, text: 'PRESS ARROW')
    @timer.text = 'Jujule Mode: Good Luck' if @mode == :jujule
    @end_text = Label.new(x: 640, y: 550, a: 0)
    @play_again = Label.new(x: 640, y: 48, text: 'PRESS ARROW', a: 0)

    @reset_solid = Solid.new(w: 1280, h: 720)

    outputs.static_solids << @timer_bar
    outputs.static_sprites << [@background, @slash]
    outputs.static_primitives << [
      @box, @lock, @timer, @end_text, @play_again, @reset_solid
    ]
    #| STATICS << |#============================================#| STATICS << |#
    @void = Solid.new(h: 720)

    @lich = Sprite.new(x: 640 - 128 * @scale_x / 2,
                       y: 168,
                       w: 128 * @scale_x,
                       h: 128 * @scale_y,
                       path: png('lich_0'),
                       z: 0)

    @orbs = (0...@n_orbs).map do |i|
      Sprite.new(x: 640 - 32 * @scale_x / 2,
                 y: 250,
                 w: 32 * @scale_x,
                 h: 32 * @scale_y,
                 path: png('orb_0'),
                 init_t: i / @n_orbs * 2 * Math::PI,
                 init_frame: 5.randomize(:int),
                 z: 0)
    end.shuffle!

    @orb_exps = [] # sprites: x, y, w, h, path, init_tick, live, z
  end

  def new_combo(size)
    (1..size).map { 4.randomize(:int) }
  end

  def unlock(combo, key)
    combo.shift if combo[0] == key
  end

  def combo_to_str(combo)
    combo.map { |i| ['→', '↑', '←', '↓'][i] }[0..5]
         .join(' ')
  end

  def tick
    key_down = inputs::keyboard::key_down
    key_presses = [
      :right, :up, :left, :down,
      :d, :w, :a, :s
    ].map { |k| key_down.send k }
    key = key_presses.index(&:itself)
    key %= 4 if key

    linear_ease = 0
    smooth_ease = 0
    shake_value = 0
    floating_shift = 5 * Math.sin(args.tick_count / 8)

    case @state
    when :start
      @reset_solid.a = 255 * 0.ease(0.5.seconds, [:identity, :flip])

      if key_down.j
        @mode = :jujule
        @state = :reset
      end

      if 0.elapsed?(0.5.seconds) && unlock(@lock.combo, key)
        gtk.stop_music()
        outputs.sounds << ogg('slaythelich')

        @state = :game
      end

    when :game
      @game_at ||= args.tick_count

      @lock.text = combo_to_str(@lock.combo) if unlock(@lock.combo, key)
      if @lock.combo.empty?
        if @mode == :jujule
          @lock.oldcombo << 4.randomize(:int)
          @lock.combo = [*@lock.oldcombo]
          @lock.text = combo_to_str(@lock.combo)
        else
          @lock.combo = new_combo(@n_orbs + 2 - @orbs.size)
          @lock.text = combo_to_str(@lock.combo)
        end

        orb = @orbs.pop
        @orb_exps << Sprite.new(x: orb.x,
                                y: orb.y,
                                w: 32 * @scale_x,
                                h: 32 * @scale_y,
                                path: png('orb_exp_0'),
                                init_tick: args.tick_count,
                                live: true,
                                z: orb.z)

        @slash.live = true
        @slash.init_tick = args.tick_count

        outputs.sounds << wav('slash') if !@orbs.empty?
      end

      if @orbs.empty?
        @end_text.text = 'LICH SLAIN'

        @box.a = 0
        @lock.a = 0
        @void.a = 0

        gtk.stop_music()

        @state = :win
      end

      if @time == 0
        @end_text.text = 'THE WORLD IS GONE'

        @box.a = 0
        @lock.a = 0

        gtk.stop_music()

        @state = :lose
      else
        @time -= 1
        @timer.text = "%05.2f" % (@time / 60)
      end

      linear_ease = @game_at.ease(20.seconds, [:identity])
      smooth_ease = @game_at.ease(20.seconds, [:quad, :quad])
      shake_value = 15 * smooth_ease * Math.sin(args.tick_count / 2)

      @void.w = 20 * linear_ease + shake_value
      @void.x = 640 - @void.w / 2

    when :win
      @win_at ||= args.tick_count
      @tmp ||= args.tick_count

      if @win_at.elapsed? 7.5.seconds
        @state = :reset if key
      elsif @win_at.elapsed? 4.5.seconds
        smooth_ease = (@win_at + 4.5.seconds).ease(3.seconds, [:quad, :quad, :quad])

        @timer.y = 48 + 360 * smooth_ease
        @end_text.a = 255 * smooth_ease
        @play_again.a = 255 * smooth_ease
      else
        smooth_ease = @win_at.ease(4.5.seconds, [:quad, :quad, :quad, :flip])
        linear_ease = @win_at.ease(4.5.seconds, [:identity, :flip])
        shake_value = 15 * smooth_ease * Math.sin(args.tick_count / 2)

        @lich.g = 0
        @lich.a = 255 * linear_ease * @win_at.frame_index(2, 2, true)

        if @tmp.elapsed?(0.2.seconds)
          @tmp = args.tick_count
          @orb_exps << Sprite.new(x: 640 - 96 * @scale_x / 2 + (64 * @scale_x).randomize(:int),
                                  y: 168 + (64 * @scale_y).randomize(:int),
                                  w: 32 * @scale_x,
                                  h: 32 * @scale_y,
                                  path: png('orb_exp_0'),
                                  init_tick: args.tick_count,
                                  live: true,
                                  z: 1)
        end
      end

      outputs.sounds << wav('win') if @win_at + 4.5.seconds == args.tick_count
      outputs.sounds << wav('lichdeath') if @win_at + 5 == args.tick_count

    when :lose
      @lose_at ||= args.tick_count

      @void.r = 10 + floating_shift

      if @lose_at.elapsed? 2.seconds
        @state = :reset if key
      elsif @lose_at.elapsed? 1.seconds
        ease = (@lose_at + 1.seconds).ease(1.seconds, [:quad, :quad, :quad])
        ease_2 = (@lose_at + 1.seconds).ease(1.seconds, [:quad, :quad, :quad, :flip])
        @end_text.a = 255 * ease
        @play_again.a = 255 * ease
        @timer.a = 255 * ease_2
      else
        linear_ease = 1
        shake_value = 15 * Math.sin(args.tick_count / 2)

        @void.w = 20 + 1260 * @lose_at.ease(1.seconds, [:identity])
        @void.x = 640 - @void.w / 2
      end

      outputs.sounds << wav('lose') if @lose_at + 5 == args.tick_count

    when :reset
      @reset_at ||= args.tick_count
      @reset_solid.a = 255 * @reset_at.ease(0.5.seconds, [:identity])
      @state = :setup if @reset_at.elapsed?(0.5.seconds)

    else
      defaults()
      outputs.sounds << ogg('waiting')

      @state = :start
    end

    @timer_bar.h = 720 * (1 - @time / 20.seconds)
    @timer_bar.r = 21 + 50 * linear_ease
    @timer_bar.b = 29 + 50 * linear_ease

    @background.x = 220 + shake_value
    @background.path = png("bg_#{0.frame_index(4, 0.5.seconds, true)}")

    @lich.y = 168 + floating_shift
    @lich.path = png("lich_#{0.frame_index(2, 0.2.seconds, true)}")

    @orbs.each do |orb|
      x = Math.cos(orb.init_t + args.tick_count / 32)
      y = Math.sin(orb.init_t + args.tick_count / 32)
      shift_x = 200 * x
      shift_y = 50 * y * y * y + floating_shift

      frame = (0.frame_index(5, 0.2.seconds, true) + orb.init_frame) % 5
      orb.x = (640 - 32 * @scale_x / 2) + shift_x
      orb.y = 250 + shift_y
      orb.path = png("orb_#{frame}")
      orb.z = 0 <=> y
    end

    flag = false
    @orb_exps.each do |exp|
      if frame = exp.init_tick.frame_index(5, 0.1.seconds, false)
        exp.path = png("orb_exp_#{frame}")
      else
        exp.live = false
        flag = true
      end
    end
    @orb_exps.select!(&:live) if flag

    if @slash.live
      frame = @slash.init_tick.frame_index(4, 0.05.seconds, false)
      if frame
        @slash.x = 640 - 128 * @scale_x / 2 + shake_value
        @slash.path = png("slash_#{frame}")
        @slash.a = 255

        @lich.g = 0
        @lich.a = 255 * @slash.init_tick.frame_index(2, 2, true)
      else
        @slash.live = false
        @slash.a = 0

        @lich.g = 255
        @lich.a = 255
      end
    end

    outputs.background_color = @bg_color
    outputs.primitives << @void
    outputs.primitives << [
      @lich, *@orbs, *@orb_exps
    ].sort { |a, b| a.z <=> b.z }
  end
end

$game = SlayTheLich.new
def tick(args)
  $game.args = args
  $game.tick
end
$gtk.reset