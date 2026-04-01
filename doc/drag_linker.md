# DragLinker - MATLAB Drag & Drop Framework

A comprehensive drag-and-drop framework for MATLAB App Designer (uifigure) applications.

## Files Included

### Core Classes
- **`DragLinker.m`** - Main drag-drop linking class
- **`DragLinkerFactory.m`** - Singleton factory for managing drag-drop relationships

### Testing
- **`DragLinkerTest.m`** - Comprehensive test suite using only public interfaces
  - Run with: `runtests('DragLinkerTest')`
  - View results: `table(runtests('DragLinkerTest'))`

### Examples
- **`DragLinkerDemo.m`** - Interactive demo showing all features
  - Run with: `DragLinkerDemo()`

## Quick Start

### Basic Usage

```matlab
% Create figure and components
fig = uifigure();
btn = uibutton(fig, "Position", [20 150 100 30], "Text", "Drag Me");
pnl = uipanel(fig, "Position", [20 20 200 100], "Title", "Drop Here");

% Create drag-drop link
dl = DragLinker(btn, pnl, @onDrop);

function onDrop(source, target, releasePoint)
    fprintf("Dropped %s on %s at [%.1f, %.1f]\n", ...
            source.Text, target.Title, releasePoint(1), releasePoint(2));
end
```

### With Factory Pattern

```matlab
% Register components from different scopes
DragLinkerFactory.addSource("MyButton", btnHandle);
DragLinkerFactory.addDestination("MyPanel", pnlHandle);

% Define relationship
DragLinkerFactory.addLink("MyButton", "MyPanel", ...
    "UseItemGhost", true, ...
    "DragKey", "control");
```

### Listbox with Item-Level Dragging

```matlab
lst = uilistbox(fig, "Items", ["A"; "B"; "C"], "Multiselect", "on");
pnl = uipanel(fig, "Position", [150 20 200 200]);

dl = DragLinker(lst, pnl, @onDrop, "UseItemGhost", true);

function onDrop(src, tgt, pt)
    items = src.Value;  % Get selected items
    fprintf("Dropped: %s\n", strjoin(items, ", "));
end
```

## Key Features

### DragLinker
- ✅ Supports uibutton, uipanel, uilistbox, uitree, uiaxes
- ✅ Configurable modifier keys (Ctrl, Alt, Shift, or none)
- ✅ Item-level ghosts for ListBox and Tree
- ✅ Cross-figure dragging
- ✅ Events: DragStarted, DragSuccessful, DragFailed
- ✅ Visual feedback (ghost element, target highlighting)

### DragLinkerFactory
- ✅ Singleton pattern for global registration
- ✅ Automatic link creation when both sides available
- ✅ Built-in default behaviors:
  - ListBox ↔ ListBox (transfer items)
  - ListBox ↔ Tree (convert to nodes)
  - Tree ↔ Tree (move nodes)
  - Components → Axes (plot items)
  - Any ↔ Any (swap positions with Alt)
- ✅ Custom link functions
- ✅ Multiple drag keys per source-destination pair

## Configuration Options

### DragKey
Controls which modifier key activates dragging:
- `"control"` - Ctrl+Drag (default)
- `"alt"` - Alt+Drag
- `"shift"` - Shift+Drag
- `""` - No modifier required

### UseItemGhost
For ListBox and Tree sources:
- `true` - Show selected item text in ghost
- `false` - Show component label (default)

## Default Behaviors

The factory provides intelligent defaults:

| Source → Target | Behavior |
|---|---|
| ListBox → ListBox | Transfer selected items to drop location |
| ListBox → Tree | Create tree nodes from selected items |
| Tree → ListBox | Convert selected nodes to list items |
| Tree → Tree | Move nodes to new parent |
| ListBox/Tree → Axes | Plot items as line series |
| Any → Any (Alt) | Swap component positions |

## Running Tests

The test suite verifies all public functionality:

```matlab
% Run all tests
results = runtests('DragLinkerTest');

% View results table
disp(table(results));

% Run specific test
results = runtests('DragLinkerTest', 'Name', 'testBasicConstruction');

% Check for failures
assert(all([results.Passed]), 'Some tests failed!');
```

### Test Coverage

The test suite covers:
- ✅ Constructor with various argument combinations
- ✅ Invalid input validation
- ✅ All supported component types (ListBox, Tree, UIAxes, Panel, Button)
- ✅ Public static methods (getAbsolutePosition, pointInRect, componentLabel)
- ✅ Event system (DragStarted, DragSuccessful, DragFailed)
- ✅ Factory singleton pattern
- ✅ Factory source/destination registration
- ✅ Link creation and lazy evaluation
- ✅ Invalid component cleanup
- ✅ Multiple drag keys
- ✅ Cross-component type integration

## Running Demo

```matlab
% Full interactive demo
DragLinkerDemo();
```

The demo shows:
- Multiple ListBoxes with item transfer
- Trees with node movement
- Axes with plotting integration
- Component reparenting with Alt+Drag

**Controls:**
- **Ctrl+Drag**: Transfer items between components
- **Alt+Drag**: Swap component positions

## Public API Reference

### DragLinker Class

#### Constructor
```matlab
dl = DragLinker(source, target, callback, Name=Value)
```

**Arguments:**
- `source` - Graphics handle to drag source
- `target` - Graphics handle to drop target
- `callback` - Function handle with signature: `function(source, target, releasePoint)`

