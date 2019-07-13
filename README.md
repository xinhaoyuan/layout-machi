# ![](icon.png) layout-machi


A manual layout for Awesome with a rapid interactive editor.

Demos: https://imgur.com/a/OlM60iw

## Why?

TL;DR --- I want the control of my layout.

1. Dynamic tiling is an overkill, since tiling is only useful for persistent windows, and people extensively use hibernate/sleep these days.
2. I don't want to have all windows moving around whenever a new window shows up.
3. I want to have a flexible layout such that I can quickly adjust to whatever I need.

## Quick usage

Suppose this git is checked out at `~/.config/awesome/layout-machi`

`machi = require("layout-machi")`

The package provide a default layout `machi.default_layout` and editor `machi.default_editor`, which can be added into the layout list.

## Use the layout

Use `layout = machi.layout.create(name, editor)` to instantiate the layout with an editor object.
`machi.default_editor` can be used, or see below on creating editors.
You can also create multiple layouts with different names and share the same editor.
The editor will restore the last setups of the layouts based on their names.
The layout will be dependent on different tags.

## Editor

Call `editor = machi.editor.create()` to create an editor.
To edit the layout `l` on screen `s`, call `editor.start_interactive(s = awful.screen.focused(), l = awful.layout.get(s))`.

### The layout editing command

The editing starts with the open area of the entire workarea, takes commands to split the current area into multiple sub-areas, then recursively edits each of them.
The editor is keyboard driven, each command is a key with optional digits (namely `D`) before it as parameter (or multiple parameters depending on the command).

1. `Up`/`Down`: restore to the history command sequence
2. `h`/`v`: split the current region horizontally/vertically into `#D` regions. The split will respect the ratio of digits in `D`.
3. `w`: Take the last two digits from `D` as `D = ...AB` (1 if `D` is shorter than 2 digits), and split the current region equally into A rows and B columns. If no digits are provided at all, behave the same as `Space`.
4. `s`: shift the current editing region with other open regions. If digits are provided, shift for that many times.
5. `Space` or `-`: Without parameters, close the current region and move to the next open region. With digits, set the maximum depth of splitting (the default depth is 2).
6. `Enter`/`.`: close all open regions. When all regions are closed, press `Enter` will save the layout and exit the editor.
7. `Backspace`: undo the last command.
8. `Escape`: exit the editor without saving the layout.

For examples:

`h-v`

```
11 22
11 22
11
11 33
11 33
```


`hvv` (or `22w`)

```
11 33
11 33

22 44
22 44
```


`131h2v-12v`

Details:

 - `131h`: horizontally split the initial region (entire desktop) to the ratio of 1:3:1
 - For the first `1` part:
   - `2v`: vertically split the region to the ratio of 2:1
 - `-`: skip the editing of the middle `3` part
 - For the right `1` part:
   - `12v`: split the right part vertically to the ratio of 1:2

Tada!

```
11 3333 44
11 3333 44
11 3333
11 3333 55
   3333 55
22 3333 55
22 3333 55
```


### Persistent history

By default, the last 100 command sequences are stored in `.cache/awesome/history_machi`.
To change that, please refer to `editor.lua`. (XXX more documents)

## Switcher

Calling `machi.switcher.start()` will create a switcher supporting the following keys:

 - Arrow keys: move focus into other regions by the direction.
 - `Shift` + arrow keys: move the focused window to other regions by the direction.
 - `Tab`: switch windows in the same regions.

So far, the key binding is not configurable. One has to modify the source code to change it.

## Other functions

`machi.editor.fit_region(c, cycle = false)` will fit a floating client into the closest region.
If `cycle` is true, it then moves the window by cycling all regions.

## Caveats

`beautiful.useless_gap` is handled differently in layout-machi and it doesn't cooperate well with the standard way.
In my usage I set `gap = 0` for the tags and let machi handle the gaps.

Also, true transparency is required. Otherwise switcher and editor will block the clients.

## TODO

 - Tabs on regions?

## License

Apache 2.0 --- See LICENSE
