module GTK
  module DrawOrderOutputs
    attr_reader :layers, :static_layers

    class Layers
      attr_reader :int_keys, :sym_keys

      def self.valid_layers
        @valid_layers ||= [:solids, :sprites, :primitives,
                           :labels, :lines, :borders,
                           :static_solids, :static_sprites, :static_primitives,
                           :static_labels, :static_lines, :static_borders,
                           :layers, :static_layers]
      end

      def initialize(caller_name)
        @layers = {}
        @int_keys = []
        @sym_keys = []
        @draw_order = nil
        @caller = caller_name
      end

      def __active_count__
        return __active_int_count__ + __active_sym_count__
      end

      def __active_int_count__
        return __int_count__ unless @draw_order
        return __count__ @draw_order & @int_keys, @layers
      end

      def __active_sym_count__
        return __sym_count__ unless @draw_order
        return __count__ @draw_order & @sym_keys, @layers
      end

      def __total_count__
        return __int_count__ + __sym_count__
      end

      def __int_count__
        return __count__ @int_keys, @layers
      end

      def __sym_count__
        return __count__ @sym_keys, @layers
      end

      def __count__ keys, layers
        sum  = 0
        idx  = 0
        ilen = keys.length
        while idx < ilen
          sum += layers[keys.value idx].length
          idx += 1
        end
        return sum
      end

      def [](arg)
        val = @layers[arg]
        return val if val
        if arg.is_a? Integer
          @int_keys << arg
          @int_keys.sort!
          return @layers[arg] = FlatArray.new(arg, :mark_assert!, $gtk.args.outputs.outputs_with_ids)
        elsif arg.is_a? Symbol
          @sym_keys << arg.to_sym
          return @layers[arg.to_sym] = FlatArray.new(arg.to_sym, :mark_assert!, $gtk.args.outputs.outputs_with_ids)
        else
          raise '[]: Accepts only Integers or Symbols'
        end
      rescue Exception => e
        raise <<-S
* ERROR
#{@caller}#{e}
arg: #{arg.is_a?(String) ? "'#{arg}'" : arg }
S
      end

      def draw_order
        return @draw_order
      end

      def draw_order= arg
        return @draw_order = nil unless arg
        raise 'Argument is not an Array or nil' unless arg.is_a? Array
        raise 'Array may only contain Integers or Symbols' unless arg.all? { |obj| obj.is_a?(Integer) || obj.is_a?(Symbol) }
        return @draw_order = arg
      rescue Exception => e
        raise <<-S
* ERROR
#{@caller}.draw_order=: #{e}
arg: #{arg}
S
      end

      def delete arg
        if arg.is_a? Integer
          @int_keys.delete arg
          @layers.delete arg
        elsif arg.is_a? Symbol
          @sym_keys.delete arg
          @layers.delete arg
        else
          raise 'Argument is not an Integer or Symbol'
        end
      rescue Exception => e
        raise <<-S
* ERROR
#{@caller}.delete: #{e}
arg: #{arg.is_a?(String) ? "'#{arg}'" : arg }
S
      end

      def clear
        idx = 0
        ilen = @int_keys.length
        while idx < ilen
          @layers[@int_keys.value idx].clear
          idx += 1
        end

        idx = 0
        ilen = @sym_keys.length
        while idx < ilen
          @layers[@sym_keys.value idx].clear
          idx += 1
        end
        return
      end
    end

    def draw_order
      @draw_order
    end

    def draw_order= arg
      return @draw_order = nil unless arg
      raise 'Argument is not an array or nil' unless arg.is_a? Array
      raise 'Array may only contain symbols' unless arg.all? Symbol
      arr = (arg - Layers.valid_layers)
              .reject { |k| k.start_with?('layers_') ||
                            k.start_with?('static_layers_') }
      raise "Argument contains invalid layers #{arr}" if arr.length > 0
      return @draw_order = arg
    rescue Exception => e
      raise <<-S
