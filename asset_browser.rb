return if $gtk.production

require 'lib/dimensions.rb'

module GTK
  class AssetBrowser
    class Label
      attr :x, :y, :text,
           :size_enum, :alignment_enum,
           :r, :g, :b, :a,
           :font

      def initialize x:, y:, text:, se: 0, ae: 0, r: 255, g: 255, b: 255
        @x = x
        @y = y
        @text = text
        @size_enum = se
        @alignment_enum = ae
        @r = r
        @g = g
        @b = b
      end

      def primitive_marker
        return :label
      end
    end

    class Sprite
      attr_sprite
      attr :bw, :bh

      def initialize
        @x = 0
        @y = 0
        @w = 0
        @h = 0
        @path = ''

        @bx = 640
        @by = 360
        @bw = 0
        @bh = 0

        move
      end

      def set_base_wh w, h
        @bw = w
        @bh = h
      end

      def set_path path
        @path = path
        @bw, @bh = getdimensions path
      end

      def shift point
        @x = @bx + point.x - @w.half
        @y = @by + point.y - @h.half
      end

      def set_shift point
        @bx += point.x
        @by += point.y
        move
      end

      def move point = [@bx, @by]
        @bx, @by = point.x, point.y
        @x = @bx - @w.half
        @y = @by - @h.half
      end

      def resize zoom
        @w = zoom * @bw
        @h = zoom * @bh
      end
    end

    def ls path
      return `cmd /c "dir /b \"#{path}\""`.split("\r\n") if $gtk.platform == 'Windows'
      return `ls \"#{path}\"`.split("\n") if $gtk.platform == 'Linux' or $gtk.platform == 'Mac Os X'
    end

    def rec_ls base_path, path = ''
      return ls("#{base_path}/#{path}").map do |f|
        file = "#{base_path}/#{path}#{f}"
        next rec_ls(base_path, "#{path}#{f}/") if File.directory? file
        "#{path}#{f}" # if f.end_with? '.png'
      end.reject { |v| v.nil? || v.empty?}
    end

    def generate_listing base_path, path, file_types, hash = {}
      listing = ls("#{base_path}/#{path}")
      return nil unless listing
      dirs  = listing.select { |f| File.directory? "#{base_path}/#{path}#{f}" }
      files = listing.select { |f| file_types.any? { |type| f.end_with? type } }
      return nil if dirs.empty? && files.empty?

      hash[path] = {}
      hash[path][:dirs]  = dirs unless dirs.empty?
      hash[path][:files] = files unless files.empty?
      return hash unless hash[path][:dirs]
      hash[path][:dirs].each_with_index do |f, i|
        v = generate_listing base_path, "#{path}#{f}/", file_types, hash
        hash[path][:dirs][i] = nil if v.nil?
      end
      hash[path][:dirs].reject! { |v| v.nil? }

      return hash
    end

    def flat_list base_path, hash
      return nil unless hash
      list = __flat_list base_path, hash
      return list.flatten
    end

    def __flat_list base_path, hash, array = [], path = ''
      array << hash[base_path][:files].map { |f| "#{path}#{f}" } if hash[base_path][:files]
      hash[base_path][:dirs].each do |dir|
        __flat_list "#{base_path}#{dir}/", hash, array, "#{path}#{dir}/"
      end if hash[base_path][:dirs]
      return array
    end

    def wrapped_lines strings, joiner
      lines = []
      s = nil
      strings.each do |str|
        next s = str if s.nil?
        v = [s, str].join(joiner)
        if v.length < 129
          s = v
        else
          lines << s
          s = str
        end
      end
      lines << s if !s.nil?
      return lines
    end

    def pp obj, ind = ''
      case obj
      when Hash
        puts ind + '{'
        obj.map do |h, v|
          pp h, ind + '  '
          pp v, ind + '    '
        end
        puts ind + '}'
      when Array
        puts ind + '['
        obj.map do |v|
          pp v, ind + '  '
        end
        puts ind + ']'
      when NilClass
        puts "#{ind}NIL"
      when String
        puts obj.quote
      else
        puts "#{ind}#{obj}"
      end
    end

    def initialize
      @visible = false

      @asset_modes   = [:sprites, :sounds].cycle
      @asset_mode    = @asset_modes.next

      @view_modes = [:dir, :listing].cycle
      @view_mode  = @view_modes.next

      @dir = $gtk.get_game_dir

      @sprite_files = generate_listing @dir, "sprites/", ['.png']
      @sound_files  = generate_listing @dir, "sounds/",  ['.wav', '.ogg']

      @bwd = 'sprites/'
      @cwd = @bwd

      @files = @sprite_files
      @file_listing = flat_list(@cwd, @files)

      @idx = 0
      @zoom = 1

      @choice_chars = '1234567890qrtyuiopafghjklzxcvbnm'
      @cmd = ''

      @bg_solid   = { x: 0, y: 0, w: 1280, h: 720, r: 0, g: 0, b: 0, a: 224 }.solid
      @title      = Label.new x: 1280, y: 720, text: title_text, ae: 2
      @title_line = { x: 0, y: 698, x2: 1280, y2: 698, r: 255, g: 255, b: 255 }.line
      @cwd_label  = Label.new x: 0, y: 720, text: cwd_text
      @dir_labels = make_dir_labels
      @dir_lines  = make_dir_lines
      @sprite     = Sprite.new

      return unless @files
      set_sprite_path @cwd + @files[@cwd][:files][0] if @files[@cwd][:files]
      @sprite.resize @zoom
      @sprite.move

      @cur_file = "#{@cwd}#{@files[@cwd][:files][@idx]}" if @files[@cwd][:files]
    end

    def title_text
      return "#{@cmd.length > 0 ? '| CMD: ' + @cmd : '' } | #{@zoom} ZOOM | #{@view_mode.upcase} VIEW | #{@asset_mode.upcase} MODE | ASSET BROWSER "
    end

    def cwd_text
      return 'DIR: NO DIRECTORY' unless @files
      return "DIR: #{@cwd}"
    end

    def make_dir_labels
      return [] unless @files&.dig @cwd, :dirs
      lines = wrapped_lines @files[@cwd][:dirs].map.with_index { |dir, i| "[#{@choice_chars[i]}] #{dir}" }, ' | '
      return lines.map.with_index { |line, i| Label.new x: 0, y: 698 - 22*i, text: line }
    end

    def make_dir_lines
      return @dir_labels.length.times.map { |i| { x: 0, y: 676 - 22*i, x2: 1280, y2: 676 - 22*i, r: 255, g: 255, b: 255 }.line }
    end

    def toggle
      @visible = !@visible
      return
    end

    def toggle_asset_mode
      @asset_mode = @asset_modes.next
      @bwd = "#{@asset_mode}/"
      @cwd = @bwd

      case @asset_mode
      when :sprites
        @files = @sprite_files
      when :sounds
        @files = @sound_files
      end

      refresh
      return
    end

    def toggle_view_mode
      @view_mode = @view_modes.next
      refresh
      return
    end

    def refresh
      @cwd_label.text = cwd_text
      @title.text = title_text
      @idx = 0

      case @view_mode
      when :dir
        @dir_labels = make_dir_labels
        @dir_lines  = make_dir_lines
      else
        @file_listing = flat_list(@cwd, @files)
      end

      return unless @files

      case @asset_mode
      when :sprites
        case @view_mode
        when :dir
          set_sprite_path @files[@cwd][:files] ? "#{@cwd}#{@files[@cwd][:files][0]}" : nil
          @cur_file = "#{@cwd}#{@files[@cwd][:files][@idx]}" if @files[@cwd][:files]
        else
          set_sprite_path "#{@cwd}#{@file_listing[@idx]}"
          @cur_file = "#{@cwd}#{@file_listing[@idx]}"
        end

        @sprite.resize @zoom
        @sprite.move
      when :sounds
      end

      return
    end

    def getdimensions path
      return Dimensions.dimensions "#{@dir}/#{path}"
    end

    def set_sprite_path path
      @sprite.path = path
      return @sprite.set_base_wh(0, 0) unless path
      @sprite.set_base_wh(*getdimensions(path))
    end

    def sprite_mode_inputs inputs
      kb = inputs.keyboard
      kd = kb.key_down

      if @cmd.length > 0
        return (@cmd = ''; refresh) if kd.escape
        @cmd += inputs.text[0] if inputs.text.length > 0
        case @cmd[0]
        when 'f'
          if @cmd[1]
            i = @choice_chars.index(@cmd[1])
            @cwd += @files[@cwd][:dirs][i] + '/' if i && @files[@cwd][:dirs][i]
            @cmd = ''
            refresh
          end
        end
        return
      end

      pdx = @idx
      @idx -= kb.up_down
      @idx -= 1 if kd.e
      @idx += 1 if kd.d

      case @view_mode
      when :dir
        if kd.r && @cwd != @bwd
          @cwd = @cwd.split('/')[0..-2].join('/') + '/'
          refresh
        end

        if kd.f && @cmd.length == 0 && @files[@cwd][:dirs]
          @cmd = 'f'
          refresh
        end

        @idx = @files[@cwd][:files] ? @idx % @files[@cwd][:files].length : 0

        if pdx != @idx
          set_sprite_path "#{@cwd}#{@files[@cwd][:files][@idx]}" if @files[@cwd][:files]
          @sprite.resize @zoom
          @sprite.move

          @cur_file = "#{@cwd}#{@files[@cwd][:files][@idx]}" if @files[@cwd][:files]
        end
      else
        if kd.f
          paths = @file_listing[@idx].split('/')
          if paths.length > 1
            @cwd += paths[0] + '/'
            refresh
          end
        end

        if kd.r && @cwd != @bwd
          @cwd = @cwd.split('/')[0..-2].join('/') + '/'
          refresh
        end

        @idx = @idx % @file_listing.length
        if pdx != @idx
          set_sprite_path "#{@cwd}#{@file_listing[@idx]}"
          @sprite.resize @zoom
          @sprite.move

          @cur_file = "#{@cwd}#{@file_listing[@idx]}"
        end
      end

      m = inputs.mouse
      pzoom = @zoom
      @zoom = (m.wheel.y < 0 ? @zoom / 2 : @zoom * 2).clamp(0.125, 16) if m.wheel

      if m.button_middle
        @zoom = 1
        @sprite.move [640, 360]
      end

      if pzoom != @zoom
        @title.text = title_text
        @sprite.resize @zoom
        @sprite.move
      end

      @sprite.move m.point if m.button_left

      if m.button_right
        @m_grab ||= m.click
        p2 = m.point
        @sprite.shift [p2.x - @m_grab.x, p2.y - @m_grab.y]
      else
        if @m_grab
          p2 = m.point
          @sprite.set_shift [p2.x - @m_grab.x, p2.y - @m_grab.y]
          @m_grab = nil
        end
      end
    end

    def inputs inputs
      return unless $console.hidden?
      toggle if inputs.keyboard.key_down.exclamation_point

      return unless @visible
      kb = inputs.keyboard
      kd = kb.key_down

      # toggle_asset_mode if kd.m # TODO: Add a sound mode
      toggle_view_mode  if kd.n

      return unless @files
      case @asset_mode
      when :sprites
        sprite_mode_inputs inputs
      when :sounds
      end

      $gtk.set_clipboard(@cur_file) if inputs.keyboard.key_down.enter && @cur_file
    end

    def render args
      return unless @visible

      case @asset_mode
      when :sprites
        case @view_mode
        when :dir
          if @files&.dig @cwd, :files
            list = (@idx..@idx+29).map.with_index do |v, i|
              s = @files[@cwd][:files][@idx - 1 + i]
              s = v == 0 ? '' : '[...]' if i == 0
              s = s ? '[...]' : '' if i == 29
              Label.new x: 0, y: 690 - 22*@dir_lines.length - 22*i, text: s
            end
            list[1].g = 0
            list[1].b = 0
          else
            list = []
          end
          list.push(*@dir_labels, *@dir_lines)
        else
          if @file_listing
            list = (@idx..@idx+30).map.with_index do |v, i|
              s = @file_listing[@idx - 1 + i]
              s = v == 0 ? '' : '[...]' if i == 0
              s = s ? '[...]' : '' if i == 30
              Label.new x: 0, y: 690 - 22*i, text: s
            end
            list[1].g = 0
            list[1].b = 0
          else
            list = []
          end
        end

        args.outputs.reserved.unshift(
          @bg_solid,
          @title,
          @title_line,
          @cwd_label,
          *list,
          @sprite
        )
      when :sounds
        list = []
        args.outputs.reserved.unshift(
          @bg_solid,
          @title,
          @title_line,
          @cwd_label,
          *list
        )
      end
    end
  end

  module AssetBrowserExt
    def assetbrowser
      return @assetbrowser ||= AssetBrowser.new
    end

    def set_clipboard text
      IO.popen("echo -n \"#{text}\" | xclip -sel c").close if self.platform == 'Linux'
      `cmd /c \"echo | set /p dummy=#{text}| clip\"` if self.platform == 'Windows'
      `echo -n \"#{text}\" | pbcopy` if self.platform == 'Max Os X'
      return
    end

    def tick count
      assetbrowser.inputs $args.inputs
      super
      assetbrowser.render $args
      return
    end
  end

  class Runtime
    prepend AssetBrowserExt
  end
end
