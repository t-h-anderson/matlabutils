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

        ColumnWidth (1,:) % Mixed pixel/relative widths for visible columns ({100, "2x", ...})
        DataColumnWidth (1,:) % Mixed pixel/relative widths for all data columns
        DefaultColumnWidths (1,:) % Default column widths restored when ColumnWidth is reset to {}

        % Per-column width details (all data columns)
        PixelDataColumnWidths  (1,:) double  % Pixel width per data column (NaN for Relative until bridge resolves)
        RelativeDataColumnWidths (1,:) string % Relative weight per data column (missing for Pixel until bridge resolves)
        DataColumnWidthTypes   (1,:) string  % Width type per data column: "Pixel" or "Relative"

        % Per-column width details (visible columns only)
        PixelColumnWidths   (1,:) double  % Pixel width per visible column (NaN for Relative until bridge resolves)
        RelativeColumnWidths (1,:) string  % Relative weight per visible column
        ColumnWidthTypes    (1,:) string   % Width type per visible column: "Pixel" or "Relative"

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

        % Column-width stores — three parallel arrays aligned to DataColumnNames.
        % DataColumnWidthTypes_ is the "truth"; the other two are both updated on
        % every graphical update (bridge → MATLAB) so callers can query either
        % representation.  Empty arrays mean "all 1x Relative" (default state).
        PixelDataColumnWidths_    (1,:) double  % Pixel widths; NaN for Relative cols until bridge resolves
        RelativeDataColumnWidths_ (1,:) string  % "Nx" weights; missing for Pixel cols until bridge resolves
        DataColumnWidthTypes_     (1,:) string  % "Pixel" | "Relative" per column; empty = all Relative

        DefaultColumnWidths_ (1,:) cell % Default column widths restored when ColumnWidth is reset to {}

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
            val = this.buildMixedWidthCell(true(1, numel(this.DataColumnNames)));
        end

        function set.DataColumnWidth(this, val)
            val = gwidgets.Table.normalizeColumnWidths(val);
            nData = numel(this.DataColumnNames);
            if isscalar(val)
                val = repelem(val, 1, nData);
            end
            if ~isempty(val) && numel(val) ~= nData
                error("GraphicsWidgets:Table:DataColumnWidthSize", ...
                    "Size of DataColumnWidth must match the number of data columns, be scalar, or be empty (restore to default)");
            end
            this.setColumnWidthStores(val, true(1, nData));
            if this.UpdateManager.doRun("DataColumnWidth")
                this.doUpdateSequence(StartFrom="Interaction");
            end
        end

        function val = get.DefaultColumnWidths(this)
            val = this.DefaultColumnWidths_;
            val = convertCharsToStrings(val);
            if ~iscell(val)
                val = num2cell(val);
            end
            val = gwidgets.Table.normalizeColumnWidths(val);
        end

        function set.DefaultColumnWidths(this, val)
            val = gwidgets.Table.normalizeColumnWidths(val);
            if isscalar(val)
                val = repelem(val, 1, numel(this.DataColumnNames));
            end
            if ~isempty(val) && numel(val) ~= numel(this.DataColumnNames)
                error("GraphicsWidgets:Table:DefaultColumnWidthsSize", ...
                    "Size of DefaultColumnWidths must match the number of data columns, be scalar, or be empty");
            end
            this.DefaultColumnWidths_ = val;
        end

        function val = get.ColumnWidth(this)
            val = this.buildMixedWidthCell(this.ColumnVisible);
        end

        function set.ColumnWidth(this, val)
            val = gwidgets.Table.normalizeColumnWidths(val);
            nData = numel(this.DataColumnNames);

            if isempty(val)
                % Empty resets to DefaultColumnWidths if set, otherwise all "1x" Relative
                if ~isempty(this.DefaultColumnWidths_)
                    defVal = gwidgets.Table.normalizeColumnWidths(this.DefaultColumnWidths_);
                    this.setColumnWidthStores(defVal, true(1, nData));
                else
                    this.resetToDefaultWidths();
                end
            else
                if isscalar(val)
                    val = repelem(val, 1, sum(this.ColumnVisible));
                end
                if numel(val) ~= sum(this.ColumnVisible)
                    error("GraphicsWidgets:Table:ColumnWidthSize", ...
                        "Size of ColumnWidth must match the number of visible columns, be scalar, or be empty (restore to default)");
                end
                % Map visible widths into the per-data-column stores,
                % preserving the stored widths of hidden columns.
                this.setColumnWidthStores(val, this.ColumnVisible);
            end

            if this.UpdateManager.doRun("DataColumnWidth")
                this.doUpdateSequence(StartFrom="Interaction");
            end
        end

        % ---- New width-detail getters (read-only, derived from backing stores) ----

        function val = get.PixelDataColumnWidths(this)
            val = this.resolvedPixelWidths(true(1, numel(this.DataColumnNames)));
        end

        function val = get.PixelColumnWidths(this)
            val = this.resolvedPixelWidths(this.ColumnVisible);
        end

        function val = get.RelativeDataColumnWidths(this)
            val = this.resolvedRelativeWidths(true(1, numel(this.DataColumnNames)));
        end

        function val = get.RelativeColumnWidths(this)
            val = this.resolvedRelativeWidths(this.ColumnVisible);
        end

        function val = get.DataColumnWidthTypes(this)
            val = this.resolvedTypes(true(1, numel(this.DataColumnNames)));
        end

        function val = get.ColumnWidthTypes(this)
            val = this.resolvedTypes(this.ColumnVisible);
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
                this (1,1) %#ok<INUSA>
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
        HasAutoResizeColumns (1,1) logical
    end

    properties (Access = protected)
        CustomContextMenuItems_ (1,:) matlab.ui.container.Menu = matlab.ui.container.Menu.empty(1,0)
        SupportedSelectionTypes_ (1,:) string {mustBeMember(SupportedSelectionTypes_, ["cell", "row", "column"])}= "cell"
        HasToggleFilter_ (1,1) logical = false
        HasChangeGroupingVariable_ (1,1) logical = false
        HasToggleShowEmptyGroups_ (1,1) logical = false
        HasColumnSorting_ (1,1) logical = false
        HasAutoResizeColumns_ (1,1) logical = false
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

        function val = get.HasAutoResizeColumns(this)
            val = this.HasAutoResizeColumns_;
        end

        function set.HasAutoResizeColumns(this, val)
            this.HasAutoResizeColumns_ = val;
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

        BridgeDiagEnabled (1,1) logical % Enable JS bridge diagnostic output
    end

    properties (Hidden)
        VisibleGroupHeaderRowIdx (1,:) double % (1,nVisGroups) Indices of header rows
        
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

        GroupFilteredCount (1,:) double % (1,nGroups) Group filtered counts
        
        % Bridge diagnostics
        BridgeDiagEnabled_ (1,1) logical = false % Enable JS bridge diagnostic output

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

            idx = ~ismember(val, this.HiddenGroups_);
            val = val(idx);
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
            idx = ismember(this.DisplayGroups, this.OpenGroups);
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

        function set.BridgeDiagEnabled(this, val)
            this.toggleBridgeDiag(val);
        end

        function val = get.BridgeDiagEnabled(this)
            val = this.BridgeDiagEnabled_;
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

        function toggleBridgeDiag(this, val)
            this.BridgeDiagEnabled_ = val;
            if ~isempty(this.ColumnWidthBridge_)
                sendEventToHTMLSource(this.ColumnWidthBridge_, "Diag", val);
            end
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
            this.setupColumnWidthBridge();
            this.doUpdateSequence();
        end

        function updateDisplayData(this)

            vars = [...
                "VisibleData" ...
                ];

            this.updateDisplayTable(vars);

            % Apply column widths immediately so Data and ColumnWidth stay
            % in sync — avoids MATLAB rendering the new (shorter) column
            % list with the old positional widths before updateInteraction runs.
            this.applyColumnWidthToDisplay();
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
            % Suppress is sent first (bridge also self-suppresses on mouseup),
            % so ResizeObserver echoes — including the snap-back that fires when
            % the drag handler releases its px constraints — are silently dropped.

            % The Auto flush resets MATLAB's internal column-type metadata so
            % relative weights are correctly re-applied after each drag.
            % drawnow flushes both ColumnWidth DOM updates before Restore
            % is queued.  This ensures attachObserver (called from Restore) sees
            % the settled DOM rather than the stale snap-back widths.  drawnow is
            % safe here because the bridge self-suppresses on mouseup, so the
            % snap-back never reaches MATLAB's DataChangedFcn queue.
            this.sendSuppressToBridge();
            visWidths = this.buildMixedWidthCell(this.ColumnVisible);
            if ~isequal(this.DisplayTable.ColumnWidth, visWidths)
                if isempty(visWidths)
                    visWidths = {"Auto"};
                end
                this.DisplayTable.ColumnWidth = {"Auto"};
                this.forceRefresh();
                this.DisplayTable.ColumnWidth = visWidths;
            end
            this.sendRestoreToBridge();
        end

        % ---- Column-width store helpers ----------------------------------------

        function setColumnWidthStores(this, val, mask)
            % Parse a cell array of widths into the three backing stores.
            %
            % val  – cell array of widths for the columns selected by mask.
            %        Each element is either a positive numeric (Pixel) or a
            %        string "Nx" (Relative).  Empty cell resets all masked
            %        columns to "1x" Relative.
            % mask – logical row vector over all data columns.
            nData = numel(this.DataColumnNames);
            types = this.extendStore(this.DataColumnWidthTypes_, "Relative", nData);
            px    = this.extendStore(this.PixelDataColumnWidths_, NaN,       nData);
            rel   = this.extendStore(this.RelativeDataColumnWidths_, "1x",   nData);

            maskIdxs = find(mask);
            if isempty(val)
                % Reset masked columns to "1x" Relative
                types(mask) = "Relative";
                px(mask)    = NaN;
                rel(mask)   = "1x";
            else
                for k = 1:numel(val)
                    i = maskIdxs(k);
                    v = val{k};
                    if isnumeric(v) && isscalar(v) && v > 0
                        types(i) = "Pixel";
                        px(i)    = v;
                        rel(i)   = string(missing);  % resolved by bridge later
                    else
                        types(i) = "Relative";
                        px(i)    = NaN;
                        rel(i)   = string(v);  % e.g. "1x", "2x"
                    end
                end
            end
            this.DataColumnWidthTypes_     = types;
            this.PixelDataColumnWidths_    = px;
            this.RelativeDataColumnWidths_ = rel;
        end

        function resetToDefaultWidths(this)
            % Reset all columns to "1x" Relative (the "unset" state).
            nData = numel(this.DataColumnNames);
            this.DataColumnWidthTypes_     = repelem("Relative", 1, nData);
            this.PixelDataColumnWidths_    = nan(1, nData);
            this.RelativeDataColumnWidths_ = repelem("1x", 1, nData);
        end

        function changed = updateStoresFromBridgeWidths(this, pixelWidths)
            % Process actual positive pixel widths from the bridge.
            %
            % Updates PixelDataColumnWidths_ for all visible columns, then
            % recomputes RelativeDataColumnWidths_ for every column (including
            % hidden) using the GCD of all finite pixel widths.
            % DataColumnWidthTypes_ is never modified here.
            % Returns true when any stored value changed.
            nVisible = sum(this.ColumnVisible);
            if numel(pixelWidths) ~= nVisible
                this.onBridgeReattachNeeded();
                changed = false;
                return
            end

            nData   = numel(this.DataColumnNames);
            visIdxs = find(this.ColumnVisible);
            px      = this.extendStore(this.PixelDataColumnWidths_, NaN,  nData);
            rel     = this.extendStore(this.RelativeDataColumnWidths_, "1x", nData);

            for k = 1:nVisible
                px(visIdxs(k)) = pixelWidths(k);
            end

            % Recompute GCD-normalised relative weights for all columns that
            % have a resolved pixel width (visible or hidden).
            g = gwidgets.Table.gcdPixelWidths(px);
            for i = 1:nData
                if ~isnan(px(i)) && px(i) > 0
                    rel(i) = string(round(px(i) / g)) + "x";
                end
            end

            changed = ~isequaln(px,  this.PixelDataColumnWidths_) || ...
                      ~isequaln(rel, this.RelativeDataColumnWidths_);
            this.PixelDataColumnWidths_    = px;
            this.RelativeDataColumnWidths_ = rel;
        end

        function val = buildMixedWidthCell(this, mask)
            % Build a cell array of column widths for the columns given by mask.
            % "Pixel" columns → numeric pixel value.
            % "Relative" columns → "Nx" string (or "1x" if not yet resolved).
            nData   = numel(this.DataColumnNames);
            nResult = sum(mask);
            if nResult == 0
                val = {};
                return
            end
            types = this.extendStore(this.DataColumnWidthTypes_, "Relative", nData);
            px    = this.extendStore(this.PixelDataColumnWidths_, NaN,       nData);
            rel   = this.extendStore(this.RelativeDataColumnWidths_, "1x",   nData);
            maskIdxs = find(mask);
            val = cell(1, nResult);
            for k = 1:nResult
                i = maskIdxs(k);
                if types(i) == "Pixel"
                    val{k} = px(i);
                else
                    r = rel(i);
                    if ismissing(r) || r == ""
                        val{k} = "1x";
                    else
                        val{k} = r;
                    end
                end
            end
        end

        function val = resolvedPixelWidths(this, mask)
            nData   = numel(this.DataColumnNames);
            px      = this.extendStore(this.PixelDataColumnWidths_, NaN, nData);
            val     = px(mask);
        end

        function val = resolvedRelativeWidths(this, mask)
            nData = numel(this.DataColumnNames);
            rel   = this.extendStore(this.RelativeDataColumnWidths_, "1x", nData);
            val   = rel(mask);
        end

        function val = resolvedTypes(this, mask)
            nData = numel(this.DataColumnNames);
            val   = this.extendStore(this.DataColumnWidthTypes_, "Relative", nData);
            val   = val(mask);
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
            this.DisplayTableTag_ = "graphicscomponentsTable_" + gwidgets.internal.uniqueID();
            this.DisplayTable.Tag  = this.DisplayTableTag_;

            htmlFile = fullfile(fileparts(mfilename("fullpath")), ...
                "+internal", ...
                "column_width_bridge.html");

            this.ColumnWidthBridge_ = uihtml( ...
                "Parent",       this.Grid, ...
                "HTMLSource",   htmlFile, ...
                "DataChangedFcn", @(src,~) this.onBridgeData(src), ...
                "Visible","off");

            this.ColumnWidthBridge_.Layout.Row    = 4;
            this.ColumnWidthBridge_.Layout.Column = 1;

            % Enforce default in JS
            this.BridgeDiagEnabled = this.BridgeDiagEnabled;

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
                    % setup() has run — send Init then Ready so the bridge
                    % attaches its ResizeObserver to the (already-rendered) table.
                    sendEventToHTMLSource(this.ColumnWidthBridge_, "Init", ...
                        struct("tableTag", this.DisplayTableTag_));
                    sendEventToHTMLSource(this.ColumnWidthBridge_, "Diag", this.BridgeDiagEnabled);
                    this.sendReadyToBridge();

                case "ColumnWidthChanged"
                    % Bridge fires on every ResizeObserver callback.
                    % Ignore mid-drag (moving=true) events — only process the
                    % settled value when the user releases the mouse.
                    if isfield(d, "moving") && d.moving
                        return
                    end

                    % If the incoming widths match PixelDataColumnWidths_ (within
                    % 1 px browser-rounding tolerance) the event was caused by
                    % MATLAB's own CSS settling — ignore it to avoid a loop.
                    % Otherwise it is a genuine user-initiated change; update
                    % stores and re-apply so the display reflects the new state.
                    if this.didBridgeWidthsChange(d.widths)
                        this.updateStoresFromBridgeWidths(d.widths);
                        this.applyColumnWidthToDisplay();
                    else
                        % Drag produced no net width change, but the bridge
                        % self-suppressed on mouseup.  Re-enable callbacks.
                        this.sendRestoreToBridge();
                    end

                case "BridgeDiag"
                    fprintf("%s\n", d.msg);

            end
        end

        function onBridgeReattachNeeded(this)
            % Column count mismatch — tell bridge to re-attach to current DOM.
            this.sendReadyToBridge();
        end

        function sendSuppressToBridge(this)
            % Tell the bridge to stop reporting ColumnWidthChanged events.
            % Queue this before DisplayTable.ColumnWidth changes so the
            % ResizeObserver echo during our own DOM update is silently dropped.
            if isempty(this.ColumnWidthBridge_), return; end
            sendEventToHTMLSource(this.ColumnWidthBridge_, "Suppress", []);
        end

        function sendRestoreToBridge(this)
            % Tell the bridge to re-enable reporting and re-enable
            % ColumnWidthChanged callbacks.

            if isempty(this.ColumnWidthBridge_), return; end
            sendEventToHTMLSource(this.ColumnWidthBridge_, "Restore", []);
        end

        function sendReadyToBridge(this)
            % Signal the bridge to (re-)attach its ResizeObserver once the
            % table DOM has settled.
            if isempty(this.ColumnWidthBridge_), return; end
            sendEventToHTMLSource(this.ColumnWidthBridge_, "Ready", []);
        end

    end

    % Test hooks — accessible to matlab.unittest.TestCase but not public API
    methods (Access = ?matlab.unittest.TestCase)

        function simulateBridgeDrag(this, pixelWidths)
            % Simulate a ColumnWidthChanged notification from the bridge
            % without requiring a live DOM/figure.
            % pixelWidths: positive pixel widths for all visible columns.
            this.updateStoresFromBridgeWidths(pixelWidths);
            this.applyColumnWidthToDisplay();
        end

        function changed = didBridgeWidthsChange(this, incomingPx)
            % Return true when the incoming pixel widths differ from the stored
            % PixelDataColumnWidths_ by more than 1 px (browser-rounding
            % tolerance).  NaN in the store (Relative column not yet resolved)
            % is always treated as changed so the first report is processed.
            nData  = numel(this.DataColumnNames);
            nVis   = sum(this.ColumnVisible);
            if numel(incomingPx) ~= nVis
                changed = false;   % count mismatch — updateStoresFromBridgeWidths handles it
                return
            end
            visIdxs = find(this.ColumnVisible);
            px = this.extendStore(this.PixelDataColumnWidths_, NaN, nData);
            for k = 1:nVis
                stored = px(visIdxs(k));
                if isnan(stored) || abs(stored - incomingPx(k)) > 1
                    changed = true;
                    return
                end
            end
            changed = false;
        end

    end

    % Selection manipulation
    methods (Access = protected)

        function clearSelection(this)
            switch this.SelectionType
                case "cell"
                    this.Selection_ = zeros(0,2);
                otherwise
                    this.Selection_ = zeros(1,0);
            end
        end

        function dataIdxs =  displaySelectionToDataSelection(this, visibleIdxs, type)
            % displaySelectionToDataSelection Maps display selection to
            %   data selection
            arguments
                this
                visibleIdxs
                type (1,1) string {mustBeMember(type, ["cell", "row", "column"])} = this.SelectionType
            end
            if isempty(visibleIdxs)
                dataIdxs = visibleIdxs;
                return
            end

            switch type
                case "cell"
                    rowIdxs = visibleIdxs(:,1);
                    colIdxs = visibleIdxs(:,2);
                case "row"
                    rowIdxs = visibleIdxs;
                    colIdxs = zeros(size(rowIdxs));
                case "column"
                    colIdxs = visibleIdxs;
                    rowIdxs = zeros(size(colIdxs));
                otherwise
                    error("Selection must be a matrix with two columns for cell selection, or a row vector for column/row selection")
            end

            % Map rows
            if ~any(ismissing(rowIdxs)) && any(rowIdxs ~= 0)
                rowIdxs = this.FoldedVisibleToDataMap(rowIdxs)';
                noDataIdx = ismissing(rowIdxs);

                rowIdxs(noDataIdx) = NaN;
                colIdxs(noDataIdx) = NaN;
            end

            % Map columns
            % Remove hidden and group columns, reorder if necessary
            visibleCols = this.VisibleColumnNames;
            visibleCols(ismember(visibleCols, this.GroupingVariable)) = [];
            dataCols = this.DataColumnNames;

            for i = 1:numel(colIdxs)
                colIdx = colIdxs(i);
                if ~ismissing(colIdx) && colIdx ~= 0
                    thisCol = visibleCols(colIdx);
                    idx = find(dataCols == thisCol, 1);
                    if isempty(idx)
                        idx = NaN;
                    end
                    colIdxs(i) = idx;
                end
            end

            % Remove missing selection
            colIdxs = reshape(colIdxs, [], 1);
            rowIdxs = reshape(rowIdxs, [], 1);
            idx = ismissing(rowIdxs) | ismissing(colIdxs);
            rowIdxs(idx) = [];
            colIdxs(idx) = [];

            switch type
                case "cell"
                    rowIdxs = reshape(rowIdxs, [], 1);
                    colIdxs = reshape(colIdxs, [], 1);
                    dataIdxs = [rowIdxs, colIdxs];
                    if isempty(dataIdxs)
                        dataIdxs = zeros(0,2);
                    end
                case "row"
                    dataIdxs = reshape(rowIdxs, 1, []);
                    dataIdxs(dataIdxs==0) = [];
                case "column"
                    dataIdxs = reshape(colIdxs, 1, []);
                    dataIdxs(dataIdxs==0) = [];
            end

        end

        function visibleIdxs = dataSelectionToDisplaySelection(this, dataIdxs, type)
            % dataSelectionToDisplaySelection Maps data selection to
            %   display selection
            arguments
                this
                dataIdxs
                type (1,1) string {mustBeMember(type, ["cell", "row", "column", "table"])} = this.SelectionType
            end

            if isempty(dataIdxs)
                visibleIdxs = dataIdxs;
                return
            end

            switch type
                case "cell"
                    rowIdxs = dataIdxs(:,1)';
                    colIdxs = dataIdxs(:,2)';
                case "row"
                    assert(isvector(dataIdxs), "GraphicsWidgets:Table:IncorrectSelectionSize", ...
                        "Selection must be a vector for row selection");
                    rowIdxs = reshape(dataIdxs, 1, []);
                    colIdxs = zeros(size(rowIdxs));
                case "column"
                    assert(isvector(dataIdxs), "GraphicsWidgets:Table:IncorrectSelectionSize", ...
                        "Selection must be a vector for column selection");
                    colIdxs = reshape(dataIdxs, 1, []);
                    rowIdxs = zeros(size(colIdxs));
            end

            % Check for out of range indices
            rowsInRange = all(rowIdxs >= 1 & rowIdxs <= numel(this.FilteredDataToVisibleMap));
            colsInRange = all(colIdxs >= 1 & colIdxs <= size(this.Data_, 2));

            checkRowsInRange = type ~= "column" && ~any(ismissing(rowIdxs));
            checkColsInRange = type ~= "row" && ~any(ismissing(colIdxs));

            if (checkRowsInRange && ~rowsInRange) ...
                    || (checkColsInRange && ~colsInRange)
                error("GraphicsWidgets:Table:SelectionOutOfRange", ...
                    "Selection outside data range");
            elseif isempty(this.FoldedDataToVisibleMap)
                % Map not yet initialized - table not rendered yet
                % Return empty with correct dimensions
                switch type
                    case "cell"
                        visibleIdxs = zeros(0,2);
                    case "row"
                        visibleIdxs = zeros(1,0);
                    case "column"
                        % No change needed as columns not affected by
                        % folding
                        visibleIdxs = colIdxs;
                end
            else
                % Map rows
                if ~any(ismissing(rowIdxs)) && any(rowIdxs ~= 0)
                    rowIdxs = this.FoldedDataToVisibleMap(rowIdxs);
                    noDataIdxs = ismissing(rowIdxs);
                    colIdxs(noDataIdxs) = [];
                    rowIdxs(noDataIdxs) = [];
                end

                % Map columns
                % Remove hidden and group columns, reorder if necessary
                visibleCols = this.VisibleDataColumnNames;
                visibleCols(ismember(visibleCols, this.GroupingVariable)) = [];
                dataCols = this.DataColumnNames;
                for i = 1:numel(colIdxs)
                    colIdx = colIdxs(i);
                    if ~ismissing(colIdx) && colIdx ~= 0
                        thisCol = dataCols(colIdx);
                        matchingColIdx = find(visibleCols == thisCol,1);
                        if isempty(matchingColIdx)
                            matchingColIdx = NaN;
                        end
                        colIdxs(i) = matchingColIdx;
                    end
                end

                % Remove missing selection
                idx = ismissing(rowIdxs) | ismissing(colIdxs);
                rowIdxs(idx) = [];
                colIdxs(idx) = [];

                switch type
                    case "cell"
                        rowIdxs = reshape(rowIdxs, [], 1);
                        colIdxs = reshape(colIdxs, [], 1);
                        visibleIdxs = [rowIdxs, colIdxs];
                        if isempty(visibleIdxs)
                            visibleIdxs = zeros(0,2);
                        end
                    case "row"
                        visibleIdxs = rowIdxs;
                        visibleIdxs(visibleIdxs==0) = [];
                        if isempty(visibleIdxs)
                            visibleIdxs = zeros(1,0);
                        end
                    case "column"
                        visibleIdxs = colIdxs;
                        visibleIdxs(visibleIdxs==0) = [];
                        if isempty(visibleIdxs)
                            visibleIdxs = zeros(1,0);
                        end
                end

            end

        end

        function refreshVisibleSelection(this)
            % Only update DisplayTable if it exists and table is initialized
            if isempty(this.DisplayTable) || isempty(this.FoldedDataToVisibleMap)
                return
            end

            selection = this.Selection_;
            if this.SelectionMode == "Data"
                selection = this.dataSelectionToDisplaySelection(selection);
            end

            % Set flag to prevent callback recursion
            this.IsSettingSelectionProgrammatically = true;
            try
                this.DisplayTable.Selection = selection;
            catch ME
                % May fail if the data has changed shape so the selection
                % is not longer valid
                this.DisplayTable.Selection = [];
            end
            this.IsSettingSelectionProgrammatically = false;

            this.forceRefresh();
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
                %updating = true;
            end

            this.forceRefresh();
        end

        function addContextMenu(this)

            % Save the custom context menu items
            for i = 1:numel(this.CustomContextMenuItems)
                [this.CustomContextMenuItems.Parent] = deal([]);
                [this.CustomContextMenuItems.Tag] = deal("graphicscomponentsTableContextMenu");
            end

            % Delete the existing context menu and remake it to all changes
            % in state
            if ~isempty(this.ContextMenu) && isvalid(this.ContextMenu)
                delete(this.ContextMenu);
            end

            fh = ancestor(this.DisplayTable, "figure");
            this.ContextMenu = uicontextmenu("Parent", fh, "Tag", "graphicscomponentsTableContextMenu");

            if this.HasChangeGroupingVariable || this.HasToggleShowEmptyGroups
                m = uimenu("Parent", this.ContextMenu, "Text", "Grouping", "Tag", "graphicscomponentsTableContextMenu");
                if this.HasChangeGroupingVariable
                    uimenu("Parent", m, "Text", "Group", "MenuSelectedFcn", @(s,e) this.onGroupByRequest(s,e), "Tag", "graphicscomponentsTableContextMenu");
                    uimenu("Parent", m, "Text", "Ungroup", "MenuSelectedFcn", @(s,e) this.onUngroupByRequest(s,e), "Tag", "graphicscomponentsTableContextMenu");
                end
                if this.HasToggleShowEmptyGroups
                    uimenu("Parent", m, "Text", "Show/hide empty groups", "MenuSelectedFcn", @(s,e) this.onToggleShowEmptyGroupsRequest(s,e), "Tag", "graphicscomponentsTableContextMenu");
                end
            end

            if this.HasColumnSorting && any(this.ColumnSortable)
                m = uimenu("Parent", this.ContextMenu, "Text", "Sort", "Tag", "graphicscomponentsTableContextMenu");
                uimenu("Parent", m, "Text", "Ascending", "MenuSelectedFcn", @(s,e) this.onSortByRequest(s,e, "Ascend"), "Tag", "graphicscomponentsTableContextMenu");
                uimenu("Parent", m, "Text", "Descending", "MenuSelectedFcn", @(s,e) this.onSortByRequest(s,e, "Descend"), "Tag", "graphicscomponentsTableContextMenu");
                uimenu("Parent", m, "Text", "None", "MenuSelectedFcn", @(s,e) this.onSortByRequest(s,e, "None"), "Tag", "graphicscomponentsTableContextMenu");
            end

            if numel(this.SupportedSelectionTypes) > 1
                m = uimenu("Parent", this.ContextMenu, "Text", "Selection Mode", "Tag", "graphicscomponentsTableContextMenu");
                if contains("cell", this.SupportedSelectionTypes)
                    uimenu("Parent", m, "Text", "Cell", "MenuSelectedFcn", @(s,e) this.onCellSelectionRequest(s,e), "Tag", "graphicscomponentsTableContextMenu");
                end

                if contains("row", this.SupportedSelectionTypes)
                    uimenu("Parent", m, "Text", "Row", "MenuSelectedFcn", @(s,e) this.onRowSelectionRequest(s,e), "Tag", "graphicscomponentsTableContextMenu");
                end

                if contains("column", this.SupportedSelectionTypes)
                    uimenu("Parent", m, "Text", "Column", "MenuSelectedFcn", @(s,e) this.onColumnSelectionRequest(s,e), "Tag", "graphicscomponentsTableContextMenu");
                end
            end

            if this.HasToggleFilter
                uimenu("Parent", this.ContextMenu, "Text", "Show/hide row filter", "MenuSelectedFcn", @(s,e) this.onToggleRowFilterRequest(s,e), "Tag", "graphicscomponentsTableContextMenu");
            end

            if this.HasAutoResizeColumns
                uimenu("Parent", this.ContextMenu, "Text", "Auto-resize columns", "MenuSelectedFcn", @(s,e) this.onAutoResizeColumnsRequest(s,e), "Tag", "graphicscomponentsTableContextMenu");
            end

            if this.HasAutoResizeColumns
                uimenu("Parent", this.ContextMenu, "Text", "Auto-resize columns", "MenuSelectedFcn", @(s,e) this.onAutoResizeColumnsRequest(s,e), "Tag", "GWidgetsTableContextMenu");
            end

            for i = 1:numel(this.CustomContextMenuItems)
                this.CustomContextMenuItems(i).Parent = this.ContextMenu;
            end

            this.DisplayTable.ContextMenu = this.ContextMenu;

        end

        function reparentContextMenu(this)
            fh = ancestor(this, "figure");
            this.ContextMenu.Parent = fh;
        end

        function updateGroupLabel(this)

            nGroups = numel(this.Groups);
            nGroupsVisible = numel(this.VisibleGroupHeaderRowIdx);

            % Replace each grouping variable name with its alias, then join
            groupingVariableName = strjoin(this.translateNames(this.GroupingVariable_), "|");
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

        function forceRefresh(~)
            % Force a refresh
            pause(0);
            drawnow limitrate
        end
    end

    % Filtering update
    methods (Access = protected)

        function updateFiltering(this)

            data = this.Data_;

            % Filter based on aliases - lengths can be assumed to be
            % correct due to set methods
            if ~isempty(this.ColumnNames)
                data.Properties.VariableNames = this.ColumnNames;
            end
            [data, idx] = this.FilterController.applyFilter(data, this.Filter);

            % Underlying data should use actual data names
            data.Properties.VariableNames = this.DataColumnNames;

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
            if isempty(this.GroupingVariable)
                this.GroupedVisibleData = table2cell(this.FilteredData);
                this.GroupedDataVariables = string(this.FilteredData.Properties.VariableNames);
                this.Groups = string.empty(1,0);
                this.GroupHeaderRowIdx = zeros(1,0);
                this.GroupColumnIdx = zeros(1,0);
                this.GroupFilteredCount = zeros(1,0);
                this.GroupIdxs = zeros(1,0);

                this.GroupedDataToVisibleMap = this.FilteredDataToVisibleMap;
                this.GroupedVisibleToDataMap = this.FilteredVisibleToDataMap;
            else
                g = this.GroupingVariable;
                this.GroupColumnIdx = ismember(this.Data_.Properties.VariableNames, g);

                if numel(g) > 1
                    allGroupVars = arrayfun(@(x) this.Data_.(x), g, "UniformOutput", false);
                    allGroupVars = cellfun(@(x) string(x), allGroupVars, 'UniformOutput', false);
                    allGroupVars = join([allGroupVars{:}], "|", 2);
                else
                    % Use all data so filtered groups are known
                    allGroupVars = this.Data_.(g);
                end

                if isempty(allGroupVars)
                    groupIdxs = zeros(1,0);
                    allGroups = allGroupVars;
                else
                    [groupIdxs, allGroups] = findgroups(allGroupVars);
                end

                this.Groups = allGroups;
                this.GroupIdxs = groupIdxs;

                if numel(g) > 1
                    filteredGroupVars = arrayfun(@(x) this.FilteredData.(x), g, "UniformOutput", false);
                    filteredGroupVars = cellfun(@(x) string(x), filteredGroupVars, 'UniformOutput', false);
                    filteredGroupVars = join([filteredGroupVars{:}], "|", 2);
                else
                    filteredGroupVars = this.FilteredData.(g);
                end

                tmpData = this.FilteredData;

                idx = ismember(tmpData.Properties.VariableNames, g);
                groupedDataVariables = string(tmpData.Properties.VariableNames(~idx));
                tmpData(:, idx) = []; % Remove the group column
                tmpData = table2cell(tmpData); % Create cell so can manipulate fully

                groupedData = cell(1, 2*numel(allGroups));
                headerIdx = false(0,1);
                groupTotalCounts = zeros(0,1);
                groupFilteredCount = zeros(0,1);

                data2visible = this.FilteredDataToVisibleMap;
                d2v = find(~ismissing(data2visible));
                visible2data = this.FilteredVisibleToDataMap;
                updatedVisible2data = NaN(1, numel(allGroups) + height(tmpData));

                nVisibleRows = 0;

                for i = 1:numel(allGroups)
                    thisGroup = allGroups(i);

                    thisGroupMemberIdx = ismember(filteredGroupVars, thisGroup);
                    nInGroup = nnz(thisGroupMemberIdx);
                    thisGroupDisp = tmpData(thisGroupMemberIdx, :);

                    % Mapping from data to visible rows
                    nVisibleRows = nVisibleRows + 1; % Row header
                    visibleRowIdxs = nVisibleRows + (1:nInGroup);
                    data2visible(d2v(thisGroupMemberIdx)) = visibleRowIdxs;

                    % Mapping from visible to data rows
                    updatedVisible2data((nVisibleRows+1):(nVisibleRows+nInGroup)) = visible2data(thisGroupMemberIdx);
                    nVisibleRows = nVisibleRows + nInGroup;

                    % Add the "visible/total" to the group heading
                    allIdx = ismember(allGroupVars, thisGroup);
                    nAll = nnz(allIdx);

                    thisGroupHeading = cell(1, size(thisGroupDisp, 2));
                    thisGroupHeading{1} = string(thisGroup) + " (" + nInGroup + "/" + nAll + ")";
                    thisGroupData = tmpData(thisGroupMemberIdx, :);

                    % Keep track of the number of items in each group
                    groupFilteredCount = [groupFilteredCount; nInGroup]; %#ok<AGROW>
                    if size(thisGroupData, 2) == 0
                        % No columns except group column so no rows to show
                        nInGroup = 0;
                    end

                    % Add to a running total of all the groups + their
                    % heading row
                    groupedData{2*i-1} = thisGroupHeading;
                    groupedData{2*i} = thisGroupData;

                    headerIdx = [headerIdx, true, false(1, nInGroup)]; %#ok<AGROW>
                    groupTotalCounts = [groupTotalCounts; nAll]; %#ok<AGROW>
                end

                groupedData = vertcat(groupedData{:});

                if isempty(groupedData)
                    % Ensure the grouped data has the correct number of
                    % columns
                    groupedData = tmpData;
                end

                this.GroupedVisibleData = groupedData;
                this.GroupedDataVariables = groupedDataVariables;

                this.GroupHeaderRowIdx = find(headerIdx);
                this.GroupFilteredCount = groupFilteredCount;

                this.GroupedDataToVisibleMap = data2visible;
                this.GroupedVisibleToDataMap = updatedVisible2data;

            end

        end

        function updateFolding(this)

            groupedData = this.SortedVisibleData;
            idxsHeaderRow = this.SortedGroupHeaderRowIdx;
            idxHeading = [this.SortedGroupHeaderRowIdx, height(groupedData)+1];

            idxVisibleHeaderRowMask = false(1, size(groupedData, 1));
            idxVisibleHeaderRowMask(idxsHeaderRow) = true;

            visRowToRemove = false(1,height(groupedData));

            this.DisplayGroups = this.SortedGroupValues;

            hiddenGroups = string.empty(1,0);
            for i = numel(idxsHeaderRow):-1:1

                thisGroup = this.DisplayGroups(i);
                idxHeaderRow = idxsHeaderRow(i);
                idxGroupData = (idxHeading(i) + 1):(idxHeading(i+1)-1);

                isHidden = (~this.ShowEmptyGroups && this.GroupFilteredCount(i) == 0);

                if ~isHidden && ~ismember(thisGroup, this.OpenGroups)
                    % Group is closed, so update the header to show it is
                    % closed and removed the rows corresponding to the group
                    groupedData{idxHeaderRow, 1} = "⮞ " + groupedData{idxHeaderRow, 1};
                    visRowToRemove(idxGroupData) = true;

                elseif ~isHidden
                    % Group is open, so update the header to show it is
                    % open
                    groupedData{idxHeaderRow, 1} = "⮟ " + groupedData{idxHeaderRow, 1};
                else
                    % Group is hidden, so remove it from the view
                    hiddenGroups = [hiddenGroups, thisGroup]; %#ok<AGROW>

                    visRowToRemove(idxGroupData) = true;
                    visRowToRemove(idxHeaderRow) = true;
                    this.DisplayGroups(i) = [];
                end

            end

            groupedData(visRowToRemove, :) = [];
            idxVisibleHeaderRowMask(visRowToRemove) = [];

            % Update visible to data map
            visibleToDataMap = this.SortedVisibleToDataMap;
            visibleToDataMap(visRowToRemove) = [];
            this.FoldedVisibleToDataMap = visibleToDataMap;

            % Update data to visible map
            dataToVisibleMap = this.SortedDataToVisibleMap;
            visRowToRemoveId = find(visRowToRemove); % Headers and groups to remove
            dataToVisibleMap(ismember(dataToVisibleMap, visRowToRemoveId)) = NaN;

            % Remove row counts from map when rows are hidden
            if ~isempty(visRowToRemoveId)
                dataToVisibleMap = dataToVisibleMap - sum(dataToVisibleMap > visRowToRemoveId', 1);
            end

            this.FoldedDataToVisibleMap = dataToVisibleMap;

            vars = this.Data_.Properties.VariableNames;
            vars(ismember(vars, this.GroupingVariable_)) = [];
            if isempty(vars) && ~isempty(this.GroupingVariable)
                % Only group column remains
                vars = "Groups";
                if size(groupedData, 2) == 0
                    groupedData = num2cell(this.Groups)';
                end

            end

            groupedData = cell2table(groupedData, VariableNames=vars);

            this.VisibleData = groupedData;

            this.UpdateManager.addSuppression("HiddenGroups", Times=1);
            this.HiddenGroups = hiddenGroups;

            this.VisibleGroupHeaderRowIdx = find(idxVisibleHeaderRowMask);

            this.updateGroupLabel();

        end

    end

    % Style updates
    methods (Access = protected)

        function updateStyle(this)
            this.DisplayTable.removeStyle();

            styles = [this.Styles, this.GroupHeaderStyle];

            for i = 1:numel(styles)
                thisStyle = styles(i);

                style = thisStyle.Style;
                target = thisStyle.Target;

                index = thisStyle.indices(this);
                if thisStyle.SelectionMode == gwidgets.internal.table.SelectionMode.Data
                    index = this.dataSelectionToDisplaySelection(index, thisStyle.Target);
                end
                this.DisplayTable.addStyle(style, target, index);
            end

            this.forceRefresh();
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
                group = this.DisplayGroups(idxHeader);
                if ismember(group, this.OpenGroups)
                    this.OpenGroups(this.OpenGroups == group) = [];
                else
                    this.OpenGroups = [this.OpenGroups, group];
                end
            end
        end

        function onSelection_(this, displayIdx, selectionType)
            arguments
                this (1,1)
                displayIdx (:,2) % onSelection always sends row/col
                selectionType (1,1) string = this.SelectionType
            end

            % Skip if we're setting the selection programmatically
            if this.IsSettingSelectionProgrammatically
                return
            end

            % Update the display index to match the current selection type
            switch selectionType
                case "cell"
                    if isempty(displayIdx)
                        displayIdx = zeros(0,2);
                    end
                case "row"
                    displayIdx = unique(displayIdx(:,1));
                    displayIdx = reshape(displayIdx, 1, []);
                case "column"
                    displayIdx = unique(displayIdx(:,2));
                    displayIdx = reshape(displayIdx, 1, []);
            end

            this.Selection_ = displayIdx;
            this.SelectionMode = "Display";
            this.refreshVisibleSelection();

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

    methods (Access = {?matlab.unittest.TestCase, ?gwidgets.Table})

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
                currentSortColumn = this.SortByColumn;

                this.UpdateManager.addSuppression("SortDirection", Times=1);
                if newSortColumn == currentSortColumn
                    if this.SortDirection == "None"
                        this.SortDirection = "Ascend";
                    elseif this.SortDirection == "Ascend"
                        this.SortDirection = "Descend";
                    else
                        this.SortDirection = "None";
                    end
                else
                    this.SortDirection = "Ascend";
                end

                this.SortByColumn = e.InteractionVariable;
            end

            % Forward to custom cell edit callback
            if ~isempty(this.DisplayDataChangedCallback)
                this.DisplayDataChangedCallback(s, e);
            end

        end

        function onUngroupByRequest(this, ~, ~)
            this.clearSelection();
            this.GroupingVariable = string.empty(1,0);
        end

        function onGroupByRequest(this, ~, e)

            if ~isempty(this.DisplaySelection)
                if this.SelectionType == "cell"
                    columnIdx = unique(this.DisplaySelection(:, 2));
                elseif this.SelectionType == "column"
                    columnIdx = this.DisplaySelection;
                else
                    columnIdx = e.InteractionInformation.DisplayColumn;
                end
            else
                columnIdx = e.InteractionInformation.DisplayColumn;
            end

            % Convert from alias back to underlying data for grouping
            % TODO: Make util for this
            groupingVariable = string(this.DisplayTable.Data.Properties.VariableNames(columnIdx));
            idx = find(ismember(this.ColumnNames, groupingVariable));
            groupingVariable = string(this.Data_.Properties.VariableNames(idx));

            if isempty(groupingVariable)
                groupingVariable = string.empty(1,0);
            end

            this.clearSelection();
            try
                this.GroupingVariable = groupingVariable;
            catch me
                this.GroupingVariable = string.empty(1,0);
            end
        end

    end

    % Context menu callbacks
    methods (Access = private)

        function onCellSelectionRequest(this, ~, ~)
            this.SelectionType = "cell";
            this.clearSelection();
        end

        function onRowSelectionRequest(this, ~, ~)
            this.SelectionType = "row";
            this.clearSelection();
        end

        function onColumnSelectionRequest(this, ~, ~)
            this.SelectionType = "column";
            this.clearSelection();
        end

        function onAutoResizeColumnsRequest(this, ~, ~)
            % Reset to DefaultColumnWidths if set, otherwise clear to auto.
            this.ColumnWidth = {};
        end

        function onToggleRowFilterRequest(this, ~, ~)
            this.ShowRowFilter = ~this.ShowRowFilter;
        end

        function onToggleShowEmptyGroupsRequest(this, ~, ~)
            this.ShowEmptyGroups = ~this.ShowEmptyGroups;
        end

        function onSortByRequest(this, ~, e, direction)

            this.UpdateManager.addSuppression("SortDirection", Times=1);
            this.SortDirection = direction;

            if ismember(e.InteractionInformation.DisplayRow, this.VisibleGroupHeaderRowIdx)
                % Sort groups by sorting on group row
                % TODO: Sort groups and columns
                vars = this.GroupingVariable;
            else

                if this.SelectionType == "cell"
                    colIdx = unique(this.DisplaySelection(:,2));
                elseif this.SelectionType == "column"
                    colIdx = unique(this.DisplaySelection);
                else
                    % Allow sorting by at least one column when using row
                    % selection
                    colIdx = e.InteractionInformation.DisplayColumn;
                end

                vars = this.GroupedDataVariables(colIdx);

            end

            this.SortByColumn = vars;

        end

    end

    methods (Static, Hidden)

        function store = extendStore(store, defaultVal, nData)
            % Ensure store has exactly nData elements, padding with defaultVal.
            n = numel(store);
            if n == nData
                return
            elseif n == 0
                if isnumeric(defaultVal)
                    store = repelem(defaultVal, 1, nData);
                else
                    store = repelem(string(defaultVal), 1, nData);
                end
            elseif n < nData
                if isnumeric(defaultVal)
                    store = [store, repelem(defaultVal, 1, nData - n)];
                else
                    store = [store, repelem(string(defaultVal), 1, nData - n)];
                end
            else
                store = store(1:nData);
            end
        end

        function g = gcdPixelWidths(px)
            % GCD of all finite positive pixel widths (integer arithmetic).
            vals = round(px(isfinite(px) & px > 0));
            if isempty(vals)
                g = 1;
                return
            end
            g = vals(1);
            for i = 2:numel(vals)
                g = gcd(g, vals(i));
            end
            if g == 0, g = 1; end
        end

        function val = normalizeColumnWidths(val)
            % Accept numeric arrays, string arrays, char, or cell.
            % Returns a cell array (or empty cell if input was empty).
            % "auto" and "fit" are normalised to "1x" since only Pixel
            % and Relative column types are supported.
            val = convertCharsToStrings(val);
            if isempty(val)
                val = {"fit"};
            elseif ~iscell(val)
                val = num2cell(val);
            else
                val = cellfun(@(x) convertCharsToStrings(x), val, "UniformOutput", false);
            end

            if isscalar(val) && isstring(val{1}) && val{1} == ""
                val = {};
            end

            for i = 1:numel(val)
                v = val{i};
                if isstring(v) && (v == "auto" || v == "fit")
                    val{i} = "1x";
                end
            end
        end

    end

end