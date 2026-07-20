classdef DataController < gwidgets.internal.table.TableController
    % DataController owns raw and derived table data state.

    properties (Dependent)
        Table (:,:) table
        Display (:,:) table
    end

    properties
        TextColumns (:,:) table = table.empty(0,0)
        RowFilterIndices (1,:) logical = false(1,0)
        Filtered (:,:) table = table.empty(0,0)
        FilteredVisibleToDataMap (1,:) double = double.empty(1,0)
        FilteredDataToVisibleMap (1,:) double = double.empty(1,0)
        GroupedVisible (:,:) cell = cell.empty(0,0)
        GroupedVariables (1,:) string = string.empty(1,0)
        GroupKeys (:,:) table = table.empty(0,0)
        GroupHeaderRowIdx (1,:) double = double.empty(1,0)
        GroupHeaderLevels (1,:) double = double.empty(1,0)
        GroupHeaderDataRows (1,:) cell = cell.empty(1,0)
        GroupColumnIdx (1,:) double = double.empty(1,0)
        GroupFilteredCount (1,:) double = double.empty(1,0)
        GroupIdxs (1,:) double = double.empty(1,0)
        GroupedVisibleToDataMap (1,:) double = double.empty(1,0)
        GroupedDataToVisibleMap (1,:) double = double.empty(1,0)
        SortedVisible (:,:) cell = cell.empty(0,0)
        SortedGroupHeaderRowIdx (1,:) double = double.empty(1,0)
        SortedGroupHeaderLevels (1,:) double = double.empty(1,0)
        SortedGroupHeaderDataRows (1,:) cell = cell.empty(1,0)
        SortedGroupValues (1,:) string = string.empty(1,0)
        SortedGroupKeys (:,:) table = table.empty(0,0)
        SortedGroupFilteredCount (1,:) double = double.empty(1,0)
        SortedVisibleToDataMap (1,:) double = double.empty(1,0)
        SortedDataToVisibleMap (1,:) double = double.empty(1,0)
        FoldedVisibleToDataMap (1,:) double = double.empty(1,0)
        FoldedDataToVisibleMap (1,:) double = double.empty(1,0)
        Visible (:,:) table = table.empty(0,0)
        VisibleGroupHeaderRowIdx (1,:) double = double.empty(1,0)
        VisibleGroupHeaderLevels (1,:) double = double.empty(1,0)
    end

    properties (Access = private)
        Table_ (:,:) table = table.empty(0,0)
        FilteringChangedListener (1,:) event.listener {mustBeScalarOrEmpty}
    end

    methods
        function this = DataController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
        end

        function set.Table(this, data)
            arguments
                this (1,1) gwidgets.internal.table.DataController
                data (:,:) table
            end

            this.Table_ = data;
            this.requestTableUpdate();
        end

        function data = get.Table(this)
            data = this.Table_;
        end

        function initialize(this)
            arguments
                this (1,1) gwidgets.internal.table.DataController
            end

            owner = this.owner();
            if isempty(owner)
                return
            end

            this.attachFilterController(owner.Filter);
        end

        function val = get.Display(this)
            owner = this.owner();
            if isempty(owner) || isempty(owner.Graphics.DisplayTable)
                val = table.empty(0,0);
                return
            end

            val = owner.Graphics.DisplayTable.Data;
        end

        function attachFilterController(this, filterController)
            arguments
                this (1,1) gwidgets.internal.table.DataController
                filterController (1,1) gwidgets.internal.table.FilterController
            end

            this.FilteringChangedListener = this.weaklistener(filterController, "FilterChanged");
        end

        function updateFiltering(this)
            arguments
                this (1,1) gwidgets.internal.table.DataController
            end

            owner = this.owner();
            filterController = owner.Filter;
            columnController = owner.Column;
            data = this.Table;

            if ~isempty(columnController.Names)
                data.Properties.VariableNames = columnController.Names;
            end
            [data, idx] = filterController.applyFilter(data, filterController.FilterValue);

            data.Properties.VariableNames = columnController.DataNames;

            this.FilteredVisibleToDataMap = find(idx);
            tmp = cumsum(idx);
            tmp(~idx) = NaN;
            this.FilteredDataToVisibleMap = tmp;

            this.Filtered = data;
            this.RowFilterIndices = idx;
        end

        function updateGrouping(this)
            arguments
                this (1,1) gwidgets.internal.table.DataController
            end

            owner = this.owner();
            groupController = owner.Group;
            if isempty(groupController.By)
                this.GroupedVisible = table2cell(this.Filtered);
                this.GroupedVariables = string(this.Filtered.Properties.VariableNames);
                groupController.clearGroupingState();
                this.GroupKeys = table.empty(0,0);
                this.GroupHeaderRowIdx = zeros(1,0);
                this.GroupHeaderLevels = zeros(1,0);
                this.GroupHeaderDataRows = cell.empty(1,0);
                this.GroupColumnIdx = zeros(1,0);
                this.GroupFilteredCount = zeros(1,0);
                this.GroupIdxs = zeros(1,0);

                this.GroupedDataToVisibleMap = this.FilteredDataToVisibleMap;
                this.GroupedVisibleToDataMap = this.FilteredVisibleToDataMap;
                return
            end

            result = groupController.groupData(this);

            this.GroupedVisible = result.GroupedVisibleData;
            this.GroupedVariables = result.GroupedDataVariables;
            groupController.applyGroupingResult(result);
            this.GroupKeys = result.GroupKeys;
            this.GroupHeaderRowIdx = result.GroupHeaderRowIdx;
            this.GroupHeaderLevels = result.GroupHeaderLevels;
            this.GroupHeaderDataRows = result.GroupHeaderDataRows;
            this.GroupColumnIdx = result.GroupColumnIdx;
            this.GroupFilteredCount = result.GroupFilteredCount;
            this.GroupIdxs = result.GroupIdxs;
            this.GroupedDataToVisibleMap = result.GroupedDataToVisibleMap;
            this.GroupedVisibleToDataMap = result.GroupedVisibleToDataMap;
        end

        function updateSorting(this)
            arguments
                this (1,1) gwidgets.internal.table.DataController
            end

            owner = this.owner();
            sortController = owner.Sort;
            groupController = owner.Group;
            this.SortedVisible = this.GroupedVisible;
            this.SortedDataToVisibleMap = this.GroupedDataToVisibleMap;
            this.SortedVisibleToDataMap = this.GroupedVisibleToDataMap;
            this.SortedGroupHeaderRowIdx = this.GroupHeaderRowIdx;
            this.SortedGroupHeaderLevels = this.GroupHeaderLevels;
            this.SortedGroupHeaderDataRows = this.GroupHeaderDataRows;
            this.SortedGroupValues = groupController.Groups;
            this.SortedGroupKeys = this.GroupKeys;
            this.SortedGroupFilteredCount = this.GroupFilteredCount;

            if sortController.Direction == "None" || isempty(sortController.ByData)
                return
            end

            result = sortController.sortData(this);

            this.SortedVisible = result.SortedVisibleData;
            this.SortedDataToVisibleMap = result.SortedDataToVisibleMap;
            this.SortedVisibleToDataMap = result.SortedVisibleToDataMap;
            this.SortedGroupHeaderRowIdx = result.SortedGroupHeaderRowIdx;
            this.SortedGroupHeaderLevels = result.SortedGroupHeaderLevels;
            this.SortedGroupHeaderDataRows = result.SortedGroupHeaderDataRows;
            this.SortedGroupValues = result.SortedGroupValues;
            this.SortedGroupKeys = result.SortedGroupKeys;
            this.SortedGroupFilteredCount = result.SortedGroupFilteredCount;
        end

        function updateFolding(this)
            arguments
                this (1,1) gwidgets.internal.table.DataController
            end

            owner = this.owner();
            groupController = owner.Group;
            if isempty(groupController.By)
                groupController.clearDisplayGroups();
                this.FoldedVisibleToDataMap = this.SortedVisibleToDataMap;
                this.FoldedDataToVisibleMap = this.SortedDataToVisibleMap;
                this.VisibleGroupHeaderRowIdx = zeros(1,0);
                this.VisibleGroupHeaderLevels = zeros(1,0);
                this.Visible = cell2table(this.SortedVisible, ...
                    VariableNames=string(this.Table.Properties.VariableNames));
                return
            end

            result = groupController.foldData(this);

            this.Visible = result.VisibleData;
            owner.addControllerUpdateSuppression("HiddenGroups", Times=1);
            groupController.applyFoldingResult(result);
            this.VisibleGroupHeaderRowIdx = result.VisibleGroupHeaderRowIdx;
            this.VisibleGroupHeaderLevels = result.VisibleGroupHeaderLevels;
            this.FoldedVisibleToDataMap = result.FoldedVisibleToDataMap;
            this.FoldedDataToVisibleMap = result.FoldedDataToVisibleMap;
        end

        function editDisplayCell(this, displayIdx, value, selectionController)
            arguments
                this (1,1) gwidgets.internal.table.DataController
                displayIdx (:,2)
                value
                selectionController (1,1) gwidgets.internal.table.SelectionController
            end

            dataIdx = selectionController.displayToData(displayIdx, "cell");
            this.Table{dataIdx(1), dataIdx(2)} = value;

            owner = this.owner();
            if owner.doControllerUpdate("Filter")
                owner.requestControllerUpdate(StartFrom="Filtering");
            end
        end

        function result = find(this, str, target)
            arguments
                this (1,1) gwidgets.internal.table.DataController
                str (1,1) string
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])} = "table"
            end

            [~, ~, ~, filterMatches] = gwidgets.internal.FilterController.filterIndices(str, this.Table);

            result = cell(1, numel(filterMatches));
            for iMatch = 1:numel(filterMatches)

                thisCol = find(filterMatches(iMatch).ColumnIdx);
                rowIdxs = find(filterMatches(iMatch).RowIdx);

                result{iMatch} = [rowIdxs, repelem(thisCol, numel(rowIdxs), 1)];
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
                otherwise
                    % Argument validation prevents this branch.
            end
        end
    end

    methods (Access = {?gwidgets.internal.WithWeakListeners})
        function onFilterChanged(this, ~, ~)
            owner = this.owner();
            if isempty(owner)
                return
            end

            if owner.doControllerUpdate("Filter")
                owner.requestControllerUpdate(StartFrom="Filtering");
            end
        end

    end

    methods (Access = private)
        function requestTableUpdate(this)
            owner = this.owner();
            if isempty(owner) || ~owner.doControllerUpdate("Data")
                return
            end

            try
                owner.requestControllerUpdate(StartFrom="Filtering");
            catch ME
                owner.reset();
                warning("GraphicsWidgets:Table:DataUpdateReset", ...
                    "Data update failed; table was reset. Original error: %s", ME.message);
            end
        end
    end
end
