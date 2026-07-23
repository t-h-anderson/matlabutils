classdef DisplayController < gwidgets.internal.table.TableController
    % DisplayController applies computed table state to the backing uitable.

    properties (Dependent)
        Orientation
    end

    properties (Access = private)
        Orientation_ (1,1) string {mustBeMember(Orientation_, ["Normal", "Transposed"])} = "Normal"
        GroupHeaderColumnWidths_ (1,:) double = nan(1,0)
        GroupHeaderRowWidths_ (1,:) double = nan(1,0)
    end

    methods
        function this = DisplayController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
        end

        function val = get.Orientation(this)
            val = this.Orientation_;
        end

        function set.Orientation(this, val)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                val (1,1) string {mustBeMember(val, ["Normal", "Transposed"])}
            end

            if this.Orientation_ == val
                return
            end

            this.Orientation_ = val;
            owner = this.owner();
            owner.Selection.clear();
            if owner.doControllerUpdate("DisplayOrientation")
                owner.requestControllerUpdate(StartFrom="Display");
            end
        end

        function updateData(this)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
            end

            this.update("VisibleData");
            this.applyColumnWidth();
        end

        function updateInteraction(this)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
            end

            vars = ["ColumnEditable", "ColumnSortable", "SelectionType"];
            this.update(vars);
            this.applyColumnWidth();
            this.owner().Selection.refresh();
        end

        function applyColumnWidth(this)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
            end

            owner = this.owner();
            backend = owner.Graphics.Backend;

            owner.Bridge.suppress();
            visWidths = this.visibleColumnWidths(owner);
            if ~isequal(backend.ColumnWidth, visWidths)
                if isempty(visWidths)
                    visWidths = {"Auto"};
                end
                backend.ColumnWidth = {"Auto"};
                owner.forceRefresh();
                backend.ColumnWidth = visWidths;
            end
            owner.Bridge.restore();
        end

        function requestAutoResize(this)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
            end

            owner = this.owner();
            owner.Bridge.applyGroupHeaderSpans();
            owner.Bridge.requestGroupSpanMeasurement();
        end

        function applyGroupSpanMeasurements(this, data)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                data (1,1) struct
            end

            changed = false;
            if isfield(data, "columns") && isfield(data, "columnWidths")
                [this.GroupHeaderColumnWidths_, didChange] = ...
                    gwidgets.internal.table.DisplayController.setIndexedValues( ...
                    this.GroupHeaderColumnWidths_, ...
                    reshape(double(data.columns), 1, []), ...
                    reshape(double(data.columnWidths), 1, []));
                changed = changed || didChange;
            end

            if isfield(data, "rows") && isfield(data, "rowWidths")
                [this.GroupHeaderRowWidths_, didChange] = ...
                    gwidgets.internal.table.DisplayController.setIndexedValues( ...
                    this.GroupHeaderRowWidths_, ...
                    reshape(double(data.rows), 1, []), ...
                    reshape(double(data.rowWidths), 1, []));
                changed = changed || didChange;
            end

            if changed
                this.applyColumnWidth();
            end
        end

        function handleBridgeColumnWidths(this, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                pixelWidths (1,:) double
            end

            owner = this.owner();
            if this.Orientation == "Transposed"
                if this.updateTransposedHeaderWidths(owner, pixelWidths)
                    this.applyColumnWidth();
                else
                    owner.Bridge.restore();
                end
                return
            end

            [dataPixelWidths, visibleMask, syntheticPixelWidths, canMap] = ...
                this.normalBridgeWidthMap(owner, pixelWidths);
            if ~canMap
                owner.Bridge.restore();
                return
            end

            changed = false;
            if any(visibleMask) && owner.Column.didBridgeWidthsChangeForMask(dataPixelWidths, visibleMask)
                owner.Column.updateBridgeWidthsForMask(dataPixelWidths, visibleMask);
                changed = true;
            end

            if this.updateNormalSyntheticHeaderWidths(owner, syntheticPixelWidths)
                changed = true;
            end

            if changed
                this.applyColumnWidth();
            else
                owner.Bridge.restore();
            end
        end

        function update(this, vars)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                vars (1,:) string
            end

            owner = this.owner();
            backend = owner.Graphics.Backend;
            toUpdate = cell(1, 6*numel(vars));
            nUpdates = 0;
            for iVar = 1:numel(vars)
                currentVar = vars(iVar);
                newVal = this.propertyValue(owner, currentVar);

                if currentVar == "VisibleData"
                    currentVal = backend.DisplayData;
                    newVal = gwidgets.internal.table.DisplayController.visibleDataForTable( ...
                        newVal, this.updateState(owner));
                    columnName = this.columnNamesForDisplay(newVal);
                    newVal = this.orientVisibleData(newVal);
                    newVar = "Data";
                else
                    currentVal = backend.(currentVar);
                    newVar = currentVar;
                end

                if ~isequal(currentVal, newVal)
                    nUpdates = nUpdates + 2;
                    toUpdate(nUpdates-1:nUpdates) = {newVar, newVal};
                end

                if currentVar == "VisibleData" && ~isequal(backend.ColumnName, columnName)
                    nUpdates = nUpdates + 2;
                    toUpdate(nUpdates-1:nUpdates) = {"ColumnName", columnName};
                end

                if currentVar == "VisibleData"
                    [groupHeaderRows, groupHeaderLevels] = this.groupHeadersForDisplay(owner);
                    if ~isequal(backend.GroupHeaderRows, groupHeaderRows)
                        nUpdates = nUpdates + 2;
                        toUpdate(nUpdates-1:nUpdates) = {"GroupHeaderRows", groupHeaderRows};
                    end
                    if ~isequal(backend.GroupHeaderLevels, groupHeaderLevels)
                        nUpdates = nUpdates + 2;
                        toUpdate(nUpdates-1:nUpdates) = {"GroupHeaderLevels", groupHeaderLevels};
                    end
                end
            end

            if nUpdates > 0
                backend.setProperties(toUpdate(1:nUpdates));
            end
        end
    end

    methods (Access = private)
        function value = propertyValue(this, owner, propertyName)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                propertyName (1,1) string
            end

            switch propertyName
                case "VisibleData"
                    value = owner.Data.Visible;
                case "ColumnEditable"
                    if this.Orientation == "Transposed"
                        value = false(1, this.transposedWidth());
                    else
                        value = owner.Column.Editable;
                    end
                case "ColumnSortable"
                    if this.Orientation == "Transposed"
                        value = false(1, this.transposedWidth());
                    else
                        value = owner.Column.Sortable;
                    end
                case "SelectionType"
                    value = owner.Selection.Type;
                otherwise
                    error("GraphicsWidgets:UITable:DisplayProperty", ...
                        "Unsupported display property: %s", propertyName);
            end
        end

        function state = updateState(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
            end

            if isempty(this.owner())
                state = struct();
                return
            end

            state = struct( ...
                "VisibleDataColumnNames", owner.Column.VisibleDataNames, ...
                "GroupingVariable", owner.Group.By, ...
                "VisibleGroupHeaderRowIdx", owner.Data.VisibleGroupHeaderRowIdx, ...
                "DataColumnNames", owner.Column.DataNames, ...
                "ColumnNames", owner.Column.Names);
        end

        function data = orientVisibleData(this, data)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                data (:,:) table
            end

            if this.Orientation ~= "Transposed"
                return
            end

            data = gwidgets.internal.table.DisplayController.transposeVisibleData(data);
        end

        function [rows, levels] = groupHeadersForDisplay(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
            end

            if this.Orientation ~= "Normal"
                rows = zeros(1,0);
                levels = zeros(1,0);
                return
            end

            rows = reshape(owner.Data.VisibleGroupHeaderRowIdx, 1, []);
            levels = reshape(owner.Data.VisibleGroupHeaderLevels, 1, []);
            if isempty(rows)
                levels = zeros(1,0);
                return
            end

            if numel(levels) ~= numel(rows)
                levels = ones(1, numel(rows));
            elseif all(levels == 0)
                levels = ones(1, numel(rows));
            end
        end

        function columnName = columnNamesForDisplay(this, data)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                data (:,:) table
            end

            if this.Orientation ~= "Transposed"
                columnName = cellstr(string(data.Properties.VariableNames).');
                return
            end

            nColumns = height(data) + 1;
            rowNames = string(data.Properties.RowNames);
            if isempty(rowNames)
                columnName = repmat({char.empty(0,0)}, nColumns, 1);
                return
            end

            columnName = cellstr([""; rowNames(:)]);
        end

        function widths = visibleColumnWidths(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
            end

            if this.Orientation ~= "Transposed"
                widths = this.normalColumnWidths(owner);
                return
            end

            nColumns = this.transposedWidth();
            widths = repmat({"1x"}, 1, nColumns);
            headerColumns = owner.Data.VisibleGroupHeaderRowIdx + 1;
            headerWidths = gwidgets.internal.table.DisplayController.indexedValues( ...
                this.GroupHeaderColumnWidths_, headerColumns);
            for iColumn = 1:numel(headerColumns)
                displayColumn = headerColumns(iColumn);
                if displayColumn < 1 || displayColumn > nColumns
                    continue
                end
                if isfinite(headerWidths(iColumn)) && headerWidths(iColumn) > 0
                    widths{displayColumn} = headerWidths(iColumn);
                end
            end
        end

        function width = transposedWidth(this)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
            end

            owner = this.owner();
            width = height(owner.Data.Visible) + 1;
        end

        function widths = normalColumnWidths(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
            end

            displayData = owner.Graphics.Backend.Data;
            if width(displayData) == 0
                widths = {};
                return
            end

            displayNames = string(displayData.Properties.VariableNames);
            isSyntheticDisplay = this.isNormalSyntheticGroupDisplay(owner, displayData);
            dataNames = owner.Column.aliasesToData(displayNames);
            allDataNames = owner.Column.DataNames;
            allWidths = owner.Column.DataWidth;
            widths = cell(1, numel(dataNames));
            for iName = 1:numel(dataNames)
                dataIdx = find(allDataNames == dataNames(iName), 1);
                if isSyntheticDisplay || isempty(dataIdx)
                    widths{iName} = this.syntheticNormalColumnWidth(owner);
                else
                    widths{iName} = allWidths{dataIdx};
                end
            end
        end

        function width = syntheticNormalColumnWidth(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
            end

            rowWidths = gwidgets.internal.table.DisplayController.indexedValues( ...
                this.GroupHeaderRowWidths_, owner.Data.VisibleGroupHeaderRowIdx);
            rowWidths = rowWidths(isfinite(rowWidths) & rowWidths > 0);
            if isempty(rowWidths)
                width = "1x";
            else
                width = max(rowWidths);
            end
        end

        function [dataPixelWidths, visibleMask, syntheticPixelWidths, canMap] = normalBridgeWidthMap( ...
                this, owner, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                pixelWidths (1,:) double
            end

            displayData = owner.Graphics.Backend.Data;
            allDataNames = owner.Column.DataNames;
            nData = numel(allDataNames);
            visibleMask = false(1, nData);
            dataPixelWidths = zeros(1,0);
            syntheticPixelWidths = zeros(1,0);
            canMap = false;

            if width(displayData) == 0 || numel(pixelWidths) ~= width(displayData)
                return
            end

            if this.isNormalSyntheticGroupDisplay(owner, displayData)
                syntheticPixelWidths = pixelWidths;
                canMap = true;
                return
            end

            displayNames = string(displayData.Properties.VariableNames);
            dataNames = owner.Column.aliasesToData(displayNames);
            dataIdxs = zeros(1, numel(dataNames));
            dataWidths = zeros(1, numel(dataNames));
            syntheticPixelWidths = zeros(1, numel(dataNames));
            nDataWidths = 0;
            nSyntheticWidths = 0;
            for iName = 1:numel(dataNames)
                dataIdx = find(allDataNames == dataNames(iName), 1);
                if isempty(dataIdx)
                    nSyntheticWidths = nSyntheticWidths + 1;
                    syntheticPixelWidths(nSyntheticWidths) = pixelWidths(iName);
                else
                    nDataWidths = nDataWidths + 1;
                    dataIdxs(nDataWidths) = dataIdx;
                    dataWidths(nDataWidths) = pixelWidths(iName);
                end
            end
            dataIdxs = dataIdxs(1:nDataWidths);
            dataWidths = dataWidths(1:nDataWidths);
            syntheticPixelWidths = syntheticPixelWidths(1:nSyntheticWidths);

            visibleMask(dataIdxs) = true;
            [~, order] = sort(dataIdxs);
            dataPixelWidths = dataWidths(order);
            canMap = true;
        end

        function changed = updateNormalSyntheticHeaderWidths(this, owner, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                pixelWidths (1,:) double
            end

            headerRows = owner.Data.VisibleGroupHeaderRowIdx;
            pixelWidths = pixelWidths(isfinite(pixelWidths) & pixelWidths > 0);
            if isempty(headerRows) || isempty(pixelWidths)
                changed = false;
                return
            end

            headerWidths = repelem(max(pixelWidths), 1, numel(headerRows));
            [this.GroupHeaderRowWidths_, changed] = ...
                gwidgets.internal.table.DisplayController.setIndexedValues( ...
                this.GroupHeaderRowWidths_, headerRows, headerWidths);
        end

        function tf = isNormalSyntheticGroupDisplay(this, owner, displayData)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                displayData (:,:) table
            end

            headerRows = owner.Data.VisibleGroupHeaderRowIdx;
            tf = owner.Group.IsGrouped ...
                && width(displayData) == 1 ...
                && ~isempty(headerRows) ...
                && numel(headerRows) == height(displayData) ...
                && all(ismember(owner.Column.DataNames, owner.Group.By));
        end

        function changed = updateTransposedHeaderWidths(this, owner, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                pixelWidths (1,:) double
            end

            headerColumns = owner.Data.VisibleGroupHeaderRowIdx + 1;
            idx = headerColumns >= 1 & headerColumns <= numel(pixelWidths);
            headerColumns = headerColumns(idx);
            if isempty(headerColumns)
                changed = false;
                return
            end

            [this.GroupHeaderColumnWidths_, changed] = ...
                gwidgets.internal.table.DisplayController.setIndexedValues( ...
                this.GroupHeaderColumnWidths_, headerColumns, pixelWidths(headerColumns));
        end
    end

    methods (Static)
        function data = visibleDataForTable(data, state)
            arguments
                data (:,:) table
                state (1,1) struct
            end

            if width(data) ~= 0
                data = gwidgets.internal.table.DisplayController.selectVisibleColumns(data, state);
            end

            data.Properties.VariableNames = gwidgets.internal.table.ColumnController.translateNames( ...
                string(data.Properties.VariableNames), state.DataColumnNames, state.ColumnNames);
        end

        function data = transposeVisibleData(data)
            arguments
                data (:,:) table
            end

            variableNames = string(data.Properties.VariableNames);
            nRows = height(data);
            nVars = width(data);
            values = cell(nVars, nRows + 1);
            values(:, 1) = cellstr(variableNames(:));

            for iVar = 1:nVars
                columnData = data{:, iVar};
                if iscell(columnData)
                    values(iVar, 2:end) = reshape(columnData, 1, []);
                else
                    values(iVar, 2:end) = num2cell(reshape(columnData, 1, []));
                end
            end

            displayNames = ["Variable", "Row" + string(1:nRows)];
            displayNames = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(displayNames));
            data = cell2table(values, VariableNames=cellstr(displayNames));
        end
    end

    methods (Static, Access = private)
        function values = indexedValues(store, idx)
            arguments
                store (1,:) double
                idx (1,:) double
            end

            values = nan(1, numel(idx));
            valid = idx >= 1 & idx <= numel(store);
            values(valid) = store(idx(valid));
        end

        function [store, changed] = setIndexedValues(store, idx, values)
            arguments
                store (1,:) double
                idx (1,:) double
                values (1,:) double
            end

            nValues = min(numel(idx), numel(values));
            idx = idx(1:nValues);
            values = values(1:nValues);
            idx = round(idx);
            valid = idx >= 1 & isfinite(idx) & isfinite(values);
            idx = idx(valid);
            values = values(valid);
            if isempty(idx)
                changed = false;
                return
            end

            original = store;
            nStore = max(numel(store), max(idx));
            if numel(store) < nStore
                store(end+1:nStore) = NaN;
            end

            for iValue = 1:numel(idx)
                store(idx(iValue)) = values(iValue);
            end
            changed = ~isequaln(original, store);
        end

        function data = selectVisibleColumns(data, state)
            idx = ismember(data.Properties.VariableNames, state.VisibleDataColumnNames);
            firstIdx = find(idx, 1);

            if (isempty(firstIdx) || firstIdx ~= 1) && ~isempty(state.GroupingVariable)
                data = gwidgets.internal.table.DisplayController.selectGroupedColumns(data, idx, firstIdx, state);
            else
                data = data(:, idx);
            end
        end

        function data = selectGroupedColumns(data, idx, firstIdx, state)
            vghri = state.VisibleGroupHeaderRowIdx;
            rowHeaders = data{vghri, 1};
            if isempty(rowHeaders)
                rowHeaders = string.empty(0,1);
            end

            if isempty(firstIdx)
                data = table(repelem("Hidden Item", height(data), 1), VariableNames="Group");
                data{vghri, 1} = num2cell(rowHeaders);
                return
            end

            data = data(:, idx);
            if ~isstring(data{:, 1})
                if ~iscell(data{:, 1})
                    data = convertvars(data, 1, "cell");
                end
                data{vghri, 1} = num2cell(rowHeaders);
            else
                data{vghri, 1} = rowHeaders;
            end
        end
    end
end

