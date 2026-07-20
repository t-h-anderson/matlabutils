classdef SelectionController < gwidgets.internal.table.TableController
    % SelectionController owns table display/data selection mapping.

    properties (Dependent)
        Value
        DisplayValue
        Type
        Multiselect
    end

    properties (Access = private)
        Mode (1,1) gwidgets.table.SelectionMode = "Data"
        Value_ (:,:) double
        IsSettingProgrammatically (1,1) logical = false
    end

    methods
        function this = SelectionController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
        end

        function val = get.Value(this)
            val = this.Value_;
            if this.Mode == "Display"
                val = this.displayToData(val);
            end
        end

        function set.Value(this, val)
            val = this.validateShape(val);
            this.validateDimensions(val, size(this.owner().Data.Table));
            this.Value_ = val;
            this.Mode = "Data";
            this.refreshVisibleSelection();
        end

        function val = get.DisplayValue(this)
            val = this.Value_;
            if this.Mode == "Data"
                val = this.dataToDisplay(val);
            end
        end

        function set.DisplayValue(this, val)
            val = this.validateShape(val);
            this.validateDimensions(val, this.displaySelectionSize());
            this.Value_ = val;
            this.Mode = "Display";
            this.refreshVisibleSelection();
        end

        function val = get.Type(this)
            val = this.owner().Graphics.DisplayTable.SelectionType;
        end

        function set.Type(this, val)
            this.owner().Graphics.DisplayTable.SelectionType = val;
            this.clear();

            if this.owner().doControllerUpdate("SelectionType")
                this.owner().requestControllerUpdate(StartFrom="Interaction");
            end
        end

        function val = get.Multiselect(this)
            val = this.owner().Graphics.DisplayTable.Multiselect;
        end

        function set.Multiselect(this, val)
            this.owner().Graphics.DisplayTable.Multiselect = val;
            this.clear();
        end

        function clear(this)
            this.Value_ = gwidgets.internal.table.SelectionController.emptySelection(this.Type);
            this.Mode = "Data";
        end

        function requestCellSelection(this)
            arguments
                this (1,1) gwidgets.internal.table.SelectionController
            end

            this.Type = "cell";
        end

        function requestRowSelection(this)
            arguments
                this (1,1) gwidgets.internal.table.SelectionController
            end

            this.Type = "row";
        end

        function requestColumnSelection(this)
            arguments
                this (1,1) gwidgets.internal.table.SelectionController
            end

            this.Type = "column";
        end

        function dataIdxs = displayToData(this, visibleIdxs, type)
            arguments
                this (1,1) gwidgets.internal.table.SelectionController
                visibleIdxs
                type (1,1) string {mustBeMember(type, ["cell", "row", "column"])} = this.Type
            end

            if isempty(visibleIdxs)
                dataIdxs = visibleIdxs;
                return
            end

            if this.owner().Display.Orientation == "Transposed" && type == "cell"
                visibleIdxs = this.transposedCellsToNormal(visibleIdxs);
            end

            dataIdxs = gwidgets.internal.table.SelectionController.displayToDataStatic( ...
                visibleIdxs, type, this.mapState());
        end

        function visibleIdxs = dataToDisplay(this, dataIdxs, type)
            arguments
                this (1,1) gwidgets.internal.table.SelectionController
                dataIdxs
                type (1,1) string {mustBeMember(type, ["cell", "row", "column", "table"])} = this.Type
            end

            if isempty(dataIdxs)
                visibleIdxs = dataIdxs;
                return
            end

            visibleIdxs = gwidgets.internal.table.SelectionController.dataToDisplayStatic( ...
                dataIdxs, type, this.mapState());
            if this.owner().Display.Orientation == "Transposed" && type == "cell"
                visibleIdxs = gwidgets.internal.table.SelectionController.normalCellsToTransposed(visibleIdxs);
            end
        end

        function [displayIdx, shouldContinue] = onDisplaySelection(this, displayIdx, selectionType)
            arguments
                this (1,1) gwidgets.internal.table.SelectionController
                displayIdx (:,2)
                selectionType (1,1) string = this.Type
            end

            shouldContinue = false;
            if this.IsSettingProgrammatically
                return
            end

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
                otherwise
                    % Argument validation prevents this branch.
            end

            this.Value_ = displayIdx;
            this.Mode = "Display";
            this.refreshVisibleSelection();
            shouldContinue = true;
        end

        function [displayIdx, shouldContinue] = handleDisplaySelection(this, displayIdx, selectionType)
            arguments
                this (1,1) gwidgets.internal.table.SelectionController
                displayIdx (:,2)
                selectionType (1,1) string = this.Type
            end

            [displayIdx, shouldContinue] = this.onDisplaySelection(displayIdx, selectionType);
            if shouldContinue
                this.updateCategoricalFilterVariables(displayIdx, selectionType);
            end
        end

        function refresh(this)
            this.refreshVisibleSelection();
        end
    end

    methods (Static)
        function selection = emptySelection(selectionType)
            arguments
                selectionType (1,1) string {mustBeMember(selectionType, ["cell", "row", "column"])}
            end

            switch selectionType
                case "cell"
                    selection = zeros(0,2);
                case {"row", "column"}
                    selection = zeros(1,0);
                otherwise
                    selection = zeros(1,0);
            end
        end

        function dataIdxs = displayToDataStatic(visibleIdxs, type, state)
            arguments
                visibleIdxs
                type (1,1) string {mustBeMember(type, ["cell", "row", "column"])}
                state (1,1) struct
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
                    error("GraphicsWidgets:Table:IncorrectSelectionSize", ...
                        "Selection must be a matrix with two columns for cells, or a vector for rows/columns.");
            end

            if ~any(ismissing(rowIdxs)) && any(rowIdxs ~= 0)
                rowIdxs = state.FoldedVisibleToDataMap(rowIdxs).';
                noDataIdx = ismissing(rowIdxs);
                rowIdxs(noDataIdx) = NaN;
                colIdxs(noDataIdx) = NaN;
            end

            visibleCols = state.VisibleDataColumnNames;
            visibleCols(ismember(visibleCols, state.GroupingVariable)) = [];
            dataCols = state.DataColumnNames;
            for iCol = 1:numel(colIdxs)
                colIdx = colIdxs(iCol);
                if ~ismissing(colIdx) && colIdx ~= 0
                    thisCol = visibleCols(colIdx);
                    idx = find(dataCols == thisCol, 1);
                    if isempty(idx)
                        idx = NaN;
                    end
                    colIdxs(iCol) = idx;
                end
            end

            dataIdxs = gwidgets.internal.table.SelectionController.combineSelection(rowIdxs, colIdxs, type);
        end

        function visibleIdxs = dataToDisplayStatic(dataIdxs, type, state)
            arguments
                dataIdxs
                type (1,1) string {mustBeMember(type, ["cell", "row", "column", "table"])}
                state (1,1) struct
            end

            if isempty(dataIdxs)
                visibleIdxs = dataIdxs;
                return
            end

            switch type
                case "cell"
                    rowIdxs = dataIdxs(:,1).';
                    colIdxs = dataIdxs(:,2).';
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
                otherwise
                    rowIdxs = dataIdxs;
                    colIdxs = zeros(size(rowIdxs));
            end

            rowsInRange = all(rowIdxs >= 1 & rowIdxs <= numel(state.FilteredDataToVisibleMap));
            colsInRange = all(colIdxs >= 1 & colIdxs <= state.DataWidth);

            checkRowsInRange = type ~= "column" && ~any(ismissing(rowIdxs));
            checkColsInRange = type ~= "row" && ~any(ismissing(colIdxs));

            if (checkRowsInRange && ~rowsInRange) || (checkColsInRange && ~colsInRange)
                error("GraphicsWidgets:Table:SelectionOutOfRange", ...
                    "Selection outside data range");
            elseif isempty(state.FoldedDataToVisibleMap)
                visibleIdxs = gwidgets.internal.table.SelectionController.emptyMappedSelection(type, colIdxs);
                return
            end

            if ~any(ismissing(rowIdxs)) && any(rowIdxs ~= 0)
                rowIdxs = state.FoldedDataToVisibleMap(rowIdxs);
                noDataIdxs = ismissing(rowIdxs);
                colIdxs(noDataIdxs) = [];
                rowIdxs(noDataIdxs) = [];
            end

            visibleCols = state.VisibleDataColumnNames;
            visibleCols(ismember(visibleCols, state.GroupingVariable)) = [];
            dataCols = state.DataColumnNames;
            for iCol = 1:numel(colIdxs)
                colIdx = colIdxs(iCol);
                if ~ismissing(colIdx) && colIdx ~= 0
                    thisCol = dataCols(colIdx);
                    matchingColIdx = find(visibleCols == thisCol, 1);
                    if isempty(matchingColIdx)
                        matchingColIdx = NaN;
                    end
                    colIdxs(iCol) = matchingColIdx;
                end
            end

            visibleIdxs = gwidgets.internal.table.SelectionController.combineSelection(rowIdxs, colIdxs, type);
        end
    end

    methods (Static, Access = private)
        function selection = emptyMappedSelection(type, colIdxs)
            switch type
                case "cell"
                    selection = zeros(0,2);
                case "row"
                    selection = zeros(1,0);
                case "column"
                    selection = colIdxs;
                otherwise
                    selection = zeros(1,0);
            end
        end

        function selection = combineSelection(rowIdxs, colIdxs, type)
            colIdxs = reshape(colIdxs, [], 1);
            rowIdxs = reshape(rowIdxs, [], 1);
            idx = ismissing(rowIdxs) | ismissing(colIdxs);
            rowIdxs(idx) = [];
            colIdxs(idx) = [];

            switch type
                case "cell"
                    selection = [rowIdxs, colIdxs];
                    if isempty(selection)
                        selection = zeros(0,2);
                    end
                case "row"
                    selection = reshape(rowIdxs, 1, []);
                    selection(selection == 0) = [];
                    if isempty(selection)
                        selection = zeros(1,0);
                    end
                case "column"
                    selection = reshape(colIdxs, 1, []);
                    selection(selection == 0) = [];
                    if isempty(selection)
                        selection = zeros(1,0);
                    end
                otherwise
                    selection = zeros(1,0);
            end
        end
    end

    methods (Access = private)
        function selection = validateShape(this, selection)
            errorMsg = this.Type + " selection must be a vector, or []";
            if ~isnumeric(selection)
                error("GraphicsWidgets:Table:UnsupportedSelectionSize", errorMsg);
            end

            switch this.Type
                case "cell"
                    if isempty(selection)
                        selection = zeros(0,2);
                    elseif size(selection, 2) == 2
                        % Already correct.
                    elseif size(selection, 1) == 2
                        selection = selection.';
                    else
                        errorMsg = this.Type + " selection must be a matrix with two columns, or []";
                        error("GraphicsWidgets:Table:UnsupportedSelectionSize", errorMsg);
                    end
                    selection = unique(selection, "rows", "stable");

                case {"row", "column"}
                    if isempty(selection)
                        selection = zeros(1,0);
                    elseif isvector(selection)
                        selection = reshape(selection, 1, []);
                    else
                        error("GraphicsWidgets:Table:UnsupportedSelectionSize", errorMsg);
                    end
                    selection = unique(selection, "stable");

                otherwise
                    % Argument validation prevents this branch.
            end

            if this.Multiselect == "off" && ~isempty(selection)
                switch this.Type
                    case "cell"
                        if size(selection, 1) > 1
                            error("GraphicsWidgets:Table:InvalidSingleSelection", ...
                                "Multiselect is off but multiple cells were selected");
                        end
                    case {"row", "column"}
                        if numel(selection) > 1
                            error("GraphicsWidgets:Table:InvalidSingleSelection", ...
                                "Multiselect is off but multiple rows or columns were selected");
                        end
                    otherwise
                        % Argument validation prevents this branch.
                end
            end
        end

        function validateDimensions(this, selection, destSize)
            if any(isnan(selection), "all") || any(selection < 1, "all") || any(isinf(selection), "all")
                error("GraphicsWidgets:Table:UnsupportedSelection", "Selection outside limits or undefined");
            end

            if isempty(selection)
                return
            end

            switch this.Type
                case "cell"
                    idxFail = selection(:, 1) > destSize(1) | selection(:, 2) > destSize(2);
                    if any(idxFail)
                        failSelection = strjoin(string(num2str(selection(idxFail, :), "[%d,%d]")), ",");
                        limits = "[" + destSize(1) + "," + destSize(2) + "]";
                        error("GraphicsWidgets:Table:SelectionOutsideLimits", ...
                            "Selection " + failSelection + " outside limits " + limits);
                    end

                case {"row", "column"}
                    if this.Type == "row"
                        destSize = destSize(1);
                    else
                        destSize = destSize(2);
                    end

                    idxFail = selection > destSize;
                    if any(idxFail)
                        failSelection = strjoin(string(selection(idxFail)), ",");
                        limits = destSize;
                        error("GraphicsWidgets:Table:SelectionOutsideLimits", ...
                            "Selection " + failSelection + " outside limits " + limits);
                    end
                otherwise
                    % Argument validation prevents this branch.
            end
        end

        function refreshVisibleSelection(this)
            owner = this.owner();
            if isempty(owner.Graphics.DisplayTable) || isempty(owner.Data.FoldedDataToVisibleMap)
                return
            end

            selection = this.Value_;
            if this.Mode == "Data"
                selection = this.dataToDisplay(selection);
            end

            this.IsSettingProgrammatically = true;
            cleanupObj = onCleanup(@()this.clearProgrammaticFlag());
            try
                owner.Graphics.DisplayTable.Selection = selection;
            catch
                owner.Graphics.DisplayTable.Selection = [];
            end
            delete(cleanupObj);
            if owner.Menu.HasChangeGroupingVariable
                owner.Menu.refresh();
            end
            owner.forceRefresh();
        end

        function clearProgrammaticFlag(this)
            this.IsSettingProgrammatically = false;
        end

        function updateCategoricalFilterVariables(this, displayIdx, selectionType)
            arguments
                this (1,1) gwidgets.internal.table.SelectionController
                displayIdx (:,2)
                selectionType (1,1) string
            end

            if isempty(displayIdx)
                this.owner().Filter.CategoricalVariables = [];
                return
            end

            switch selectionType
                case "cell"
                    colIdx = unique(displayIdx(:, 2));
                case "column"
                    colIdx = displayIdx;
                case "row"
                    colIdx = [];
                otherwise
                    colIdx = [];
            end

            if ~isscalar(colIdx)
                this.owner().Filter.CategoricalVariables = [];
                return
            end

            values = this.owner().Graphics.DisplayTable.Data{:, colIdx};
            if iscategorical(values)
                this.owner().Filter.CategoricalVariables = categories(values);
            else
                this.owner().Filter.CategoricalVariables = [];
            end
        end

        function state = mapState(this)
            owner = this.owner();
            state = struct( ...
                "FoldedVisibleToDataMap", owner.Data.FoldedVisibleToDataMap, ...
                "FoldedDataToVisibleMap", owner.Data.FoldedDataToVisibleMap, ...
                "FilteredDataToVisibleMap", owner.Data.FilteredDataToVisibleMap, ...
                "VisibleColumnNames", owner.Column.VisibleNames, ...
                "VisibleDataColumnNames", owner.Column.VisibleDataNames, ...
                "DataColumnNames", owner.Column.DataNames, ...
                "GroupingVariable", owner.Group.By, ...
                "DataWidth", size(owner.Data.Table, 2));
        end

        function normalIdxs = transposedCellsToNormal(this, displayIdxs)
            arguments
                this (1,1) gwidgets.internal.table.SelectionController
                displayIdxs (:,2) double
            end

            state = this.mapState();
            visibleCols = state.VisibleDataColumnNames;
            visibleCols(ismember(visibleCols, state.GroupingVariable)) = [];

            isDataCell = displayIdxs(:, 2) > 1 ...
                & displayIdxs(:, 1) >= 1 ...
                & displayIdxs(:, 1) <= numel(visibleCols) ...
                & displayIdxs(:, 2) - 1 <= numel(state.FoldedVisibleToDataMap);
            displayIdxs = displayIdxs(isDataCell, :);
            normalIdxs = [displayIdxs(:, 2) - 1, displayIdxs(:, 1)];
        end

        function sz = displaySelectionSize(this)
            owner = this.owner();
            if owner.Display.Orientation == "Transposed"
                sz = size(owner.Graphics.DisplayTable.Data);
            else
                sz = size(owner.Data.Visible);
            end
        end
    end

    methods (Static)
        function displayIdxs = normalCellsToTransposed(normalIdxs)
            arguments
                normalIdxs (:,2) double
            end

            displayIdxs = [normalIdxs(:, 2), normalIdxs(:, 1) + 1];
        end
    end

end
