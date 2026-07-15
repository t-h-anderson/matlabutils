classdef DisplayController < gwidgets.internal.table.TableController
    % DisplayController applies computed table state to the backing uitable.

    methods
        function this = DisplayController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
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
            displayTable = owner.DisplayTable;

            owner.BridgeController_.suppress();
            visWidths = owner.Column.Width;
            if ~isequal(displayTable.ColumnWidth, visWidths)
                if isempty(visWidths)
                    visWidths = {"Auto"};
                end
                displayTable.ColumnWidth = {"Auto"};
                owner.forceRefresh();
                displayTable.ColumnWidth = visWidths;
            end
            owner.BridgeController_.restore();
        end

        function update(this, vars)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController
                vars (1,:) string
            end

            owner = this.owner();
            displayTable = owner.DisplayTable;
            toUpdate = cell(1, 2*numel(vars));
            nUpdates = 0;
            for iVar = 1:numel(vars)
                currentVar = vars(iVar);
                newVal = this.propertyValue(owner, currentVar);

                if currentVar == "VisibleData"
                    currentVal = displayTable.DisplayData;
                    newVal = gwidgets.internal.table.DisplayController.visibleDataForTable( ...
                        newVal, this.updateState(owner));
                    newVar = "Data";
                else
                    currentVal = displayTable.(currentVar);
                    newVar = currentVar;
                end

                if ~isequal(currentVal, newVal)
                    nUpdates = nUpdates + 2;
                    toUpdate(nUpdates-1:nUpdates) = {newVar, newVal};
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
                this (1,1) gwidgets.internal.table.DisplayController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                propertyName (1,1) string
            end

            switch propertyName
                case "VisibleData"
                    value = owner.Data.Visible;
                case "ColumnEditable"
                    value = owner.Column.Editable;
                case "ColumnSortable"
                    value = owner.Column.Sortable;
                case "SelectionType"
                    value = owner.Selection.Type;
                otherwise
                    error("GraphicsWidgets:UITable:DisplayProperty", ...
                        "Unsupported display property: %s", propertyName);
            end
        end

        function state = updateState(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.DisplayController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
            end

            state = struct( ...
                "VisibleDataColumnNames", owner.Column.VisibleDataNames, ...
                "GroupingVariable", owner.Group.By, ...
                "VisibleGroupHeaderRowIdx", owner.Data.VisibleGroupHeaderRowIdx, ...
                "DataColumnNames", owner.Column.DataNames, ...
                "ColumnNames", owner.Column.Names);
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

