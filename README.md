# Draw Order
Alters outputs and related classes so that you can change layer ordering and create arbitrary layers

## How to?
Put [`draw_order.rb`](draw_order.rb) somewhere and require it!

[`main.rb`](main.rb) shows example usage.

## Features
### Alterations
Change draw order of layers and choose what layers to draw! Try it out like so:
```
# Only the sprite and solid layers will be displayed now
args.outputs.draw_order = [:sprites, :solids] # Sprites first, Solids after

# Set drawing order back to normal
args.outputs.draw_order = nil
```

### Additions
You can create an arbitrary amount of layers now!
Use: `args.outputs.layers[integer_or_symbol]`
```
# Use them like primitive layers
args.outputs.layers[:waffles] << [0, 0, 100, 100, 'waffle.png'].sprite
args.outputs.layers[0] << [100, 0, 100, 100, 'dragonruby.png'].sprite
```

You even have access to static layers!
```
args.outputs.static_layers[:pancakes] << [0, 0, 1280, 720].solid
```

Notes: layers

Requires version: 1.26
