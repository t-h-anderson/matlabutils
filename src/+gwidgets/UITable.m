classdef UITable < gwidgets.internal.Reparentable
    %TABLE Custom table with filterable columns

    %% Standard functionality
    properties (Dependent, SetAccess = private)
        Column (1,1) gwidgets.internal.table.ColumnController
        Group (1,1) gwidgets.internal.table.GroupController
        Sort (1,1) gwidgets.internal.table.SortController
        Style (1,1) gwidgets.internal.table.StyleController
        Data (1,1) gwidgets.internal.table.DataController
        Filter (1,1) gwidgets.internal.FilterController
        Menu (1,1) gwidgets.internal.table.ContextMenuController
        Tooltip (1,1) gwidgets.internal.table.TooltipController
        Callback (1,1) gwidgets.internal.table.CallbackController
        Selection (1,1) gwidgets.internal.table.SelectionController
    end

    properties (Access = private)
        UpdateManager (1,:) gwidgets.internal.UpdateManager {mustBeScalarOrEmpty} = gwidgets.internal.UpdateManager() % Suppress update trigger from a property to improve performance

        % Avoid global pause/drawnow flushes while the widget is still
        % being constructed; a single refresh is enough once setup is live.
        SuppressForceRefresh_ (1,1) logical = true

        ColumnApi_ (1,:) gwidgets.internal.table.ColumnController {mustBeScalarOrEmpty}
        GroupApi_ (1,:) gwidgets.internal.table.GroupController {mustBeScalarOrEmpty}
        SortApi_ (1,:) gwidgets.internal.table.SortController {mustBeScalarOrEmpty}
        StyleApi_ (1,:) gwidgets.internal.table.StyleController {mustBeScalarOrEmpty}
        DataApi_ (1,:) gwidgets.internal.table.DataController {mustBeScalarOrEmpty}
        FilterApi_ (1,:) gwidgets.internal.FilterController {mustBeScalarOrEmpty}
        TooltipController_ (1,:) gwidgets.internal.table.TooltipController {mustBeScalarOrEmpty}
        CallbackApi_ (1,:) gwidgets.internal.table.CallbackController {mustBeScalarOrEmpty}
        SelectionApi_ (1,:) gwidgets.internal.table.SelectionController {mustBeScalarOrEmpty}
        MenuApi_ (1,:) gwidgets.internal.table.ContextMenuController {mustBeScalarOrEmpty}
    end

    properties (GetAccess = {?gwidgets.Table, ...
            ?gwidgets.internal.table.ColumnController, ...
            ?gwidgets.internal.table.SelectionController, ...
            ?gwidgets.internal.table.StyleController, ...
            ?gwidgets.internal.table.GroupController, ...
            ?gwidgets.internal.table.ContextMenuController, ...
            ?gwidgets.internal.table.SortController, ...
            ?gwidgets.internal.table.DisplayController, ...
            ?gwidgets.internal.table.DataController, ...
            ?gwidgets.internal.table.CallbackController, ...
            ?gwidgets.internal.table.BridgeController, ...
            ?gwidgets.internal.table.TooltipController}, ...
            SetAccess = private)
        DisplayController_ (1,:) gwidgets.internal.table.DisplayController {mustBeScalarOrEmpty}
        BridgeController_ (1,:) gwidgets.internal.table.BridgeController {mustBeScalarOrEmpty}
    end

    methods
        function this = UITable(namedArgs)
            arguments (Input)
                namedArgs.?gwidgets.UITable
                namedArgs.Data (:,:) table = table.empty(0,0)
                namedArgs.ShowRowFilter (1,1) logical = false
            end

            this@gwidgets.internal.Reparentable();

            % Enable suppression of updates
            this.UpdateManager = gwidgets.internal.UpdateManager();
            this.createControllers();
            this.initializeControllersAfterSetup();

            data = namedArgs.Data;
            namedArgs = rmfield(namedArgs, "Data");

            this.Data.Table = data;
            set(this, namedArgs);

            this.Selection.Value = []; % Enforces correct inital selection shape

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
            delete(this.DataApi_);
            delete(this.FilterApi_);
            delete(this.TooltipController_);
            delete(this.CallbackApi_);
            delete(this.SelectionApi_);
            delete(this.MenuApi_);
            delete(this.DisplayController_);
            delete(this.BridgeController_);
            delete(this.GroupingController_);
            delete(this.SortingController_);
            delete(this.ContextMenu);
        end

        function reset(this)

            data = this.Data.Table;

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
            this.Data.TextColumns = textColumns;

            % Apply the filter to the new data and clear the selection in case it is out of range
            this.Selection.clear();

            if this.UpdateManager.doRun("Reset")
                this.doUpdateSequence();
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

        function val = get.Tooltip(this)
            val = this.TooltipController_;
        end

        function val = get.Callback(this)
            val = this.CallbackApi_;
        end

        function val = get.Selection(this)
            val = this.SelectionApi_;
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
            ?gwidgets.internal.table.CallbackController, ...
            ?gwidgets.internal.table.BridgeController, ...
            ?gwidgets.internal.table.TooltipController})
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

        function forceRefresh(this)
            % Force a refresh
            if this.SuppressForceRefresh_
                return
            end
            gwidgets.internal.Drawnow.runWithPause("limitrate");
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
            if state
                this.Grid.RowHeight{1} = "fit";
            else
                this.Grid.RowHeight{1} = 0;
            end

        end

    end

    %% Grouping
    properties (Access = private)
        GroupingController_ (1,:) gwidgets.internal.table.GroupingController {mustBeScalarOrEmpty}
    end

    %% Sorting
    properties (Access = private)
        SortingController_ (1,:) gwidgets.internal.table.SortingController {mustBeScalarOrEmpty}
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

    %% Graphics components
    properties (GetAccess = {?matlab.unittest.TestCase, ...
            ?gwidgets.Table, ...
            ?gwidgets.internal.table.SelectionController, ...
            ?gwidgets.internal.table.StyleController, ...
            ?gwidgets.internal.table.GroupController, ...
            ?gwidgets.internal.table.ContextMenuController, ...
            ?gwidgets.internal.table.SortController, ...
            ?gwidgets.internal.table.DisplayController, ...
            ?gwidgets.internal.table.DataController, ...
            ?gwidgets.internal.table.BridgeController, ...
            ?gwidgets.internal.table.TooltipController}, ...
            SetAccess = private)
        Grid (1,:) matlab.ui.container.GridLayout {mustBeScalarOrEmpty}

        GroupLabel (1,:) matlab.ui.control.Label {mustBeScalarOrEmpty}
        DisplayTable (1,:) matlab.ui.control.Table {mustBeScalarOrEmpty}

        HelpPanel (1,:) matlab.ui.container.Panel {mustBeScalarOrEmpty}
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

            this.FilterApi_ = gwidgets.internal.FilterController(...
                Parent=this.Grid,HelpParent=uigridlayout(this.HelpPanel, [1,1], "Padding",0));
            this.Filter.Layout.Column = 1;
            this.Filter.Layout.Row = 1;

            % Create the table to display the filtered and grouped data
            this.GroupLabel = uilabel("Parent", this.Grid);
            this.GroupLabel.Layout.Column = 1;
            this.GroupLabel.Layout.Row = 2;

            this.DisplayTable = uitable(this.Grid);
            this.DisplayTable.ClickedFcn = @(s,e)this.Callback.onCellClicked(s,e);
            this.DisplayTable.DoubleClickedFcn = @(s,e)this.Callback.onCellDoubleClicked(s,e);
            this.DisplayTable.CellSelectionCallback = @(s,e)this.Callback.onSelection(s,e);
            this.DisplayTable.CellEditCallback = @(s,e)this.Callback.onCellEdit(s,e);
            this.DisplayTable.DisplayDataChangedFcn = @(s,e)this.Callback.onDisplayDataChanged(s,e);
            this.DisplayTable.Layout.Column = 1;
            this.DisplayTable.Layout.Row = 3;
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

        function doUpdateSequence(this, nvp)
            arguments
                this
                nvp.StartFrom (1,1) string {mustBeMember(nvp.StartFrom, ["Filtering", "Grouping", "Sorting", "Folding", "Display", "Style", "Interaction", "Skip"])} = "Filtering"
            end

            updating = false;
            if nvp.StartFrom == "Filtering" || updating
                this.Data.updateFiltering(this.Filter, this.Filter.FilterValue, this.Column);
                updating = true;
            end

            if nvp.StartFrom == "Grouping" || updating
                this.Data.updateGrouping(this.GroupingController_, this.Group);
                updating = true;
            end

            if nvp.StartFrom == "Sorting" || updating
                this.Data.updateSorting(this.SortingController_, this.Sort, this.Group, this.Column);
                updating = true;
            end

            if nvp.StartFrom == "Folding" || updating
                this.Data.updateFolding(this.GroupingController_, this.Group);
                this.Group.updateLabel(this.GroupLabel, this.Grid, this.Column, this.Data);
                updating = true;
            end

            if nvp.StartFrom == "Display" || updating
                this.DisplayController_.updateData();
                updating = true;
            end

            if nvp.StartFrom == "Style" || updating
                this.Style.applyToDisplay();
                updating = true;
            end

            if nvp.StartFrom == "Interaction" || updating
                this.DisplayController_.updateInteraction();
            end

            this.forceRefresh();
        end

    end

    % Internal callbacks
    methods (Access = private)

        function createControllers(this)
            this.ColumnApi_ = gwidgets.internal.table.ColumnController(this);
            this.GroupApi_ = gwidgets.internal.table.GroupController(this);
            this.SortApi_ = gwidgets.internal.table.SortController(this);
            this.StyleApi_ = gwidgets.internal.table.StyleController(this);
            this.DataApi_ = gwidgets.internal.table.DataController(this);
            this.DisplayController_ = gwidgets.internal.table.DisplayController(this);
            this.BridgeController_ = gwidgets.internal.table.BridgeController(this);
            this.MenuApi_ = gwidgets.internal.table.ContextMenuController(this);
            this.TooltipController_ = gwidgets.internal.table.TooltipController(this);
            this.CallbackApi_ = gwidgets.internal.table.CallbackController(this);
            this.SelectionApi_ = gwidgets.internal.table.SelectionController(this);
            this.GroupingController_ = gwidgets.internal.table.GroupingController();
            this.SortingController_ = gwidgets.internal.table.SortingController();
        end

        function initializeControllersAfterSetup(this)
            this.Data.attachFilterController(this.Filter);
            this.Menu.refresh();
            this.BridgeController_.setup(this.Grid, this.DisplayTable);

            % Apply any tooltip state that was configured before setup ran.
            % The bridge will enable hover reports once it signals BridgeReady.
            this.DisplayTable.Tooltip = this.Tooltip.Text;
        end

    end

    methods (Access = {?gwidgets.UITable, ?gwidgets.Table})
        function setConstructionRefreshSuppressed(this, state)
            this.SuppressForceRefresh_ = state;
        end

        function runFilterUpdate(this)
            if this.UpdateManager.doRun("Filter")
                this.doUpdateSequence(StartFrom="Filtering");
            end
        end

        function runConstructionUpdate(this)
            this.doUpdateSequence();
        end

        function refreshAfterConstruction(this)
            if ~isempty(this.Parent)
                this.forceRefresh();
            end
        end
    end

end
