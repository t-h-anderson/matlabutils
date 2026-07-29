%[text] # Table Widget
%[text] This live script demonstrates basic usage of the custom Table component: 
%[text] - Create sample data
%[text] - Construct the Table
%[text] - Show filtering, grouping, sorting, selection, and styling
%[text] - Hook callbacks to observe interactions \
%[text] ### Create sample data
%[text] Create a sample table with numeric, categorical, and text columns.
n = 30; 
T = table; 
T.ID = (1:n).'; 
T.Category = categorical(randi([1 4], n, 1), 1:4, ["A","B","C","D"]); 
T.Group = categorical(randi([1 5], n, 1), 1:5, compose("G%d", 1:5)); 
T.Value = randn(n,1) * 10 + 50;
T.Note = arrayfun(@(x) "Row" + x, (1:n).', 'UniformOutput', false);
T.Note = string(T.Note);
%%
%[text] ### Create the widget
fig = uifigure('Name','Table Widget Demo');
gl = uigridlayout(fig, [1,1]);
%[text] Construct the Table widget using name-value pairs supported by the class 
tb = gwidgets.Table(Parent=gl, Data=T, Backend="JavaScript");
%%
%[text] ### Enable features
%[text] Enable the row filter control 
tb.Menu.HasToggleFilter = true; tb.ShowRowFilter = true;
%%
%[text] Make grouping-related features available 
tb.Menu.HasChangeGroupingVariable = true; tb.Menu.HasToggleShowEmptyGroups = true;
%%
%[text] Allow sorting from the table and context menu
tb.Column.Sortable = true; tb.Menu.HasColumnSorting = true;
%%
%[text] Allow cell selection and column selection (context menu will show both) 
tb.Menu.SupportedSelectionTypes = ["cell","column"];
%%
tb.Menu.HasChangeDisplayOrientation = true;
tb.DisplayOrientation = "Transposed";
tb.Menu.HasToggleTableMetrics = true;
%%
%[text] ### Grouping example (programmatic)
%[text] Group by the Category column
tb.Group.By = "Category";
%[text] Open all groups 
tb.Group.openAll();
%%
%[text] ###  Filtering example (programmatic)
%[text] Restrict to Category A and B.
tb.FilterControl.FilterValue = "Category = A|B";
%%
%[text] ### Sorting example
%[text] Sort by Value descending 
tb.Sort.By = "Value";
tb.Sort.Direction = "Descend";
%%
%[text] Selection and callbacks
%[text] Cell clicked callback: show selected data indices and values in the command window. 
tb.SelectionControl.Type = "cell";
tb.Callback.CellDoubleClick = @(src, evt) fprintf("CellClicked: DataIdx = %s, DisplayIdx = %s"+newline, mat2str(evt.Indices), mat2str(evt.DisplayIndices));
%%
%[text] ## Add a custom context menu item
m = uimenu(fig, Text="Export Visible Rows", MenuSelectedFcn=@(~, ~)assignin("base", "ExportedVisible", tb.DisplayData)); 
tb.Menu.addItem(m);
%%
%[text] ## Custom style example
%[text] Create a style that highlights rows with Value \> 60
s = matlab.ui.style.Style(BackgroundColor=[0.8 0.2 0.5]);
%[text] target function takes the Table object
%[text] Apply a "row" style using the widget's addStyle API. SelectionMode "Display" makes the style use visible selection mapping.
tb.Style.remove()
tb.Style.add(s, "row", "Value>48");
%%
%[text] ## Custom tooltip example
%[text] Tooltips are registered with `TooltipControl.add(text, target, indices)` — same shape as `Style.add`. All matching tooltips for the hovered cell are joined most-specific-first (cell → row → column → table). Hover briefly over a cell to see the popup.
tb.TooltipControl.remove() %[output:75313ee1]
%[text] Static text per target. The whole-table `TooltipControl.Text` value is the fallback when nothing more specific matches.
tb.TooltipControl.Text = "Hover any cell for details";
tb.TooltipControl.add("Categorical group label", "column", 2);
tb.TooltipControl.add("Highlighted row",         "row",    3);
tb.TooltipControl.add("Outlier",                 "cell",   [5 4]);
%[text] Function form: receives a `TooltipContext` with fields `Value`, `Row`, `Column`, `Table`, `DisplayRow`/`DisplayColumn`, `DataRow`/`DataColumn`, and `Target`. `Row` / `Column` slices come from the underlying `Data` table (hidden columns and filtered-out rows reachable). Per-target `ContextShape` defaults: `column`=Values vector, `row`=1×N Table, `table`=full Data, `cell`=cell value. Override with `ContextShape="Values"` or `ContextShape="Table"`.
tb.TooltipControl.add(@(ctx) "Cell value: " + string(ctx.Value),       "column", 4);
tb.TooltipControl.add(@(ctx) "Column max: " + max(ctx.Column),         "column", 4);
tb.TooltipControl.add(@(ctx) "Row label: "  + string(ctx.Row.Note),    "row",    3);
tb.TooltipControl.add(@(ctx) "Total rows: " + height(ctx.Table),       "table");
%[text] Use `ContextShape="Values"` to get the row as a vector for numeric aggregates:
tb.TooltipControl.add(@(ctx) "Row sum: " + sum(ctx.Row), "row", 3, "ContextShape", "Values");
%[text] ### Styled tooltips
%[text] Pass a `TooltipStyle` or a function returning one. Per-tooltip styles override the widget-wide `DefaultTooltipStyle`.
tb.TooltipControl.DefaultStyle = gwidgets.table.TooltipStyle(BackgroundColor="#222", FontColor="white", Padding=6);
heat = @(ctx) gwidgets.table.TooltipStyle( ...
    BackgroundColor=string(sprintf("rgb(%d,80,80)", min(255, round(ctx.Value*4)))), ...
    FontColor="white", Padding=6);
tb.TooltipControl.add(@(ctx) "Value: " + string(ctx.Value), "column", 4, "Style", heat);

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":38.7}
%---
%[output:75313ee1]
%   data: {"dataType":"textualVariable","outputData":{"header":"logical","name":"ans","value":"   0\n"}}
%---
