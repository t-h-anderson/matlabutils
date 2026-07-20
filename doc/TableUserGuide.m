%[text] # gwidgets.Table User Guide
%[text] |gwidgets.Table| is a controller-first table widget for MATLAB apps. It wraps a |uitable| with filtering, grouping, sorting, selection, styling, context menus, and styled hover tooltips.
%%
%[text] ## Create a Table
%[text] Create the widget with |Parent| and |Data| name-value arguments. For app startup performance, set as much state as possible before making the parent figure visible.
data = table( ...
    categorical(["A"; "B"; "A"; "C"]), ...
    ["Open"; "Closed"; "Open"; "Pending"], ...
    [12.5; 41.0; 33.5; 18.0], ...
    VariableNames=["Category", "Status", "Value"]);
fig = uifigure(Name="Table Guide", Visible="off");
grid = uigridlayout(fig, [1, 1], Padding=0);
tbl = gwidgets.Table(Parent=grid, Data=data);
fig.Visible = "on";
%%
%[text] ## Controller Surface
%[text] New code should use the controller properties. Each controller owns one behavior area and keeps related settings together.
tbl.Column.Sortable = true;
tbl.FilterControl.FilterValue = "Category=A|B";
tbl.Group.By = "Category";
tbl.Group.openAll();
tbl.SelectionControl.Type = "row";
tbl.SelectionControl.Value = 1;
tbl.Sort.By = "Value";
tbl.Sort.Direction = "Descend";
tbl.TooltipControl.Text = "Visible row";
%%
%[text] ## Data and Display Data
%[text] |Data| is the source table. |DisplayData| is the currently visible table after filtering, grouping, folding, and sorting. Use |DisplayData| for export commands that should respect the user's current view.
visibleRows = tbl.DisplayData;
%%
%[text] ## Filtering
%[text] Programmatic filters use |FilterControl.FilterValue|. Simple expressions support numeric comparisons, string contains matches with |?=|, logical values, categorical labels, dates, durations, conjunctions with |&|, and alternatives separated by vertical bars.
tbl.FilterControl.FilterValue = "Value>=18&Status?=Open";
%%
%[text] ## Grouping and Folding
%[text] Use |Group.By| to group by one or more variables. |openAll| and |closeAll| control folded groups. |ShowEmpty| controls whether empty groups remain visible.
tbl.Group.By = ["Category", "Status"];
tbl.Group.ShowEmpty = true;
tbl.Group.openAll();
%%
%[text] ## Sorting
%[text] Use |Sort.By| with visible column names and |Sort.ByData| with source data variable names. |Sort.Direction| accepts |"Ascend"|, |"Descend"|, or |"None"|.
tbl.Column.DataSortable = true;
tbl.Sort.ByData = "Value";
tbl.Sort.Direction = "Ascend";
%%
%[text] ## Selection and Callbacks
%[text] |SelectionControl.Type| selects |"cell"|, |"row"|, |"column"|, or |"table"| mode. |Value| is expressed in data coordinates; |DisplayValue| is expressed in current display coordinates.
tbl.SelectionControl.Type = "cell";
tbl.SelectionControl.Value = [2 3];
tbl.Callback.CellSelection = @(src, evt)setappdata(fig, "LastSelection", evt);
tbl.Callback.CellDoubleClick = @(src, evt)setappdata(fig, "LastDoubleClick", evt);
%%
%[text] ## Columns
%[text] |Column.Width|, |Column.Visible|, |Column.Names|, |Column.Editable|, and |Column.Sortable| act on visible columns. The corresponding |Data| properties act on source data columns before visibility mapping.
tbl.Column.DataWidth = {120, "1x", 90};
tbl.Column.Visible = [true, true, true];
tbl.Column.Editable = [false, false, true];
%%
%[text] ## Styles
%[text] Styles use the same target names as MATLAB |uitable.addStyle|: |"table"|, |"row"|, |"column"|, and |"cell"|. Targets can be numeric indices, query strings, or functions.
highlight = uistyle(BackgroundColor=[0.90 0.95 1.00]);
tbl.Style.remove();
tbl.Style.add(highlight, "row", "Value>20");
%%
%[text] ## Tooltips
%[text] |TooltipControl.Text| is the whole-table fallback. |TooltipControl.add| registers more specific static or function-based tooltips. Function tooltips receive a |gwidgets.table.TooltipContext|.
tbl.TooltipControl.remove();
tbl.TooltipControl.Text = "Hover a cell";
tbl.TooltipControl.add("Numeric value", "column", 3);
tbl.TooltipControl.add(@(ctx)"Value: " + string(ctx.Value), "cell", [1 3]);
tbl.TooltipControl.DefaultStyle = gwidgets.table.TooltipStyle(BackgroundColor="#222222", FontColor="white", Padding=6);
%%
%[text] ## Context Menus
%[text] Use |Menu| to enable built-in context-menu actions and add custom menu items. Custom callbacks can read |DisplayData|, |SelectionControl.Value|, or |SelectionControl.DisplayValue|.
tbl.Menu.HasToggleFilter = true;
tbl.Menu.HasColumnSorting = true;
exportItem = uimenu(fig, Text="Store Visible Rows", MenuSelectedFcn=@(~, ~)setappdata(fig, "VisibleRows", tbl.DisplayData));
tbl.Menu.addItem(exportItem);
%%
%[text] ## Compatibility Aliases
%[text] Older pass-through properties remain supported for existing code. Examples include |Filter|, |GroupingVariable|, |OpenGroups|, |SortByColumn|, |SortDirection|, |Selection|, |SelectionType|, |Tooltip|, and |DefaultTooltipStyle|. Prefer the controller API in new code.
tbl.Filter = "Category=A";
tbl.SelectionType = "row";
tbl.Selection = 1;
%%
%[text] ## Performance Guidance
%[text] The widget does not call |drawnow| or |pause| automatically during normal creation and customisation. Build complex apps with figures hidden, assign controller state in batches, then show the figure. Avoid calling |drawnow| or |pause| from app setup callbacks unless you are diagnosing a rendering issue.
fig.Visible = "on";
%%
%[text] ## See Also
%[text] |gwidgets.Table|, |gwidgets.UITable|, |gwidgets.table.TooltipStyle|, |gwidgets.table.TooltipContext|, |doc/TableDeveloperGuide.m|, |doc/TableDemo.m|
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
