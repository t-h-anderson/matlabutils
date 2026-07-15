classdef Table < gwidgets.UITable
    %TABLE Legacy-compatible wrapper around gwidgets.UITable.

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

    methods
        function this = Table(namedArgs)
            arguments (Input)
                namedArgs.?gwidgets.Table
                namedArgs.ShowRowFilter (1,1) logical = false
                namedArgs.GroupHeaderStyle = gwidgets.Table.defaultGroupHeaderStyle
            end

            this@gwidgets.UITable();
            this.setConstructionRefreshSuppressed(true);
            cleanupObj = onCleanup(@()this.setConstructionRefreshSuppressed(false));

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
            this.doUpdateSequence();
            delete(cleanupObj);
            if ~isempty(this.Parent)
                this.forceRefresh();
            end
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

            this.legacyContextMenuController().addItem(menuItems);
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
            controller = this.legacyContextMenuControllerIfPresent();
            val = ~isempty(controller) && controller.HasToggleFilter;
        end

        function set.HasToggleFilter(this, val)
            this.legacyContextMenuController().HasToggleFilter = val;
        end

        function val = get.HasChangeGroupingVariable(this)
            controller = this.legacyContextMenuControllerIfPresent();
            val = ~isempty(controller) && controller.HasChangeGroupingVariable;
        end

        function set.HasChangeGroupingVariable(this, val)
            this.legacyContextMenuController().HasChangeGroupingVariable = val;
        end

        function val = get.HasToggleShowEmptyGroups(this)
            controller = this.legacyContextMenuControllerIfPresent();
            val = ~isempty(controller) && controller.HasToggleShowEmptyGroups;
        end

        function set.HasToggleShowEmptyGroups(this, val)
            this.legacyContextMenuController().HasToggleShowEmptyGroups = val;
        end

        function val = get.HasColumnSorting(this)
            controller = this.legacyContextMenuControllerIfPresent();
            val = ~isempty(controller) && controller.HasColumnSorting;
        end

        function set.HasColumnSorting(this, val)
            this.legacyContextMenuController().HasColumnSorting = val;
        end

        function val = get.HasAutoResizeColumns(this)
            controller = this.legacyContextMenuControllerIfPresent();
            val = ~isempty(controller) && controller.HasAutoResizeColumns;
        end

        function set.HasAutoResizeColumns(this, val)
            this.legacyContextMenuController().HasAutoResizeColumns = val;
        end

        function val = get.SupportedSelectionTypes(this)
            controller = this.legacyContextMenuControllerIfPresent();
            if isempty(controller)
                val = "cell";
            else
                val = controller.SupportedSelectionTypes;
            end
        end

        function set.SupportedSelectionTypes(this, val)
            arguments
                this (1,1) gwidgets.Table
                val (1,:) string {mustBeMember(val, ["cell", "row", "column"]), mustBeNonempty} = "cell"
            end

            this.legacyContextMenuController().SupportedSelectionTypes = val;
        end

        function val = get.CustomContextMenuItems(this)
            controller = this.legacyContextMenuControllerIfPresent();
            if isempty(controller)
                val = matlab.ui.container.Menu.empty(1,0);
            else
                val = controller.CustomItems;
            end
        end

        function set.CustomContextMenuItems(this, val)
            this.legacyContextMenuController().CustomItems = val;
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
            val = this.getBridgeDiagEnabled();
        end

        function set.BridgeDiagEnabled(this, val)
            this.setBridgeDiagEnabled(val);
        end
    end

    methods (Static)
        function style = defaultGroupHeaderStyle(style)
            arguments
                style (1,1) matlab.ui.style.Style = matlab.ui.style.Style( ...
                    "BackgroundColor", [0.1 0.1 0.8], ...
                    "FontColor", [0.9 0.9 0.9])
            end

            style = gwidgets.UITable.defaultGroupHeaderStyle(style);
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
