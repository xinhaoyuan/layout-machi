# layout-machi

A manual layout for Awesome with a rapid interactive editor.

## Why?

TL;DR --- I want the control of my layout.

1. Dynamic tiling is an overkill, since tiling is only useful for persistent windows, and people extensively use hibernate/sleep these days.
2. I don't want to have all windows moving around whenever a new window shows up.
3. I want to have a flexible layout such that I can quickly adjust to whatever I need.

## Use the layout

Use `layotu = layout_machi.layout.create()` to instantiate the layout.

## Use the editor

Call `editor = layout_machi.editor.create()` to create an editor that can either

 - Interactively edit layout by calling `editor.start_interactive()`
 - Set the layout with batched commands by calling `editor.set_by_cmd(cmd)`, where cmd is a string

`data` is an object for storing the history of the editing, initially `{}`.

### The layout editing command

The editing starts with the open area of the entire workarea, takes commands to split the current area into multiple sub-areas, then recursively edits each of them.
The editor is keyboard driven, each command is a key with at most 2 digits as parameters (A, B) before the command.
Undefined parameters are (mostly) treated as 1.

1. `Up`/`Down`: restore to the history command sequence
2. `h`/`v`: split the current region horizontally/vertically into 2 regions. The split will respect the ratio A:B.
3. `w`: Take two parameters (A, B), and split the current region equally into A columns and B rows. If no parameter is defined, behave the same as `Space` without parameters.
4. `s`: shift the current editing region with other open regions. If A is defined, shift for A times.
5. `Space` or `-`: Without parameters, close the current region and move to the next open region. With parameters, set the maximum depth of splitting (default is 2).
6. `Enter`/`.`: close all open regions. When all regions are closed, press `Enter` will save the layout and exit the editor.
7. `Backspace`: undo the last command.
8. `Escape`: exit the editor without saving the layout.

For examples:

h-v

```
11 22
11 22
11
11 33
11 33
```


hvv (or 22w)

```
11 33
11 33

22 44
22 44
```


3-13h2v--2h-12v

Details:

 - `3-`: set the maximum editing depth to 3
 - `13h`: horizontally split the initial region (entire desktop) to the ratio of 1:3
 - For the left part:
   - `2v`: vertically split the region to the ratio of 2:1
   - `--`: ignore further editing the splitted regions
 - For the right part:
   - `2h`: horizontally split the region to the ratio of 2:1
   - `-`: ignore the left part of the splitted regions
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

By default, the last 100 command sequences is stored in `~/.machi_history`.
To change that, please refer to `editor.lua`. (XXX more documents)

## Other functions

`layout_machi.editor.cycle_region(c)` will fit a floating client into the closest region, then cycle through all regions.

## TODO

 - Tabs on regions?

## License

Apache 2.0 --- See LICENSE
