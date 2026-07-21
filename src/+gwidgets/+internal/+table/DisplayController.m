classdef DisplayController < gwidgets.internal.table.TableController
    % DisplayController applies computed table state to the backing uitable.

    properties (Dependent)
        Orientation
    end

    properties (Access = private)
        Orientation_ (1,1) string {mustBeMember(Orientation_, ["Normal", "Transposed"])} = "Normal"
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
            displayTable = owner.Graphics.DisplayTable;

            owner.Bridge.suppress();
            visWidths = this.visibleColumnWidths(owner);
            if ~isequal(displayTable.ColumnWidth, visWidths)
                if isempty(visWidths)
                    visWidths = {"Auto"};
                end
                displayTable.ColumnWidth = {"Auto"};
                owner.forceRefresh();
                displayTable.ColumnWidth = visWidths;
            end
            owner.Bridge.restore();
        end

        function update(this, vars)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                vars (1,:) string
            end

            owner = this.owner();
            displayTable = owner.Graphics.DisplayTable;
            toUpdate = cell(1, 2*numel(vars));
            nUpdates = 0;
            for iVar = 1:numel(vars)
                currentVar = vars(iVar);
                newVal = this.propertyValue(owner, currentVar);

                if currentVar == "VisibleData"
                    currentVal = displayTable.DisplayData;
                    newVal = gwidgets.internal.table.DisplayController.visibleDataForTable( ...
                        newVal, this.updateState(owner));
                    columnName = this.columnNamesForDisplay(newVal);
                    newVal = this.orientVisibleData(newVal);
                    newVar = "Data";
                else
                    currentVal = displayTable.(currentVar);
                    newVar = currentVar;
                end

                if ~isequal(currentVal, newVal)
                    nUpdates = nUpdates + 2;
                    toUpdate(nUpdates-1:nUpdates) = {newVar, newVal};
                end

                if currentVar == "VisibleData" && ~isequal(displayTable.ColumnName, columnName)
                    nUpdates = nUpdates + 2;
                    toUpdate(nUpdates-1:nUpdates) = {"ColumnName", columnName};
                end
            end

            if nUpdates > 0
                set(displayTable, toUpdate{1:nUpdates});
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
                widths = owner.Column.Width;
                return
            end

            widths = [{"Auto"}, repmat({"Auto"}, 1, height(owner.Data.Visible))];
        end

        function width = transposedWidth(this)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
            end

            owner = this.owner();
            width = height(owner.Data.Visible) + 1;
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

