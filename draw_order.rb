module GTK
  module OutputsExtension
    class Layers
      attr_reader :int_keys, :sym_keys

      def initialize
        @layers = {}
        @int_keys = []
        @sym_keys = []
      end

      def [](arg)
        val = @layers[arg]
        return val if val
        if arg.is_a? Integer
          @int_keys << arg
          @int_keys.sort!
          return @layers[arg] = FlatArray.new(arg, :mark_assert!, $gtk.args.outputs.outputs_with_ids)
        else
          @sym_keys << arg.to_sym
          return @layers[arg.to_sym] = FlatArray.new(arg.to_sym, :mark_assert!, $gtk.args.outputs.outputs_with_ids)
        end
      end
      
      def delete arg
        if arg.is_a? Integer
          if @int_keys.include? arg
            @int_keys.delete arg
            @layers.delete arg
          end
        else
          if @sym_keys.include? arg.to_sym
            @sym_keys.delete arg.to_sym
            @layers.delete arg.to_sym
          end
        end
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
      end
    end

    def layers
      return @layers ||= Layers.new
    end

    def static_layers
      return @static_layers ||= Layers.new
    end

    def clear
      super
      layers.clear
      static_layers.clear
    end
  end

  module RuntimeExtension
    def clear_draw_primitives pass
      super
      pass.layers.clear
    end
  end

  class Outputs
    attr :draw_order, :layers, :static_layers
    prepend OutputsExtension
  end

  class Runtime
    prepend RuntimeExtension
  end
end

module GTK
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
              draw_method = method(:"draw_#{name.to_s.delete_suffix('s')}")
              while jdx < jlen
                draw_method.call layer.value jdx
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
  end
end