* ERROR
draw_order=: #{e}
arg: #{arg}
S
    end

    def layers
      return @layers ||= Layers.new(__method__)
    end

    def static_layers
      return @static_layers ||= Layers.new(__method__)
    end

    def clear
      super
      layers.clear
      static_layers.clear
    end
  end

  module DrawOrderRuntime
    def clear_draw_primitives pass
      super
      pass.layers.clear
    end
  end

  Outputs.prepend DrawOrderOutputs
  Runtime.prepend DrawOrderRuntime

  class Runtime
    module Draw
      def primitives pass
        if $top_level.respond_to? :primitives_override
          return $top_level.tick_render @args, pass
        end

        lay        = pass.layers
        static_lay = pass.static_layers

        ord = pass.draw_order
        if ord
          idx  = 0
          ilen = ord.length
          while idx < ilen
            name = ord.value idx
            if name.start_with?('layers_')
              key   = name.to_s.byteslice(7..-1)
              layer = lay[key.to_i.to_s == key ? key.to_i : key.to_sym]
              jdx   = 0
              jlen  = layer.length
              while jdx < jlen
                draw_primitive layer.value jdx
                jdx += 1
              end
            elsif name.start_with?('static_layers_')
              key   = name.to_s.byteslice(14..-1)
              layer = static_lay[key.to_i.to_s == key ? key.to_i : key.to_sym]
              jdx   = 0
              jlen  = layer.length
              while jdx < jlen
                draw_primitive layer.value jdx
                jdx += 1
              end
            elsif name.to_s == 'layers'
              render_layers lay
            elsif name.to_s == 'static_layers'
              render_layers static_lay
            else
              layer = pass.send name
              jdx   = 0
              jlen  = layer.length
              sym = :"draw_#{name.to_s.delete_suffix('s')}"
              while jdx < jlen
                send(sym, layer.value(jdx))
                jdx += 1
              end
            end
            idx += 1
          end
        else # else
          # Don't change this draw order unless you understand
          # the implications.

          # pass.solids.each            { |s| draw_solid s }
          # while loops are faster than each with block
          idx = 0
          while idx < pass.solids.length
            draw_solid (pass.solids.value idx) # accessing an array using .value instead of [] is faster
            idx += 1
          end

          # pass.static_solids.each     { |s| draw_solid s }
          idx = 0
          while idx < pass.static_solids.length
            draw_solid (pass.static_solids.value idx)
            idx += 1
          end

          # pass.sprites.each           { |s| draw_sprite s }
          idx = 0
          while idx < pass.sprites.length
            draw_sprite (pass.sprites.value idx)
            idx += 1
          end

          # pass.static_sprites.each    { |s| draw_sprite s }
          idx = 0
          while idx < pass.static_sprites.length
            draw_sprite (pass.static_sprites.value idx)
            idx += 1
          end

          # pass.primitives.each        { |p| draw_primitive p }
          idx = 0
          while idx < pass.primitives.length
            draw_primitive (pass.primitives.value idx)
            idx += 1
          end

          render_layers lay

          # pass.static_primitives.each { |p| draw_primitive p }
          idx = 0
          while idx < pass.static_primitives.length
            draw_primitive (pass.static_primitives.value idx)
            idx += 1
          end

          render_layers static_lay

          # pass.labels.each            { |l| draw_label l }
          idx = 0
          while idx < pass.labels.length
            draw_label (pass.labels.value idx)
            idx += 1
          end

          # pass.static_labels.each     { |l| draw_label l }
          idx = 0
          while idx < pass.static_labels.length
            draw_label (pass.static_labels.value idx)
            idx += 1
          end

          # pass.lines.each             { |l| draw_line l }
          idx = 0
          while idx < pass.lines.length
            draw_line (pass.lines.value idx)
            idx += 1
          end

          # pass.static_lines.each      { |l| draw_line l }
          idx = 0
          while idx < pass.static_lines.length
            draw_line (pass.static_lines.value idx)
            idx += 1
          end

          # pass.borders.each           { |b| draw_border b }
          idx = 0
          while idx < pass.borders.length
            draw_border (pass.borders.value idx)
            idx += 1
          end

          # pass.static_borders.each    { |b| draw_border b }
          idx = 0
          while idx < pass.static_borders.length
            draw_border (pass.static_borders.value idx)
            idx += 1
          end
        end # endif

        if !$gtk.production
          # pass.debug.each        { |r| draw_primitive r }
          idx = 0
          while idx < pass.debug.length
            draw_primitive (pass.debug.value idx)
            idx += 1
          end

          # pass.static_debug.each { |r| draw_primitive r }
          idx = 0
          while idx < pass.static_debug.length
            draw_primitive (pass.static_debug.value idx)
            idx += 1
          end
        end

        # pass.reserved.each          { |r| draw_primitive r }
        idx = 0
        while idx < pass.reserved.length
          draw_primitive (pass.reserved.value idx)
          idx += 1
        end

        # pass.static_reserved.each   { |r| draw_primitive r }
        idx = 0
        while idx < pass.static_reserved.length
          draw_primitive (pass.static_reserved.value idx)
          idx += 1
        end
      rescue Exception => e
        pause!
        pretty_print_exception_and_export! e
      end

      def render_layers layers
        draw_order = layers.draw_order
        if draw_order
          # layers.draw_order.each { |k| layers[k].each { |p| draw_primitive p } }
          idx  = 0
          ilen = draw_order.length
          while idx < ilen
            key   = draw_order.value idx
            layer = layers[key]
            jdx   = 0
            jlen  = layer.length
            while jdx < jlen
              draw_primitive layer.value jdx
              jdx += 1
            end
            idx += 1
          end
        else
          ikeys = layers.int_keys
          skeys = layers.sym_keys

          # layers.int_keys.each { |k| layers[k].each { |p| draw_primitive p } }
          idx  = 0
          ilen = ikeys.length
          while idx < ilen
            key   = ikeys.value idx
            layer = layers[key]
            jdx   = 0
            jlen  = layer.length
            while jdx < jlen
              draw_primitive layer.value jdx
              jdx += 1
            end
            idx += 1
          end

          # layers.sym_keys.each { |k| layers[k].each { |p| draw_primitive p } }
          idx  = 0
          ilen = skeys.length
          while idx < ilen
            key   = skeys.value idx
            layer = layers[key]
            jdx   = 0
            jlen  = layer.length
            while jdx < jlen
              draw_primitive layer.value jdx
              jdx += 1
            end
            idx += 1
          end
        end
      end

      def draw_static_solid s
        draw_primitive s
      end

      def draw_static_sprite s
        draw_primitive s
      end

      def draw_static_primitive s
        draw_primitive s
      end

      def draw_static_label s
        draw_primitive s
      end

      def draw_static_line s
        draw_primitive s
      end

      def draw_static_border s
        draw_primitive s
      end
    end

    module FramerateDiagnostics
      def framerate_get_diagnostics
        <<-S
