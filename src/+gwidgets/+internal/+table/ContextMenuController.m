classdef ContextMenuController < gwidgets.internal.table.TableController
    % ContextMenuController owns table context-menu state and construction.

    properties (Dependent)
        CustomItems
        SupportedSelectionTypes
        HasToggleFilter
        HasChangeGroupingVariable
        HasToggleShowEmptyGroups
        HasColumnSorting
        HasAutoResizeColumns
        HasToggleDragging
    end

    properties (Access = private)
        CustomItems_ (1,:) matlab.ui.container.Menu = matlab.ui.container.Menu.empty(1,0)
        SupportedSelectionTypes_ (1,:) string {mustBeMember(SupportedSelectionTypes_, ["cell", "row", "column"])} = "cell"
        HasToggleFilter_ (1,1) logical = false
        HasChangeGroupingVariable_ (1,1) logical = false
        HasToggleShowEmptyGroups_ (1,1) logical = false
        HasColumnSorting_ (1,1) logical = false
        HasAutoResizeColumns_ (1,1) logical = false
        HasToggleDragging_ (1,1) logical = false
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
            owner.ContextMenu = this.buildForTable( ...
                owner.Graphics.DisplayTable, owner.ContextMenu, owner.Column.Sortable);
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
                "HasColumnSorting", this.HasColumnSorting_, ...
                "ColumnSortable", columnSortable, ...
                "SupportedSelectionTypes", this.SupportedSelectionTypes_, ...
                "HasToggleFilter", this.HasToggleFilter_, ...
                "HasAutoResizeColumns", this.HasAutoResizeColumns_, ...
                "HasToggleDragging", this.HasToggleDragging_, ...
                "DragEnabled", this.owner().Drag.Enabled);
        end

        function callbacks = callbacks(this)
            owner = this.owner();
            callbacks = struct( ...
                "Group", @(~,e)owner.Group.requestGroupBy(e.InteractionInformation.DisplayColumn), ...
                "Ungroup", @(~,~)owner.Group.requestUngroup(), ...
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
                "ToggleDragging", @(~,~)this.toggleDragging());
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
                uimenu("Parent", m, "Text", "Group", ...
                    "MenuSelectedFcn", callbacks.Group, ...
                    "Tag", "graphicscomponentsTableContextMenu");
                uimenu("Parent", m, "Text", "Ungroup", ...
                    "MenuSelectedFcn", callbacks.Ungroup, ...
                    "Tag", "graphicscomponentsTableContextMenu");
            end
            if options.HasToggleShowEmptyGroups
                uimenu("Parent", m, "Text", "Show/hide empty groups", ...
                    "MenuSelectedFcn", callbacks.ToggleShowEmptyGroups, ...
                    "Tag", "graphicscomponentsTableContextMenu");
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
    end

end

