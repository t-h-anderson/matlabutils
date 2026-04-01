function DragLinkerDemo()
%DRAGLINKERFACTORYDEMO Interactive demo of DragLinkerFactory
%
%   This demo shows how to use DragLinkerFactory to create drag-drop
%   relationships between various UI components.
%
%   Controls:
%     • Ctrl+Drag - Transfer items between components
%     • Alt+Drag  - Swap component positions

% Clear factory and start fresh
DragLinkerFactory.make(true);

% Create main figure
fig = uifigure("Name", "DragLinker Factory Demo", ...
    "Position", [100 100 800 600]);

% Create grid layout
grid = uigridlayout(fig, [3, 3]);
grid.RowHeight = {'1x', '1x', '1x'};
grid.ColumnWidth = {'1x', '1x', '1x'};

% Create components in grid
makeListBox(grid, "1", 1, 1);
makeListBox(grid, "2", 1, 2);
makeTree(grid, "1", 1, 3);

makeTree(grid, "2", 2, 1);
makeAxes(grid, "1", 2, 2);
makeAxes(grid, "2", 2, 3);

makePanel(grid, "1", 3, 1);
makePanel(grid, "2", 3, 2);
makePanel(grid, "3", 3, 3);

% Define drag-drop relationships
% ListBox ↔ ListBox
DragLinkerFactory.addLink("ListBox1", "ListBox2");
DragLinkerFactory.addLink("ListBox2", "ListBox1");

% ListBox → Tree
DragLinkerFactory.addLink("ListBox1", "Tree1");
DragLinkerFactory.addLink("ListBox2", "Tree2");

% Tree → ListBox
DragLinkerFactory.addLink("Tree1", "ListBox1");
DragLinkerFactory.addLink("Tree2", "ListBox2");

% Tree ↔ Tree
DragLinkerFactory.addLink("Tree1", "Tree2");
DragLinkerFactory.addLink("Tree2", "Tree1");

% Components → Axes (plotting)
DragLinkerFactory.addLink("ListBox1", "Axes1");
DragLinkerFactory.addLink("ListBox2", "Axes2");
DragLinkerFactory.addLink("Tree1", "Axes1");
DragLinkerFactory.addLink("Tree2", "Axes2");

% Reparenting with Alt key
components = ["ListBox1", "ListBox2", "Tree1", "Tree2", ...
    "Axes1", "Axes2", "Panel1", "Panel2", "Panel3"];

for i = 1:numel(components)
    for j = 1:numel(components)
        if i ~= j
            DragLinkerFactory.addDragToReparentLink(components(i), ...
                components(j));
        end
    end
end

% Add instructions
uilabel(fig, ...
    "Text", ["Drag & Drop Demo"; ""; ...
    "Ctrl+Drag: Transfer items"; ...
    "Alt+Drag: Swap positions"], ...
    "Position", [10 10 180 80], ...
    "FontSize", 11, ...
    "FontWeight", "bold", ...
    "VerticalAlignment", "top");

end

% ====================================================================== %
% Component Factories
% ====================================================================== %

function lst = makeListBox(parent, name, row, col)
% Create a listbox with sample items
lst = uilistbox(parent, ...
    "Items", ["Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig"], ...
    "Tag", "ListBox" + name, ...
    "Multiselect", "on");

lst.Layout.Row = row;
lst.Layout.Column = col;

DragLinkerFactory.addSource("ListBox" + name, lst);
DragLinkerFactory.addDestination("ListBox" + name, lst);
end

function tree = makeTree(parent, name, row, col)
% Create a tree with sample nodes
tree = uitree(parent, "Tag", "Tree" + name);

% Add root nodes
node1 = uitreenode(tree, "Text", "Fruits");
uitreenode(node1, "Text", "Apple");
uitreenode(node1, "Text", "Banana");

node2 = uitreenode(tree, "Text", "Colors");
uitreenode(node2, "Text", "Red");
uitreenode(node2, "Text", "Blue");

tree.Layout.Row = row;
tree.Layout.Column = col;

DragLinkerFactory.addSource("Tree" + name, tree);
DragLinkerFactory.addDestination("Tree" + name, tree);
end

function ax = makeAxes(parent, name, row, col)
% Create an axes for plotting
ax = uiaxes(parent);
title(ax, "Axes " + name);
legend(ax);

ax.Layout.Row = row;
ax.Layout.Column = col;

DragLinkerFactory.addSource("Axes" + name, ax);
DragLinkerFactory.addDestination("Axes" + name, ax);
end

function pnl = makePanel(parent, name, row, col)
% Create an empty panel
pnl = uipanel(parent, ...
    "Title", "Panel " + name, ...
    "Tag", "Panel" + name);

pnl.Layout.Row = row;
pnl.Layout.Column = col;

DragLinkerFactory.addSource("Panel" + name, pnl);
DragLinkerFactory.addDestination("Panel" + name, pnl);
end