* INFO: Framerate Diagnostics
You can display these diagnostics using:

#+begin_src
  def tick args
    # ....

    # IMPORTANT: Put this at the END of the ~tick~ method.
    args.outputs.debug << args.gtk.framerate_diagnostics_primitives
  end
#+end_src

** Draw Calls: ~<<~ Invocation Perf Counter
Here is how many times ~args.outputs.PRIMITIVE_ARRAY <<~ was called:

  #{$perf_counter_outputs_push_count} times invoked.

If the number above is high, consider batching primitives so you can lower the invocation of ~<<~. For example.

Instead of:

#+begin_src
  args.state.enemies.map do |e|
    e.alpha = 128
    args.outputs.sprites << e # <-- ~args.outputs.sprites <<~ is invoked a lot
  end
#+end_src

Do this:

#+begin_src
  args.outputs.sprites << args.state
                              .enemies
                              .map do |e| # <-- ~args.outputs.sprites <<~ is only invoked once.
    e.alpha = 128
    e
  end
#+end_src

** Array Primitives
~Primitives~ represented as an ~Array~ (~Tuple~) are great for prototyping, but are not as performant as using a ~Hash~.

Here is the number of ~Array~ primitives that were encountered:

  #{$perf_counter_primitive_is_array} Array Primitives.

If the number above is high, consider converting them to hashes. For example.

Instead of:

#+begin_src
  args.outputs.sprites << [0, 0, 100, 100, 'sprites/enemy.png']
#+begin_end

Do this:

#+begin_src
  args.outputs.sprites << { x: 0,
                            y: 0,
                            w: 100,
                            h: 100,
                            path: 'sprites/enemy.png' }
#+begin_end

** Primitive Counts
Here are the draw counts ordered by lowest to highest z order:

#{layers_info}
** Additional Help
Come to the DragonRuby Discord channel if you need help troubleshooting performance issues. http://discord.dragonruby.org.

