# Asset Browser
Currently being worked on, expect breaking things  
In order to get png dimensions, I use Dimensions  
Checkout the [source](https://github.com/sstephenson/dimensions) for Dimensions

## How To:
Put both [asset_browser.rb](asset_browswer.rb) and [dimensions.rb](dimensions.rb) in your 'mygame' folder inside a 'lib' folder  
and require like so:
```ruby
require 'lib/asset_browser.rb'
```

## Keybinds:
```
w - Fast Up
s - Fast Down
e - 1 Up
d - 1 Down
r - Return to previous Directory
f - Forward Directory | In 'dir view', press f and then corresponding directory number/letter
n - Change View Mode
enter - Copy file path
  
mouse 1 - Move sprite to cursor
mouse 2 - Move sprite
mouse 3 - Reset Sprite
mouse wheel - Change Zoom
```

