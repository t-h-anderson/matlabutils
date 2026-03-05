classdef Table < gwidgets.internal.Reparentable
    %TABLE Custom table with filterable columns

    %% Standard functionality
    % Default uitable properties
    properties (Dependent)
        ColumnEditable (1,:) logical % Logical array indicating which displayed columns are editable
        ColumnSortable (1,:) logical % Logical array indicating which displayed columns are sortable

        DataColumnEditable (1,:) logical % Logical array indicating which data columns are editable
        DataColumnSortable (1,:) logical % Logical array indicating which data columns are sortable

        Multiselect (1,1) matlab.lang.OnOffSwitchState % Enable/disable multiple selection
        SelectionType (1,1) string % Type of selection: 'cell', 'row', or 'column'
        
        ColumnWidth (1,:) cell % Column Width
        DataColumnWidth (1,:) cell % Column Width

        Selection (:,:) double % Data selection. Either (:,2) for cell or (1,:) otherwise
        DisplaySelection (:,:) double % Display Selection. Either (:,2) for cell or (1,:) otherwise

        Data (:,:) table % Underlying data table
        DisplayData (1,1) table % Data as displayed
    end

    properties (Dependent)
        DataColumnNames (1,:) string % Column Names of underlying data (no set method)
        ColumnNames (1,:) string % Aliases for column names in display order
    end

    % Column name properties
    properties (Dependent)
        ColumnVisible (1,:) logical % Logical array indicating which columns are visible

        VisibleColumnNames (1,:) string % Aliases for displayed columns
        VisibleDataColumnNames (1,:) string % Aliases for displayed columns

        HiddenColumnNames (1,:) string % List of column names that are hidden
        HiddenDataColumnNames (1,:) string % List of data column names that are hidden
    end

    properties (Access = private)
        Data_ (:,:) table % Private storage for the data table
        TextColumns (:,:) table % Text columns extracted from data as strings

        ColumnNames_ (1,:) string % Private storage for column aliases
        ColumnVisible_ (1,:) logical % Private storage for column visible

        DataColumnEditable_ (1,:) logical % Logical array indicating which columns are editable
        DataColumnSortable_ (1,:) logical % Logical array indicating which columns are sortable

        % Column-width bridge
        DisplayTableTag_ (1,1) string   % Unique DOM tag used to scope bridge JS queries
        IsPushingWidthToDisplay_ (1,1) logical = false % True while programmatic widths are being applied

        DataColumnWidth_ (1,:) cell % Width of data columns

        UpdateManager (1,:) gwidgets.internal.UpdateManager {mustBeScalarOrEmpty} = gwidgets.internal.UpdateManager() % Suppress update trigger from a property to improve performance

        % Record whether data or view was specified on selection
        SelectionMode (1,1) gwidgets.internal.table.SelectionMode = "Data"
        Selection_ (:,:) % Selected Data: Either (:,2) for cell or (1,:) otherwise

        % Flag to prevent selection callback recursion
        IsSettingSelectionProgrammatically (1,1) logical = false
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
        function this = Table(namedArgs)
            arguments (Input)
                namedArgs.?gwidgets.Table
                namedArgs.ShowRowFilter (1,1) logical = false
                namedArgs.GroupHeaderStyle = gwidgets.Table.defaultGroupHeaderStyle
            end

            this@gwidgets.internal.Reparentable();

            % Enable suppression of updates
            this.UpdateManager = gwidgets.internal.UpdateManager();

            set(this, namedArgs);

            this.Selection = []; % Enforces correct inital selection shape

            % Support creation with filtering and grouping set
            this.doUpdateSequence();
        end

        function delete(this)
            delete(this.FilterController);
            delete(this.CustomContextMenuItems);
            delete(this.ContextMenu);
        end

        function reset(this)

            data = this.Data_;

            % Clear the state of the table, suppressing update till the end

            % All columns are default visible, suppress update to wait for data
            this.UpdateManager.addSuppression("ColumnVisible", Times=1);
            this.ColumnVisible = true;

            % Remove aliases
            this.UpdateManager.addSuppression("ColumnNames", Times=1);
            this.ColumnNames = [];
            this.UpdateManager.addSuppression("DataColumnEditable", Times=1);
            this.ColumnEditable = [];
            this.UpdateManager.addSuppression("DataColumnSortable", Times=1);
            this.ColumnSortable = [];
            this.UpdateManager.addSuppression("DataColumnWidth", Times=1);
            this.DataColumnWidth = {};

            % Clear the styling
            this.UpdateManager.addSuppression("UpdateStyle", Times=1);
            this.removeStyle();

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
                catch
                    % Update failed with new data, e.g. caused by change in
                    % size of table or data types, so reset the table
                    this.reset();
                end
            end
        end

        function val = get.DataColumnWidth(this)
            val = this.DataColumnWidth_;
            if isempty(val) && ~isempty(this.DataColumnNames)
                val = repelem({"auto"}, 1, numel(this.DataColumnNames));
            end
        end

        function set.DataColumnWidth(this, val)
            val = gwidgets.Table.normalizeColumnWidths(val);
            if isscalar(val)
                val = repelem(val, 1, numel(this.DataColumnNames));
            end
            if ~isempty(val) && numel(val) ~= numel(this.DataColumnNames)
                error("GraphicsWidgets:Table:DataColumnWidthSize", ...
                    "Size of DataColumnWidth must match the number of data columns, be scalar, or be empty (restore to default)");
            end
            this.DataColumnWidth_ = val;
            if this.UpdateManager.doRun("DataColumnWidth")
                this.doUpdateSequence(StartFrom="Interaction");
            end
        end

        function val = get.ColumnWidth(this)
            if isempty(this.DataColumnWidth_)
                % No explicit widths set — read the display table's current value
                val = this.DisplayTable.ColumnWidth;
                if ~iscell(val)
                    val = {val};
                end
            else
                val = this.DataColumnWidth_(this.ColumnVisible);
            end
        end

        function set.ColumnWidth(this, val)
            val = gwidgets.Table.normalizeColumnWidths(val);

            if isempty(val)
                % Empty clears all explicit widths (restores to auto)
                this.DataColumnWidth_ = {};
            else
                if isscalar(val)
                    val = repelem(val, 1, sum(this.ColumnVisible));
                end
                if numel(val) ~= sum(this.ColumnVisible)
                    error("GraphicsWidgets:Table:ColumnWidthSize", ...
                        "Size of ColumnWidth must match the number of visible columns, be scalar, or be empty (restore to default)");
                end
                % Map visible widths back into the per-data-column array,
                % preserving any explicitly stored width for hidden columns
                dataWidths = this.DataColumnWidth;
                dataWidths(this.ColumnVisible) = val;
                this.DataColumnWidth_ = dataWidths;
            end

            if this.UpdateManager.doRun("DataColumnWidth")
                this.doUpdateSequence(StartFrom="Interaction");
            end
        end

        function val = get.ColumnVisible(this)
            val = this.ColumnVisible_;
            if isempty(val)
                val = true(1, width(this.Data_));
            end
        end

        function set.ColumnVisible(this, val)
            if isscalar(val)
                val = repelem(val, size(this.Data_,2));
            end
            if numel(val) ~= size(this.Data_,2)
                error("GraphicsWidgets:Table:InvalidColumnVisibility", ...
                    "Column visibility must be specified for all columns.")
            end
            this.ColumnVisible_ = val;

            if this.UpdateManager.doRun("ColumnVisible")
                this.doUpdateSequence(StartFrom="Display");
            end
        end

        function val = get.VisibleColumnNames(this)
            val = this.ColumnNames(this.ColumnVisible);
        end

        function set.VisibleColumnNames(this, val)
            idx = ismember(this.ColumnNames, val);
            this.ColumnVisible = idx;
        end

        function val = get.VisibleDataColumnNames(this)
            val = this.DataColumnNames(this.ColumnVisible);
        end

        function set.VisibleDataColumnNames(this, val)
            idx = ismember(this.DataColumnNames, val);
            this.ColumnVisible = idx;
        end

        function val = get.HiddenColumnNames(this)
            val = this.ColumnNames(~this.ColumnVisible);
        end

        function set.HiddenColumnNames(this, val)

            idx = ismember(val, this.ColumnNames);
            if any(~idx)
                error("GraphicsWidgets:Table:NonexistentColumnName", "Columns not found: " + strjoin(val(~idx), ", "));
            end

            idx = ismember(this.ColumnNames, val);
            this.ColumnVisible = ~idx;
        end

        function val = get.HiddenDataColumnNames(this)
            val = this.DataColumnNames(~this.ColumnVisible);
        end

        function set.HiddenDataColumnNames(this, val)
            idx = ismember(this.DataColumnNames, val);
            this.ColumnVisible = ~idx;
        end

        function val = get.DataColumnNames(this)
            val = string(this.Data_.Properties.VariableNames);
        end

        function val = get.ColumnNames(this)
            val = this.ColumnNames_;

            % Initialise the column names to the data column names
            if isempty(val)
                val = this.DataColumnNames;
                this.ColumnNames_ = val;
            end
        end

        function set.ColumnNames(this, val)
            val(val == "") = [];
            if ~isempty(val) ... % empty restores to data names
                    && numel(val) ~= numel(this.DataColumnNames)
                error("GraphicsWidgets:Table:InvalidColumnAliases", ...
                    "Number of column aliases must match number of columns");
            end

            this.ColumnNames_ = val;

            if this.UpdateManager.doRun("ColumnNames")
                this.doUpdateSequence(StartFrom="Display");
            end
        end

        function val = get.DataColumnEditable(this)
            val = this.DataColumnEditable_;
            if isempty(val)
                val = false(1, size(this.Data_, 2));
                this.DataColumnEditable_ = val;
            end
        end

        function set.DataColumnEditable(this, val)
            if isscalar(val)
                val = repelem(val, 1, size(this.Data_, 2));
            end
            if ~isempty(val) ... % empty restores to default
                    && numel(val) ~= numel(this.DataColumnNames)
                error("GraphicsWidgets:Table:DataColumnEditableSize", ...
                    "Size of data column editable must match the underlying data, be scalar (apply to all), or empty (restore to default)");
            end
            this.DataColumnEditable_ = val;
            if this.UpdateManager.doRun("DataColumnEditable")
                this.doUpdateSequence(StartFrom="Interaction");
            end
        end

        function val = get.ColumnEditable(this)
            val = this.DataColumnEditable_;
            if isempty(val)
                val = false(1, numel(this.ColumnNames));
                this.DataColumnEditable_ = val;
            end
            val = val(this.ColumnVisible);
        end

        function set.ColumnEditable(this, val)
            if isscalar(val)
                val = repelem(val, 1, numel(this.VisibleColumnNames));
            end
            if ~isempty(val) ... % empty restores to default
                    && numel(val) ~= numel(this.VisibleColumnNames)
                error("GraphicsWidgets:Table:ColumnEditableSize", ...
                    "Size of column editable must match the visible table, be scalar (apply to all), or empty (restore to default)");
            end

            if isempty(val)
                this.DataColumnEditable_ = val;
            else
                this.DataColumnEditable_ = false(size(this.DataColumnNames));
                this.DataColumnEditable_(this.ColumnVisible) = val;
            end
            if this.UpdateManager.doRun("DataColumnEditable")
                this.doUpdateSequence(StartFrom="Interaction");
            end
        end

        function val = get.DataColumnSortable(this)
            val = this.DataColumnSortable_;
            if isempty(val)
                val = false(1, size(this.Data_, 2));
                this.DataColumnSortable_ = val;
            end
        end

        function set.DataColumnSortable(this, val)
            if isscalar(val)
                val = repelem(val, 1, size(this.Data_, 2));
            end
            if ~isempty(val) ... % empty restores to default
                    && numel(val) ~= numel(this.DataColumnNames)
                error("GraphicsWidgets:Table:DataColumnSortableSize", ...
                    "Size of data column sortable must match the underlying data, be scalar (apply to all), or empty (restore to default)");
            end
            this.DataColumnSortable_ = val;

            this.UpdateManager.addSuppression("SortByColumn", Times=1);
            this.SortByColumn = [];

            if this.UpdateManager.doRun("DataColumnSortable")
                this.doUpdateSequence(StartFrom="Interaction");
            end
        end

        function val = get.ColumnSortable(this)
            val = this.DataColumnSortable_;
            if isempty(val)
                val = false(1, size(this.Data_, 2));
                this.DataColumnSortable_ = val;
            end
            val = val(this.ColumnVisible);
        end

        function set.ColumnSortable(this, val)
            if isscalar(val)
                val = repelem(val, 1, numel(this.VisibleColumnNames));
            end
            if ~isempty(val) ... % empty restores to default
                    && numel(val) ~= numel(this.VisibleColumnNames)
                error("GraphicsWidgets:Table:ColumnSortableSize", ...
                    "Size of column sortable must match the visible table, be scalar (apply to all), or empty (restore to default)");
            end

            this.UpdateManager.addSuppression("DataColumnSortable", Times=1);
            if isempty(val)
                this.DataColumnSortable = val;
            else
                tmp = false(size(this.DataColumnNames));
                tmp(this.ColumnVisible) = val;
                this.DataColumnSortable = tmp;
            end

            if this.UpdateManager.doRun("DataColumnSortable")
                this.doUpdateSequence(StartFrom="Interaction");
            end
        end

        function val = get.Multiselect(this)
            val = this.DisplayTable.Multiselect;
        end

        function set.Multiselect(this, val)
            this.DisplayTable.Multiselect = val;

            % Clear the selection
            this.Selection = [];
        end

        function val = get.Selection(this)
            % Selected Data
            val = this.Selection_;
            if this.SelectionMode == "Display"
                val = this.displaySelectionToDataSelection(val);
            end
        end

        function set.Selection(this, selection)
            arguments
                this (1,1)
                selection (:,:) double
            end
            selection = this.validateSelectionShape(selection);
            this.validateSelectionDimensions(selection, size(this.Data_));
            this.Selection_ = selection;
            this.SelectionMode = "Data";
            this.refreshVisibleSelection();
        end

        function val = get.SelectionType(this)
            val = this.DisplayTable.SelectionType;
        end

        function set.SelectionType(this, selectionType)
            this.DisplayTable.SelectionType = selectionType;
            this.clearSelection();

            if this.UpdateManager.doRun("SelectionType")
                this.doUpdateSequence(StartFrom="Interaction")
            end
        end

        function val = get.DisplaySelection(this)
            % Get the displayed selection
            val = this.Selection_;
            if this.SelectionMode == "Data"
                val = this.dataSelectionToDisplaySelection(val);
            end
        end

        function set.DisplaySelection(this, selection)
            % Set the displayed selection
            selection = this.validateSelectionShape(selection);
            this.validateSelectionDimensions(selection, size(this.VisibleData));
            this.Selection_ = selection;
            this.SelectionMode = "Display";
            this.refreshVisibleSelection();
        end

        function val = get.DisplayData(this)
            val = this.DisplayTable.Data;
        end
    end

    methods (Access = private)

        function selection = validateSelectionShape(this, selection)

            errorMsg = this.SelectionType + " selection must be a vector, or []";

            % Must be vector or matrix
            if ~(isvector(selection) || ismatrix(selection))
                error("GraphicsWidgets:Table:UnsupportedSelectionSize", errorMsg);
            end

            % Update the data selection
            switch this.SelectionType
                case "cell"

                    if all(size(selection) == 0)
                        selection = double.empty(0,2);
                    end

                    % Selection must be two columns (or rows) of
                    % indices
                    if ~any(size(selection) == [2,2])
                        error("GraphicsWidgets:Table:UnsupportedSelectionSize", errorMsg);
                    end

                    selection = reshape(selection, [], 2);
                    selection = unique(selection, "rows", "stable");
                otherwise

                    if all(size(selection) == 0)
                        selection = double.empty(1,0);
                    end

                    % Selection must be a row or column vector
                    if ~isvector(selection)
                        error("GraphicsWidgets:Table:UnsupportedSelectionSize", errorMsg);
                    end

                    selection = reshape(selection, 1, []);
                    selection = unique(selection, "stable");
            end

            if ~this.Multiselect

                switch this.SelectionType
                    case "cell"
                        if height(selection) > 1
                            error("GraphicsWidgets:Table:InvalidSingleSelection", errorMsg);
                        end
                    otherwise
                        if numel(selection) > 1
                            error("GraphicsWidgets:Table:InvalidSingleSelection", errorMsg);
                        end
                end

            end

        end

        function validateSelectionDimensions(this, selection, destSize)

            if ~(all(size(selection) == [0,0])) % Support []

                if any(ismissing(selection) | (selection < 1) | isinf(selection))
                    error("GraphicsWidgets:Table:UnsupportedSelection", "Selection outside limits or undefined");
                end

                % Update the data selection
                switch this.SelectionType
                    case "cell"

                        idxFail = selection(:,1) > destSize(1) ...
                            | selection(:,2) > destSize(2);

                        if any(idxFail)
                            failSelection = strjoin(string(num2str(selection(idxFail, :), "[%d,%d]")), ",");
                            limits = strjoin(string(num2str(destSize, "[%d,%d]")), ",");
                            error("GraphicsWidgets:Table:SelectionOutsideLimits", "Selection " + failSelection + " outside limits " + limits);
                        end

                    otherwise

                        if this.SelectionType == "row"
                            destSize = destSize(1);
                            idxFail = selection > destSize;
                        else
                            destSize = destSize(2);
                            idxFail = selection > destSize;
                        end

                        if any(idxFail)
                            failSelection = strjoin(selection(idxFail), ",");
                            limits = destSize;
                            error("GraphicsWidgets:Table:SelectionOutsideLimits", "Selection " + failSelection + " outside limits " + limits);
                        end

                end

            end

        end

        function result = translateNames(this, inputs, srcNames, destNames)
            arguments
                this (1,1)
                inputs (1,:) string
                srcNames (1,:) string = this.DataColumnNames
                destNames (1,:) string = this.ColumnNames
            end

            if numel(srcNames) ~= numel(destNames)
                error("For translation, mapping must exist for each value");
            end

            % Don't translate anything not in sources, e.g. "Group" heading
            idx = ismember(inputs, srcNames);
            result = inputs;

            % Do the translation of any inputs in map
            d = dictionary(srcNames, destNames);
            result(idx) = d(inputs(idx));
        end
    end

    %% Styling
    properties (Dependent, Hidden)
        GroupHeaderStyle (1,:) gwidgets.internal.table.TableStyle
    end

    properties (Dependent)
        StyleConfigurations (:,3) table
    end

    properties (Access = protected)
        % Styling
        Styles (1,:) gwidgets.internal.table.TableStyle
        GroupHeaderStyle_ (1,:) gwidgets.internal.table.TableStyle {mustBeScalarOrEmpty} = gwidgets.Table.defaultGroupHeaderStyle()
    end

    methods
        function addStyle(this, s, tableTarget, targetIndicesOrFunction, nvp)
            arguments
                this (1,1) gwidgets.Table
                s (1,1) matlab.ui.style.Style
                tableTarget (1,1) string {mustBeMember(tableTarget, ["table", "row", "column", "cell"])} = "table"
                targetIndicesOrFunction (:,:) = []
                nvp.SelectionMode (1,1) gwidgets.internal.table.SelectionMode = gwidgets.internal.table.SelectionMode.Data
            end

            if isa(targetIndicesOrFunction, "function_handle")
                newStyle = gwidgets.internal.table.TableStyle(s, tableTarget, "TargetFunction", targetIndicesOrFunction, "SelectionMode", nvp.SelectionMode);
            elseif isa(targetIndicesOrFunction, "string")
                targetIndicesOrFunction =  @(t) t.find(targetIndicesOrFunction, tableTarget);
                newStyle = gwidgets.internal.table.TableStyle(s, tableTarget, "TargetFunction", targetIndicesOrFunction, "SelectionMode", nvp.SelectionMode);
            elseif isnumeric(targetIndicesOrFunction)
                newStyle = gwidgets.internal.table.TableStyle(s, tableTarget, "TargetIndices", targetIndicesOrFunction, "SelectionMode", nvp.SelectionMode);
            else
                error("Table index must an index array, or a function that takes the table object as input");
            end

            this.Styles(end+1) = newStyle;

            if this.UpdateManager.doRun("UpdateStyle")
                this.doUpdateSequence("StartFrom", "Style");
            end
        end

        function removeStyle(this, orderNum)
            arguments
                this
                orderNum (1,:) double = []
            end

            if isempty(orderNum)
                this.Styles(:) = [];
            else
                this.Styles(orderNum) = [];
            end

            if this.UpdateManager.doRun("UpdateStyle")
                this.doUpdateSequence("StartFrom", "Style");
            end

        end

    end

    methods % Get/Set

        function val = get.StyleConfigurations(this)
            val = this.DisplayTable.StyleConfigurations;
        end

        function set.StyleConfigurations(this, tbl)
            this.DisplayTable.StyleConfigurations = tbl;
        end

        function val = get.GroupHeaderStyle(this)
            val = this.GroupHeaderStyle_;
        end

        function set.GroupHeaderStyle(this, val)
            this.GroupHeaderStyle_ = val;
            if this.UpdateManager.doRun("GroupHeaderStyle")
                this.doUpdateSequence("StartFrom", "Style");
            end
        end

    end

    methods (Static)

        function style = defaultGroupHeaderStyle(s)
            arguments
                s (1,1) matlab.ui.style.Style = matlab.ui.style.Style("BackgroundColor", [0.1 0.1 0.8], "FontColor", [0.9 0.9 0.9]);
            end
            style = gwidgets.internal.table.TableStyle(s, "row", "SelectionMode", "Display", "TargetFunction", @(this) this.VisibleGroupHeaderRowIdx);
        end

    end

    %% Context Menu
    properties (Hidden, Dependent)
        CustomContextMenuItems (1,:) matlab.ui.container.Menu
    end

    % Context menu options
    properties (Dependent)
        SupportedSelectionTypes (1,:) string
        HasToggleFilter (1,1) logical
        HasChangeGroupingVariable (1,1) logical
        HasToggleShowEmptyGroups (1,1) logical
        HasColumnSorting (1,1) logical
    end

    properties (Access = protected)
        CustomContextMenuItems_ (1,:) matlab.ui.container.Menu = matlab.ui.container.Menu.empty(1,0)
        SupportedSelectionTypes_ (1,:) string {mustBeMember(SupportedSelectionTypes_, ["cell", "row", "column"])}= "cell"
        HasToggleFilter_ (1,1) logical = false
        HasChangeGroupingVariable_ (1,1) logical = false
        HasToggleShowEmptyGroups_ (1,1) logical = false
        HasColumnSorting_ (1,1) logical = false
    end

    methods

        function addContextMenuItem(this, menuItems)
            arguments
                this (1,1) gwidgets.Table
                menuItems (1,:) matlab.ui.container.Menu
            end
            this.CustomContextMenuItems = [this.CustomContextMenuItems, menuItems];
        end

    end

    methods % Get/Set

        function val = get.HasToggleFilter(this)
            val = this.HasToggleFilter_;
        end

        function set.HasToggleFilter(this, val)
            this.HasToggleFilter_ = val;
            this.addContextMenu();
        end

        function val = get.HasChangeGroupingVariable(this)
            val = this.HasChangeGroupingVariable_;
        end

        function set.HasChangeGroupingVariable(this, val)
            this.HasChangeGroupingVariable_ = val;
            this.addContextMenu();
        end

        function val = get.HasToggleShowEmptyGroups(this)
            val = this.HasToggleShowEmptyGroups_;
        end

        function set.HasToggleShowEmptyGroups(this, val)
            this.HasToggleShowEmptyGroups_ = val;
            this.addContextMenu();
        end

        function val = get.HasColumnSorting(this)
            val = this.HasColumnSorting_;
        end

        function set.HasColumnSorting(this, val)
            this.HasColumnSorting_ = val;
            this.addContextMenu();
        end

        function val = get.SupportedSelectionTypes(this)
            val = this.SupportedSelectionTypes_;
        end

        function set.SupportedSelectionTypes(this, val)
            arguments
                this
                val (1,:) string {mustBeMember(val, ["cell", "row", "column"]), mustBeNonempty} = "cell"
            end

            this.SupportedSelectionTypes_ = val;

            if ~ismember(this.SelectionType, val)
                this.clearSelection();
                this.SelectionType = val(1);
            end

            this.addContextMenu();
        end

        function val = get.CustomContextMenuItems(this)
            val = this.CustomContextMenuItems_;
        end

        function set.CustomContextMenuItems(this, val)
            arguments
                this
                val (1,:) matlab.ui.container.Menu
            end
            this.CustomContextMenuItems_ = val;
            this.addContextMenu();
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
                this (1,1) gwidgets.Table
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
    properties (Dependent)
        ShowEmptyGroups (1,1) logical
    end

    properties (Access = protected)
        ShowEmptyGroups_ (1,1) logical = false
    end

    properties (SetAccess = protected)
        Groups (1,:) string % All group column variables
        DisplayGroups (1,:) % All visible group column variables in view order
    end

    properties (Dependent)
        IsGroupTable (1,1) logical
        GroupingVariable (1,:) string % Can be multiple
        GroupingVariableName (1,1) string = "" % Concatenated for display

        OpenGroups (1,:) string % Groups that are open
        ClosedGroups (1,:) string % Groups that are collapsed
        HiddenGroups (1,:) string % Groups that are hidden
    end

    properties (Access = private)
        % Grouping
        GroupingVariable_ (1,:) string = string.empty(1,0)
        GroupColumnIdx (1,:) double = []
        GroupIdxs (1,:) double = []

        % Raw grouping
        GroupedVisibleData (:,:) cell % Headers and data before sorting
        GroupedDataVariables  (1,:) string % Table variable names after grouping
        GroupHeaderRowIdx (1,:) double % (1,nGroups) Indices of group header rows
        VisibleGroupHeaderRowIdx (1,:) double % (1,nVisGroups) Indices of header rows

        GroupFilteredCount (1,:) double % (1,nGroups) Group filtered counts

        % List of open groups
        OpenGroups_ (1,:) string
        HiddenGroups_ (1,:) string

        % Sorted group values, to converted to DisplayGroupVariable once any are hidden
        SortedGroupValues (1,:) string

        % Maps after grouping
        GroupedVisibleToDataMap (1,:) double % Mapping from visible rows to data rows
        GroupedDataToVisibleMap (1,:) double % Mapping from data rows to visible rows

        % Maps after folding - note, sorting comes before folding for
        % performance reasons
        FoldedVisibleToDataMap (1,:) double % Mapping from visible rows to data rows
        FoldedDataToVisibleMap (1,:) double % Mapping from data rows to visible rows
    end

    methods
        function openAllGroups(this)
            % By default, all groups are hidden
            this.OpenGroups = this.Groups;
        end

        function closeAllGroups(this)
            % By default, all groups are hidden
            this.OpenGroups = string.empty(1,0);
        end
    end

    methods % Get/Set
        function val = get.IsGroupTable(this)
            if isempty(this.GroupingVariable)
                val = false;
            else
                val = true;
            end
        end

        function val = get.OpenGroups(this)
            val = this.OpenGroups_;
        end

        function set.OpenGroups(this, val)

            idx = ismember(val, this.Groups);
            if any(~idx)
                error("GraphicsWidgets:Table:NonexistentGroupingVariable", "Grouping variables not found: " + strjoin(val(~idx), ", "));
            end

            idx = ismember(this.Groups, val);
            this.OpenGroups_ = this.Groups(idx);
            if this.UpdateManager.doRun("OpenGroups")
                this.doUpdateSequence(StartFrom="Folding");
            end
        end

        function val = get.ClosedGroups(this)
            idx = ismember(this.Groups, this.OpenGroups);
            val = this.Groups(~idx);
        end

        function set.ClosedGroups(this, val)

            idx = ismember(val, this.Groups);
            if any(~idx)
                error("GraphicsWidgets:Table:NonexistentGroupingVariable", "Grouping variables not found: " + strjoin(val(~idx), ", "));
            end

            idx = ismember(this.Groups, val);
            this.OpenGroups_ = this.Groups(~idx);
            if this.UpdateManager.doRun("ClosedGroups")
                this.doUpdateSequence(StartFrom="Folding");
            end
        end

        function val = get.HiddenGroups(this)
            val = this.HiddenGroups_;
        end

        function set.HiddenGroups(this, val)
            idx = ismember(this.Groups, val);
            this.HiddenGroups_ = this.Groups(idx);
            if this.UpdateManager.doRun("HiddenGroups")
                this.doUpdateSequence(StartFrom="Folding");
            end
        end

        function val = get.ShowEmptyGroups(this)
            val = this.ShowEmptyGroups_;
        end

        function set.ShowEmptyGroups(this, val)
            this.ShowEmptyGroups_ = val;

            if this.UpdateManager.doRun("ShowEmptyGroups")
                this.doUpdateSequence(StartFrom="Folding");
            end
        end

        function val = get.GroupingVariableName(this)
            val = strjoin(this.GroupingVariable_, "|");
            if isempty(val)
                val = "";
            end
        end

        function val = get.GroupingVariable(this)
            val = this.GroupingVariable_;
        end

        function set.GroupingVariable(this, val)

            val = unique(val, "stable");

            % Remove "" from lists, but replace if only
            val(val == "") = [];

            if ~isempty(val) ...
                    && any(~ismember(val, this.DataColumnNames))
                error("GraphicsWidgets:Table:NonexistentGroupingVariable", ...
                    "Grouping variable must either be """" or exist in the data table.")
            end

            this.GroupingVariable_ = val;
            this.Selection_ = [];

            if this.UpdateManager.doRun("GroupingVariable")
                this.doUpdateSequence(StartFrom="Grouping");
            end
        end

    end

    %% Sorting
    properties (Dependent)
        SortByColumn (1,:) string = string.empty()
        SortByDataColumn (1,:) string = string.empty()
        SortDirection (1,1) string {mustBeMember(SortDirection, ["Ascend", "Descend", "None"])} = "None"
    end

    properties (GetAccess = ?matlab.unittest.TestCase, SetAccess = private)
        SortedVisibleData (:,:) cell % Headers and data after sorting
        SortedGroupHeaderRowIdx (1,:) double % (1,nGroups) Indices of group header rows after sorting

        % Maps after sorting
        SortedVisibleToDataMap (1,:) double % Mapping from visible rows to data rows
        SortedDataToVisibleMap (1,:) double % Mapping from data rows to visible rows
    end

    properties (Access = protected)
        SortByColumnIdxs_ (1,:) double = double.empty(1,0)
        SortDirection_ (1,1) string {mustBeMember(SortDirection_, ["Ascend", "Descend", "None"])} = "None"
    end

    methods

        function val = get.SortByColumn(this)
            idx = this.SortByColumnIdxs_;
            val = this.ColumnNames(idx);
        end

        function set.SortByColumn(this, val)
            val = rmmissing(val);

            idx = ~ismember(val, this.ColumnNames(this.DataColumnSortable));
            if any(idx)
                error("GraphicsWidgets:Table:NotASortableColumn", ...
                    "Specified columns are not sortable")
            end

            idx = (val == this.ColumnNames');
            id = nan(1,size(idx,2));
            for i = 1:size(idx, 2)
                id(i) = find(idx(:,i), 1);
            end

            this.SortByColumnIdxs_ = id;
            if this.UpdateManager.doRun("SortByColumn")
                this.doUpdateSequence(StartFrom="Sorting");
            end
        end

        function val = get.SortByDataColumn(this)
            idx = this.SortByColumnIdxs_;
            val = this.DataColumnNames(idx);
        end

        function set.SortByDataColumn(this, val)
            val = rmmissing(val);

            idx = ~ismember(val, this.DataColumnNames(this.DataColumnSortable));
            if any(idx)
                error("GraphicsWidgets:Table:NotASortableColumn", ...
                    "Specified columns are not sortable")
            end

            idx = (val == this.DataColumnNames');
            id = nan(1,size(idx,2));
            for i = 1:size(idx, 2)
                id(i) = find(idx(:,i), 1);
            end

            this.SortByColumnIdxs_ = id;
            if this.UpdateManager.doRun("SortByColumn")
                this.doUpdateSequence(StartFrom="Sorting");
            end
        end

        function val = get.SortDirection(this)
            val = this.SortDirection_;
        end

        function set.SortDirection(this, val)
            this.SortDirection_ = val;

            if this.UpdateManager.doRun("SortDirection")
                this.doUpdateSequence(StartFrom="Sorting");
            end

        end

    end

    methods (Access = protected)

        function updateSorting(this)
            arguments
                this (1,1) gwidgets.Table
            end

            data = this.GroupedVisibleData;

            % Pass forwards the data in case we return early
            this.SortedVisibleData = data;
            this.SortedDataToVisibleMap = this.GroupedDataToVisibleMap;
            this.SortedVisibleToDataMap = this.GroupedVisibleToDataMap;
            this.SortedGroupHeaderRowIdx = this.GroupHeaderRowIdx;
            this.SortedGroupValues = this.Groups;

            if this.SortDirection == "None"
                return
            end

            % Separate the group variables from the data variables. Group variables are
            % sorted separately.
            dataVars = this.GroupedDataVariables;
            groupVars = this.GroupingVariable;

            sortBy = this.SortByDataColumn;

            % Don't allow sort by columns that aren't sortable
            if isempty(this.DataColumnSortable) ... % unset
                    || (isscalar(this.DataColumnSortable) && ~this.DataColumnSortable)... % single false
                    || (~isscalar(this.DataColumnSortable) && all(~this.DataColumnSortable)) % all false
                % Table is not sortable
                return
            elseif ~isscalar(this.DataColumnSortable)
                vars = string(this.Data_.Properties.VariableNames);
                sortableVars = vars(this.DataColumnSortable);
                sortBy = sortBy(ismember(sortBy, sortableVars));
            end

            sortByGroupVars = sortBy(ismember(sortBy, groupVars));
            sortByDataVars = sortBy(ismember(sortBy, dataVars));
            dataColIdx = ismember(dataVars, sortBy);

            % Sort the content of each group
            d2vMap = this.GroupedDataToVisibleMap;
            v2dMap = this.GroupedVisibleToDataMap;
            sortDirection = lower(this.SortDirection);

            groupHeaderRowIdxs = this.GroupHeaderRowIdx;

            if isempty(groupHeaderRowIdxs)
                % No grouping, so "group" is everying and starts at 0
                groupHeaderRowIdxs = 0;
            end

            groupHeaderRowIdxs = [groupHeaderRowIdxs, height(data)+1]; % Add an extra fake group start to make calculating start and end group idxs easy

            if ~isempty(sortByDataVars)

                for iGroup = 1:(numel(groupHeaderRowIdxs)-1)

                    dataStartIdx = groupHeaderRowIdxs(iGroup) + 1;
                    dataEndIdx = groupHeaderRowIdxs(iGroup+1) - 1;

                    groupIdxs = dataStartIdx:dataEndIdx;

                    subData = data(groupIdxs, dataColIdx);

                    subData = cell2table(subData, 'VariableNames', sortByDataVars); % TODO: This is probably slow
                    [~, orderIdx] = sortrows(subData, sortBy, sortDirection);

                    groupIdxsReordered = groupIdxs(orderIdx);

                    data(groupIdxs, :) = data(groupIdxsReordered, :);

                    % Update the maps
                    idx = ismember(d2vMap, groupIdxs);
                    tmp = d2vMap(idx);
                    tmp(orderIdx) = tmp;
                    d2vMap(idx) = tmp;

                    tmp = v2dMap(groupIdxs);
                    v2dMap(groupIdxs) = tmp(orderIdx);
                end
            end

            for iGroupVar = 1:numel(sortByGroupVars)
                if iGroupVar > 1
                    warning("Multiple grouping not yet supported");
                    continue
                end

                groupData = [this.GroupedVisibleData{this.GroupHeaderRowIdx, 1}];
                [~, orderIdx] = sort(groupData, sortDirection);

                groupIdxs = cell(1, numel(groupHeaderRowIdxs)-1);
                groupSize = NaN(1, numel(groupHeaderRowIdxs)-1);
                d2vMapGroup = cell(1, numel(groupHeaderRowIdxs)-1);
                for iGroup = 1:(numel(groupHeaderRowIdxs)-1)

                    % Indices of group, inc. header
                    groupStartIdx = groupHeaderRowIdxs(iGroup);
                    groupEndIdx = groupHeaderRowIdxs(iGroup+1) - 1;
                    groupIdxs{iGroup} = groupStartIdx:groupEndIdx;

                    groupSize(iGroup) = numel(groupIdxs{iGroup}) - 1;

                    idx = ismember(d2vMap, groupIdxs{iGroup});
                    tmp = d2vMap;
                    tmp = tmp - sum(groupSize(1:iGroup-1)) - iGroup;
                    d2vMapGroup{iGroup} = tmp .* idx;
                end

                % Re order the indices
                groupSize = groupSize(orderIdx);
                groupIdxs = groupIdxs(orderIdx);
                groupIdxs = [groupIdxs{:}];
                d2vMapGroup = d2vMapGroup(orderIdx);

                data = data(groupIdxs, :);

                % Update the mappings
                v2dMap = v2dMap(groupIdxs);

                d2vMap = 0*d2vMap;
                cumSize = 1;
                for i = 1:numel(d2vMapGroup)
                    d2vMap = d2vMap + d2vMapGroup{i} + (d2vMapGroup{i} ~=0) * (cumSize);
                    cumSize = cumSize + (groupSize(i) + 1);
                end

                % Update the row header markers
                newGroupHeaderIdxs = [0, cumsum(groupSize)] + (1:(numel(groupSize)+1));
                this.SortedGroupHeaderRowIdx = newGroupHeaderIdxs(1:end-1);

                this.SortedGroupValues = this.SortedGroupValues(orderIdx);
            end

            this.SortedVisibleData = data;

            this.SortedDataToVisibleMap = d2vMap;
            this.SortedVisibleToDataMap = v2dMap;

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
        ColumnWidthBridge_ (1,:) matlab.ui.control.HTML {mustBeScalarOrEmpty}
    end

    properties (SetAccess = private)
        VisibleData (:,:) table % Data after grouping and filtering
    end

    %% Private methods
    % From matlab.ui.componentcontainer.ComponentContainer
    methods (Access = protected)
        function setup(this)
            %SETUP Initialize the component's graphics.

            % Add the card panel for the filter
            p = uipanel("Parent", this, ...
                "BorderType", "none");
            this.Grid = uigridlayout(p, ...
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
            this.setupColumnWidthBridge();
            this.doUpdateSequence();
        end

        function updateDisplayData(this)

            vars = [...
                "VisibleData" ...
                ];

            this.updateDisplayTable(vars);
        end

        function updateInteraction(this)
            vars = [...
                "ColumnEditable", ...
                "ColumnSortable", ...
                "SelectionType" ...
                ];
            this.updateDisplayTable(vars);
            this.applyColumnWidthToDisplay();
            this.refreshVisibleSelection();

        end

        function applyColumnWidthToDisplay(this)
            % Push the current visible column widths to the display table.
            %
            % Setting DisplayTable.ColumnWidth causes DOM-level column resize
            % events, which would otherwise be picked up by the bridge and
            % incorrectly reported as user-driven changes.  We pause the
            % bridge for a short window (longer than its debounce delay) to
            % prevent that feedback loop.
            this.pauseColumnWidthBridge();

            if isempty(this.DataColumnWidth_)
                % Widths cleared or never set — restore display to "auto"
                if ~isequal(this.DisplayTable.ColumnWidth, "auto")
                    this.DisplayTable.ColumnWidth = "auto";
                end
            else
                visWidths = this.DataColumnWidth_(this.ColumnVisible);
                if ~isequal(this.DisplayTable.ColumnWidth, visWidths)
                    this.DisplayTable.ColumnWidth = visWidths;
                end
            end
        end

        function pauseColumnWidthBridge(this)
            % Tell the bridge to ignore resize events for a short window.
            % Also set the MATLAB-side flag as a belt-and-braces guard.
            this.IsPushingWidthToDisplay_ = true;
            pauseMs = 500; % must exceed the bridge's DEBOUNCE_MS (200 ms)
            if ~isempty(this.ColumnWidthBridge_)
                sendEventToHTMLSource(this.ColumnWidthBridge_, "Pause", ...
                    struct("durationMs", pauseMs));
            end
            % Clear the MATLAB flag after the same window.
            t = timer("StartDelay", pauseMs/1000, "ExecutionMode", "singleShot", ...
                "TimerFcn", @(~,~) this.clearPushingFlag());
            start(t);
        end

        function clearPushingFlag(this)
            this.IsPushingWidthToDisplay_ = false;
        end

        function updateDisplayTable(this, vars)

            toUpdate = {};
            for i = 1:numel(vars)

                % Allow variable mapping, e.g. DisplayData -> Data
                currentVar = vars(i);

                % Only update values that have changed
                newVal = this.(currentVar);

                if currentVar == "VisibleData"
                    % TODO: Make this a different step in the update

                    % The .DisplayData for the table widget is the .Data
                    % for the uitable
                    currentVal = this.DisplayTable.DisplayData;

                    % Reorder/hide columns, keeping track of the group
                    % headers to make sure they aren't removed
                    if width(newVal) ~= 0
                        visColumns = this.VisibleDataColumnNames;
                        idx = ismember(newVal.Properties.VariableNames, visColumns);

                        firstIdx = find(idx, 1);

                        if (isempty(firstIdx) || firstIdx ~= 1) && ~isempty(this.GroupingVariable)
                            % Take a copy of the row headers so they can be
                            % restored if the first column is removed
                            vghri = this.VisibleGroupHeaderRowIdx;
                            rowHeaders = newVal{vghri, 1};
                            if isempty(rowHeaders)
                                % When there are no groups and the table is
                                % empty, the row header array has the wrong
                                % size (0,0), rather than (0,1)
                                rowHeaders = string.empty(0,1);
                            end

                            if isempty(firstIdx)
                                % Retain group headers if all columns are hidden
                                newVal = table(repelem("Hidden Item", height(newVal), 1), 'VariableNames', "Group");
                                newVal{vghri, 1} = num2cell(rowHeaders);
                            else
                                % Restore the group headers in the first
                                % column

                                % Remove hidden columns
                                newVal = newVal(:, idx);

                                if ~isstring(newVal{:, 1})
                                    if ~iscell(newVal{:, 1})
                                        newVal = convertvars(newVal, 1, "cell");
                                    end
                                    newVal{vghri, 1} = num2cell(rowHeaders);
                                else
                                    newVal{vghri, 1} = rowHeaders;
                                end

                            end

                        else
                            % Remove hidden columns
                            newVal = newVal(:, idx);
                        end

                    end

                    % Apply aliasing to non-group variables
                    newValVarNames = string(newVal.Properties.VariableNames);
                    newValVarNames = this.translateNames(newValVarNames);
                    newVal.Properties.VariableNames = newValVarNames;

                    newVar = "Data";
                else
                    currentVal = this.DisplayTable.(currentVar);
                    newVar = currentVar;
                end

                if ~isequal(currentVal, newVal)
                    toUpdate = [toUpdate, {newVar, newVal}]; %#ok<AGROW>
                end
            end

            if ~isempty(toUpdate)
                set(this.DisplayTable, toUpdate{:});
            end
        end

    end

    % From gwidgets.internal.Reparentable
    methods (Access = protected)

        function reactToFigureChanged(this)
            this.reparentContextMenu();
        end

    end

    % Column-width bridge
    methods (Access = private)

        function setupColumnWidthBridge(this)
            % Create a tiny (2 px tall) uihtml component that uses a
            % ResizeObserver in the figure's web context to detect when the
            % user drags a column divider and report the new pixel widths
            % back to MATLAB.  The component lives in row 4 of this.Grid,
            % which has a fixed height of 2 px so it is effectively invisible.

            % Assign a unique tag to the uitable so the bridge JS can scope
            % its DOM query to this table specifically (avoids cross-talk
            % when multiple Table widgets live in the same figure).
            this.DisplayTableTag_ = "GwidgetsTable_" + mlut.uniqueID();
            this.DisplayTable.Tag  = this.DisplayTableTag_;

            htmlFile = fullfile(fileparts(mfilename("fullpath")), ...
                "+internal", "column_width_bridge.html");

            this.ColumnWidthBridge_ = uihtml( ...
                "Parent",       this.Grid, ...
                "HTMLSource",   htmlFile, ...
                "DataChangedFcn", @(src,~) this.onBridgeData(src));
            this.ColumnWidthBridge_.Layout.Row    = 4;
            this.ColumnWidthBridge_.Layout.Column = 1;

            % Do NOT call sendEventToHTMLSource here — the HTML page loads
            % asynchronously.  The JS sets Data = {event:"BridgeReady"} once
            % setup() completes, and onBridgeData responds with Init.
        end

        function onBridgeData(this, src)
            % Dispatcher: JS -> MATLAB channel uses htmlComponent.Data = {...}
            % which triggers DataChangedFcn.  Route on the 'event' field.
            d = src.Data;
            if ~isstruct(d) || ~isfield(d, "event")
                return
            end

            switch d.event

                case "BridgeReady"
                    % setup() has run — safe to send Init now.
                    sendEventToHTMLSource(this.ColumnWidthBridge_, "Init", ...
                        struct("tableTag", this.DisplayTableTag_));

