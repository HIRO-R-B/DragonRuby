module GTK
  class KeyboardKeys
    attr_accessor :lshift, :rshift, :lalt, :ralt, :lmeta, :rmeta, :lctrl, :rctrl,
                  :num_lock, :num_forward_slash, :num_asterisk, :num_hyphen, :num_plus, :num_enter,
                  :num_1, :num_2, :num_3,
                  :num_4, :num_5, :num_6,
                  :num_7, :num_8, :num_9,
                  :num_0, :num_period,
                  :caps_lock,
                  :f1, :f2, :f3, :f4, :f5, :f6, :f7, :f8, :f9, :f10, :f11, :f12

    def self.sdl_to_key raw_key, modifier
      return nil unless (raw_key >= 0 && raw_key <= 255) ||
                        raw_key == 1073741903 || # Arrow Right
                        raw_key == 1073741904 || # Arrow Left
                        raw_key == 1073741905 || # Arrow Down
                        raw_key == 1073741906 || # Arrow Up
                        raw_key == 1073741899 || # Page Up
                        raw_key == 1073741902 || # Page Down
                        (raw_key >= 1073742048 && raw_key <= 1073742055) || # Modifier Keys
                        (raw_key >= 1073741907 && raw_key <= 1073741923) || # Num Keys
                        (raw_key >= 1073741881 && raw_key <= 1073741893)#|| # Caps Lock & Function Keys

      @num_lock_mode = (modifier & (4096)) != 0       # num lock is on?
      @caps_lock_mode = (modifier & (8192)) != 0      # caps lock is on?
      char = KeyboardKeys.char_with_shift raw_key, modifier
      names = KeyboardKeys.char_to_method char, raw_key
      names << :alt if (modifier & (256|512)) != 0    # alt key
      names << :meta if (modifier & (1024|2048)) != 0 # meta key (command/apple/windows key)
      names << :control if (modifier & (64|128)) != 0 # ctrl key
      names << :shift if (modifier & (1|2)) != 0      # shift key
      names
    end

    def self.char_to_method_hash
      @char_to_method ||= {
        'A'  => [:a],
        'B'  => [:b],
        'C'  => [:c],
        'D'  => [:d],
        'E'  => [:e],
        'F'  => [:f],
        'G'  => [:g],
        'H'  => [:h],
        'I'  => [:i],
        'J'  => [:j],
        'K'  => [:k],
        'L'  => [:l],
        'M'  => [:m],
        'N'  => [:n],
        'O'  => [:o],
        'P'  => [:p],
        'Q'  => [:q],
        'R'  => [:r],
        'S'  => [:s],
        'T'  => [:t],
        'U'  => [:u],
        'V'  => [:v],
        'W'  => [:w],
        'X'  => [:x],
        'Y'  => [:y],
        'Z'  => [:z],
        "!"  => [:exclamation_point],
        "0"  => [:zero],
        "1"  => [:one],
        "2"  => [:two],
        "3"  => [:three],
        "4"  => [:four],
        "5"  => [:five],
        "6"  => [:six],
        "7"  => [:seven],
        "8"  => [:eight],
        "9"  => [:nine],
        "\b" => [:backspace],
        "\e" => [:escape],
        "\r" => [:enter],
        "\t" => [:tab],
        "("  => [:open_round_brace],
        ")"  => [:close_round_brace],
        "{"  => [:open_curly_brace],
        "}"  => [:close_curly_brace],
        "["  => [:open_square_brace],
        "]"  => [:close_square_brace],
        ":"  => [:colon],
        ";"  => [:semicolon],
        "="  => [:equal_sign],
        "-"  => [:hyphen],
        " "  => [:space],
        "$"  => [:dollar_sign],
        "\"" => [:double_quotation_mark],
        "'"  => [:single_quotation_mark],
        "`"  => [:backtick],
        "~"  => [:tilde],
        "."  => [:period],
        ","  => [:comma],
        "|"  => [:pipe],
        "_"  => [:underscore],
        "#"  => [:hash],
        "+"  => [:plus],
        "@"  => [:at],
        "/"  => [:forward_slash],
        "\\" => [:back_slash],
        "*"  => [:asterisk],
        "<"  => [:less_than],
        ">"  => [:greater_than],
        "^"  => [:circumflex],
        "&"  => [:ampersand],
        "²"  => [:superscript_two],
        "§"  => [:section_sign],
        "?"  => [:question_mark],
        '%'  => [:percent_sign],
        "º"  => [:ordinal_indicator],
        1073741903 => [:right],
        1073741904 => [:left],
        1073741905 => [:down],
        1073741906 => [:up],
        1073741899 => [:pageup],
        1073741902 => [:pagedown],
        127 => [:delete],
        1073742049 => [:lshift, :shift],
        1073742053 => [:rshift, :shift],
        1073742050 => [:lalt, :alt],
        1073742054 => [:ralt, :alt],
        1073742051 => [:lmeta, :meta],
        1073742055 => [:rmeta, :meta],
        1073742048 => [:lctrl, :control],
        1073742052 => [:rctrl, :control],
        1073741907 => [:num_lock],
        1073741908 => [:num_forward_slash],
        1073741909 => [:num_asterisk],
        1073741910 => [:num_hyphen],
        1073741911 => [:num_plus],
        1073741912 => [:num_enter],
        1073741913 => [:num_1],
        1073741914 => [:num_2],
        1073741915 => [:num_3],
        1073741916 => [:num_4],
        1073741917 => [:num_5],
        1073741918 => [:num_6],
        1073741919 => [:num_7],
        1073741920 => [:num_8],
        1073741921 => [:num_9],
        1073741922 => [:num_0],
        1073741923 => [:num_period],
        1073741881 => [:caps_lock],
        1073741882 => [:f1],
        1073741883 => [:f2],
        1073741884 => [:f3],
        1073741885 => [:f4],
        1073741886 => [:f5],
        1073741887 => [:f6],
        1073741888 => [:f7],
        1073741889 => [:f8],
        1073741890 => [:f9],
        1073741891 => [:f10],
        1073741892 => [:f11],
        1073741893 => [:f12]
      }
    end

    def self.char_to_method char, int = nil
      v = char_to_method_hash[char] || char_to_method_hash[int]
      v ? v.dup : [char.to_sym || int]
    end

    def self.num_lock_mode
      @num_lock_mode ||= false
    end

    def self.caps_lock_mode
      @caps_lock_mode ||= false
    end

    def only? key, keys
      keys.delete key
      values = get(keys.map { |k| k.without_ending_bang })
      any_true = values.any? do |k, v|
        v
      end

      if any_true
        keys.each do |k|
          clear_key k if k.end_with_bang?
        end
        return false
      end

      self.send(key)
    end

    def method_missing m, *args
      begin
        if [:A, :B, :C, :D, :E, :F, :G, :H,
            :I, :J, :K, :L, :M, :N, :O, :P,
            :Q, :R, :S, :T, :U, :V, :W, :X,
            :Y, :Z].include?(m)

          define_singleton_method(m) do
            r1 = self.instance_variable_get("@#{m.downcase.without_ending_bang}".to_sym)
            r2 = self.instance_variable_get("@lshift".to_sym)
            r3 = self.instance_variable_get("@rshift".to_sym)
            clear_key m
            return [r1, r2, r3].select(&:itself).max if r1 && r2 || r3
          end
        else
          define_singleton_method(m) do
            r = self.instance_variable_get("@#{m.without_ending_bang}".to_sym)
            clear_key m
            return r
          end
        end

        return self.send m
      rescue Exception => e
        log_important "#{e}"
      end

      raise <<-S
* ERROR:
There is no member on the keyboard called #{m}. Here is a to_s representation of what's available:

#{KeyboardKeys.char_to_method_hash.map { |k, v| "[#{k} => #{v.join(",")}]" }.join("  ")}

S
    end
  end

  class Keyboard
    def num_lock?
      KeyboardKeys.num_lock_mode
    end

    def caps_lock?
      KeyboardKeys.caps_lock_mode
    end
  end
end