Source code for these diagnostics can be found at: [[https://github.com/dragonruby/dragonruby-game-toolkit-contrib/]]
S
      end

      def layers_info
        o = @args.outputs
        draw_order = o.draw_order

        lay   = o.layers
        lay_order = lay.draw_order
        ikeys = lay.int_keys
        skeys = lay.sym_keys

        stat_lay   = o.static_layers
        stat_lay_order = stat_lay.draw_order
        stat_ikeys = stat_lay.int_keys
        stat_skeys = stat_lay.sym_keys

        check = lambda do |k|
          if k == :layers
            lay.__active_count__
          elsif k == :static_layers
            stat_lay.__active_count__
          elsif k.start_with?('layers_')
            key = k.to_s.byteslice(7..-1)
            layer = lay[key.to_i.to_s == key ? key.to_i : key.to_sym]
            layer.length
          elsif k.start_with?('static_layers_')
            key = k.to_s.byteslice(14..-1)
            layer = lay[key.to_i.to_s == key ? key.to_i : key.to_sym]
            layer.length
          else
            o.send(k).length
          end
        end

        dr_s = if draw_order
                   l = draw_order.max_by { |k| k.length }.length
                   <<-S
DRAW ORDER ACTIVE
#{"PRIMITIVE".ljust(l)}  COUNT
#{draw_order.map { |k| "#{"#{k}:".ljust(l + 2)}#{check.call(k)}" }.join("\n")}
#{'debug:'.ljust(l + 2)}#{o.debug.length}, #{o.static_debug.length}
#{'reserved:'.ljust(l + 2)}#{o.reserved.length}, #{o.static_reserved.length}

S
               end

        sect_1 = <<-S
#{dr_s}PRIMITIVE   COUNT, STATIC COUNT
solids:     #{o.solids.length}, #{o.static_solids.length}
sprites:    #{o.sprites.length}, #{o.static_sprites.length}
primitives: #{o.primitives.length}, #{o.static_primitives.length}
layers:     #{lay.__active_count__}, #{stat_lay.__active_count__}
labels:     #{o.labels.length}, #{o.static_labels.length}
lines:      #{o.lines.length}, #{o.static_lines.length}
borders:    #{o.borders.length}, #{o.static_borders.length}
debug:      #{o.debug.length}, #{o.static_debug.length}
reserved:   #{o.reserved.length}, #{o.static_reserved.length}

S

        l_idx_s = if ikeys.length > 0
                    <<-S
layers idx: #{lay.__active_int_count__}, #{lay.__int_count__}
#{ikeys.map { |i| "  #{i}: #{lay_order && !lay_order.include?(i) ? "INACTIVE " : nil}#{lay[i].length}" }.join("\n")}
S
                  end
        l_sym_s = if skeys.length > 0
                    <<-S
layers sym: #{lay.__active_sym_count__}, #{lay.__sym_count__}
#{skeys.map { |s| "  #{s}: #{lay_order && !lay_order.include?(s) ? "INACTIVE " : nil}#{lay[s].length}" }.join("\n")}
S
                  end
        sl_idx_s = if stat_ikeys.length > 0
                     <<-S
layers idx: #{stat_lay.__active_int_count__}, #{stat_lay.__int_count__}
#{stat_ikeys.map { |i| "  #{i}: #{stat_lay_order && !stat_lay_order.include?(i) ? "INACTIVE " : nil}#{stat_lay[i].length}" }.join("\n")}
S
                   end
        sl_sym_s = if stat_skeys.length > 0
                     <<-S
layers sym: #{stat_lay.__active_sym_count__}, #{stat_lay.__sym_count__}
#{stat_skeys.map { |s| "  #{s}: #{stat_lay_order && !stat_lay_order.include?(s) ? "INACTIVE " : nil}#{stat_lay[s].length}" }.join("\n")}
S
                   end
        title_2 = 'PRIMITIVE   [ACTIVE?,] COUNT' if l_idx_s || l_sym_s || sl_idx_s || sl_sym_s
        return <<-S.chomp
#{sect_1}#{title_2}#{lay_order ? "\nlayers DRAW ORDER ACTIVE" : nil}
#{l_idx_s}#{l_sym_s}#{stat_lay_order ? "\nstatic_layers DRAW ORDER ACTIVE" : nil}#{sl_idx_s}#{sl_sym_s}
S
      end
    end

  end
end
