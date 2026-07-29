classdef DisplayController < gwidgets.internal.table.TableController
    % DisplayController applies computed table state to the backing uitable.

    properties (Dependent)
        Orientation
        Data
        ColumnName
        ColumnEditable
        ColumnSortable
        ColumnWidth
        GroupHeaderRows
        GroupHeaderLevels
    end

    properties (Access = private)
        Orientation_ (1,1) string {mustBeMember(Orientation_, ["Normal", "Transposed"])} = "Normal"
        RenderedData_ (:,:) table = table.empty(0,0)
        ColumnName_ (1,:) cell = cell.empty(1,0)
        ColumnEditable_ (1,:) logical = false(1,0)
        ColumnSortable_ (1,:) logical = false(1,0)
        SelectionType_ (1,1) string {mustBeMember(SelectionType_, ["cell", "row", "column"])} = "cell"
        ColumnWidth_ (1,:) cell = cell.empty(1,0)
        GroupHeaderRows_ (1,:) double = zeros(1,0)
        GroupHeaderLevels_ (1,:) double = zeros(1,0)
        GroupHeaderColumnWidths_ (1,:) double = nan(1,0)
        GroupHeaderColumnKeys_ (1,:) string = string.empty(1,0)
        GroupHeaderColumnKeyWidths_ (1,:) double = nan(1,0)
        GroupHeaderRowWidths_ (1,:) double = nan(1,0)
        TransposedDataRowColumnWidths_ (1,:) double = nan(1,0)
        TransposedVariableHeaderWidth_ (1,1) double = NaN
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
            owner.Menu.refresh();
        end

        function val = get.Data(this)
            val = this.RenderedData_;
        end

        function val = get.ColumnName(this)
            val = this.ColumnName_;
        end

        function val = get.ColumnEditable(this)
            val = this.ColumnEditable_;
        end

        function val = get.ColumnSortable(this)
            val = this.ColumnSortable_;
        end

        function val = get.ColumnWidth(this)
            val = this.ColumnWidth_;
        end

        function val = get.GroupHeaderRows(this)
            val = this.GroupHeaderRows_;
        end

        function val = get.GroupHeaderLevels(this)
            val = this.GroupHeaderLevels_;
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
            if isempty(backend) || ~backend.isReady()
                return
            end

            owner.Bridge.suppress();
            visWidths = this.visibleColumnWidths(owner);
            if isempty(visWidths)
                visWidths = {"Auto"};
            end

            if ~isequal(this.ColumnWidth_, visWidths)
                this.ColumnWidth_ = visWidths;
                if isa(backend, "gwidgets.internal.table.backend.JSTableBackend")
                    owner.Graphics.setViewProperties({"ColumnWidth", visWidths});
                    owner.forceRefresh();
                    owner.Bridge.restore();
                    return
                end

                owner.Graphics.setViewProperties({"ColumnWidth", {"Auto"}});
                owner.forceRefresh();
                owner.Graphics.setViewProperties({"ColumnWidth", visWidths});
            else
                owner.Graphics.refreshViews();
            end
            owner.Bridge.restore();
        end

        function requestAutoResize(this)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
            end

            owner = this.owner();
            backend = owner.Graphics.Backend;
            if isa(backend, "gwidgets.internal.table.backend.JSTableBackend")
                backend.requestAutoResizeColumns();
                return
            end

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

        function handleAutoResizeColumnWidths(this, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                pixelWidths (1,:) double
            end

            owner = this.owner();
            if this.Orientation == "Transposed"
                if this.updateTransposedWidths(owner, pixelWidths)
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
            if any(visibleMask)
                changed = owner.Column.setPixelWidthsForMask(dataPixelWidths, visibleMask);
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

        function handleBridgeColumnWidths(this, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                pixelWidths (1,:) double
            end

            owner = this.owner();
            if this.Orientation == "Transposed"
                if this.updateTransposedWidths(owner, pixelWidths)
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

        function handleBridgeColumnResize(this, displayColumn, pixelWidths, startPixelWidth)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                displayColumn (1,1) double
                pixelWidths (1,:) double
                startPixelWidth (1,1) double = NaN
            end

            owner = this.owner();
            displayColumn = round(displayColumn);
            if ~isfinite(displayColumn) || displayColumn < 1 || displayColumn > numel(pixelWidths)
                owner.Bridge.restore();
                return
            end

            if this.Orientation == "Transposed"
                if this.updateTransposedWidth(owner, displayColumn, pixelWidths(displayColumn))
                    this.applyColumnWidth();
                else
                    owner.Bridge.restore();
                end
                return
            end

            [dataPixelWidths, visibleMask, ~, canMap] = this.normalBridgeWidthMap(owner, pixelWidths);
            if ~canMap
                owner.Bridge.restore();
                return
            end

            [resizedMask, syntheticPixelWidth, canMap] = ...
                this.normalBridgeResizedColumnMap(owner, displayColumn, pixelWidths);
            if ~canMap
                owner.Bridge.restore();
                return
            end

            changed = false;
            if any(resizedMask)
                changed = owner.Column.updateBridgeResizeForMask( ...
                    dataPixelWidths, visibleMask, resizedMask, startPixelWidth);
            end

            if isfinite(syntheticPixelWidth) && syntheticPixelWidth > 0
                changed = this.updateNormalSyntheticHeaderWidths(owner, syntheticPixelWidth) || changed;
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
            toUpdate = cell(1, 6*numel(vars));
            nUpdates = 0;
            for iVar = 1:numel(vars)
                currentVar = vars(iVar);
                newVal = this.propertyValue(owner, currentVar);

                if currentVar == "VisibleData"
                    newVal = gwidgets.internal.table.DisplayController.visibleDataForTable( ...
                        newVal, this.updateState(owner));
                    columnName = this.columnNamesForDisplay(newVal);
                    newVal = this.orientVisibleData(newVal);
                    newVar = "Data";
                    currentVal = this.RenderedData_;
                else
                    currentVal = this.currentRenderProperty(currentVar);
                    newVar = currentVar;
                end

                if ~isequal(currentVal, newVal)
                    this.setRenderProperty(newVar, newVal);
                    nUpdates = nUpdates + 2;
                    toUpdate(nUpdates-1:nUpdates) = {newVar, newVal};
                end

                if currentVar == "VisibleData" && ~isequal(this.ColumnName_, columnName)
                    this.ColumnName_ = columnName;
                    nUpdates = nUpdates + 2;
                    toUpdate(nUpdates-1:nUpdates) = {"ColumnName", columnName};
                end

                if currentVar == "VisibleData"
                    [groupHeaderRows, groupHeaderLevels] = this.groupHeadersForDisplay(owner);
                    if ~isequal(this.GroupHeaderRows_, groupHeaderRows)
                        this.GroupHeaderRows_ = groupHeaderRows;
                        nUpdates = nUpdates + 2;
                        toUpdate(nUpdates-1:nUpdates) = {"GroupHeaderRows", groupHeaderRows};
                    end
                    if ~isequal(this.GroupHeaderLevels_, groupHeaderLevels)
                        this.GroupHeaderLevels_ = groupHeaderLevels;
                        nUpdates = nUpdates + 2;
                        toUpdate(nUpdates-1:nUpdates) = {"GroupHeaderLevels", groupHeaderLevels};
                    end
                end
            end

            if nUpdates > 0
                owner.Graphics.setViewProperties(toUpdate(1:nUpdates));
            end
        end

        function state = renderState(this)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
            end

            owner = this.owner();
            state = struct( ...
                "Data", this.RenderedData_, ...
                "ColumnName", {this.ColumnName_}, ...
                "ColumnEditable", this.ColumnEditable_, ...
                "ColumnSortable", this.ColumnSortable_, ...
                "SelectionType", owner.Selection.Type, ...
                "Multiselect", owner.Selection.Multiselect, ...
                "Selection", owner.Selection.DisplayValue, ...
                "ColumnWidth", {this.ColumnWidth_}, ...
                "GroupHeaderRows", this.GroupHeaderRows_, ...
                "GroupHeaderLevels", this.GroupHeaderLevels_, ...
                "StyleConfigurations", owner.Style.Configurations, ...
                "Tooltip", owner.Tooltip.Text, ...
                "Orientation", this.Orientation_);
        end
    end

    methods (Access = private)
        function value = currentRenderProperty(this, propertyName)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                propertyName (1,1) string
            end

            switch propertyName
                case "ColumnEditable"
                    value = this.ColumnEditable_;
                case "ColumnSortable"
                    value = this.ColumnSortable_;
                case "SelectionType"
                    value = char(this.SelectionType_);
                otherwise
                    error("GraphicsWidgets:UITable:DisplayProperty", ...
                        "Unsupported display property: %s", propertyName);
            end
        end

        function setRenderProperty(this, propertyName, value)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                propertyName (1,1) string
                value
            end

            switch propertyName
                case "Data"
                    this.RenderedData_ = value;
                case "ColumnEditable"
                    this.ColumnEditable_ = value;
                case "ColumnSortable"
                    this.ColumnSortable_ = value;
                case "SelectionType"
                    this.SelectionType_ = string(value);
                otherwise
                    error("GraphicsWidgets:UITable:DisplayProperty", ...
                        "Unsupported display property: %s", propertyName);
            end
        end

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
            widths{1} = this.transposedVariableHeaderWidth(owner);
            widths = this.applyTransposedDataRowWidths(owner, widths);

            headerColumns = owner.Data.VisibleGroupHeaderRowIdx + 1;
            headerWidths = this.visibleGroupHeaderColumnWidths(owner, headerColumns);
            defaultHeaderWidth = gwidgets.internal.table.DisplayController.defaultGroupHeaderColumnWidth();
            for iColumn = 1:numel(headerColumns)
                displayColumn = headerColumns(iColumn);
                if displayColumn < 1 || displayColumn > nColumns
                    continue
                end
                if isfinite(headerWidths(iColumn)) && headerWidths(iColumn) > 0
                    widths{displayColumn} = headerWidths(iColumn);
                else
                    widths{displayColumn} = defaultHeaderWidth;
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

            displayData = this.Data;
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

            displayData = this.Data;
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

        function [resizedMask, syntheticPixelWidth, canMap] = normalBridgeResizedColumnMap( ...
                this, owner, displayColumn, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                displayColumn (1,1) double
                pixelWidths (1,:) double
            end

            displayData = this.Data;
            allDataNames = owner.Column.DataNames;
            resizedMask = false(1, numel(allDataNames));
            syntheticPixelWidth = NaN;
            canMap = false;

            if width(displayData) == 0 || numel(pixelWidths) ~= width(displayData) || ...
                    displayColumn > width(displayData)
                return
            end

            if this.isNormalSyntheticGroupDisplay(owner, displayData)
                syntheticPixelWidth = pixelWidths(displayColumn);
                canMap = true;
                return
            end

            displayNames = string(displayData.Properties.VariableNames);
            dataName = owner.Column.aliasesToData(displayNames(displayColumn));
            dataIdx = find(allDataNames == dataName, 1);
            if isempty(dataIdx)
                syntheticPixelWidth = pixelWidths(displayColumn);
            else
                resizedMask(dataIdx) = true;
            end
            canMap = true;
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

        function changed = updateTransposedWidths(this, owner, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                pixelWidths (1,:) double
            end

            changed = false;
            changed = this.updateTransposedDataRowWidths(owner, pixelWidths) || changed;
            changed = this.updateTransposedHeaderWidths(owner, pixelWidths) || changed;
        end

        function changed = updateTransposedWidth(this, owner, displayColumn, pixelWidth)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                displayColumn (1,1) double
                pixelWidth (1,1) double
            end

            if displayColumn == 1
                changed = this.updateTransposedVariableHeaderWidth(pixelWidth);
                return
            end

            changed = this.updateTransposedHeaderWidth(owner, displayColumn, pixelWidth);
            if changed
                return
            end

            changed = this.updateTransposedDataRowWidth(owner, displayColumn, pixelWidth);
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
            didChangeKeys = this.setGroupHeaderColumnKeyWidths(owner, headerColumns, pixelWidths(headerColumns));
            changed = didChangeKeys || changed;
        end

        function changed = updateTransposedHeaderWidth(this, owner, displayColumn, pixelWidth)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                displayColumn (1,1) double
                pixelWidth (1,1) double
            end

            headerColumns = owner.Data.VisibleGroupHeaderRowIdx + 1;
            if ~any(headerColumns == displayColumn)
                changed = false;
                return
            end

            [this.GroupHeaderColumnWidths_, changed] = ...
                gwidgets.internal.table.DisplayController.setIndexedValues( ...
                this.GroupHeaderColumnWidths_, displayColumn, pixelWidth);
            didChangeKey = this.setGroupHeaderColumnKeyWidths(owner, displayColumn, pixelWidth);
            changed = didChangeKey || changed;
        end

        function changed = updateTransposedDataRowWidths(this, owner, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                pixelWidths (1,:) double
            end

            visibleToData = reshape(owner.Data.FoldedVisibleToDataMap, 1, []);
            displayColumns = 2:(numel(visibleToData) + 1);
            idx = displayColumns <= numel(pixelWidths) & isfinite(visibleToData) & visibleToData > 0;
            dataRows = visibleToData(idx);
            displayColumns = displayColumns(idx);
            if isempty(dataRows)
                changed = false;
                return
            end

            [this.TransposedDataRowColumnWidths_, changed] = ...
                gwidgets.internal.table.DisplayController.setIndexedValues( ...
                this.TransposedDataRowColumnWidths_, dataRows, pixelWidths(displayColumns));
        end

        function changed = updateTransposedDataRowWidth(this, owner, displayColumn, pixelWidth)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                displayColumn (1,1) double
                pixelWidth (1,1) double
            end

            visibleRow = displayColumn - 1;
            visibleToData = reshape(owner.Data.FoldedVisibleToDataMap, 1, []);
            if visibleRow < 1 || visibleRow > numel(visibleToData)
                changed = false;
                return
            end

            dataRow = visibleToData(visibleRow);
            if ~isfinite(dataRow) || dataRow <= 0
                changed = false;
                return
            end

            [this.TransposedDataRowColumnWidths_, changed] = ...
                gwidgets.internal.table.DisplayController.setIndexedValues( ...
                this.TransposedDataRowColumnWidths_, dataRow, pixelWidth);
        end

        function changed = updateTransposedVariableHeaderWidth(this, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                pixelWidths (1,:) double
            end

            if isempty(pixelWidths) || ~isfinite(pixelWidths(1)) || pixelWidths(1) <= 0
                changed = false;
                return
            end

            changed = ~isequaln(this.TransposedVariableHeaderWidth_, pixelWidths(1));
            this.TransposedVariableHeaderWidth_ = pixelWidths(1);
        end

        function widths = visibleGroupHeaderColumnWidths(this, owner, headerColumns)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                headerColumns (1,:) double
            end

            widths = gwidgets.internal.table.DisplayController.indexedValues( ...
                this.GroupHeaderColumnWidths_, headerColumns);

            groupKeys = reshape(owner.Group.DisplayGroups, 1, []);
            nValues = min(numel(groupKeys), numel(widths));
            for iGroup = 1:nValues
                keyIdx = find(this.GroupHeaderColumnKeys_ == groupKeys(iGroup), 1);
                if isempty(keyIdx)
                    continue
                end

                keyWidth = this.GroupHeaderColumnKeyWidths_(keyIdx);
                if isfinite(keyWidth) && keyWidth > 0
                    widths(iGroup) = keyWidth;
                end
            end
        end

        function widths = applyTransposedDataRowWidths(this, owner, widths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                widths (1,:) cell
            end

            visibleToData = reshape(owner.Data.FoldedVisibleToDataMap, 1, []);
            storedWidths = gwidgets.internal.table.DisplayController.indexedValues( ...
                this.TransposedDataRowColumnWidths_, visibleToData);
            nRows = min(numel(visibleToData), numel(widths) - 1);
            for iRow = 1:nRows
                if isfinite(storedWidths(iRow)) && storedWidths(iRow) > 0
                    widths{iRow + 1} = storedWidths(iRow);
                end
            end
        end

        function width = transposedVariableHeaderWidth(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
            end

            width = this.TransposedVariableHeaderWidth_;
            if ~isfinite(width) || width <= 0
                backend = owner.Graphics.Backend;
                if isa(backend, "gwidgets.internal.table.backend.JSTableBackend")
                    width = gwidgets.internal.table.DisplayController.defaultTransposedVariableHeaderWidth(owner);
                else
                    width = "1x";
                end
            end
        end

        function changed = setGroupHeaderColumnKeyWidths(this, owner, headerColumns, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                owner (1,1) gwidgets.UITable
                headerColumns (1,:) double
                pixelWidths (1,:) double
            end

            groupKeys = reshape(owner.Group.DisplayGroups, 1, []);
            visibleColumns = reshape(owner.Data.VisibleGroupHeaderRowIdx, 1, []) + 1;
            nValues = min(numel(headerColumns), numel(pixelWidths));
            changed = false;
            for iValue = 1:nValues
                displayColumn = headerColumns(iValue);
                groupIdx = find(visibleColumns == displayColumn, 1);
                if isempty(groupIdx) || groupIdx > numel(groupKeys)
                    continue
                end

                pixelWidth = pixelWidths(iValue);
                if ~isfinite(pixelWidth) || pixelWidth <= 0
                    continue
                end

                key = groupKeys(groupIdx);
                existingIdx = find(this.GroupHeaderColumnKeys_ == key, 1);
                if isempty(existingIdx)
                    this.GroupHeaderColumnKeys_(end+1) = key;
                    this.GroupHeaderColumnKeyWidths_(end+1) = pixelWidth;
                    changed = true;
                elseif ~isequaln(this.GroupHeaderColumnKeyWidths_(existingIdx), pixelWidth)
                    this.GroupHeaderColumnKeyWidths_(existingIdx) = pixelWidth;
                    changed = true;
                end
            end
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

        function width = defaultGroupHeaderColumnWidth()
            arguments
            end

            width = 36;
        end

        function width = defaultTransposedVariableHeaderWidth(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            labels = reshape(owner.Column.VisibleNames, 1, []);
            labels(ismember(owner.Column.VisibleDataNames, owner.Group.By)) = [];
            labels = ["Variable", labels];
            width = max(64, 14 + 7*max(strlength(labels)));
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

