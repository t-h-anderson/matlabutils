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
        Callback (1,1) gwidgets.internal.table.CallbackController
        Selection (1,1) gwidgets.internal.table.SelectionController
        Drag (1,1) gwidgets.internal.table.DragController
        Display (1,1) gwidgets.internal.table.DisplayController
    end

    properties (SetAccess = private)
        Backend (1,1) string {mustBeMember(Backend, ["UITable", "JavaScript"])} = "UITable"
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
            ?gwidgets.internal.table.TooltipController}, ...
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
                namedArgs.Backend (1,1) string {mustBeMember(namedArgs.Backend, ["UITable", "JavaScript"])} = "UITable"
            end

            this@gwidgets.internal.Reparentable();

            this.Backend = namedArgs.Backend;
            namedArgs = rmfield(namedArgs, "Backend");

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
            this.Update.addSuppression("DataColumnWidth", Times=1);
            this.Column.DataWidth = {};

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

        function val = get.Bridge(this)
            val = this.BridgeApi_;
        end

        function val = get.Tooltip(this)
            val = this.TooltipController_;
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
            ?gwidgets.internal.table.TooltipController})
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

    end

    %% Filtering
    properties (Dependent)
        ShowRowFilter (1,1) logical
    end

    properties (Access = protected)
        ShowRowFilter_ (1,1) logical = false
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

end
