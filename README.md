# Draw Order
Alters outputs and related classes so that you can change layer ordering and create arbitrary layers

## How to?
Put [`draw_order.rb`](draw_order.rb) somewhere and require it!

[`main.rb`](main.rb) shows example usage.

## Features
### Alterations
Change draw order of layers and choose what layers to draw! Try it out like so:
```ruby
# Only the sprite and solid layers will be displayed now
args.outputs.draw_order = [:sprites, :solids] # Sprites first, Solids after

# Set drawing order back to normal
args.outputs.draw_order = nil
```
### Additions
You can create an arbitrary amount of layers now!
```ruby
args.outputs.layers[integer_or_symbol]
```
#### Notes
Use them like `outputs.primitives`
```ruby
args.outputs.layers[0] << [0, 0, 20, 20].solid
```
Indexed layers are always drawn in order (You can even skip indexes)
```ruby
args.outputs.layers[2] << [0, 0, 100, 100].solid                    # Drawn second
args.outputs.layers[0] << [0, 0, 100, 100, 'dragonruby.png'].sprite # Drawn first
# Just displays a black square
```
Named layers are drawn in the order they're created
```ruby
args.outputs.layers[:pancakes] << [0, 0, 1280, 720].solid               # This layer's drawn first
args.outputs.layers[:waffles]  << [0, 0, 100, 100, 'waffle.png'].sprite # This layer's drawn second
args.outputs.layers[:pancakes] << [0, 640, 640, 720].solid              # This is drawn between the first two
```
However, Indexed layers will be drawn before Named layers
### More Additions
You're not limited to just extra layers! Enjoy static layers too!
```ruby
args.outputs.static_layers[:ahhh] << [0, 0, 1280, 720].solid
args.outputs.layers[:nooo] << [0, 0, 100, 100, 'dragonruby.png].sprite
# Just a black screen, statics are drawn after their normal counterparts
```
## Mix and Match
You can change the draw order of the extra layers too of course!
```ruby
# Use it like so
args.outputs.draw_order = [:layers_apple, :layers_0, :static_layers_banana, ...]
```

Requires version: 1.26
