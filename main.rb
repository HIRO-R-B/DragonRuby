require "app/extra_keys.rb"

def row_labels(x, y, strings)
  strings.map_with_index do |str, i|
    [x, y - 20*i, str]
  end
end

def tick(args)
  o = args::outputs
  i = args::inputs
  ik = i::keyboard
  ikh = ik::key_held

  collec = [:k, :l, :up, :down, :left, :right]

  fkeys = (1..12).map { |i| "f#{i}" }
  num_keys_num = (0..9).map { |i| "num_#{i.to_s}" }
  num_keys_oth = [:num_lock, :num_forward_slash, :num_asterisk,
                  :num_hyphen, :num_plus, :num_enter, :num_period]

  o.labels << row_labels(0, 0.from_top, [
                           "Num Lock State: #{ik.num_lock?}",
                           "Caps Lock State: #{ik.caps_lock?}",
                           '',
                           "Down: #{i.keyboard.key_down.truthy_keys}",
                           "Held: #{i.keyboard.key_held.truthy_keys}",
                           "Up: #{i.keyboard.key_up.truthy_keys}",
                           '',
                           "Left Shift Held: #{ikh.lshift}",
                           "Right Alt Held: #{ikh.ralt}",
                           '',
                           "key_held.A = #{ikh.A.to_s.ljust(5, ' ')} key_held.a = #{ikh.a}",
                           "key_held.H = #{ikh.H.to_s.ljust(5, ' ')} key_held.h = #{ikh.h}",
                           '',
                           "Of Keys: #{collec}",
                           "Only k held? #{ik.key_held.only? :k, collec}",
                           '',
                           'Keys: ' + fkeys.map { |k| k.to_s.ljust(6, ' ') }.join,
                           'Held: ' + fkeys.map { |k| ikh.send(k.to_sym).to_s.ljust(6, ' ') }.join,
                           '',
                           'Keys: ' + num_keys_num.map { |k| k.to_s.ljust(6, ' ') }.join,
                           'Held: ' + num_keys_num.map { |k| ikh.send(k.to_sym).to_s.ljust(6, ' ') }.join,
                           '',
                           'Keys: ' + num_keys_oth.map { |k| k.to_s }.join('   '),
                           'Held: ' + num_keys_oth.map { |k| ikh.send(k).to_s.ljust(k.length, ' ') }.join('   '),
                         ])
end