**Name-Value Options:**
- `DragKey` - Modifier key ("control"|"alt"|"shift"|"") - default: "control"
- `UseItemGhost` - Show item text for ListBox/Tree - default: false

#### Public Properties (SetAccess = private)
- `Source` - Handle to draggable object
- `Target` - Handle to drop target
- `Callback` - Drop callback function

#### Public Static Methods
- `getAbsolutePosition(h)` - Get component position in figure coordinates
- `pointInRect(cp, rect)` - Test if point is inside rectangle
- `componentLabel(h)` - Get human-readable component description
- `figureAtCursor()` - Find figure(s) under cursor
- `cursorPositionForFigure(fig)` - Get cursor position in figure coordinates

#### Events
- `DragStarted` - Fired when drag gesture begins
- `DragSuccessful` - Fired when drop succeeds
- `DragFailed` - Fired when drop fails

### DragLinkerFactory Class

#### Static Methods
- `make(clearFlag)` - Get/create singleton instance
- `addSource(name, handle)` - Register drag source
- `addDestination(name, handle)` - Register drop target
- `addLink(src, dst, Name=Value)` - Define drag-drop relationship
- `addDragToReparentLink(src, dst, Name=Value)` - Define swap relationship

#### Public Methods
- `removeInvalid()` - Clean up deleted components
- `clearDragLinkers()` - Delete all linkers

#### Public Properties (SetAccess = private)
- `Sources` - Dictionary of registered sources
- `Destinations` - Dictionary of registered destinations
- `DragLinkers` - Dictionary of active DragLinker instances
- `LinkFunctions` - Dictionary of custom link functions
- `LinkUseItemGhost` - Dictionary of UseItemGhost settings
- `LinkDragKeys` - Dictionary of drag key settings

## Architecture

### DragLinker
- **Event Listeners**: Uses WindowMousePress/Motion/Release on figures
- **State Machine**: Tracks IsClicked → IsDragging → Finalized
- **Cross-Figure Support**: Tracks cursor via groot.PointerLocation
- **Ghost Element**: Floating uilabel that follows cursor during drag

### Factory
- **Lazy Linking**: DragLinker instances created only when both source and destination registered
- **Automatic Cleanup**: Invalid components removed via removeInvalid()
- **Key Management**: Unique dictionary keys per source-destination-modifier combo
- **Default Functions**: Type-based routing to appropriate transfer handlers

## Best Practices

1. **Always specify DragKey explicitly**
   ```matlab
   dl = DragLinker(src, tgt, cb, "DragKey", "control");
   ```

2. **Use factory for components in different scopes**
   ```matlab
   % In function A
   DragLinkerFactory.addSource("Btn1", myBtn);
   
   % In function B
   DragLinkerFactory.addDestination("Pnl1", myPnl);
   
   % Anywhere
   DragLinkerFactory.addLink("Btn1", "Pnl1");
   ```

3. **Enable debug mode for troubleshooting**
   ```matlab
   dl.IsDebugMode = true;  % Prints debug info to console
   ```

4. **Listen to events for custom feedback**
   ```matlab
   addlistener(dl, 'DragStarted', @(~,~) disp('Drag started'));
   addlistener(dl, 'DragSuccessful', @(~,~) playSound('success'));
   addlistener(dl, 'DragFailed', @(~,~) playSound('error'));
   ```

5. **To clean up factory**
   ```matlab
   factory = DragLinkerFactory.make();
   factory.removeInvalid();  % Remove deleted components
   ```

## Troubleshooting

### Drag not starting
- Check DragKey matches what you're pressing (Ctrl = "control")
- Verify source component is valid
- Try `dl.IsDebugMode = true` to see events
- Make sure source is not disabled

### Drop not triggering
- Ensure target component is valid
- Check cursor is actually over target on release
- Verify both figures are visible
- Check callback signature is correct: `function(src, tgt, pt)`

### Ghost not showing
- Check source has Position property
- Verify figure is visible
- Look for errors in console

### Factory links not creating
- Verify both source AND destination registered
- Check names match exactly (case-sensitive)
- Look for warnings about link creation failure
- Try calling `DragLinkerFactory.updateLinks()` manually

### Tests failing
- Ensure MATLAB R2020b or later
- Check test figure isn't being deleted prematurely
- Verify no other tests are interfering with singleton factory
- Run tests individually to isolate issues

## Performance Notes

- Mouse motion listeners created only during active drags
- Figures cached per DragLinker instance
- Ghost updates position only, not fully recreated
- Factory lazy-creates links (not all upfront)
- Private properties used for performance-critical state

## Requirements

- **MATLAB R2020b** or later (for `arguments` blocks)

## License

Original code © 2003 The MathWorks, Inc.  
Refactored and enhanced 2024.

## Acknowledgments

Based on original `dragndrop` implementation by Michelle Hirsch (MathWorks).  
Refactored for modern MATLAB with:
- Event listener architecture
- App Designer (uifigure) support
- Factory pattern for global registration
- Comprehensive test suite
- Cross-figure dragging

## Contributing

To report issues or suggest improvements:
1. Include MATLAB version (`ver`)
2. Provide minimal reproduction example
3. Include error messages and stack traces
4. Check if issue exists in basic demo first

## Version History

- **v2.0** (2024) - Complete refactor for modern MATLAB
  - Added event listener architecture
  - Added factory pattern
  - Added comprehensive tests
  - Added cross-figure support
  - Improved documentation

- **v1.0** (2003) - Original implementation
  - Basic drag-drop for figure/uicontrol
  - ButtonDownFcn-based