classdef UITable < gwidgets.internal.Reparentable
    %TABLE Custom table with filterable columns

    %% Standard functionality
    % Domain controller facades
    properties (Dependent, SetAccess = private)
        Column (1,1) gwidgets.internal.table.ColumnController
        Group (1,1) gwidgets.internal.table.GroupController
        Sort (1,1) gwidgets.internal.table.SortController
        Style (1,1) gwidgets.internal.table.StyleController
        SelectionControl (1,1) gwidgets.internal.table.SelectionController
    end

    properties (Dependent)
        Data (:,:) table % Underlying data table
        DisplayData (1,1) table % Data as displayed
    end

    properties (Access = private)
        Data_ (:,:) table % Private storage for the data table
        TextColumns (:,:) table % Text columns extracted from data as strings

        UpdateManager (1,:) gwidgets.internal.UpdateManager {mustBeScalarOrEmpty} = gwidgets.internal.UpdateManager() % Suppress update trigger from a property to improve performance

        % Avoid global pause/drawnow flushes while the widget is still
        % being constructed; a single refresh is enough once setup is live.
        SuppressForceRefresh_ (1,1) logical = true

        ColumnApi_ (1,:) gwidgets.internal.table.ColumnController {mustBeScalarOrEmpty}
        GroupApi_ (1,:) gwidgets.internal.table.GroupController {mustBeScalarOrEmpty}
        SortApi_ (1,:) gwidgets.internal.table.SortController {mustBeScalarOrEmpty}
        StyleApi_ (1,:) gwidgets.internal.table.StyleController {mustBeScalarOrEmpty}
        SelectionApi_ (1,:) gwidgets.internal.table.SelectionController {mustBeScalarOrEmpty}
        ContextMenuController_ (1,:) gwidgets.internal.table.ContextMenuController {mustBeScalarOrEmpty}
        DisplayController_ (1,:) gwidgets.internal.table.DisplayController {mustBeScalarOrEmpty}
        BridgeController_ (1,:) gwidgets.internal.table.BridgeController {mustBeScalarOrEmpty}

    end

    % Custom table callbacks
    properties
        CellSelectionCallback function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
        CellClickedCallback function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
        CellDoubleClickCallback function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
        CellEditCallback function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
        DisplayDataChangedCallback function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
    end

    methods
        function this = UITable(namedArgs)
            arguments (Input)
                namedArgs.?gwidgets.UITable
                namedArgs.ShowRowFilter (1,1) logical = false
            end

            this@gwidgets.internal.Reparentable();

            % Enable suppression of updates
            this.UpdateManager = gwidgets.internal.UpdateManager();

            set(this, namedArgs);

            this.SelectionControl.Value = []; % Enforces correct inital selection shape

            % Support creation with filtering and grouping set
            this.doUpdateSequence();

            this.SuppressForceRefresh_ = false;
            if ~isempty(this.Parent)
                this.forceRefresh();
            end
        end

        function delete(this)
            delete(this.ColumnApi_);
            delete(this.GroupApi_);
            delete(this.SortApi_);
            delete(this.StyleApi_);
            delete(this.SelectionApi_);
            delete(this.ContextMenuController_);
            delete(this.DisplayController_);
            delete(this.BridgeController_);
            delete(this.FilterController);
            delete(this.GroupingController_);
            delete(this.SortingController_);
            delete(this.ContextMenu);
        end

        function reset(this)

            data = this.Data_;

            % Clear the state of the table, suppressing update till the end

            % All columns are default visible, suppress update to wait for data
            this.UpdateManager.addSuppression("ColumnVisible", Times=1);
            this.Column.Visible = true;

            % Remove aliases
            this.UpdateManager.addSuppression("ColumnNames", Times=1);
            this.Column.Names = [];
            this.UpdateManager.addSuppression("DataColumnEditable", Times=1);
            this.Column.Editable = [];
            this.UpdateManager.addSuppression("DataColumnSortable", Times=1);
            this.Column.Sortable = [];
            this.UpdateManager.addSuppression("DataColumnWidth", Times=1);
            this.Column.DataWidth = {};

            % Clear the styling
            this.UpdateManager.addSuppression("UpdateStyle", Times=1);
            this.Style.remove();

            % Stash the text columns as a table of strings.
            textColumns = [data(:, vartype("char")), ...
                data(:, vartype("string")), ...
                data(:, vartype("cellstr")), ...
                data(:, vartype("categorical"))];
            textColumns = convertvars(textColumns, ...
                1:width(textColumns), "string");
            this.TextColumns = textColumns;

            % Apply the filter to the new data and clear the selection in case it is out of range
            this.clearSelection();

            if this.UpdateManager.doRun("Reset")
                this.doUpdateSequence();
            end

        end

    end

    methods % Get/Set
        function val = get.Column(this)
            if isempty(this.ColumnApi_) || ~isvalid(this.ColumnApi_)
                this.ColumnApi_ = gwidgets.internal.table.ColumnController(this);
            end
            val = this.ColumnApi_;
        end

        function val = get.Group(this)
            if isempty(this.GroupApi_) || ~isvalid(this.GroupApi_)
                this.GroupApi_ = gwidgets.internal.table.GroupController(this);
            end
            val = this.GroupApi_;
        end

        function val = get.Sort(this)
            if isempty(this.SortApi_) || ~isvalid(this.SortApi_)
                this.SortApi_ = gwidgets.internal.table.SortController(this);
            end
            val = this.SortApi_;
        end

        function val = get.Style(this)
            if isempty(this.StyleApi_) || ~isvalid(this.StyleApi_)
                this.StyleApi_ = gwidgets.internal.table.StyleController(this);
            end
            val = this.StyleApi_;
        end

        function val = get.SelectionControl(this)
            if isempty(this.SelectionApi_) || ~isvalid(this.SelectionApi_)
                this.SelectionApi_ = gwidgets.internal.table.SelectionController(this);
            end
            val = this.SelectionApi_;
        end

        function value = get.Data(this)
            value = this.Data_;
        end

        function set.Data(this, data)
            arguments
                this
                data table
            end

            % Update the internal and display properties.
            this.Data_ = data;

            if this.UpdateManager.doRun("Data")
                try
                    this.doUpdateSequence();
                catch ME
                    % Update failed with new data, e.g. caused by change in
                    % size of table or data types, so reset the table
                    this.reset();
                    warning("GraphicsWidgets:Table:DataUpdateReset", ...
                        "Data update failed; table was reset. Original error: %s", ME.message);
                end
            end
        end

        function val = get.DisplayData(this)
            val = this.DisplayTable.Data;
        end
    end

    methods (Access = {?gwidgets.internal.table.ColumnController, ...
            ?gwidgets.internal.table.SelectionController, ...
            ?gwidgets.internal.table.StyleController, ...
            ?gwidgets.internal.table.GroupController, ...
            ?gwidgets.internal.table.ContextMenuController, ...
            ?gwidgets.internal.table.SortController, ...
            ?gwidgets.internal.table.DisplayController, ...
            ?gwidgets.internal.table.BridgeController})
        function addControllerUpdateSuppression(this, propertyName, nvp)
            arguments
                this (1,1) gwidgets.UITable
                propertyName (1,1) string
                nvp.Times (1,1) double = 1
            end

            this.UpdateManager.addSuppression(propertyName, Times=nvp.Times);
        end

        function tf = doControllerUpdate(this, propertyName)
            arguments
                this (1,1) gwidgets.UITable
                propertyName (1,1) string
            end

            tf = this.UpdateManager.doRun(propertyName);
        end

        function requestControllerUpdate(this, nvp)
            arguments
                this (1,1) gwidgets.UITable
                nvp.StartFrom (1,1) string {mustBeMember(nvp.StartFrom, ["Filtering", "Grouping", "Sorting", "Folding", "Display", "Style", "Interaction", "Skip"])}
            end

            this.doUpdateSequence(StartFrom=nvp.StartFrom);
        end

        function onColumnBridgeReattachNeeded(this)
            this.onBridgeReattachNeeded();
        end

        function val = displaySelectionType(this)
            val = this.DisplayTable.SelectionType;
        end

        function setDisplaySelectionType(this, val)
            this.DisplayTable.SelectionType = val;
        end

        function val = displayMultiselect(this)
            val = this.DisplayTable.Multiselect;
        end

        function setDisplayMultiselect(this, val)
            this.DisplayTable.Multiselect = val;
        end

        function state = selectionMapState(this)
            state = struct( ...
                "FoldedVisibleToDataMap", this.FoldedVisibleToDataMap, ...
                "FoldedDataToVisibleMap", this.FoldedDataToVisibleMap, ...
                "FilteredDataToVisibleMap", this.FilteredDataToVisibleMap, ...
                "VisibleColumnNames", this.Column.VisibleNames, ...
                "VisibleDataColumnNames", this.Column.VisibleDataNames, ...
                "DataColumnNames", this.Column.DataNames, ...
                "GroupingVariable", this.Group.By, ...
                "DataWidth", size(this.Data_, 2));
        end

        function sz = selectionDataSize(this)
            sz = size(this.Data_);
        end

        function sz = selectionVisibleDataSize(this)
            sz = size(this.VisibleData);
        end

        function tf = canApplyDisplaySelection(this)
            tf = ~isempty(this.DisplayTable) && ~isempty(this.FoldedDataToVisibleMap);
        end

        function applyDisplaySelection(this, selection)
            try
                this.DisplayTable.Selection = selection;
            catch
                this.DisplayTable.Selection = [];
            end
        end

        function refreshVisibleSelection(this)
            this.SelectionControl.refresh();
        end

        function displayTable = styleDisplayTable(this)
            displayTable = this.DisplayTable;
        end

        function configs = styleConfigurations(this)
            configs = this.DisplayTable.StyleConfigurations;
        end

        function setStyleConfigurations(this, configs)
            this.DisplayTable.StyleConfigurations = configs;
        end

        function refreshStyleDisplay(this)
            this.forceRefresh();
        end

        function clearGroupSelection(this)
            this.clearSelection();
        end

        function refreshContextMenu(this)
            this.addContextMenu();
        end

        function selectionType = contextSelectionType(this)
            selectionType = this.SelectionControl.Type;
        end

        function setContextSelectionType(this, selectionType)
            this.SelectionControl.Type = selectionType;
        end

        function clearContextSelection(this)
            this.clearSelection();
        end

        function displayTable = displayTableForController(this)
            displayTable = this.DisplayTable;
        end

        function value = displayPropertyValue(this, propertyName)
            arguments
                this (1,1) gwidgets.UITable
                propertyName (1,1) string
            end

            switch propertyName
                case "VisibleData"
                    value = this.VisibleData;
                case "ColumnEditable"
                    value = this.Column.Editable;
                case "ColumnSortable"
                    value = this.Column.Sortable;
                case "SelectionType"
                    value = this.SelectionControl.Type;
                otherwise
                    error("GraphicsWidgets:UITable:DisplayProperty", ...
                        "Unsupported display property: %s", propertyName);
            end
        end

        function state = displayUpdateState(this)
            state = struct( ...
                "VisibleDataColumnNames", this.Column.VisibleDataNames, ...
                "GroupingVariable", this.Group.By, ...
                "VisibleGroupHeaderRowIdx", this.VisibleGroupHeaderRowIdx, ...
                "DataColumnNames", this.Column.DataNames, ...
                "ColumnNames", this.Column.Names);
        end

        function widths = displayColumnWidths(this)
            widths = this.Column.Width;
        end

        function suppressDisplayBridge(this)
            controller = this.bridgeControllerIfPresent();
            if ~isempty(controller)
                controller.suppress();
            end
        end

        function restoreDisplayBridge(this)
            controller = this.bridgeControllerIfPresent();
            if ~isempty(controller)
                controller.restore();
            end
        end

        function refreshDisplayNow(this)
            this.forceRefresh();
        end

        function tf = bridgeHasTooltips(this)
            tf = ~isempty(this.Tooltips);
        end

        function changed = bridgeDidWidthsChange(this, incomingPx)
            changed = this.Column.didBridgeWidthsChange(incomingPx);
        end

        function bridgeUpdateWidthStores(this, pixelWidths)
            this.Column.updateStoresFromBridgeWidths(pixelWidths);
        end

        function bridgeApplyColumnWidth(this)
            this.applyColumnWidthToDisplay();
        end

        function blocks = bridgeTooltipBlocks(this, displayRow, displayColumn)
            controller = this.tooltipController();
            blocks = controller.resolveBlocks(this, displayRow, displayColumn);
        end
    end

    %% Styling
    methods (Static)

        function style = defaultGroupHeaderStyle(s)
            arguments
                s (1,1) matlab.ui.style.Style = matlab.ui.style.Style("BackgroundColor", [0.1 0.1 0.8], "FontColor", [0.9 0.9 0.9]);
            end
            style = gwidgets.internal.table.TableStyle(s, "row", "SelectionMode", "Display", "TargetFunction", @(this) this.VisibleGroupHeaderRowIdx);
        end

    end

    %% Tooltips
    properties (Dependent)
        Tooltip (1,1) string % Table-wide tooltip; pass-through to uitable.Tooltip
        DefaultTooltipStyle (1,1) gwidgets.table.TooltipStyle % Widget-wide fallback style
    end

    properties (Dependent, GetAccess = ?matlab.unittest.TestCase, SetAccess = protected)
        Tooltips (1,:) gwidgets.internal.table.TableTooltip
    end

    properties (Access = protected)
        TooltipController_ (1,:) gwidgets.internal.table.TooltipController {mustBeScalarOrEmpty}
        TableTooltipText_ (1,1) string = ""
        DefaultTooltipStyle_ (1,1) gwidgets.table.TooltipStyle = gwidgets.table.TooltipStyle.default()
    end

    methods
        function addTooltip(this, text, tableTarget, targetIndicesOrFunction, nvp)
            % addTooltip registers a hover-tooltip configuration. Mirrors addStyle.
            %   addTooltip(t, "Click to open", "table")
            %   addTooltip(t, "Patient height (cm)", "column", 4)
            %   addTooltip(t, "Outlier", "cell", [3 2; 5 7])
            %   addTooltip(t, @(ctx) "Value: " + ctx.Value, "column", [2 3])
            %     ^ function form: receives a gwidgets.table.TooltipContext
            %       with fields Value, Row, Column, Table, DisplayRow,
            %       DisplayColumn, DataRow, DataColumn, Target. Row and
            %       Column slices come from the underlying Data table
            %       (hidden columns / filtered-out rows reachable).
            %
            %   Pass ContextShape to control the shape of ctx.Row and
            %   ctx.Column:
            %     "Values" -> vectors
            %     "Table"  -> 1xN / Mx1 tables
            %   Per-target defaults: column=Values, row=Table,
            %   table=Table, cell=Values.
            arguments
                this (1,1) gwidgets.UITable
                text % string scalar OR function_handle (cellValue) -> string
                tableTarget (1,1) string {mustBeMember(tableTarget, ["table", "row", "column", "cell"])} = "table"
                targetIndicesOrFunction (:,:) = []
                nvp.SelectionMode (1,1) gwidgets.table.SelectionMode = gwidgets.table.SelectionMode.Data
                nvp.ContextShape (1,1) string {mustBeMember(nvp.ContextShape, ["Values", "Table"])} = ...
                    gwidgets.internal.table.TableTooltip.defaultContextShape(tableTarget)
                nvp.Style = []
            end

            controller = this.tooltipController();
            didEnableHover = controller.addTooltip( ...
                this, text, tableTarget, targetIndicesOrFunction, ...
                SelectionMode=nvp.SelectionMode, ...
                ContextShape=nvp.ContextShape, ...
                Style=nvp.Style);
            if didEnableHover
                bridgeController = this.bridgeControllerIfPresent();
                if ~isempty(bridgeController)
                    bridgeController.enableHover();
                end
            end
        end

        function removeTooltip(this, orderNum)
            arguments
                this
                orderNum (1,:) double = []
            end

            controller = this.tooltipControllerIfPresent();
            didDisableHover = false;
            if ~isempty(controller)
                didDisableHover = controller.removeTooltip(orderNum);
            end
            if didDisableHover
                bridgeController = this.bridgeControllerIfPresent();
                if ~isempty(bridgeController)
                    bridgeController.disableHover();
                end
            end
        end
    end

    methods % Get/Set Tooltip
        function val = get.Tooltip(this)
            val = this.TableTooltipText_;
        end

        function set.Tooltip(this, val)
            this.TableTooltipText_ = val;
            controller = this.tooltipControllerIfPresent();
            if ~isempty(controller)
                controller.setTooltipText(val);
            end
            if ~isempty(this.DisplayTable)
                this.DisplayTable.Tooltip = val;
            end
        end

        function val = get.DefaultTooltipStyle(this)
            val = this.DefaultTooltipStyle_;
        end

        function set.DefaultTooltipStyle(this, val)
            this.DefaultTooltipStyle_ = val;
            controller = this.tooltipControllerIfPresent();
            if ~isempty(controller)
                controller.setDefaultTooltipStyle(val);
            end
        end

        function val = get.Tooltips(this)
            controller = this.tooltipControllerIfPresent();
            if isempty(controller)
                val = gwidgets.internal.table.TableTooltip.empty(1,0);
            else
                val = controller.Tooltips;
            end
        end
    end

    methods (Access = ?gwidgets.internal.table.TooltipController)
        function tf = bridgeDiagnosticsEnabled(this)
            controller = this.bridgeControllerIfPresent();
            tf = ~isempty(controller) && controller.DiagEnabled;
        end
    end

    %% Filtering
    properties (Dependent)
        Filter
    end

    properties (Dependent)
        ShowRowFilter (1,1) logical
    end

    properties (Access = protected)
        ShowRowFilter_ (1,1) logical = false
    end

    properties (SetAccess = private)
        RowFilterIndices (1,:) logical
    end

    % Filtering
    properties (Access = private)
        FilteringChangedListener (1,:) event.listener {mustBeScalarOrEmpty}
        FilteringHelpListener (1,:) event.listener
        FilteredData (:,:) table

        % Maps after filtering
        FilteredVisibleToDataMap (1,:) double % Mapping from visible rows to data rows
        FilteredDataToVisibleMap (1,:) double % Mapping from data rows to visible rows
    end

    methods

        function expandFilterController(this, value)
            arguments
                this
                value (1,1) logical = true
            end
            this.FilterController.expand(value);
        end

    end

    methods % Get/Set

        function val = get.Filter(this)
            val = this.FilterController.FilterValue;
        end

        function set.Filter(this, val)
            this.FilterController.FilterValue = val;

            if this.UpdateManager.doRun("Filter")
                this.doUpdateSequence(StartFrom="Filtering");
            end
        end

        function val = get.ShowRowFilter(this)
            val = this.ShowRowFilter_;
        end

        function set.ShowRowFilter(this, state)
            arguments
                this (1,1) gwidgets.UITable
                state (1,1) logical
            end

            this.ShowRowFilter_ = state;
            if state
                this.Grid.RowHeight{1} = "fit";
            else
                this.Grid.RowHeight{1} = 0;
            end

        end

    end

    %% Grouping
    properties (Hidden)
        VisibleGroupHeaderRowIdx (1,:) double % (1,nVisGroups) Indices of header rows
        
    end

    properties (Access = private)
        GroupColumnIdx (1,:) double = []
        GroupIdxs (1,:) double = []

        % Raw grouping
        GroupedVisibleData (:,:) cell % Headers and data before sorting
        GroupedDataVariables  (1,:) string % Table variable names after grouping
        GroupHeaderRowIdx (1,:) double % (1,nGroups) Indices of group header rows

        GroupFilteredCount (1,:) double % (1,nGroups) Group filtered counts
        
        % Sorted group values, to converted to DisplayGroupVariable once any are hidden
        SortedGroupValues (1,:) string

        % Maps after grouping
        GroupedVisibleToDataMap (1,:) double % Mapping from visible rows to data rows
        GroupedDataToVisibleMap (1,:) double % Mapping from data rows to visible rows

        % Maps after folding - note, sorting comes before folding for
        % performance reasons
        FoldedVisibleToDataMap (1,:) double % Mapping from visible rows to data rows
        FoldedDataToVisibleMap (1,:) double % Mapping from data rows to visible rows

        GroupingController_ (1,:) gwidgets.internal.table.GroupingController {mustBeScalarOrEmpty}
    end

    %% Sorting
    properties (GetAccess = ?matlab.unittest.TestCase, SetAccess = private)
        SortedVisibleData (:,:) cell % Headers and data after sorting
        SortedGroupHeaderRowIdx (1,:) double % (1,nGroups) Indices of group header rows after sorting

        % Maps after sorting
        SortedVisibleToDataMap (1,:) double % Mapping from visible rows to data rows
        SortedDataToVisibleMap (1,:) double % Mapping from data rows to visible rows
    end

    properties (Access = private)
        SortingController_ (1,:) gwidgets.internal.table.SortingController {mustBeScalarOrEmpty}
    end

    methods (Access = protected)

        function updateSorting(this)
            arguments
                this (1,1) gwidgets.UITable
            end

            this.SortedVisibleData = this.GroupedVisibleData;
            this.SortedDataToVisibleMap = this.GroupedDataToVisibleMap;
            this.SortedVisibleToDataMap = this.GroupedVisibleToDataMap;
            this.SortedGroupHeaderRowIdx = this.GroupHeaderRowIdx;
            this.SortedGroupValues = this.Group.Groups;

            if this.Sort.Direction == "None" || isempty(this.Sort.ByData)
                return
            end

            controller = this.sortingController();
            result = controller.sort(this.FilteredData, this.Data_, this.GroupedVisibleData, ...
                this.GroupedDataVariables, this.Group.By, this.Group.Groups, this.GroupHeaderRowIdx, ...
                this.GroupedVisibleToDataMap, this.GroupedDataToVisibleMap, this.Column.DataSortable, ...
                this.Sort.ByData, this.Sort.Direction);

            this.SortedVisibleData = result.SortedVisibleData;
            this.SortedDataToVisibleMap = result.SortedDataToVisibleMap;
            this.SortedVisibleToDataMap = result.SortedVisibleToDataMap;
            this.SortedGroupHeaderRowIdx = result.SortedGroupHeaderRowIdx;
            this.SortedGroupValues = result.SortedGroupValues;
        end

    end

    %% Find
    methods
        function result = find(this, str, target)
            arguments
                this (1,1)
                str (1,1) string
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])} = "table"
            end

            [~, ~, ~, s] = gwidgets.internal.FilterController.filterIndices(str, this.Data_);

            result = cell(1, numel(s));
            for i = 1:numel(s)

                thisCol = find(s(i).ColumnIdx);
                rowIdxs = find(s(i).RowIdx);

                idxs = [rowIdxs, repelem(thisCol, numel(rowIdxs), 1)];
                result{i} = idxs;
            end

            result = vertcat(result{:});
            if isempty(result)
                result = double.empty(0,2);
            end

            switch target
                case "table"
                    result = any(result);
                case "row"
                    result = unique(result(:,1));
                case "column"
                    result = unique(result(:,2));
            end
        end
    end

    %% Graphics components
    properties (GetAccess = ?matlab.unittest.TestCase, ...
            SetAccess = private)
        Grid (1,:) matlab.ui.container.GridLayout {mustBeScalarOrEmpty}
        FilterController (1,:) gwidgets.internal.FilterController {mustBeScalarOrEmpty}

        GroupLabel (1,:) matlab.ui.control.Label {mustBeScalarOrEmpty}
        DisplayTable (1,:) matlab.ui.control.Table {mustBeScalarOrEmpty}

        HelpPanel (1,:) matlab.ui.container.Panel {mustBeScalarOrEmpty}
    end

    properties (SetAccess = private)
        VisibleData (:,:) table % Data after grouping and filtering
    end

    %% Private methods
    % From matlab.ui.componentcontainer.ComponentContainer
    methods (Access = protected)
        function setup(this)
            %SETUP Initialize the component's graphics.

            this.Grid = uigridlayout(this, ...
                "RowHeight", {"fit", 0, "1x", 2}, "ColumnWidth", {"1x", 0}, "Padding", 0);

            this.HelpPanel = uipanel(Parent=this.Grid);
            this.HelpPanel.Layout.Column = 2;
            this.HelpPanel.Layout.Row = [1 3];

            this.FilterController = gwidgets.internal.FilterController(...
                Parent=this.Grid,HelpParent=uigridlayout(this.HelpPanel, [1,1], "Padding",0));
            this.FilterController.Layout.Column = 1;
            this.FilterController.Layout.Row = 1;

            this.FilteringChangedListener = ...
                this.weaklistener(this.FilterController, "FilterChanged");
            this.FilteringHelpListener = ...
                this.weaklistener(this.FilterController, "FilterHelpRequested");
            this.FilteringHelpListener(end+1) = ...
                this.weaklistener(this.FilterController, "FilterHelpClosed");

            % Create the table to display the filtered and grouped data
            this.GroupLabel = uilabel("Parent", this.Grid);
            this.GroupLabel.Layout.Column = 1;
            this.GroupLabel.Layout.Row = 2;

            this.DisplayTable = uitable(this.Grid);
            this.DisplayTable.ClickedFcn = @(s,e)this.onCellClicked(s,e);
            this.DisplayTable.DoubleClickedFcn = @(s,e)this.onCellDoubleClicked(s,e);
            this.DisplayTable.CellSelectionCallback = @(s,e)this.onSelection(s,e);
            this.DisplayTable.CellEditCallback = @(s,e)this.onCellEdit(s,e);
            this.DisplayTable.DisplayDataChangedFcn = @(s,e)this.onDisplayDataChanged(s,e);
            this.DisplayTable.Layout.Column = 1;
            this.DisplayTable.Layout.Row = 3;

            this.addContextMenu();
            this.setupTableBridge();
            this.doUpdateSequence();

            % Apply any tooltip state that was configured before setup ran.
            % The bridge will enable hover reports once it signals BridgeReady,
            this.DisplayTable.Tooltip = this.TableTooltipText_;
        end

        function updateDisplayData(this)
            this.displayController().updateData();
        end

        function updateInteraction(this)
            this.displayController().updateInteraction();
        end

        function applyColumnWidthToDisplay(this)
            this.displayController().applyColumnWidth();

        end

    end

    % From gwidgets.internal.Reparentable
    methods (Access = protected)

        function reactToFigureChanged(this)
            this.reparentContextMenu();
        end

    end

    % Table bridge — column-width tracking + cell-hover detection
    methods (Access = private)

        function setupTableBridge(this)
            this.bridgeController().setup(this.Grid, this.DisplayTable);
        end

        function onBridgeReattachNeeded(this)
            % Column count mismatch — tell bridge to re-attach to current DOM.
            controller = this.bridgeControllerIfPresent();
            if ~isempty(controller)
                controller.reattach();
            end
        end

    end

    % Test hooks — accessible to matlab.unittest.TestCase but not public API
    methods (Access = ?matlab.unittest.TestCase)

        function simulateBridgeDrag(this, pixelWidths)
            % Simulate a ColumnWidthChanged notification from the bridge
            % without requiring a live DOM/figure.
            % pixelWidths: positive pixel widths for all visible columns.
            this.Column.updateStoresFromBridgeWidths(pixelWidths);
            this.applyColumnWidthToDisplay();
        end

        function [text, style] = simulateBridgeHover(this, displayRow, displayColumn)
            % Simulate a CellHover notification from the bridge without
            % requiring a live DOM/figure. Returns the resolved tooltip
            % text (and resolved TooltipStyle) that would be displayed.
            controller = this.tooltipController();
            [text, style] = controller.resolveTextAndStyle(this, displayRow, displayColumn);
            this.applyTooltipPayload(displayRow, displayColumn);
        end

        function blocks = simulateTooltipBlocks(this, displayRow, displayColumn)
            % Resolve a hovered cell to the same block payload that would
            % be sent to the HTML bridge.
            controller = this.tooltipController();
            blocks = controller.resolveBlocks(this, displayRow, displayColumn);
        end

        function tf = hasTooltipController(this)
            tf = ~isempty(this.TooltipController_) && isvalid(this.TooltipController_);
        end

        function tf = hasGroupingController(this)
            tf = ~isempty(this.GroupingController_) && isvalid(this.GroupingController_);
        end

        function tf = hasSortingController(this)
            tf = ~isempty(this.SortingController_) && isvalid(this.SortingController_);
        end

        function changed = didBridgeWidthsChange(this, incomingPx)
            changed = this.Column.didBridgeWidthsChange(incomingPx);
        end

    end

    % Selection manipulation
    methods (Access = protected)

        function clearSelection(this)
            this.SelectionControl.clear();
        end

        function dataIdxs = displaySelectionToDataSelection(this, visibleIdxs, type)
            % displaySelectionToDataSelection Maps display selection to
            %   data selection
            arguments
                this
                visibleIdxs
                type (1,1) string {mustBeMember(type, ["cell", "row", "column"])} = this.SelectionControl.Type
            end
            if isempty(visibleIdxs)
                dataIdxs = visibleIdxs;
                return
            end

            dataIdxs = this.SelectionControl.displayToData(visibleIdxs, type);
        end

        function visibleIdxs = dataSelectionToDisplaySelection(this, dataIdxs, type)
            % dataSelectionToDisplaySelection Maps data selection to
            %   display selection
            arguments
                this
                dataIdxs
                type (1,1) string {mustBeMember(type, ["cell", "row", "column", "table"])} = this.SelectionControl.Type
            end

            if isempty(dataIdxs)
                visibleIdxs = dataIdxs;
                return
            end

            visibleIdxs = this.SelectionControl.dataToDisplay(dataIdxs, type);
        end

    end

    % Graphical update
    methods (Access = protected)

        function update(~)
            % We do all the updating manually
        end

        function doUpdateSequence(this, nvp)
            arguments
                this
                nvp.StartFrom (1,1) string {mustBeMember(nvp.StartFrom, ["Filtering", "Grouping", "Sorting", "Folding", "Display", "Style", "Interaction", "Skip"])} = "Filtering"
            end

            updating = false;
            if nvp.StartFrom == "Filtering" || updating
                this.updateFiltering();
                updating = true;
            end

            if nvp.StartFrom == "Grouping" || updating
                this.updateGrouping();
                updating = true;
            end

            if nvp.StartFrom == "Sorting" || updating
                this.updateSorting();
                updating = true;
            end

            if nvp.StartFrom == "Folding" || updating
                this.updateFolding();
                updating = true;
            end

            if nvp.StartFrom == "Display" || updating
                this.updateDisplayData();
                updating = true;
            end

            if nvp.StartFrom == "Style" || updating
                this.updateStyle();
                updating = true;
            end

            if nvp.StartFrom == "Interaction" || updating
                this.updateInteraction();
            end

            this.forceRefresh();
        end

        function addContextMenu(this)
            controller = this.contextMenuControllerIfPresent();
            if isempty(controller)
                return
            end

            this.ContextMenu = controller.buildForTable( ...
                this.DisplayTable, this.ContextMenu, this.Column.Sortable, this.contextMenuCallbacks());
        end

        function reparentContextMenu(this)
            gwidgets.internal.table.ContextMenuController.reparent(this.ContextMenu, this);
        end

        function callbacks = contextMenuCallbacks(this)
            callbacks = struct( ...
                "Group", @(s,e)this.onGroupByRequest(s,e), ...
                "Ungroup", @(s,e)this.onUngroupByRequest(s,e), ...
                "ToggleShowEmptyGroups", @(s,e)this.onToggleShowEmptyGroupsRequest(s,e), ...
                "SortAscend", @(s,e)this.onSortByRequest(s,e, "Ascend"), ...
                "SortDescend", @(s,e)this.onSortByRequest(s,e, "Descend"), ...
                "SortNone", @(s,e)this.onSortByRequest(s,e, "None"), ...
                "CellSelection", @(s,e)this.onCellSelectionRequest(s,e), ...
                "RowSelection", @(s,e)this.onRowSelectionRequest(s,e), ...
                "ColumnSelection", @(s,e)this.onColumnSelectionRequest(s,e), ...
                "ToggleRowFilter", @(s,e)this.onToggleRowFilterRequest(s,e), ...
                "AutoResizeColumns", @(s,e)this.onAutoResizeColumnsRequest(s,e));
        end

        function updateGroupLabel(this)

            nGroups = numel(this.Group.Groups);
            nGroupsVisible = numel(this.VisibleGroupHeaderRowIdx);

            % Replace each grouping variable name with its alias, then join
            groupingVariableName = strjoin(this.Column.dataToAliases(this.Group.By), "|");
            if isempty(groupingVariableName)
                groupingVariableName = "";
            end

            if nGroups == nGroupsVisible
                this.GroupLabel.Text = "Group: " + groupingVariableName + " (" + nGroups + " groups)";
            else
                this.GroupLabel.Text = "Group: " + groupingVariableName + " (" + nGroupsVisible + "/" + nGroups + " groups visible)";
            end

            if groupingVariableName == ""
                this.Grid.RowHeight{2} = 0;
            else
                this.Grid.RowHeight{2} = "fit";
            end
        end

        function forceRefresh(this)
            % Force a refresh
            if this.SuppressForceRefresh_
                return
            end
            gwidgets.internal.Drawnow.runWithPause("limitrate");
        end
    end

    % Filtering update
    methods (Access = protected)

        function updateFiltering(this)

            data = this.Data_;

            % Filter based on aliases - lengths can be assumed to be
            % correct due to set methods
            if ~isempty(this.Column.Names)
                data.Properties.VariableNames = this.Column.Names;
            end
            [data, idx] = this.FilterController.applyFilter(data, this.Filter);

            % Underlying data should use actual data names
            data.Properties.VariableNames = this.Column.DataNames;

            % Keep track of the mapping to simplify selection mappings
            this.FilteredVisibleToDataMap = find(idx);
            tmp = cumsum(idx);
            tmp(~idx) = NaN;
            this.FilteredDataToVisibleMap = tmp;

            this.FilteredData = data;
            this.RowFilterIndices = idx;

        end

    end

    % Grouping update
    methods (Access = protected)

        function updateGrouping(this)
            if isempty(this.Group.By)
                this.GroupedVisibleData = table2cell(this.FilteredData);
                this.GroupedDataVariables = string(this.FilteredData.Properties.VariableNames);
                this.Group.clearGroupingState();
                this.GroupHeaderRowIdx = zeros(1,0);
                this.GroupColumnIdx = zeros(1,0);
                this.GroupFilteredCount = zeros(1,0);
                this.GroupIdxs = zeros(1,0);

                this.GroupedDataToVisibleMap = this.FilteredDataToVisibleMap;
                this.GroupedVisibleToDataMap = this.FilteredVisibleToDataMap;
                return
            end

            controller = this.groupingController();
            result = controller.group(this.Data_, this.FilteredData, this.FilteredDataToVisibleMap, ...
                this.FilteredVisibleToDataMap, this.Group.By, this.Group.RawOpen, this.Group.Hidden);

            this.GroupedVisibleData = result.GroupedVisibleData;
            this.GroupedDataVariables = result.GroupedDataVariables;
            this.Group.applyGroupingResult(result);
            this.GroupHeaderRowIdx = result.GroupHeaderRowIdx;
            this.GroupColumnIdx = result.GroupColumnIdx;
            this.GroupFilteredCount = result.GroupFilteredCount;
            this.GroupIdxs = result.GroupIdxs;
            this.GroupedDataToVisibleMap = result.GroupedDataToVisibleMap;
            this.GroupedVisibleToDataMap = result.GroupedVisibleToDataMap;

        end

        function updateFolding(this)

            if isempty(this.Group.By)
                this.Group.clearDisplayGroups();
                this.FoldedVisibleToDataMap = this.SortedVisibleToDataMap;
                this.FoldedDataToVisibleMap = this.SortedDataToVisibleMap;
                this.VisibleGroupHeaderRowIdx = zeros(1,0);
                this.VisibleData = cell2table(this.SortedVisibleData, ...
                    VariableNames=string(this.Data_.Properties.VariableNames));
                this.updateGroupLabel();
                return
            end

            controller = this.groupingController();
            result = controller.fold(this.SortedVisibleData, this.SortedGroupHeaderRowIdx, ...
                this.SortedGroupValues, this.SortedVisibleToDataMap, this.SortedDataToVisibleMap, ...
                this.GroupFilteredCount, this.Group.By, this.Group.Groups, this.Group.Open, ...
                this.Group.ShowEmpty, string(this.Data_.Properties.VariableNames));

            this.VisibleData = result.VisibleData;
            this.UpdateManager.addSuppression("HiddenGroups", Times=1);
            this.Group.applyFoldingResult(result);
            this.VisibleGroupHeaderRowIdx = result.VisibleGroupHeaderRowIdx;
            this.FoldedVisibleToDataMap = result.FoldedVisibleToDataMap;
            this.FoldedDataToVisibleMap = result.FoldedDataToVisibleMap;

            this.updateGroupLabel();

        end

    end

    % Style updates
    methods (Access = protected)

        function updateStyle(this)
            this.Style.applyToDisplay();
        end

    end

    % Internal callbacks
    methods (Access = private)

        function onCellClicked_(this, displayIdx)
            arguments
                this (1,1)
                displayIdx (:,2) double % onCellClicked always sends row/col
            end

            % Deal with the group table
            rowIdxs = unique(displayIdx(:,1));
            this.toggleGroupOpenStateViaRowSelection(rowIdxs);
        end

        function onCellDoubleClicked_(this, displayIdx)
            arguments
                this (1,1) %#ok<INUSA>
                displayIdx (:,2) double %#ok<INUSA> % onCellClicked always sends row/col
            end
            % Nothing to do - yet
        end


        function toggleGroupOpenStateViaRowSelection(this, rowIdx)
            idxHeader = this.VisibleGroupHeaderRowIdx;
            idxHeader = (idxHeader == rowIdx);
            if any(idxHeader)
                group = this.Group.DisplayGroups(idxHeader);
                if ismember(group, this.Group.Open)
                    this.Group.Open(this.Group.Open == group) = [];
                else
                    this.Group.Open = [this.Group.Open, group];
                end
            end
        end

        function controller = displayController(this)
            if isempty(this.DisplayController_) || ~isvalid(this.DisplayController_)
                this.DisplayController_ = gwidgets.internal.table.DisplayController(this);
            end
            controller = this.DisplayController_;
        end

        function controller = bridgeController(this)
            if isempty(this.BridgeController_) || ~isvalid(this.BridgeController_)
                this.BridgeController_ = gwidgets.internal.table.BridgeController(this);
            end
            controller = this.BridgeController_;
        end

        function controller = bridgeControllerIfPresent(this)
            if isempty(this.BridgeController_) || ~isvalid(this.BridgeController_)
                controller = gwidgets.internal.table.BridgeController.empty(1,0);
            else
                controller = this.BridgeController_;
            end
        end

        function controller = contextMenuController(this)
            if isempty(this.ContextMenuController_) || ~isvalid(this.ContextMenuController_)
                this.ContextMenuController_ = gwidgets.internal.table.ContextMenuController(this);
            end
            controller = this.ContextMenuController_;
        end

        function controller = contextMenuControllerIfPresent(this)
            if isempty(this.ContextMenuController_) || ~isvalid(this.ContextMenuController_)
                controller = gwidgets.internal.table.ContextMenuController.empty(1,0);
            else
                controller = this.ContextMenuController_;
            end
        end

        function controller = groupingController(this)
            if isempty(this.GroupingController_) || ~isvalid(this.GroupingController_)
                this.GroupingController_ = gwidgets.internal.table.GroupingController();
            end
            controller = this.GroupingController_;
        end

        function controller = sortingController(this)
            if isempty(this.SortingController_) || ~isvalid(this.SortingController_)
                this.SortingController_ = gwidgets.internal.table.SortingController();
            end
            controller = this.SortingController_;
        end

        function applyTooltipPayload(this, displayRow, displayColumn)
            this.bridgeController().applyTooltipPayload(displayRow, displayColumn);
        end

        function controller = tooltipController(this)
            if isempty(this.TooltipController_) || ~isvalid(this.TooltipController_)
                this.TooltipController_ = gwidgets.internal.table.TooltipController( ...
                    TooltipText=this.TableTooltipText_, ...
                    DefaultTooltipStyle=this.DefaultTooltipStyle_);
            end
            controller = this.TooltipController_;
        end

        function controller = tooltipControllerIfPresent(this)
            controller = this.TooltipController_;
            if ~isempty(controller) && ~isvalid(controller)
                this.TooltipController_ = gwidgets.internal.table.TooltipController.empty(1,0);
                controller = this.TooltipController_;
            end
        end

        function onSelection_(this, displayIdx, selectionType)
            arguments
                this (1,1)
                displayIdx (:,2) % onSelection always sends row/col
                selectionType (1,1) string = this.SelectionControl.Type
            end

            [displayIdx, shouldContinue] = this.SelectionControl.onDisplaySelection(displayIdx, selectionType);
            if ~shouldContinue
                return
            end

            % Enable/disable the categories button.
            % Selection itself done via get/set methods on underlying table
            if isempty(displayIdx)
                showCats = false;
            else
                switch selectionType
                    case "cell"
                        colIdx = unique(displayIdx(:, 2));
                    case "column"
                        colIdx = displayIdx;
                    case "row"
                        colIdx = [];
                end

                if ~isscalar(colIdx)
                    % No cats shown on multiple columns selected
                    showCats = false;
                else
                    c = this.DisplayTable.Data{:, colIdx};
                    showCats = iscategorical(c);
                end
            end

            if showCats
                this.FilterController.CategoricalVariables = categories(c);
            else
                this.FilterController.CategoricalVariables = [];
            end

        end

        function onCellEdit_(this, displayIdx, value)
            arguments
                this (1,1)
                displayIdx (:,2) % onCellEdit always sends row/col
                value
            end

            dataIdx = this.displaySelectionToDataSelection(displayIdx, "cell");
            this.Data_{dataIdx(1), dataIdx(2)} = value;

            if this.UpdateManager.doRun("Filter")
                this.doUpdateSequence(StartFrom="Filtering");
            end

        end

    end

    methods (Access = protected)
        function setConstructionRefreshSuppressed(this, state)
            this.SuppressForceRefresh_ = state;
        end

        function controller = legacyContextMenuController(this)
            controller = this.contextMenuController();
        end

        function controller = legacyContextMenuControllerIfPresent(this)
            controller = this.contextMenuControllerIfPresent();
        end

        function setBridgeDiagEnabled(this, val)
            this.bridgeController().DiagEnabled = val;
        end

        function val = getBridgeDiagEnabled(this)
            val = this.bridgeController().DiagEnabled;
        end
    end

    methods (Access = {?gwidgets.internal.WithWeakListeners})

        function onFilterChanged(this, ~, ~)
            if this.UpdateManager.doRun("Filter")
                this.doUpdateSequence(StartFrom="Filtering");
            end
        end

        function onFilterHelpRequested(this, ~, ~)
            this.Grid.ColumnWidth = {"1x", "1x"};
        end

        function onFilterHelpClosed(this, ~, ~)
            this.Grid.ColumnWidth = {"1x", 0};
        end

    end

    methods (Access = {?matlab.unittest.TestCase, ?gwidgets.UITable})

        function onCellClicked(this, ~, e)
            % Do internal cell clicked action
            rowIdx = e.InteractionInformation.DisplayRow';
            colIdx = e.InteractionInformation.DisplayColumn';

            if ~isempty(rowIdx) % Row index is empty if column is clicked
                displayIdx = [rowIdx, colIdx];
                this.onCellClicked_(displayIdx);
            else
                displayIdx = zeros(0,2);
            end

            % Forward to user specified cell clicked function
            if ~isempty(this.CellClickedCallback)
                dataIdx = this.displaySelectionToDataSelection(displayIdx);
                e = gwidgets.internal.table.CellInteractionData(dataIdx, displayIdx);
                s = this;
                this.CellClickedCallback(s, e);
            end

        end

        function onCellDoubleClicked(this, ~, e)

            % Do internal cell clicked action
            rowIdx = e.InteractionInformation.DisplayRow';
            colIdx = e.InteractionInformation.DisplayColumn';

            if ~isempty(rowIdx) % Row index is empty if column is clicked
                displayIdx = [rowIdx, colIdx];
                this.onCellDoubleClicked_(displayIdx);
            else
                displayIdx = zeros(0,2);
            end

            % Forward to user specified cell clicked function
            if ~isempty(this.CellDoubleClickCallback)
                dataIdx = this.displaySelectionToDataSelection(displayIdx);
                e = gwidgets.internal.table.CellInteractionData(dataIdx, displayIdx);
                s = this;
                this.CellDoubleClickCallback(s, e);
            end

        end

        function onSelection(this, s, e)
            % Do internal selection action
            displayIdx = e.Indices;
            this.onSelection_(displayIdx, s.SelectionType);

            % Forward to custom selection callback
            if ~isempty(this.CellSelectionCallback)
                dataIdx = this.displaySelectionToDataSelection(displayIdx, "cell"); % Cell interaction always expectes two columns
                e = gwidgets.internal.table.CellInteractionData(dataIdx, displayIdx);
                s = this;
                this.CellSelectionCallback(s, e);
            end

        end

        function onCellEdit(this, ~, e)

            % Do internal cell edit
            displayIdx = e.Indices;
            this.onCellEdit_(displayIdx, e.NewData);

            % Forward to custom cell edit callback
            if ~isempty(this.CellEditCallback)
                dataIdx = this.displaySelectionToDataSelection(displayIdx, "cell");
                editData = gwidgets.internal.table.CellEditData(e, dataIdx);
                s = this;
                this.CellEditCallback(s, editData);
            end

        end

        function onDisplayDataChanged(this, s, e)

            if e.Interaction == "sort"

                newSortColumn = e.InteractionVariable;
                currentSortColumn = this.Sort.By;

                this.UpdateManager.addSuppression("SortDirection", Times=1);
                if newSortColumn == currentSortColumn
                    if this.Sort.Direction == "None"
                        this.Sort.Direction = "Ascend";
                    elseif this.Sort.Direction == "Ascend"
                        this.Sort.Direction = "Descend";
                    else
                        this.Sort.Direction = "None";
                    end
                else
                    this.Sort.Direction = "Ascend";
                end

                this.Sort.By = e.InteractionVariable;
            end

            % Forward to custom cell edit callback
            if ~isempty(this.DisplayDataChangedCallback)
                this.DisplayDataChangedCallback(s, e);
            end

        end

        function onUngroupByRequest(this, ~, ~)
            this.clearSelection();
            this.Group.By = string.empty(1,0);
        end

        function onGroupByRequest(this, ~, e)

            if ~isempty(this.SelectionControl.DisplayValue)
                if this.SelectionControl.Type == "cell"
                    columnIdx = unique(this.SelectionControl.DisplayValue(:, 2));
                elseif this.SelectionControl.Type == "column"
                    columnIdx = this.SelectionControl.DisplayValue;
                else
                    columnIdx = e.InteractionInformation.DisplayColumn;
                end
            else
                columnIdx = e.InteractionInformation.DisplayColumn;
            end

            % Convert from alias back to underlying data for grouping
            % TODO: Make util for this
            groupingVariable = string(this.DisplayTable.Data.Properties.VariableNames(columnIdx));
            groupingVariable = this.Column.aliasesToData(groupingVariable);
            groupingVariable(~ismember(groupingVariable, this.Column.DataNames)) = [];

            if isempty(groupingVariable)
                groupingVariable = string.empty(1,0);
            end

            this.clearSelection();
            try
                this.Group.By = groupingVariable;
            catch me
                this.Group.By = string.empty(1,0);
            end
        end

    end

    % Context menu callbacks
    methods (Access = private)

        function onCellSelectionRequest(this, ~, ~)
            this.SelectionControl.Type = "cell";
            this.clearSelection();
        end

        function onRowSelectionRequest(this, ~, ~)
            this.SelectionControl.Type = "row";
            this.clearSelection();
        end

        function onColumnSelectionRequest(this, ~, ~)
            this.SelectionControl.Type = "column";
            this.clearSelection();
        end

        function onAutoResizeColumnsRequest(this, ~, ~)
            % Reset to DefaultColumnWidths if set, otherwise clear to auto.
            this.Column.Width = {};
        end

        function onToggleRowFilterRequest(this, ~, ~)
            this.ShowRowFilter = ~this.ShowRowFilter;
        end

        function onToggleShowEmptyGroupsRequest(this, ~, ~)
            this.Group.ShowEmpty = ~this.Group.ShowEmpty;
        end

        function onSortByRequest(this, ~, e, direction)

            this.UpdateManager.addSuppression("SortDirection", Times=1);
            this.Sort.Direction = direction;

            if ismember(e.InteractionInformation.DisplayRow, this.VisibleGroupHeaderRowIdx)
                % Sort groups by sorting on group row
                % TODO: Sort groups and columns
                vars = this.Group.By;
            else

                if this.SelectionControl.Type == "cell"
                    colIdx = unique(this.SelectionControl.DisplayValue(:,2));
                elseif this.SelectionControl.Type == "column"
                    colIdx = unique(this.SelectionControl.DisplayValue);
                else
                    % Allow sorting by at least one column when using row
                    % selection
                    colIdx = e.InteractionInformation.DisplayColumn;
                end

                vars = this.GroupedDataVariables(colIdx);

            end

            this.Sort.By = vars;

        end

    end

end


