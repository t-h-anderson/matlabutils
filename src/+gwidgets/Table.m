classdef Table < matlab.mixin.SetGet
    %TABLE Controller-first table widget with legacy-compatible aliases.
    %   t = gwidgets.Table(Data=T) creates an interactive table widget for
    %   tabular data. The primary API is exposed through focused
    %   controllers:
    %
    %       t.Column             Column names, widths, visibility, editing
    %       t.FilterControl      Programmatic and row-filter state
    %       t.Group              Grouping and group folding
    %       t.Sort               Sorting variables and direction
    %       t.SelectionControl   Data/display selection state
    %       t.Style              Table styles
    %       t.TooltipControl     Static and function-based hover tooltips
    %       t.Menu               Context-menu capabilities
    %       t.Callback           Stable callback properties
    %
    %   Legacy aliases such as Filter, Selection, GroupingVariable,
    %   SortByColumn, SortDirection, Tooltip, and addTooltip remain
    %   supported for compatibility. Prefer controller properties in new
    %   code.
    %
    %   Table creation and normal customisation do not force drawnow or
    %   pause. For complex apps, create figures hidden, assign controller
    %   state, and make the figure visible after setup.
    %
    %   See also gwidgets.UITable, gwidgets.table.TooltipStyle.

    properties (Access = private)
        UITable_ (1,:) gwidgets.UITable {mustBeScalarOrEmpty}
    end

    properties (Dependent, SetAccess = private)
        Column (1,1) gwidgets.internal.table.ColumnController
        Group (1,1) gwidgets.internal.table.GroupController
        Sort (1,1) gwidgets.internal.table.SortController
        Style (1,1) gwidgets.internal.table.StyleController
        Menu (1,1) gwidgets.internal.table.ContextMenuController
        Callback (1,1) gwidgets.internal.table.CallbackController
        FilterControl (1,1) gwidgets.internal.table.FilterController
        SelectionControl (1,1) gwidgets.internal.table.SelectionController
        TooltipControl (1,1) gwidgets.internal.table.TooltipController
        Drag (1,1) gwidgets.internal.table.DragController
    end

    properties (Dependent)
        Data (:,:) table
        Filter
        ShowRowFilter (1,1) logical
        Tooltip (1,1) string
        DefaultTooltipStyle (1,1) gwidgets.table.TooltipStyle
        Parent
        Position
        Units
        Visible
        CellSelectionCallback function_handle {mustBeScalarOrEmpty}
        CellClickedCallback function_handle {mustBeScalarOrEmpty}
        CellDoubleClickCallback function_handle {mustBeScalarOrEmpty}
        CellEditCallback function_handle {mustBeScalarOrEmpty}
        DisplayDataChangedCallback function_handle {mustBeScalarOrEmpty}
    end

    properties (Dependent, SetAccess = private)
        DisplayData (1,1) table
        DropSelection (1,1) struct
        Layout
        RowFilterIndices (1,:) logical
        VisibleData (:,:) table
    end

    properties (Dependent, Hidden, SetAccess = private)
        DisplayTable (1,:) matlab.ui.control.Table
        FilterController (1,:) gwidgets.internal.table.FilterController
        Grid (1,:) matlab.ui.container.GridLayout
        GroupLabel (1,:) matlab.ui.control.Label
        HelpPanel (1,:) matlab.ui.container.Panel
        ContextMenu
        SortedVisibleData (:,:) cell
        SortedGroupHeaderRowIdx (1,:) double
        SortedVisibleToDataMap (1,:) double
        SortedDataToVisibleMap (1,:) double
    end

    properties (Dependent, Hidden)
        ColumnEditable (1,:) logical
        ColumnSortable (1,:) logical
        DataColumnEditable (1,:) logical
        DataColumnSortable (1,:) logical
        Multiselect (1,1) matlab.lang.OnOffSwitchState
        SelectionType (1,1) string
        ColumnWidth (1,:)
        DataColumnWidth (1,:)
        DefaultColumnWidths (1,:)
        PixelDataColumnWidths (1,:) double
        RelativeDataColumnWidths (1,:) string
        DataColumnWidthTypes (1,:) string
        PixelColumnWidths (1,:) double
        RelativeColumnWidths (1,:) string
        ColumnWidthTypes (1,:) string
        Selection (:,:) double
        DisplaySelection (:,:) double
    end

    properties (Dependent, Hidden)
        DataColumnNames (1,:) string
        ColumnNames (1,:) string
        ColumnVisible (1,:) logical
        VisibleColumnNames (1,:) string
        VisibleDataColumnNames (1,:) string
        HiddenColumnNames (1,:) string
        HiddenDataColumnNames (1,:) string
    end

    properties (Dependent, Hidden)
        GroupHeaderStyle (1,:) gwidgets.internal.table.TableStyle
        StyleConfigurations (:,3) table
        CustomContextMenuItems (1,:) matlab.ui.container.Menu
        SupportedSelectionTypes (1,:) string
        HasToggleFilter (1,1) logical
        HasChangeGroupingVariable (1,1) logical
        HasToggleShowEmptyGroups (1,1) logical
        HasColumnSorting (1,1) logical
        HasAutoResizeColumns (1,1) logical
        HasToggleDragging (1,1) logical
    end

    properties (Dependent, Hidden)
        ShowEmptyGroups (1,1) logical
        Groups (1,:) string
        DisplayGroups (1,:) string
        IsGroupTable (1,1) logical
        GroupingVariable (1,:) string
        GroupingVariableName (1,1) string
        OpenGroups (1,:) string
        ClosedGroups (1,:) string
        HiddenGroups (1,:) string
        BridgeDiagEnabled (1,1) logical
        SortByColumn (1,:) string
        SortByDataColumn (1,:) string
        SortDirection (1,1) string
    end

    properties (Dependent, Hidden, SetAccess = private)
        Tooltips (1,:) gwidgets.internal.table.TableTooltip
    end

    properties (Dependent, Hidden, SetAccess = private)
        UITable (1,:) gwidgets.UITable
    end

    methods
        function this = Table(namedArgs)
            arguments (Input)
                namedArgs.?gwidgets.Table
                namedArgs.ShowRowFilter (1,1) logical = false
                namedArgs.GroupHeaderStyle = gwidgets.Table.defaultGroupHeaderStyle
            end

            this.UITable_ = gwidgets.UITable();
            this.UITable_.setConstructionRefreshSuppressed(true);
            cleanupObj = onCleanup(@()this.UITable_.setConstructionRefreshSuppressed(false));

            if isfield(namedArgs, "Parent")
                parent = namedArgs.Parent;
                namedArgs = rmfield(namedArgs, "Parent");
                this.Parent = parent;
            end

            if isfield(namedArgs, "Data")
                data = namedArgs.Data;
                namedArgs = rmfield(namedArgs, "Data");
                this.Data = data;
            end

            if ~isempty(fieldnames(namedArgs))
                set(this, namedArgs);
            end
            this.Selection = [];
            this.UITable_.runConstructionUpdate();
            delete(cleanupObj);
            this.UITable_.refreshAfterConstruction();
        end

        function delete(this)
            delete(this.UITable_);
        end

        function reset(this)
            this.UITable_.reset();
        end

        function result = find(this, str, target)
            arguments
                this (1,1) gwidgets.Table
                str (1,1) string
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])} = "table"
            end

            result = this.UITable_.find(str, target);
        end

        function expandFilterController(this, value)
            arguments
                this (1,1) gwidgets.Table
                value (1,1) logical = true
            end

            this.UITable_.expandFilter(value);
        end
    end

    methods
        function val = get.UITable(this)
            val = this.UITable_;
        end

        function val = get.Column(this)
            val = this.UITable_.Column;
        end

        function val = get.Group(this)
            val = this.UITable_.Group;
        end

        function val = get.Sort(this)
            val = this.UITable_.Sort;
        end

        function val = get.Style(this)
            val = this.UITable_.Style;
        end

        function val = get.Menu(this)
            val = this.UITable_.Menu;
        end

        function val = get.Callback(this)
            val = this.UITable_.Callback;
        end

        function val = get.FilterControl(this)
            val = this.UITable_.Filter;
        end

        function val = get.SelectionControl(this)
            val = this.UITable_.Selection;
        end

        function val = get.TooltipControl(this)
            val = this.UITable_.Tooltip;
        end

        function val = get.Drag(this)
            val = this.UITable_.Drag;
        end

        function val = get.Data(this)
            val = this.UITable_.Data.Table;
        end

        function set.Data(this, val)
            this.UITable_.Data.Table = val;
        end

        function val = get.DisplayData(this)
            val = this.UITable_.Data.Display;
        end

        function val = get.DropSelection(this)
            val = this.UITable_.Drag.DropSelection;
        end

        function val = get.Filter(this)
            val = this.FilterControl.FilterValue;
        end

        function set.Filter(this, val)
            this.FilterControl.FilterValue = val;
        end

        function val = get.ShowRowFilter(this)
            val = this.UITable_.ShowRowFilter;
        end

        function set.ShowRowFilter(this, val)
            this.UITable_.ShowRowFilter = val;
        end

        function val = get.Tooltip(this)
            val = this.TooltipControl.Text;
        end

        function set.Tooltip(this, val)
            this.TooltipControl.Text = val;
        end

        function val = get.DefaultTooltipStyle(this)
            val = this.TooltipControl.DefaultStyle;
        end

        function set.DefaultTooltipStyle(this, val)
            this.TooltipControl.DefaultStyle = val;
        end

        function val = get.Tooltips(this)
            val = this.TooltipControl.Tooltips;
        end

        function val = get.Parent(this)
            val = this.UITable_.Parent;
        end

        function set.Parent(this, val)
            this.UITable_.Parent = val;
        end

        function val = get.Layout(this)
            val = this.UITable_.Layout;
        end

        function val = get.Position(this)
            val = this.UITable_.Position;
        end

        function set.Position(this, val)
            this.UITable_.Position = val;
        end

        function val = get.Units(this)
            val = this.UITable_.Units;
        end

        function set.Units(this, val)
            this.UITable_.Units = val;
        end

        function val = get.Visible(this)
            val = this.UITable_.Visible;
        end

        function set.Visible(this, val)
            this.UITable_.Visible = val;
        end

        function val = get.CellSelectionCallback(this)
            val = this.UITable_.Callback.CellSelection;
        end

        function set.CellSelectionCallback(this, val)
            this.UITable_.Callback.CellSelection = val;
        end

        function val = get.CellClickedCallback(this)
            val = this.UITable_.Callback.CellClicked;
        end

        function set.CellClickedCallback(this, val)
            this.UITable_.Callback.CellClicked = val;
        end

        function val = get.CellDoubleClickCallback(this)
            val = this.UITable_.Callback.CellDoubleClick;
        end

        function set.CellDoubleClickCallback(this, val)
            this.UITable_.Callback.CellDoubleClick = val;
        end

        function val = get.CellEditCallback(this)
            val = this.UITable_.Callback.CellEdit;
        end

        function set.CellEditCallback(this, val)
            this.UITable_.Callback.CellEdit = val;
        end

        function val = get.DisplayDataChangedCallback(this)
            val = this.UITable_.Callback.DisplayDataChanged;
        end

        function set.DisplayDataChangedCallback(this, val)
            this.UITable_.Callback.DisplayDataChanged = val;
        end

        function val = get.RowFilterIndices(this)
            val = this.UITable_.Data.RowFilterIndices;
        end

        function val = get.VisibleData(this)
            val = this.UITable_.Data.Visible;
        end
    end

    methods
        function val = get.DisplayTable(this)
            val = this.UITable_.Graphics.DisplayTable;
        end

        function val = get.FilterController(this)
            val = this.UITable_.Filter;
        end

        function val = get.Grid(this)
            val = this.UITable_.Graphics.Grid;
        end

        function val = get.GroupLabel(this)
            val = this.UITable_.Graphics.GroupLabel;
        end

        function val = get.HelpPanel(this)
            val = this.UITable_.Graphics.HelpPanel;
        end

        function val = get.ContextMenu(this)
            val = this.UITable_.ContextMenu;
        end

        function val = get.SortedVisibleData(this)
            val = this.UITable_.Data.SortedVisible;
        end

        function val = get.SortedGroupHeaderRowIdx(this)
            val = this.UITable_.Data.SortedGroupHeaderRowIdx;
        end

        function val = get.SortedVisibleToDataMap(this)
            val = this.UITable_.Data.SortedVisibleToDataMap;
        end

        function val = get.SortedDataToVisibleMap(this)
            val = this.UITable_.Data.SortedDataToVisibleMap;
        end
    end

    methods
        function val = get.DataColumnWidth(this)
            val = this.Column.DataWidth;
        end

        function set.DataColumnWidth(this, val)
            this.Column.DataWidth = val;
        end

        function val = get.DefaultColumnWidths(this)
            val = this.Column.DefaultWidths;
        end

        function set.DefaultColumnWidths(this, val)
            this.Column.DefaultWidths = val;
        end

        function val = get.ColumnWidth(this)
            val = this.Column.Width;
        end

        function set.ColumnWidth(this, val)
            this.Column.Width = val;
        end

        function val = get.PixelDataColumnWidths(this)
            val = this.Column.PixelDataWidths;
        end

        function val = get.PixelColumnWidths(this)
            val = this.Column.PixelWidths;
        end

        function val = get.RelativeDataColumnWidths(this)
            val = this.Column.RelativeDataWidths;
        end

        function val = get.RelativeColumnWidths(this)
            val = this.Column.RelativeWidths;
        end

        function val = get.DataColumnWidthTypes(this)
            val = this.Column.DataWidthTypes;
        end

        function val = get.ColumnWidthTypes(this)
            val = this.Column.WidthTypes;
        end

        function val = get.ColumnVisible(this)
            val = this.Column.Visible;
        end

        function set.ColumnVisible(this, val)
            this.Column.Visible = val;
        end

        function val = get.VisibleColumnNames(this)
            val = this.Column.VisibleNames;
        end

        function set.VisibleColumnNames(this, val)
            this.Column.VisibleNames = val;
        end

        function val = get.VisibleDataColumnNames(this)
            val = this.Column.VisibleDataNames;
        end

        function set.VisibleDataColumnNames(this, val)
            this.Column.VisibleDataNames = val;
        end

        function val = get.HiddenColumnNames(this)
            val = this.Column.HiddenNames;
        end

        function set.HiddenColumnNames(this, val)
            this.Column.HiddenNames = val;
        end

        function val = get.HiddenDataColumnNames(this)
            val = this.Column.HiddenDataNames;
        end

        function set.HiddenDataColumnNames(this, val)
            this.Column.HiddenDataNames = val;
        end

        function val = get.DataColumnNames(this)
            val = this.Column.DataNames;
        end

        function val = get.ColumnNames(this)
            val = this.Column.Names;
        end

        function set.ColumnNames(this, val)
            this.Column.Names = val;
        end

        function val = get.DataColumnEditable(this)
            val = this.Column.DataEditable;
        end

        function set.DataColumnEditable(this, val)
            this.Column.DataEditable = val;
        end

        function val = get.ColumnEditable(this)
            val = this.Column.Editable;
        end

        function set.ColumnEditable(this, val)
            this.Column.Editable = val;
        end

        function val = get.DataColumnSortable(this)
            val = this.Column.DataSortable;
        end

        function set.DataColumnSortable(this, val)
            this.Column.DataSortable = val;
        end

        function val = get.ColumnSortable(this)
            val = this.Column.Sortable;
        end

        function set.ColumnSortable(this, val)
            this.Column.Sortable = val;
        end

        function val = get.Multiselect(this)
            val = this.SelectionControl.Multiselect;
        end

        function set.Multiselect(this, val)
            this.SelectionControl.Multiselect = val;
        end

        function val = get.Selection(this)
            val = this.SelectionControl.Value;
        end

        function set.Selection(this, selection)
            this.SelectionControl.Value = selection;
        end

        function val = get.SelectionType(this)
            val = this.SelectionControl.Type;
        end

        function set.SelectionType(this, selectionType)
            this.SelectionControl.Type = selectionType;
        end

        function val = get.DisplaySelection(this)
            val = this.SelectionControl.DisplayValue;
        end

        function set.DisplaySelection(this, selection)
            this.SelectionControl.DisplayValue = selection;
        end
    end

    methods
        function addTooltip(this, text, tableTarget, targetIndicesOrFunction, nvp)
            % addTooltip registers a hover-tooltip configuration. Mirrors addStyle.
            arguments
                this (1,1) gwidgets.Table
                text
                tableTarget (1,1) string {mustBeMember(tableTarget, ["table", "row", "column", "cell"])} = "table"
                targetIndicesOrFunction (:,:) = []
                nvp.SelectionMode (1,1) gwidgets.table.SelectionMode = gwidgets.table.SelectionMode.Data
                nvp.ContextShape (1,1) string {mustBeMember(nvp.ContextShape, ["Values", "Table"])} = ...
                    gwidgets.internal.table.TableTooltip.defaultContextShape(tableTarget)
                nvp.Style = []
            end

            this.TooltipControl.add(text, tableTarget, targetIndicesOrFunction, ...
                SelectionMode=nvp.SelectionMode, ...
                ContextShape=nvp.ContextShape, ...
                Style=nvp.Style);
        end

        function removeTooltip(this, orderNum)
            arguments
                this (1,1) gwidgets.Table
                orderNum (1,:) double = []
            end

            this.TooltipControl.remove(orderNum);
        end
    end

    methods (Hidden)
        function addStyle(this, style, tableTarget, targetIndicesOrFunction, nvp)
            arguments
                this (1,1) gwidgets.Table
                style (1,1) matlab.ui.style.Style
                tableTarget (1,1) string {mustBeMember(tableTarget, ["table", "row", "column", "cell"])} = "table"
                targetIndicesOrFunction (:,:) = []
                nvp.SelectionMode (1,1) gwidgets.table.SelectionMode = gwidgets.table.SelectionMode.Data
            end

            this.Style.add(style, tableTarget, targetIndicesOrFunction, SelectionMode=nvp.SelectionMode);
        end

        function removeStyle(this, orderNum)
            arguments
                this (1,1) gwidgets.Table
                orderNum (1,:) double = []
            end

            this.Style.remove(orderNum);
        end

        function addContextMenuItem(this, menuItems)
            arguments
                this (1,1) gwidgets.Table
                menuItems (1,:) matlab.ui.container.Menu
            end

            this.Menu.addItem(menuItems);
        end

        function openAllGroups(this)
            this.Group.openAll();
        end

        function closeAllGroups(this)
            this.Group.closeAll();
        end
    end

    methods
        function val = get.StyleConfigurations(this)
            val = this.Style.Configurations;
        end

        function set.StyleConfigurations(this, tbl)
            this.Style.Configurations = tbl;
        end

        function val = get.GroupHeaderStyle(this)
            val = this.Group.HeaderStyle;
        end

        function set.GroupHeaderStyle(this, val)
            this.Group.HeaderStyle = val;
        end

        function val = get.HasToggleFilter(this)
            val = this.Menu.HasToggleFilter;
        end

        function set.HasToggleFilter(this, val)
            this.Menu.HasToggleFilter = val;
        end

        function val = get.HasChangeGroupingVariable(this)
            val = this.Menu.HasChangeGroupingVariable;
        end

        function set.HasChangeGroupingVariable(this, val)
            this.Menu.HasChangeGroupingVariable = val;
        end

        function val = get.HasToggleShowEmptyGroups(this)
            val = this.Menu.HasToggleShowEmptyGroups;
        end

        function set.HasToggleShowEmptyGroups(this, val)
            this.Menu.HasToggleShowEmptyGroups = val;
        end

        function val = get.HasColumnSorting(this)
            val = this.Menu.HasColumnSorting;
        end

        function set.HasColumnSorting(this, val)
            this.Menu.HasColumnSorting = val;
        end

        function val = get.HasAutoResizeColumns(this)
            val = this.Menu.HasAutoResizeColumns;
        end

        function set.HasAutoResizeColumns(this, val)
            this.Menu.HasAutoResizeColumns = val;
        end

        function val = get.HasToggleDragging(this)
            val = this.Menu.HasToggleDragging;
        end

        function set.HasToggleDragging(this, val)
            this.Menu.HasToggleDragging = val;
        end

        function val = get.SupportedSelectionTypes(this)
            val = this.Menu.SupportedSelectionTypes;
        end

        function set.SupportedSelectionTypes(this, val)
            arguments
                this (1,1) gwidgets.Table
                val (1,:) string {mustBeMember(val, ["cell", "row", "column"]), mustBeNonempty} = "cell"
            end

            this.Menu.SupportedSelectionTypes = val;
        end

        function val = get.CustomContextMenuItems(this)
            val = this.Menu.CustomItems;
        end

        function set.CustomContextMenuItems(this, val)
            this.Menu.CustomItems = val;
        end
    end

    methods
        function val = get.IsGroupTable(this)
            val = this.Group.IsGrouped;
        end

        function val = get.Groups(this)
            val = this.Group.Groups;
        end

        function val = get.DisplayGroups(this)
            val = this.Group.DisplayGroups;
        end

        function val = get.OpenGroups(this)
            val = this.Group.Open;
        end

        function set.OpenGroups(this, val)
            this.Group.Open = val;
        end

        function val = get.ClosedGroups(this)
            val = this.Group.Closed;
        end

        function set.ClosedGroups(this, val)
            this.Group.Closed = val;
        end

        function val = get.HiddenGroups(this)
            val = this.Group.Hidden;
        end

        function set.HiddenGroups(this, val)
            this.Group.Hidden = val;
        end

        function val = get.ShowEmptyGroups(this)
            val = this.Group.ShowEmpty;
        end

        function set.ShowEmptyGroups(this, val)
            this.Group.ShowEmpty = val;
        end

        function val = get.GroupingVariableName(this)
            val = this.Group.ByName;
        end

        function val = get.GroupingVariable(this)
            val = this.Group.By;
        end

        function set.GroupingVariable(this, val)
            this.Group.By = val;
        end

        function val = get.SortByColumn(this)
            val = this.Sort.By;
        end

        function set.SortByColumn(this, val)
            this.Sort.By = val;
        end

        function val = get.SortByDataColumn(this)
            val = this.Sort.ByData;
        end

        function set.SortByDataColumn(this, val)
            this.Sort.ByData = val;
        end

        function val = get.SortDirection(this)
            val = this.Sort.Direction;
        end

        function set.SortDirection(this, val)
            this.Sort.Direction = val;
        end

        function val = get.BridgeDiagEnabled(this)
            val = this.UITable_.Bridge.DiagEnabled;
        end

        function set.BridgeDiagEnabled(this, val)
            this.UITable_.Bridge.DiagEnabled = val;
        end
    end

    methods (Access = ?matlab.unittest.TestCase)
        function simulateBridgeDrag(this, pixelWidths)
            this.UITable_.Column.applyBridgeWidths(pixelWidths);
        end

        function [text, style] = simulateBridgeHover(this, displayRow, displayColumn)
            [text, style] = this.UITable_.Tooltip.resolveTextAndStyle(displayRow, displayColumn);
            this.UITable_.Bridge.applyTooltipPayload(displayRow, displayColumn);
        end

        function blocks = simulateTooltipBlocks(this, displayRow, displayColumn)
            blocks = this.UITable_.Tooltip.resolveBlocks(displayRow, displayColumn);
        end

        function changed = didBridgeWidthsChange(this, incomingPx)
            changed = this.UITable_.Column.didBridgeWidthsChange(incomingPx);
        end

    end

    methods (Static)
        function style = defaultGroupHeaderStyle(style)
            arguments
                style (1,1) matlab.ui.style.Style = matlab.ui.style.Style( ...
                    "BackgroundColor", [0.1 0.1 0.8], ...
                    "FontColor", [0.9 0.9 0.9])
            end

            style = gwidgets.internal.table.StyleController.defaultGroupHeaderStyle(style);
        end
    end

    methods (Static, Hidden)
        function g = gcdPixelWidths(px)
            vals = round(px(isfinite(px) & px > 0));
            if isempty(vals)
                g = 1;
                return
            end

            g = vals(1);
            for k = 2:numel(vals)
                g = gcd(g, vals(k));
            end
            if g == 0
                g = 1;
            end
        end

        function val = normalizeColumnWidths(val)
            val = gwidgets.internal.table.ColumnWidthController.normalizeColumnWidths(val);
        end
    end
end
