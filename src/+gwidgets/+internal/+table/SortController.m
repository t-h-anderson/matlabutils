classdef SortController < gwidgets.internal.table.TableController
    % SortController owns sort-related table state.

    properties (Dependent)
        By
        ByData
        Direction
    end

    properties (Access = private)
        ByColumnIdxs_ (1,:) double = double.empty(1,0)
        Direction_ (1,1) string {mustBeMember(Direction_, ["Ascend", "Descend", "None"])} = "None"
        SortingEngine (1,:) gwidgets.internal.table.SortingController {mustBeScalarOrEmpty}
    end

    methods
        function this = SortController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
            this.SortingEngine = gwidgets.internal.table.SortingController();
        end

        function delete(this)
            delete(this.SortingEngine);
        end

        function val = get.By(this)
            if isempty(this.ByColumnIdxs_)
                val = string.empty(1,0);
                return
            end

            val = this.owner().Column.namesAt(this.ByColumnIdxs_);
        end

        function set.By(this, val)
            arguments
                this (1,1) gwidgets.internal.table.SortController
                val (1,:) string
            end

            val = rmmissing(val);

            owner = this.owner();
            columnNames = owner.Column.Names;
            sortableColumnNames = columnNames(owner.Column.DataSortable);
            idx = ~ismember(val, sortableColumnNames);
            if any(idx)
                error("GraphicsWidgets:Table:NotASortableColumn", ...
                    "Specified columns are not sortable")
            end

            this.ByColumnIdxs_ = gwidgets.internal.table.SortController.namesToIndex(val, columnNames);
            if owner.doControllerUpdate("SortByColumn")
                owner.requestControllerUpdate(StartFrom="Sorting");
            end
        end

        function val = get.ByData(this)
            if isempty(this.ByColumnIdxs_)
                val = string.empty(1,0);
                return
            end

            val = this.owner().Column.dataNamesAt(this.ByColumnIdxs_);
        end

        function set.ByData(this, val)
            arguments
                this (1,1) gwidgets.internal.table.SortController
                val (1,:) string
            end

            val = rmmissing(val);

            owner = this.owner();
            dataColumnNames = owner.Column.DataNames;
            sortableDataColumnNames = dataColumnNames(owner.Column.DataSortable);
            idx = ~ismember(val, sortableDataColumnNames);
            if any(idx)
                error("GraphicsWidgets:Table:NotASortableColumn", ...
                    "Specified columns are not sortable")
            end

            this.ByColumnIdxs_ = gwidgets.internal.table.SortController.namesToIndex(val, dataColumnNames);
            if owner.doControllerUpdate("SortByColumn")
                owner.requestControllerUpdate(StartFrom="Sorting");
            end
        end

        function val = get.Direction(this)
            val = this.Direction_;
        end

        function set.Direction(this, val)
            arguments
                this (1,1) gwidgets.internal.table.SortController
                val (1,1) string {mustBeMember(val, ["Ascend", "Descend", "None"])}
            end

            this.Direction_ = val;

            if this.owner().doControllerUpdate("SortDirection")
                this.owner().requestControllerUpdate(StartFrom="Sorting");
            end
        end

        function requestSortByContext(this, displayRow, displayColumn, direction)
            arguments
                this (1,1) gwidgets.internal.table.SortController
                displayRow (1,1) double
                displayColumn (1,1) double
                direction (1,1) string {mustBeMember(direction, ["Ascend", "Descend", "None"])}
            end

            owner = this.owner();
            owner.addControllerUpdateSuppression("SortDirection", Times=1);
            this.Direction = direction;

            if ismember(displayRow, owner.Data.VisibleGroupHeaderRowIdx)
                vars = owner.Group.By;
            else
                vars = owner.Data.GroupedVariables(this.sortColumnFromContext(displayColumn));
            end

            this.By = vars;
        end

        function result = sortData(this, dataController)
            arguments
                this (1,1) gwidgets.internal.table.SortController
                dataController (1,1) gwidgets.internal.table.DataController
            end

            owner = this.owner();
            result = this.SortingEngine.sort( ...
                dataController.Filtered, ...
                dataController.Table, ...
                dataController.GroupedVisible, ...
                dataController.GroupedVariables, ...
                owner.Group.By, ...
                owner.Group.Groups, ...
                dataController.GroupHeaderRowIdx, ...
                dataController.GroupedVisibleToDataMap, ...
                dataController.GroupedDataToVisibleMap, ...
                owner.Column.DataSortable, ...
                this.ByData, ...
                this.Direction);
        end
    end

    methods (Access = private)
        function colIdx = sortColumnFromContext(this, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.SortController
                displayColumn (1,1) double
            end

            selection = this.owner().Selection;
            switch selection.Type
                case "cell"
                    colIdx = unique(selection.DisplayValue(:,2));
                case "column"
                    colIdx = unique(selection.DisplayValue);
                case "row"
                    colIdx = displayColumn;
                otherwise
                    colIdx = displayColumn;
            end
        end
    end

    methods (Static, Access = private)
        function idx = namesToIndex(values, names)
            arguments
                values (1,:) string
                names (1,:) string
            end

            isMatch = (values == names');
            idx = nan(1, size(isMatch, 2));
            for iValue = 1:size(isMatch, 2)
                idx(iValue) = find(isMatch(:,iValue), 1);
            end
        end
    end
end

