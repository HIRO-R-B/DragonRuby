=begin
Slay The Lich
  It's the final battle between the hero and the Lich King
  The hero must kill the Lich King in 20 seconds before he ends the world
  Use the arrow keys (←↑→↓) [or dpad] to break the barriers guarding the lich
  and strike the final blow
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

  # Dont particularly need these classes
  # Just makes primitives a little faster / shorter to define
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

  class Label < Primitive
    def initialize(text: '', s_e: 16, a_e: 1, font: 'fonts/lowrez.ttf', **kw)
      super(primitive_marker: :label,
            text: text, size_enum: s_e, alignment_enum: a_e, font: font, **kw)
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

  # Give paths for files
  def font(name)
    "fonts/#{name}.ttf"
  end

  def png(name)
    "sprites/slaythelich/#{name}.png"
  end

  def wav(name)
    "sounds/#{name}.wav"
  end

  def ogg(name)
    "sounds/#{name}.ogg"
  end

  def new_combo(size) # Create array of ints, repesents → ↑ ← ↓ etc.
    (1..size).map { 4.randomize(:int) }
  end

  def unlock(combo, key) # Pop first int if it matches
    combo.shift if combo[0] == key
  end

  def combo_to_str(combo) # Array ints to combo text
    combo.map { |i| %w[→ ↑ ← ↓][i] }[0..5].join(' ')
  end

  def initialize # Default mode
    @mode = :normal
    #       :jujule
  end

  def defaults
    outputs.clear

    @scale_x = 105 / 32 # Scales to an SNES kind of resolution
    @scale_y = 45 / 14

    @bg_color = [0, 0, 0] # Black

    @start_at = nil # Starting ticks of game sections
    @game_at  = nil
    @win_at   = nil
    @lose_at  = nil
    @reset_at = nil

    @time = 20.seconds # Countdown time

    @n_orbs = # number of combos to win
      case @mode
      when :jujule
        14
      else
        10
      end

    #| STATICS << |#============================================#| STATICS << |#
    # Purple bars on side
    @timer_bar = Solid.new(w: 1280, r: 21, g: 9, b: 29)

    # Mountain background
    @background = Sprite.new(x: 640 - 256 * @scale_x / 2,
                             w: 256 * @scale_x,
                             h: 224 * @scale_y,
                             path: png('bg_0'))

    # Slash sprite
    @slash = Sprite.new(x: 640 - 128 * @scale_x / 2,
                        y: 168,
                        w: 128 * @scale_x,
                        h: 128 * @scale_y,
                        path: png('slash_0'),
                        a: 0,
                        live: false,
                        init_tick: 0)

    # Labels
    # Box around arrow text => [→] ↑ ← ↓
    @box = Label.new(x: 640, y: 160, text: '[ ]', font: nil)

    # Arrow text / keeps track of combo
    @lock = new_combo(1).then do |combo|
      Label.new(x: 615, y: 160,
                text: combo_to_str(combo),
                a_e: 0, font: nil,
                combo: combo)
    end

    @timer = Label.new(x: 640, y: 48, text: 'PRESS ARROW')
    @timer.text = 'Jujule Mode: Good Luck' if @mode == :jujule

    @end_text = Label.new(x: 640, y: 550, a: 0)

    @play_again = Label.new(x: 640, y: 48, text: 'PRESS ARROW', a: 0)

    # Fades in/out solid at start/reset of game
    @reset_solid = Solid.new(w: 1280, h: 720)

    outputs.static_solids << @timer_bar
    outputs.static_sprites << [@background, @slash]
    outputs.static_primitives << [
      @box, @lock, @timer, @end_text, @play_again, @reset_solid
    ]
    #| STATICS << |#============================================#| STATICS << |#

    @void = Solid.new(h: 720) # THE ALL CONSUMING VOID

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

    # Explosions
    @orb_exps = [] # sprites: x, y, w, h, path, init_tick, live, z
  end

  def tick # Where the magic happens (gameplay logic)
    key_down = inputs::keyboard::key_down
    key_presses = %i[right up left down d w a s].map { |k| key_down.send k }
    key = key_presses.index(&:itself) # Get first key pressed, if any
    key %= 4 if key # Account for wasd keypresses

    linear_ease = 0 # Eases for sprite movements
    smooth_ease = 0
    shake_value = 0
    floating_shift = 5 * Math.sin(args.tick_count / 8)

    case @state
    when :start
      if 0.elapsed?(0.5.seconds)
        if key_down.j # Secret mode change!
          @mode = :jujule
          @state = :reset
        elsif unlock(@lock.combo, key)
          gtk.stop_music()
          @state = :game
        end
      end
      @reset_solid.a = 255 * 0.ease(0.5.seconds, %i[identity flip])

    when :game
      outputs.sounds << ogg('slaythelich') unless @game_at
      @game_at ||= args.tick_count

      @lock.text = combo_to_str(@lock.combo) if unlock(@lock.combo, key)
      if @lock.combo.empty? # Change out combo
        if @mode == :jujule
          @lock.oldcombo << 4.randomize(:int)
          @lock.combo = [*@lock.oldcombo]
          @lock.text = combo_to_str(@lock.combo)
        else
          @lock.combo = new_combo(@n_orbs + 2 - @orbs.size)
          @lock.text = combo_to_str(@lock.combo)
        end

        @slash.live = true # Activate slash animation
        @slash.init_tick = args.tick_count

        @orbs.pop.tap do |orb| # Kill an orb / Add explosion
          @orb_exps << Sprite.new(x: orb.x,
                                  y: orb.y,
                                  w: 32 * @scale_x,
                                  h: 32 * @scale_y,
                                  path: png('orb_exp_0'),
                                  init_tick: args.tick_count,
                                  live: true,
                                  z: orb.z)
        end

        outputs.sounds << wav('slash') unless @orbs.empty?
      end

      if @orbs.empty? # You won
        @end_text.text = 'LICH SLAIN'
        @box.a = 0 # Combos disappear
        @lock.a = 0
        @void.a = 0 # Void disappears

        gtk.stop_music()

        @state = :win
      end

      if @time == 0 # You lose
        @end_text.text = 'THE WORLD IS GONE'
        @box.a = 0 # Combos disappear
        @lock.a = 0

        gtk.stop_music()

        @state = :lose
      else
        @time -= 1
        @timer.text = "%05.2f" % (@time / 60)
      end

      linear_ease = @game_at.ease(20.seconds, :identity)
      smooth_ease = @game_at.ease(20.seconds, %i[quad quad])
      shake_value = 15 * smooth_ease * Math.sin(args.tick_count / 2)

      @void.w = 20 * linear_ease + shake_value # Shake / Expand
      @void.x = 640 - @void.w / 2 # Center

    when :win
      outputs.sounds << wav('lichdeath') unless @win_at
      @win_at ||= args.tick_count

      outputs.sounds << wav('win') if @win_at + 4.5.seconds == args.tick_count

      if @win_at.elapsed?(7.5.seconds)
        @state = :reset if key
      elsif @win_at.elapsed?(4.5.seconds)
        smooth_ease = (@win_at + 4.5.seconds).ease(3.seconds, %i[quad quad quad])

        @timer.y = 48 + 360 * smooth_ease # Move timer up
        @end_text.a = 255 * smooth_ease # Make visible
        @play_again.a = 255 * smooth_ease
      else
        smooth_ease = @win_at.ease(4.5.seconds, %i[quad quad quad flip])
        linear_ease = @win_at.ease(4.5.seconds, %i[identity flip])
        shake_value = 15 * smooth_ease * Math.sin(args.tick_count / 2)

        @lich.g = 0 # Lich flickers in reddish hue
        @lich.a = 255 * linear_ease * @win_at.frame_index(2, 2, true)

        # Spam explosions
        if (args.tick_count - @win_at) % 0.2.seconds == 0
          @orb_exps << Sprite.new(x: 640 - 96 * @scale_x / 2
                                     + (64 * @scale_x).randomize(:int),
                                  y: 168 + (64 * @scale_y).randomize(:int),
                                  w: 32 * @scale_x,
                                  h: 32 * @scale_y,
                                  path: png('orb_exp_0'),
                                  init_tick: args.tick_count,
                                  live: true,
                                  z: 1)
        end
      end

    when :lose
      outputs.sounds << wav('lose') unless @lose_at
      @lose_at ||= args.tick_count

      @void.r = 10 + floating_shift # Void pulses with lich

      if @lose_at.elapsed?(2.seconds)
        @state = :reset if key
      elsif @lose_at.elapsed?(1.seconds)
        ease = (@lose_at + 1.seconds).ease(1.seconds, %i[quad quad quad])
        @end_text.a = 255 * ease # Make text visible
        @play_again.a = 255 * ease
        @timer.a = 255 * (1 - ease) # Invisible here
      else # Cover screen with void
        @void.w = 20 + 1260 * @lose_at.ease(1.seconds, :identity)
        @void.x = 640 - @void.w / 2
      end

    when :reset # Fade out
      @reset_at ||= args.tick_count
      @reset_solid.a = 255 * @reset_at.ease(0.5.seconds, :identity)
      @state = :setup if @reset_at.elapsed?(0.5.seconds)

    else # Reset all variables
      outputs.sounds << ogg('waiting')
      defaults()
      @state = :start
    end

    # Bar grows upward / more saturated during countdown
    @timer_bar.h = 720 * (1 - @time / 20.seconds)
    @timer_bar.r = 21 + 50 * linear_ease
    @timer_bar.b = 29 + 50 * linear_ease

    # Shake / Animate
    @background.x = 220 + shake_value
    @background.path = png("bg_#{0.frame_index(4, 0.5.seconds, true)}")

    # Floating touches / Animate
    @lich.y = 168 + floating_shift
    @lich.path = png("lich_#{0.frame_index(2, 0.2.seconds, true)}")

    @orbs.each do |orb| # Make orbs circle lich
      t = orb.init_t + args.tick_count / 32
      x = Math.cos(t)
      y = Math.sin(t)
      shift_x = 200 * x
      shift_y = 50 * y * y * y + floating_shift

      frame = (orb.init_frame + 0.frame_index(5, 0.2.seconds, true)) % 5
      orb.x = 640 - 32 * @scale_x / 2 + shift_x
      orb.y = 250 + shift_y
      orb.path = png("orb_#{frame}")
      orb.z = 0 <=> y
    end

    flag = false
    @orb_exps.each do |exp| # Animate / kill off explosions
      if (frame = exp.init_tick.frame_index(5, 0.1.seconds, false))
        exp.path = png("orb_exp_#{frame}")
      else
        exp.live = false
        flag = true
      end
    end
    @orb_exps.select!(&:live) if flag # Remove the dead

    if @slash.live # Animate slash
      if (frame = @slash.init_tick.frame_index(4, 0.05.seconds, false))
        @slash.x = 640 - 128 * @scale_x / 2 + shake_value
        @slash.path = png("slash_#{frame}")
        @slash.a = 255

        @lich.g = 0 # Flicker lich in red
        @lich.a = 255 * @slash.init_tick.frame_index(2, 2, true)
      else
        @slash.live = false
        @slash.a = 0

        @lich.g = 255
        @lich.a = 255
      end
    end

    outputs.background_color = @bg_color # Black bg
    outputs.primitives << [@void] + [
      @lich, *@orbs, *@orb_exps # Sorted sprites
    ].sort { |a, b| a.z <=> b.z }
  end
end

$game = SlayTheLich.new
def tick(args)
  $game.args = args
  $game.tick
end
$gtk.reset