# layout-machi

A simple and static layout for Awesome with a rapid interactive layout editor.

## Why?

TL;DR --- I want the control of my layout.

1. Dynamic tiling is an overkill, since tiling is only useful for persistent windows, and people extensively use hibernate/sleep these days.
2. I don't want to have all windows moving around whenever a new window shows up. 
3. I want to have a flexible layout such that I can quickly adjust to whatever I need.

## Use the layout

Use `layout-machi.layout.create_layout([LAYOUT_NAME}, [DEFAULT_REGIONS])` to instantiate the layout.
For example:

```
layout-machi.layout.create_layout("default", {})
```

Creates a layout with no regions

## Use the editor

Call `layout-machi.editor.start_editor(data)` to enter the editor for the current layout (given it is a machi instance).
`data` is am object for storing the history of the editing, initially `{}`. 
The editor starts with the open area of the entire workarea, taking command to split the current area into multiple sub-areas, then editing each of them. 
The editor is keyboard driven, accepting a number of command keys.
Before each command, you can optionally provide at most 2 digits for parameters (A, B) of the command.
By default A = B = 1.

1. `Up`/`Down`: restore to the history command sequence 
2. `h`/`v`: split the current region horizontally/vertically into 2 regions. The split will respect the ratio A:B. 
3. `w`: Take two parameters (A, B), and split the current region equally into A columns and B rows. If both A and B is 1, behave the same as `Space` without parameters.
4. `s`: shift the current editing region with other open sibling regions.
5. `Space` or `-`: Without parameters, close the current region and move to the next open region. With parameters, set the maximum depth of splitting (default is 2).
6. `Enter`/`.`: close all open regions. When all regions are closed, press `Enter` will save the layout and exit the editor. 
7. `Backspace`: undo the last command.
8. `Escape`: exit the editor without saving the layout.

## Other functions

`layout-machi.editor.cycle_region(c)` will fit a floating client into the closest region, then cycle through all regions. 

## Demos:

I used `Super + /` for the editor and `Super + Tab` for fitting the windows.


h-v

```
11 22
11 22
11 
11 33
11 33
```

![](https://i.imgur.com/QbvMRTW.gif)


hvv (or 22w)

```
11 33
11 33

22 44
22 44
```

![](https://i.imgur.com/xJebxcF.gif)


history

![](https://i.imgur.com/gzFr48V.gif)

## TODO

 - Make history persistent
 
## License

Apache 2.0 --- See LICENSE
