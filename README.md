# ![](icon.png) layout-machi

A manual layout for Awesome with a rapid interactive editor.

Demos: https://imgur.com/a/OlM60iw

## Why?

TL;DR --- I want the control of my layout.

1. Dynamic tiling is an overkill, since tiling is only useful for persistent windows, and people extensively use hibernate/sleep these days.
2. I don't want to have all windows moving around whenever a new window shows up.
3. I want to have a flexible layout such that I can quickly adjust to whatever I need.

## Compatibilities

I developed it with Awesome 4.3.
Please let me know if it does not work in other versions.

## Quick usage

Suppose this git is checked out at `~/.config/awesome/layout-machi`

`machi = require("layout-machi")`

The package provide a default layout `machi.default_layout` and editor `machi.default_editor`, which can be added into the layout list.

The package comes with the icon for `layoutbox`, which can be set with the following statement (after a theme has been loaded):

`require("beautiful").layout_machi = machi.get_icon()`

## Use the layout

Use `layout = machi.layout.create(name, editor)` to instantiate the layout with an editor object.

`name` can be a string or a function returning a string (see `init.lua` and "Advanced" below).
This is used for having different actual layout dependent on tags.

`editor` are used for editing and persisting the layouts.
`machi.default_editor` can be used, or see below on creating editors.
You can create multiple layouts with different names and share the same editor.

## Editor

Call `editor = machi.editor.create()` to create an editor.
To edit the layout `l` on screen `s`, call `editor.start_interactive(s = awful.screen.focused(), l = awful.layout.get(s))`.

### The layout editing command

The editing starts with the open area of the entire workarea, takes commands to split the current area into multiple sub-areas, then recursively edits each of them.
The editor is keyboard driven, each command is a key with optional digits (namely `D`) before it as parameter (or multiple parameters depending on the command).

1. `Up`/`Down`: restore to the history command sequence
2. `h`/`v`: split the current region horizontally/vertically into `#D` regions. The split will respect the ratio of digits in `D`.
3. `w`: Take the last two digits from `D` as `D = ...AB` (1 if `D` is shorter than 2 digits), and split the current region equally into A rows and B columns. If no digits are provided at all, behave the same as `Space`.
4. `d`: Take the argument in the format of `A0B`, where `A` and `B` do not contain any `0`, apply `h` with argument `A` unless `A` is shorter than 2 digits. On each splitted region, apply `v` with argument `B` unless `B` is shorter than 2 digit. Does nothing if the argument is ill-formed.
5. `s`: shift the current editing region with other open regions. If digits are provided, shift for that many times.
6. `Space` or `-`: Without parameters, close the current region and move to the next open region. With digits, set the maximum depth of splitting (the default depth is 2).
7. `Enter`/`.`: close all open regions. When all regions are closed, press `Enter` will save the layout and exit the editor.
8. `Backspace`: undo the last command.
9. `Escape`: exit the editor without saving the layout.

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


`12210121d`

```
11 2222 3333 44
11 2222 3333 44

55 6666 7777 88
55 6666 7777 88
55 6666 7777 88
55 6666 7777 88

99 AAAA BBBB CC
99 AAAA BBBB CC
```

### Draft mode

__This mode is experimental. Its usage may change fast.__

Unlike the original machi layout, where a window fits in a single region, draft mode allows window to span across multiple regions.
Each tiled window is associated with a upper-left region (ULR) and a bottom-right region (BRR).
The geometry of the window is from the upper-left corner of the ULR to the bottom-right corner of the BRR.

This is suppose to work with regions produced with `d` command.
To enable draft mode in a layout, configure the layout with a command with a leading `d`, for example, `d12210121d`.

### Persistent history

By default, the last 100 command sequences are stored in `.cache/awesome/history_machi`.
To change that, please refer to `editor.lua`. (XXX more documents)

## Switcher

Calling `machi.switcher.start()` will create a switcher supporting the following keys:

 - Arrow keys: move focus into other regions by the direction.
 - `Shift` + arrow keys: move the focused window to other regions by the direction. In draft mode, move the window while preserving its size.
 - `Control` + arrow keys: move the bottom-right region of the focused window by direction. Only work in draft mode.
 - `Tab`: switch beteen windows covering the current regions.

So far, the key binding is not configurable. One has to modify the source code to change it.

## Advanced

### `name` as a function in `machi.layout.create`

When passed in as a function, `name` takes the tag `t` and returns (1) a string for the tag-dependent name of the layout, and (2) a boolean indicating the persistence of the layout.

The default layout, `machi.default_layout`, uses the screen geometry and the tag name for name, thus allows the actual layout to be tag- and screen-dependent.
To differentiate tags with the same name, you may need a more advanced naming function.

## Caveats

1. layout-machi handles `beautiful.useless_gap` slightly differently.

2. True transparency is required. Otherwise switcher and editor will block the clients.

## License

Apache 2.0 --- See LICENSE
