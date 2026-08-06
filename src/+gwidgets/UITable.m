classdef UITable < gwidgets.internal.Reparentable
    %TABLE Custom table with filterable columns

    %% Standard functionality
    properties (Dependent, SetAccess = private)
        Column (1,1) gwidgets.internal.table.ColumnController
        Group (1,1) gwidgets.internal.table.GroupController
        Sort (1,1) gwidgets.internal.table.SortController
        Style (1,1) gwidgets.internal.table.StyleController
        Data (1,1) gwidgets.internal.table.DataController
        Filter (1,1) gwidgets.internal.table.FilterController
        Graphics (1,1) gwidgets.internal.table.GraphicsController
        Menu (1,1) gwidgets.internal.table.ContextMenuController
        Tooltip (1,1) gwidgets.internal.table.TooltipController
        Metric (1,1) gwidgets.internal.table.MetricController
        Callback (1,1) gwidgets.internal.table.CallbackController
        Selection (1,1) gwidgets.internal.table.SelectionController
        Drag (1,1) gwidgets.internal.table.DragController
        Display (1,1) gwidgets.internal.table.DisplayController
        Render (1,1) string
    end

    properties (SetAccess = private)
        Backend (1,1) string {mustBeMember(Backend, ["UITable", "JavaScript"])} = "UITable"
    end

    events
        CellClicked
        CellDoubleClicked
        SelectionChanged
        CellEditRequested
        CellEdited
        DisplayDataChangeRequested
        DisplayDataChanged
        FilterChangeRequested
        FilterChanged
        GroupingChangeRequested
        GroupingChanged
        GroupOpenStateChanged
        SortChangeRequested
        SortChanged
        TooltipRequested
        TooltipCleared
        DragStarted
        DropRequested
        DropCompleted
        CommandInvoked
        TableDataChanged
    end

    properties (Dependent, Access = private)
        Update (1,1) gwidgets.internal.table.UpdateController
    end

    properties (Dependent, GetAccess = {?gwidgets.Table, ...
            ?gwidgets.internal.table.ColumnController, ...
            ?gwidgets.internal.table.SelectionController, ...
            ?gwidgets.internal.table.StyleController, ...
            ?gwidgets.internal.table.GroupController, ...
            ?gwidgets.internal.table.ContextMenuController, ...
            ?gwidgets.internal.table.SortController, ...
            ?gwidgets.internal.table.DisplayController, ...
            ?gwidgets.internal.table.DataController, ...
            ?gwidgets.internal.table.FilterController, ...
            ?gwidgets.internal.table.GraphicsController, ...
            ?gwidgets.internal.table.UpdateController, ...
            ?gwidgets.internal.table.CallbackController, ...
            ?gwidgets.internal.table.BridgeController, ...
            ?gwidgets.internal.table.DragController, ...
            ?gwidgets.internal.table.MetricController, ...
            ?gwidgets.internal.table.TooltipController, ...
            ?gwidgets.internal.table.backend.JSTableBackend}, ...
            SetAccess = private)
        Bridge (1,1) gwidgets.internal.table.BridgeController
    end

    properties (Access = private)
        % Avoid global pause/drawnow flushes while the widget is still
        % being constructed; a single refresh is enough once setup is live.
        SuppressForceRefresh_ (1,1) logical = true

        ColumnApi_ (1,:) gwidgets.internal.table.ColumnController {mustBeScalarOrEmpty}
        GroupApi_ (1,:) gwidgets.internal.table.GroupController {mustBeScalarOrEmpty}
        SortApi_ (1,:) gwidgets.internal.table.SortController {mustBeScalarOrEmpty}
        StyleApi_ (1,:) gwidgets.internal.table.StyleController {mustBeScalarOrEmpty}
        DataApi_ (1,:) gwidgets.internal.table.DataController {mustBeScalarOrEmpty}
        FilterApi_ (1,:) gwidgets.internal.table.FilterController {mustBeScalarOrEmpty}
        GraphicsApi_ (1,:) gwidgets.internal.table.GraphicsController {mustBeScalarOrEmpty}
        UpdateController_ (1,:) gwidgets.internal.table.UpdateController {mustBeScalarOrEmpty}
        TooltipController_ (1,:) gwidgets.internal.table.TooltipController {mustBeScalarOrEmpty}
        MetricApi_ (1,:) gwidgets.internal.table.MetricController {mustBeScalarOrEmpty}
        CallbackApi_ (1,:) gwidgets.internal.table.CallbackController {mustBeScalarOrEmpty}
        SelectionApi_ (1,:) gwidgets.internal.table.SelectionController {mustBeScalarOrEmpty}
        DragApi_ (1,:) gwidgets.internal.table.DragController {mustBeScalarOrEmpty}
        MenuApi_ (1,:) gwidgets.internal.table.ContextMenuController {mustBeScalarOrEmpty}
        DisplayApi_ (1,:) gwidgets.internal.table.DisplayController {mustBeScalarOrEmpty}
        BridgeApi_ (1,:) gwidgets.internal.table.BridgeController {mustBeScalarOrEmpty}
        Controllers_ (1,:) cell = cell.empty(1,0)
    end

    methods
        function this = UITable(namedArgs)
            arguments (Input)
                namedArgs.?gwidgets.UITable
                namedArgs.Data (:,:) table = table.empty(0,0)
                namedArgs.ShowRowFilter (1,1) logical = false
                namedArgs.Backend (1,1) string = "<default>"
                namedArgs.Render (1,1) string = "<default>"
            end

            this@gwidgets.internal.Reparentable();

            this.Backend = gwidgets.UITable.resolveRenderName(namedArgs.Backend, namedArgs.Render);
            namedArgs = rmfield(namedArgs, "Backend");
            namedArgs = rmfield(namedArgs, "Render");

            this.createControllers(this.Backend);

            data = namedArgs.Data;
            namedArgs = rmfield(namedArgs, "Data");

            this.Data.Table = data;
            set(this, namedArgs);

            this.Selection.Value = []; % Enforces correct inital selection shape

            % Support creation with filtering and grouping set
            this.Update.run();

            this.SuppressForceRefresh_ = false;
            if ~isempty(this.Parent)
                this.forceRefresh();
            end
        end

        function delete(this)
            this.deleteControllers();
            delete(this.ContextMenu);
        end

        function reset(this)

            data = this.Data.Table;

            % Clear the state of the table, suppressing update till the end

            % All columns are default visible, suppress update to wait for data
            this.Update.addSuppression("ColumnVisible", Times=1);
            this.Column.Visible = true;

            % Remove aliases
            this.Update.addSuppression("ColumnNames", Times=1);
            this.Column.Names = [];
            this.Update.addSuppression("DataColumnEditable", Times=1);
            this.Column.Editable = [];
            this.Update.addSuppression("DataColumnSortable", Times=1);
            this.Column.Sortable = [];
            this.Update.addSuppression("DataColumnWidth", Times=5);
            this.Column.DataWidth = {};
            this.Column.DataMinWidth = [];
            this.Column.DataMaxWidth = [];
            this.Column.TableMinWidth = NaN;
            this.Column.TableMaxWidth = Inf;

            % Clear the styling
            this.Update.addSuppression("UpdateStyle", Times=1);
            this.Style.remove();

            % Stash the text columns as a table of strings.
            textColumns = [data(:, vartype("char")), ...
                data(:, vartype("string")), ...
                data(:, vartype("cellstr")), ...
                data(:, vartype("categorical"))];
            textColumns = convertvars(textColumns, ...
                1:width(textColumns), "string");
            this.Data.TextColumns = textColumns;

            % Apply the filter to the new data and clear the selection in case it is out of range
            this.Selection.clear();

            if this.Update.doRun("Reset")
                this.Update.run();
            end

        end

    end

    methods % Get/Set
        function val = get.Column(this)
            val = this.ColumnApi_;
        end

        function val = get.Group(this)
            val = this.GroupApi_;
        end

        function val = get.Sort(this)
            val = this.SortApi_;
        end

        function val = get.Style(this)
            val = this.StyleApi_;
        end

        function val = get.Data(this)
            val = this.DataApi_;
        end

        function val = get.Menu(this)
            val = this.MenuApi_;
        end

        function val = get.Filter(this)
            val = this.FilterApi_;
        end

        function val = get.Graphics(this)
            val = this.GraphicsApi_;
        end

        function val = get.Update(this)
            val = this.UpdateController_;
        end

        function val = get.Display(this)
            val = this.DisplayApi_;
        end

        function val = get.Render(this)
            val = this.Backend;
        end

        function val = get.Bridge(this)
            val = this.BridgeApi_;
        end

        function val = get.Tooltip(this)
            val = this.TooltipController_;
        end

        function val = get.Metric(this)
            val = this.MetricApi_;
        end

        function val = get.Callback(this)
            val = this.CallbackApi_;
        end

        function val = get.Selection(this)
            val = this.SelectionApi_;
        end

        function val = get.Drag(this)
            val = this.DragApi_;
        end

    end

    methods (Access = {?gwidgets.internal.table.ColumnController, ...
            ?gwidgets.Table, ...
            ?gwidgets.internal.table.SelectionController, ...
            ?gwidgets.internal.table.StyleController, ...
            ?gwidgets.internal.table.GroupController, ...
            ?gwidgets.internal.table.ContextMenuController, ...
            ?gwidgets.internal.table.SortController, ...
            ?gwidgets.internal.table.DisplayController, ...
            ?gwidgets.internal.table.DataController, ...
            ?gwidgets.internal.table.FilterController, ...
            ?gwidgets.internal.table.GraphicsController, ...
            ?gwidgets.internal.table.UpdateController, ...
            ?gwidgets.internal.table.CallbackController, ...
            ?gwidgets.internal.table.BridgeController, ...
            ?gwidgets.internal.table.DragController, ...
            ?gwidgets.internal.table.MetricController, ...
            ?gwidgets.internal.table.TooltipController, ...
            ?gwidgets.internal.table.backend.JSTableBackend})
        function addControllerUpdateSuppression(this, propertyName, nvp)
            arguments
                this (1,1) gwidgets.UITable
                propertyName (1,1) string
                nvp.Times (1,1) double = 1
            end

            this.Update.addSuppression(propertyName, Times=nvp.Times);
        end

        function tf = doControllerUpdate(this, propertyName)
            arguments
                this (1,1) gwidgets.UITable
                propertyName (1,1) string
            end

            tf = this.Update.doRun(propertyName);
        end

        function requestControllerUpdate(this, nvp)
            arguments
                this (1,1) gwidgets.UITable
                nvp.StartFrom (1,1) string {mustBeMember(nvp.StartFrom, ["Filtering", "Grouping", "Sorting", "Folding", "Display", "Style", "Interaction", "Skip"])}
            end

            this.Update.request(StartFrom=nvp.StartFrom);
        end

        function forceRefresh(this)
            % Force a refresh
            if this.SuppressForceRefresh_ || ~gwidgets.internal.Drawnow.isEnabled()
                return
            end
            gwidgets.internal.Drawnow.run("limitrate");
        end

        function eventData = emitTableEvent(this, eventName, eventData)
            arguments
                this (1,1) gwidgets.UITable
                eventName (1,1) string
                eventData (1,1) gwidgets.table.TableEventData = gwidgets.table.TableEventData()
            end

            if ~any(eventName == gwidgets.Table.tableEventNames())
                error("GraphicsWidgets:Table:EventName", ...
                    "Unsupported table event: %s", eventName);
            end

            if eventData.Backend == ""
                eventData.Backend = this.Backend;
            end

            notify(this, char(eventName), eventData);
        end

        function dataIdx = eventDisplayToData(this, displayIdx, type)
            arguments
                this (1,1) gwidgets.UITable
                displayIdx
                type (1,1) string {mustBeMember(type, ["cell", "row", "column"])} = "cell"
            end

            try
                dataIdx = this.Selection.displayToData(displayIdx, type);
            catch
                dataIdx = gwidgets.internal.table.SelectionController.emptySelection(type);
            end
        end

        function snapshot = eventSnapshot(this)
            arguments
                this (1,1) gwidgets.UITable
            end

            snapshot = struct( ...
                "Filter", this.Filter.FilterValue, ...
                "RowFilterIndices", reshape(this.Data.RowFilterIndices, 1, []), ...
                "GroupingVariables", reshape(this.Group.By, 1, []), ...
                "Groups", reshape(this.Group.Groups, 1, []), ...
                "OpenGroups", reshape(this.Group.Open, 1, []), ...
                "ClosedGroups", reshape(this.Group.Closed, 1, []), ...
                "HiddenGroups", reshape(this.Group.Hidden, 1, []), ...
                "SortBy", reshape(this.Sort.By, 1, []), ...
                "SortDirection", this.Sort.Direction);
        end

        function emitStateChangeEvents(this, beforeState)
            arguments
                this (1,1) gwidgets.UITable
                beforeState (1,1) struct
            end

            afterState = this.eventSnapshot();
            if ~isequal(beforeState.Filter, afterState.Filter) || ...
                    ~isequal(beforeState.RowFilterIndices, afterState.RowFilterIndices)
                this.emitTableEvent("FilterChanged", gwidgets.table.TableEventData( ...
                    Action="changed", ...
                    Filter=afterState.Filter, ...
                    PreviousFilter=beforeState.Filter, ...
                    RowFilterIndices=afterState.RowFilterIndices));
            end

            if ~isequal(beforeState.GroupingVariables, afterState.GroupingVariables) || ...
                    ~isequal(beforeState.Groups, afterState.Groups) || ...
                    ~isequal(beforeState.HiddenGroups, afterState.HiddenGroups)
                this.emitTableEvent("GroupingChanged", gwidgets.table.TableEventData( ...
                    Action="changed", ...
                    GroupingVariables=afterState.GroupingVariables, ...
                    PreviousGroupingVariables=beforeState.GroupingVariables, ...
                    Groups=afterState.Groups, ...
                    OpenGroups=afterState.OpenGroups, ...
                    ClosedGroups=afterState.ClosedGroups, ...
                    HiddenGroups=afterState.HiddenGroups));
            end

            if ~isequal(beforeState.OpenGroups, afterState.OpenGroups) || ...
                    ~isequal(beforeState.ClosedGroups, afterState.ClosedGroups)
                this.emitTableEvent("GroupOpenStateChanged", gwidgets.table.TableEventData( ...
                    Action="changed", ...
                    GroupingVariables=afterState.GroupingVariables, ...
                    Groups=afterState.Groups, ...
                    OpenGroups=afterState.OpenGroups, ...
                    ClosedGroups=afterState.ClosedGroups, ...
                    HiddenGroups=afterState.HiddenGroups));
            end

            if ~isequal(beforeState.SortBy, afterState.SortBy) || ...
                    ~isequal(beforeState.SortDirection, afterState.SortDirection)
                this.emitTableEvent("SortChanged", gwidgets.table.TableEventData( ...
                    Action="changed", ...
                    SortBy=afterState.SortBy, ...
                    SortDirection=afterState.SortDirection));
            end
        end

    end

    %% Filtering
    properties (Dependent)
        ShowRowFilter (1,1) logical
        ShowGroupHeaderTooltips (1,1) logical
        ShowMetrics (1,1) logical
        MetricLocation (1,1) string
        MetricDefinitions (1,:) gwidgets.table.MetricDefinition
    end

    properties (Access = protected)
        ShowRowFilter_ (1,1) logical = false
        ShowGroupHeaderTooltips_ (1,1) logical = true
    end

    methods

        function expandFilter(this, value)
            arguments
                this
                value (1,1) logical = true
            end
            this.Filter.expand(value);
        end

    end

    methods % Get/Set

        function val = get.ShowRowFilter(this)
            val = this.ShowRowFilter_;
        end

        function set.ShowRowFilter(this, state)
            arguments
                this (1,1) gwidgets.UITable
                state (1,1) logical
            end

            this.ShowRowFilter_ = state;
            this.Graphics.setRowFilterVisible(state);

        end

        function val = get.ShowGroupHeaderTooltips(this)
            val = this.ShowGroupHeaderTooltips_;
        end

        function set.ShowGroupHeaderTooltips(this, state)
            arguments
                this (1,1) gwidgets.UITable
                state (1,1) logical
            end

            if this.ShowGroupHeaderTooltips_ == state
                return
            end

            this.ShowGroupHeaderTooltips_ = state;
            this.refreshGroupHeaderTooltips();
        end

        function val = get.ShowMetrics(this)
            val = this.Metric.Enabled;
        end

        function set.ShowMetrics(this, val)
            this.Metric.Enabled = val;
        end

        function val = get.MetricLocation(this)
            val = this.Metric.Location;
        end

        function set.MetricLocation(this, val)
            this.Metric.Location = val;
        end

        function val = get.MetricDefinitions(this)
            val = this.Metric.Definitions;
        end

        function set.MetricDefinitions(this, val)
            this.Metric.Definitions = val;
        end

    end

    %% Find
    methods
        function result = find(this, str, target)
            arguments
                this (1,1) gwidgets.UITable
                str (1,1) string
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])} = "table"
            end

            result = this.Data.find(str, target);
        end
    end

    %% Private methods
    % From matlab.ui.componentcontainer.ComponentContainer
    methods (Access = protected)
        function setup(this)
            %SETUP Initialize the component's graphics.
            this.createSetupControllers(this.Backend);
            this.Graphics.setup(this);
        end

    end

    % From gwidgets.internal.Reparentable
    methods (Access = protected)

        function reactToFigureChanged(this)
            this.Menu.reparentToOwner();
        end

    end

    % Graphical update
    methods (Access = protected)

        function update(~)
            % We do all the updating manually
        end

    end

    % Internal callbacks
    methods (Access = private)

        function createSetupControllers(this, backendName)
            arguments
                this (1,1) gwidgets.UITable
                backendName (1,1) string {mustBeMember(backendName, ["UITable", "JavaScript"])} = "UITable"
            end

            if isempty(this.GraphicsApi_)
                this.GraphicsApi_ = gwidgets.internal.table.GraphicsController(Backend=backendName);
            else
                this.GraphicsApi_.configureBackend(backendName, this);
            end
        end

        function createControllers(this, backendName)
            arguments
                this (1,1) gwidgets.UITable
                backendName (1,1) string {mustBeMember(backendName, ["UITable", "JavaScript"])} = "UITable"
            end

            this.createSetupControllers(backendName);
            this.GraphicsApi_.attachOwner(this);
            this.FilterApi_ = gwidgets.internal.table.FilterController(this, this.Graphics.FilterComponent);
            this.UpdateController_ = gwidgets.internal.table.UpdateController(this);
            this.ColumnApi_ = gwidgets.internal.table.ColumnController(this);
            this.GroupApi_ = gwidgets.internal.table.GroupController(this);
            this.SortApi_ = gwidgets.internal.table.SortController(this);
            this.StyleApi_ = gwidgets.internal.table.StyleController(this);
            this.DataApi_ = gwidgets.internal.table.DataController(this);
            this.DisplayApi_ = gwidgets.internal.table.DisplayController(this);
            this.BridgeApi_ = gwidgets.internal.table.BridgeController(this);
            this.MenuApi_ = gwidgets.internal.table.ContextMenuController(this);
            this.TooltipController_ = gwidgets.internal.table.TooltipController(this);
            this.MetricApi_ = gwidgets.internal.table.MetricController(this);
            this.CallbackApi_ = gwidgets.internal.table.CallbackController(this);
            this.SelectionApi_ = gwidgets.internal.table.SelectionController(this);
            this.DragApi_ = gwidgets.internal.table.DragController(this);
            this.initializeControllers();
        end

        function initializeControllers(this)
            for iController = 1:numel(this.Controllers_)
                controller = this.Controllers_{iController};
                if isvalid(controller)
                    controller.initialize();
                end
            end
        end

        function deleteControllers(this)
            for iController = numel(this.Controllers_):-1:1
                controller = this.Controllers_{iController};
                if isvalid(controller)
                    delete(controller);
                end
            end
            this.Controllers_ = cell.empty(1,0);
        end

    end

    methods (Access = ?gwidgets.internal.table.TableController)
        function registerController(this, controller)
            arguments
                this (1,1) gwidgets.UITable
                controller (1,1) gwidgets.internal.table.TableController
            end

            for iController = 1:numel(this.Controllers_)
                if isequal(this.Controllers_{iController}, controller)
                    return
                end
            end

            this.Controllers_{end+1} = controller;
        end
    end

    methods (Access = {?gwidgets.UITable, ?gwidgets.Table})
        function setConstructionRefreshSuppressed(this, state)
            this.SuppressForceRefresh_ = state;
        end

        function runFilterUpdate(this)
            if this.Update.doRun("Filter")
                this.Update.run(StartFrom="Filtering");
            end
        end

        function runConstructionUpdate(this)
            this.Update.run();
        end

        function refreshAfterConstruction(this)
            if ~isempty(this.Parent)
                this.forceRefresh();
            end
        end
    end

    methods (Access = private)
        function refreshGroupHeaderTooltips(this)
            hasBackend = ~isempty(this.GraphicsApi_) && ~isempty(this.GraphicsApi_.Backend) && ...
                isvalid(this.GraphicsApi_.Backend);
            if hasBackend
                this.GraphicsApi_.refreshViews();
            end

            if ~isempty(this.BridgeApi_) && isvalid(this.BridgeApi_)
                this.BridgeApi_.applyGroupHeaderSpans();
            end

            if ~isempty(this.MenuApi_) && isvalid(this.MenuApi_)
                this.MenuApi_.refresh();
            end
        end
    end

    methods (Static, Hidden)
        function renderName = resolveRenderName(backendName, renderName)
            arguments
                backendName (1,1) string = "<default>"
                renderName (1,1) string = "<default>"
            end

            hasBackend = backendName ~= "<default>";
            hasRender = renderName ~= "<default>";
            if hasBackend && hasRender
                error("GraphicsWidgets:Table:RenderConflict", ...
                    "Specify either Render or Backend, not both.");
            end

            if hasBackend
                renderName = backendName;
            elseif ~hasRender
                renderName = "UITable";
            end

            renderName = gwidgets.UITable.normalizeRenderName(renderName);
        end

        function renderName = normalizeRenderName(renderName)
            arguments
                renderName (1,1) string
            end

            switch lower(strtrim(renderName))
                case {"uitable", "matlab"}
                    renderName = "UITable";
                case {"javascript", "js"}
                    renderName = "JavaScript";
                otherwise
                    error("GraphicsWidgets:Table:Render", ...
                        "Unsupported table renderer: %s", renderName);
            end
        end
    end

end
