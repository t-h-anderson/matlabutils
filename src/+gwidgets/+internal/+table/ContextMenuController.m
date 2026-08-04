classdef ContextMenuController < gwidgets.internal.table.TableController
    % ContextMenuController owns table context-menu state and construction.

    properties (Dependent)
        CustomItems
        SupportedSelectionTypes
        HasToggleFilter
        HasChangeGroupingVariable
        HasToggleShowEmptyGroups
        HasChangeDisplayOrientation
        HasColumnSorting
        HasAutoResizeColumns
        HasToggleDragging
        HasToggleGroupHeaderTooltips
        HasToggleTableMetrics
    end

    properties (Access = private)
        CustomItems_ (1,:) matlab.ui.container.Menu = matlab.ui.container.Menu.empty(1,0)
        SupportedSelectionTypes_ (1,:) string { ...
            mustBeMember(SupportedSelectionTypes_, ["cell", "row", "column"])} = "cell"
        HasToggleFilter_ (1,1) logical = false
        HasChangeGroupingVariable_ (1,1) logical = false
        HasToggleShowEmptyGroups_ (1,1) logical = false
        HasChangeDisplayOrientation_ (1,1) logical = false
        HasColumnSorting_ (1,1) logical = false
        HasAutoResizeColumns_ (1,1) logical = true
        HasToggleDragging_ (1,1) logical = false
        HasToggleGroupHeaderTooltips_ (1,1) logical = false
        HasToggleTableMetrics_ (1,1) logical = false
    end

    methods
        function this = ContextMenuController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
        end

        function delete(this)
            delete(this.CustomItems_);
        end

        function addItem(this, menuItems)
            arguments
                this (1,1) gwidgets.internal.table.ContextMenuController
                menuItems (1,:) matlab.ui.container.Menu
            end

            this.CustomItems = [this.CustomItems_, menuItems];
        end

        function initialize(this)
            arguments
                this (1,1) gwidgets.internal.table.ContextMenuController
            end

            this.refresh();
        end

        function refresh(this)
            arguments
                this (1,1) gwidgets.internal.table.ContextMenuController
            end

            owner = this.owner();
            contextMenu = owner.Graphics.buildContextMenus( ...
                owner.ContextMenu, this.CustomItems_, this.options(owner.Column.Sortable), this.callbacks());
            gwidgets.internal.table.ContextMenuController.reparent(contextMenu, owner);
            owner.ContextMenu = contextMenu;
        end

        function reparentToOwner(this)
            arguments
                this (1,1) gwidgets.internal.table.ContextMenuController
            end

            owner = this.owner();
            gwidgets.internal.table.ContextMenuController.reparent(owner.ContextMenu, owner);
        end

        function contextMenu = buildForTable(this, displayTable, contextMenu, columnSortable)
            arguments
                this (1,1) gwidgets.internal.table.ContextMenuController
                displayTable (1,:) matlab.ui.control.Table
                contextMenu
                columnSortable (1,:) logical
            end

            contextMenu = gwidgets.internal.table.ContextMenuController.build( ...
                displayTable, contextMenu, this.CustomItems_, this.options(columnSortable), this.callbacks());
        end

        function val = get.CustomItems(this)
            val = this.CustomItems_;
        end

        function set.CustomItems(this, val)
            arguments
                this (1,1) gwidgets.internal.table.ContextMenuController
                val (1,:) matlab.ui.container.Menu
            end

            this.CustomItems_ = val;
            this.refresh();
        end

        function val = get.SupportedSelectionTypes(this)
            val = this.SupportedSelectionTypes_;
        end

        function set.SupportedSelectionTypes(this, val)
            arguments
                this (1,1) gwidgets.internal.table.ContextMenuController
                val (1,:) string {mustBeMember(val, ["cell", "row", "column"]), mustBeNonempty} = "cell"
            end

            this.SupportedSelectionTypes_ = val;

            owner = this.owner();
            if ~ismember(owner.Selection.Type, val)
                owner.Selection.clear();
                owner.Selection.Type = val(1);
            end

            this.refresh();
        end

        function val = get.HasToggleFilter(this)
            val = this.HasToggleFilter_;
        end

        function set.HasToggleFilter(this, val)
            this.HasToggleFilter_ = val;
            this.refresh();
        end

        function val = get.HasChangeGroupingVariable(this)
            val = this.HasChangeGroupingVariable_;
        end

        function set.HasChangeGroupingVariable(this, val)
            this.HasChangeGroupingVariable_ = val;
            this.refresh();
        end

        function val = get.HasToggleShowEmptyGroups(this)
            val = this.HasToggleShowEmptyGroups_;
        end

        function set.HasToggleShowEmptyGroups(this, val)
            this.HasToggleShowEmptyGroups_ = val;
            this.refresh();
        end

        function val = get.HasChangeDisplayOrientation(this)
            val = this.HasChangeDisplayOrientation_;
        end

        function set.HasChangeDisplayOrientation(this, val)
            this.HasChangeDisplayOrientation_ = val;
            this.refresh();
        end

        function val = get.HasColumnSorting(this)
            val = this.HasColumnSorting_;
        end

        function set.HasColumnSorting(this, val)
            this.HasColumnSorting_ = val;
            this.refresh();
        end

        function val = get.HasAutoResizeColumns(this)
            val = this.HasAutoResizeColumns_;
        end

        function set.HasAutoResizeColumns(this, val)
            this.HasAutoResizeColumns_ = val;
            this.refresh();
        end

        function val = get.HasToggleDragging(this)
            val = this.HasToggleDragging_;
        end

        function set.HasToggleDragging(this, val)
            this.HasToggleDragging_ = val;
            this.refresh();
        end

        function val = get.HasToggleGroupHeaderTooltips(this)
            val = this.HasToggleGroupHeaderTooltips_;
        end

        function set.HasToggleGroupHeaderTooltips(this, val)
            this.HasToggleGroupHeaderTooltips_ = val;
            this.refresh();
        end

        function val = get.HasToggleTableMetrics(this)
            val = this.HasToggleTableMetrics_;
        end

        function set.HasToggleTableMetrics(this, val)
            this.HasToggleTableMetrics_ = val;
            this.refresh();
        end
    end

    methods (Access = private)
        function options = options(this, columnSortable)
            arguments
                this (1,1) gwidgets.internal.table.ContextMenuController
                columnSortable (1,:) logical
            end

            options = struct( ...
                "HasChangeGroupingVariable", this.HasChangeGroupingVariable_, ...
                "HasToggleShowEmptyGroups", this.HasToggleShowEmptyGroups_, ...
                "HasChangeDisplayOrientation", this.HasChangeDisplayOrientation_, ...
                "HasColumnSorting", this.HasColumnSorting_, ...
                "ColumnSortable", columnSortable, ...
                "SupportedSelectionTypes", this.SupportedSelectionTypes_, ...
                "HasToggleFilter", this.HasToggleFilter_, ...
                "HasAutoResizeColumns", this.HasAutoResizeColumns_, ...
                "HasToggleDragging", this.HasToggleDragging_, ...
                "HasToggleGroupHeaderTooltips", this.HasToggleGroupHeaderTooltips_, ...
                "HasToggleTableMetrics", this.HasToggleTableMetrics_, ...
                "DragEnabled", this.owner().Drag.Enabled, ...
                "ShowGroupHeaderTooltips", this.owner().ShowGroupHeaderTooltips, ...
                "ShowMetrics", this.owner().ShowMetrics, ...
                "DisplayOrientation", this.owner().Display.Orientation, ...
                "GroupingMode", this.owner().Group.Mode, ...
                "GroupingVariables", this.owner().Group.By, ...
                "GroupingVariableNames", this.owner().Column.dataToAliases(this.owner().Group.By), ...
                "DataVariables", this.owner().Column.DataNames, ...
                "DataVariableNames", this.owner().Column.dataToAliases(this.owner().Column.DataNames), ...
                "SelectedGroupingVariables", this.selectedGroupingVariables(), ...
                "SelectedGroupingVariableNames", this.owner().Column.dataToAliases(this.selectedGroupingVariables()));
        end

        function callbacks = callbacks(this)
            owner = this.owner();
            callbacks = struct( ...
                "Group", @(~,e)owner.Group.requestGroupBy(e.InteractionInformation.DisplayColumn), ...
                "AddGroup", @(~,e)owner.Group.requestAddGroupBy(e.InteractionInformation.DisplayColumn), ...
                "SetGroups", @(groupingVariables)owner.Group.replaceBy(groupingVariables), ...
                "AddGroups", @(groupingVariables)owner.Group.addBy(groupingVariables), ...
                "RemoveGroup", @(groupingVariable)owner.Group.requestRemoveGroupBy(groupingVariable), ...
                "RemoveGroups", @(groupingVariables)owner.Group.removeBy(groupingVariables), ...
                "Ungroup", @(~,~)owner.Group.requestUngroup(), ...
                "ToggleGroupingMode", @(~,~)owner.Group.requestToggleMode(), ...
                "ToggleShowEmptyGroups", @(~,~)owner.Group.requestToggleShowEmpty(), ...
                "SortAscend", @(~,e)owner.Sort.requestSortByContext( ...
                    e.InteractionInformation.DisplayRow, e.InteractionInformation.DisplayColumn, "Ascend"), ...
                "SortDescend", @(~,e)owner.Sort.requestSortByContext( ...
                    e.InteractionInformation.DisplayRow, e.InteractionInformation.DisplayColumn, "Descend"), ...
                "SortNone", @(~,e)owner.Sort.requestSortByContext( ...
                    e.InteractionInformation.DisplayRow, e.InteractionInformation.DisplayColumn, "None"), ...
                "CellSelection", @(~,~)owner.Selection.requestCellSelection(), ...
                "RowSelection", @(~,~)owner.Selection.requestRowSelection(), ...
                "ColumnSelection", @(~,~)owner.Selection.requestColumnSelection(), ...
                "ToggleRowFilter", @(~,~)this.toggleRowFilter(), ...
                "AutoResizeColumns", @(~,~)owner.Column.requestAutoResize(), ...
                "ToggleDragging", @(~,~)this.toggleDragging(), ...
                "ToggleGroupHeaderTooltips", @(~,~)this.toggleGroupHeaderTooltips(), ...
                "ToggleTableMetrics", @(~,~)this.toggleTableMetrics(), ...
                "ToggleDisplayOrientation", @(~,~)this.toggleDisplayOrientation());
        end

        function toggleRowFilter(this)
            owner = this.owner();
            owner.ShowRowFilter = ~owner.ShowRowFilter;
        end

        function toggleDragging(this)
            owner = this.owner();
            owner.Drag.Enabled = ~owner.Drag.Enabled;
            this.refresh();
        end

        function toggleGroupHeaderTooltips(this)
            owner = this.owner();
            owner.ShowGroupHeaderTooltips = ~owner.ShowGroupHeaderTooltips;
        end

        function toggleTableMetrics(this)
            owner = this.owner();
            owner.ShowMetrics = ~owner.ShowMetrics;
        end

        function toggleDisplayOrientation(this)
            owner = this.owner();
            if owner.Display.Orientation == "Normal"
                owner.Display.Orientation = "Transposed";
            else
                owner.Display.Orientation = "Normal";
            end
            this.refresh();
        end

        function groupingVariables = selectedGroupingVariables(this)
            owner = this.owner();
            selection = owner.Selection;
            groupingVariables = string.empty(1,0);
            if isempty(selection.DisplayValue)
                return
            end

            switch selection.Type
                case "cell"
                    displayColumns = unique(selection.DisplayValue(:, 2));
                case "column"
                    displayColumns = unique(selection.DisplayValue);
                otherwise
                    return
            end

            names = string(owner.Data.Display.Properties.VariableNames);
            displayColumns(displayColumns < 1 | displayColumns > numel(names)) = [];
            if isempty(displayColumns)
                return
            end

            groupingVariables = owner.Column.aliasesToData(names(displayColumns));
            groupingVariables(~ismember(groupingVariables, owner.Column.DataNames)) = [];
            groupingVariables = unique(groupingVariables, "stable");
        end
    end

    methods (Static)
        function contextMenu = build(displayTable, contextMenu, customItems, options, callbacks)
            arguments
                displayTable (1,:) matlab.ui.control.Table
                contextMenu
                customItems (1,:) matlab.ui.container.Menu
                options (1,1) struct
                callbacks (1,1) struct
            end

            if isempty(displayTable)
                return
            end

            if ~isempty(customItems)
                [customItems.Parent] = deal([]);
                [customItems.Tag] = deal("graphicscomponentsTableContextMenu");
            end

            if ~isempty(contextMenu) && isvalid(contextMenu)
                delete(contextMenu);
            end

            fh = ancestor(displayTable, "figure");
            contextMenu = uicontextmenu("Parent", fh, "Tag", "graphicscomponentsTableContextMenu");

            gwidgets.internal.table.ContextMenuController.addGroupingMenu(contextMenu, options, callbacks);
            gwidgets.internal.table.ContextMenuController.addSortMenu(contextMenu, options, callbacks);
            gwidgets.internal.table.ContextMenuController.addSelectionMenu(contextMenu, options, callbacks);
            gwidgets.internal.table.ContextMenuController.addToggleMenus(contextMenu, options, callbacks);

            for iItem = 1:numel(customItems)
                customItems(iItem).Parent = contextMenu;
            end

            displayTable.ContextMenu = contextMenu;
        end

        function reparent(contextMenu, owner)
            arguments
                contextMenu
                owner (1,1) matlab.ui.componentcontainer.ComponentContainer
            end

            if isempty(contextMenu) || ~isvalid(contextMenu)
                return
            end

            fh = ancestor(owner, "figure");
            contextMenu.Parent = fh;
        end
    end

    methods (Static, Access = private)
        function addGroupingMenu(contextMenu, options, callbacks)
            if ~(options.HasChangeGroupingVariable || options.HasToggleShowEmptyGroups)
                return
            end

            m = uimenu("Parent", contextMenu, "Text", "Grouping", "Tag", "graphicscomponentsTableContextMenu");
            if options.HasChangeGroupingVariable
                gwidgets.internal.table.ContextMenuController.addSetGroupingMenu(m, options, callbacks);
                gwidgets.internal.table.ContextMenuController.addAddGroupingMenu(m, options, callbacks);
                gwidgets.internal.table.ContextMenuController.addRemoveGroupingMenu(m, options, callbacks);
                modeText = "Use nested groups";
                if options.GroupingMode == "Nested"
                    modeText = "Use flat groups";
                end
                uimenu("Parent", m, "Text", modeText, ...
                    "MenuSelectedFcn", callbacks.ToggleGroupingMode, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end
            if options.HasToggleShowEmptyGroups
                uimenu("Parent", m, "Text", "Show/hide empty groups", ...
                    "MenuSelectedFcn", callbacks.ToggleShowEmptyGroups, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end
        end

        function addSetGroupingMenu(parent, options, callbacks)
            m = uimenu("Parent", parent, "Text", "Set", "Tag", "graphicscomponentsTableContextMenu");
            gwidgets.internal.table.ContextMenuController.addVariableActions( ...
                m, ...
                options.DataVariables, ...
                options.DataVariableNames, ...
                options.SelectedGroupingVariables, ...
                options.SelectedGroupingVariableNames, ...
                @(vars)callbacks.SetGroups(vars));
        end

        function addAddGroupingMenu(parent, options, callbacks)
            m = uimenu("Parent", parent, "Text", "Add", "Tag", "graphicscomponentsTableContextMenu");
            gwidgets.internal.table.ContextMenuController.addVariableActions( ...
                m, ...
                options.DataVariables, ...
                options.DataVariableNames, ...
                options.SelectedGroupingVariables, ...
                options.SelectedGroupingVariableNames, ...
                @(vars)callbacks.AddGroups(vars));
        end

        function addRemoveGroupingMenu(parent, options, callbacks)
            m = uimenu("Parent", parent, "Text", "Remove", "Tag", "graphicscomponentsTableContextMenu");
            selectedVariables = options.SelectedGroupingVariables( ...
                ismember(options.SelectedGroupingVariables, options.GroupingVariables));
            selectedNames = options.SelectedGroupingVariableNames( ...
                ismember(options.SelectedGroupingVariables, options.GroupingVariables));

            gwidgets.internal.table.ContextMenuController.addVariableActions( ...
                m, ...
                options.GroupingVariables, ...
                options.GroupingVariableNames, ...
                selectedVariables, ...
                selectedNames, ...
                @(vars)callbacks.RemoveGroups(vars), ...
                AllText="All");
        end

        function addVariableActions(parent, variables, names, selectedVariables, selectedNames, callback, nvp)
            arguments
                parent (1,1) matlab.ui.container.Menu
                variables (1,:) string
                names (1,:) string
                selectedVariables (1,:) string
                selectedNames (1,:) string
                callback (1,1) function_handle
                nvp.AllText (1,1) string = "All"
            end

            uimenu("Parent", parent, "Text", nvp.AllText, ...
                "MenuSelectedFcn", @(~,~)callback(variables), ...
                "Tag", "graphicscomponentsTableContextMenu");

            enableSelected = "off";
            if ~isempty(selectedVariables)
                enableSelected = "on";
            end
            uimenu("Parent", parent, ...
                "Text", gwidgets.internal.table.ContextMenuController.selectedActionText(selectedNames), ...
                "Enable", enableSelected, ...
                "MenuSelectedFcn", @(~,~)callback(selectedVariables), ...
                "Tag", "graphicscomponentsTableContextMenu");

            for iVariable = 1:numel(variables)
                variable = variables(iVariable);
                name = names(iVariable);
                uimenu("Parent", parent, "Text", name, ...
                    "MenuSelectedFcn", @(~,~)callback(variable), ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end
        end

        function text = selectedActionText(selectedNames)
            arguments
                selectedNames (1,:) string
            end

            text = "Selected";
            if ~isempty(selectedNames)
                text = "Selected (" + strjoin(selectedNames, ", ") + ")";
            end
        end

        function addSortMenu(contextMenu, options, callbacks)
            if ~(options.HasColumnSorting && any(options.ColumnSortable))
                return
            end

            m = uimenu("Parent", contextMenu, "Text", "Sort", "Tag", "graphicscomponentsTableContextMenu");
            uimenu("Parent", m, "Text", "Ascending", ...
                "MenuSelectedFcn", callbacks.SortAscend, ...
                "Tag", "graphicscomponentsTableContextMenu");
            uimenu("Parent", m, "Text", "Descending", ...
                "MenuSelectedFcn", callbacks.SortDescend, ...
                "Tag", "graphicscomponentsTableContextMenu");
            uimenu("Parent", m, "Text", "None", ...
                "MenuSelectedFcn", callbacks.SortNone, ...
                "Tag", "graphicscomponentsTableContextMenu");
        end

        function addSelectionMenu(contextMenu, options, callbacks)
            if numel(options.SupportedSelectionTypes) <= 1
                return
            end

            m = uimenu("Parent", contextMenu, "Text", "Selection Mode", ...
                "Tag", "graphicscomponentsTableContextMenu");
            if any(options.SupportedSelectionTypes == "cell")
                uimenu("Parent", m, "Text", "Cell", ...
                    "MenuSelectedFcn", callbacks.CellSelection, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end
            if any(options.SupportedSelectionTypes == "row")
                uimenu("Parent", m, "Text", "Row", ...
                    "MenuSelectedFcn", callbacks.RowSelection, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end
            if any(options.SupportedSelectionTypes == "column")
                uimenu("Parent", m, "Text", "Column", ...
                    "MenuSelectedFcn", callbacks.ColumnSelection, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end
        end

        function addToggleMenus(contextMenu, options, callbacks)
            if options.HasToggleFilter
                uimenu("Parent", contextMenu, "Text", "Show/hide row filter", ...
                    "MenuSelectedFcn", callbacks.ToggleRowFilter, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end

            if options.HasChangeDisplayOrientation
                uimenu("Parent", contextMenu, "Text", ...
                    gwidgets.internal.table.ContextMenuController.displayOrientationMenuText(options), ...
                    "MenuSelectedFcn", callbacks.ToggleDisplayOrientation, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end

            if options.HasToggleGroupHeaderTooltips
                uimenu("Parent", contextMenu, "Text", ...
                    gwidgets.internal.table.ContextMenuController.groupHeaderTooltipMenuText(options), ...
                    "MenuSelectedFcn", callbacks.ToggleGroupHeaderTooltips, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end

            if options.HasToggleTableMetrics
                uimenu("Parent", contextMenu, "Text", ...
                    gwidgets.internal.table.ContextMenuController.tableMetricsMenuText(options), ...
                    "MenuSelectedFcn", callbacks.ToggleTableMetrics, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end

            if options.HasAutoResizeColumns
                uimenu("Parent", contextMenu, "Text", "Auto-resize columns", ...
                    "MenuSelectedFcn", callbacks.AutoResizeColumns, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end

            if options.HasToggleDragging
                menuText = "Enable row dragging";
                if options.DragEnabled
                    menuText = "Disable row dragging";
                end
                uimenu("Parent", contextMenu, "Text", menuText, ...
                    "MenuSelectedFcn", callbacks.ToggleDragging, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end
        end

        function text = displayOrientationMenuText(options)
            arguments
                options (1,1) struct
            end

            text = "Transpose table";
            if options.DisplayOrientation == "Transposed"
                text = "Untranspose table";
            end
        end

        function text = groupHeaderTooltipMenuText(options)
            arguments
                options (1,1) struct
            end

            text = "Show group header tooltips";
            if options.ShowGroupHeaderTooltips
                text = "Hide group header tooltips";
            end
        end

        function text = tableMetricsMenuText(options)
            arguments
                options (1,1) struct
            end

            text = "Show table metrics";
            if options.ShowMetrics
                text = "Hide table metrics";
            end
        end
    end

end

