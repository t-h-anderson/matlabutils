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
        GroupHeaderRowIdx (1,:) double = double.empty(1,0)
        GroupColumnIdx (1,:) double = double.empty(1,0)
        GroupFilteredCount (1,:) double = double.empty(1,0)
        GroupIdxs (1,:) double = double.empty(1,0)
        GroupedVisibleToDataMap (1,:) double = double.empty(1,0)
        GroupedDataToVisibleMap (1,:) double = double.empty(1,0)
        SortedVisible (:,:) cell = cell.empty(0,0)
        SortedGroupHeaderRowIdx (1,:) double = double.empty(1,0)
        SortedGroupValues (1,:) string = string.empty(1,0)
        SortedVisibleToDataMap (1,:) double = double.empty(1,0)
        SortedDataToVisibleMap (1,:) double = double.empty(1,0)
        FoldedVisibleToDataMap (1,:) double = double.empty(1,0)
        FoldedDataToVisibleMap (1,:) double = double.empty(1,0)
        Visible (:,:) table = table.empty(0,0)
        VisibleGroupHeaderRowIdx (1,:) double = double.empty(1,0)
    end

    properties (Access = private)
        Table_ (:,:) table = table.empty(0,0)
        FilteringChangedListener (1,:) event.listener {mustBeScalarOrEmpty}
        FilteringHelpListener (1,:) event.listener
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

        function val = get.Display(this)
            owner = this.owner();
            if isempty(owner) || isempty(owner.DisplayTable)
                val = table.empty(0,0);
                return
            end

            val = owner.DisplayTable.Data;
        end

        function attachFilterController(this, filterController)
            arguments
                this (1,1) gwidgets.internal.table.DataController
                filterController (1,1) gwidgets.internal.FilterController
            end

            this.FilteringChangedListener = this.weaklistener(filterController, "FilterChanged");
            this.FilteringHelpListener = this.weaklistener(filterController, ...
                ["FilterHelpRequested", "FilterHelpClosed"]);
        end

        function updateFiltering(this, filterController, filterValue, columnController)
            arguments
                this (1,1) gwidgets.internal.table.DataController
                filterController (1,1) gwidgets.internal.FilterController
                filterValue
                columnController (1,1) gwidgets.internal.table.ColumnController
            end

            data = this.Table;

            if ~isempty(columnController.Names)
                data.Properties.VariableNames = columnController.Names;
            end
            [data, idx] = filterController.applyFilter(data, filterValue);

            data.Properties.VariableNames = columnController.DataNames;

            this.FilteredVisibleToDataMap = find(idx);
            tmp = cumsum(idx);
            tmp(~idx) = NaN;
            this.FilteredDataToVisibleMap = tmp;

            this.Filtered = data;
            this.RowFilterIndices = idx;
        end

        function updateGrouping(this, groupingController, groupController)
            arguments
                this (1,1) gwidgets.internal.table.DataController
                groupingController (1,:) gwidgets.internal.table.GroupingController {mustBeScalarOrEmpty}
                groupController (1,1) gwidgets.internal.table.GroupController
            end

            if isempty(groupController.By)
                this.GroupedVisible = table2cell(this.Filtered);
                this.GroupedVariables = string(this.Filtered.Properties.VariableNames);
                groupController.clearGroupingState();
                this.GroupHeaderRowIdx = zeros(1,0);
                this.GroupColumnIdx = zeros(1,0);
                this.GroupFilteredCount = zeros(1,0);
                this.GroupIdxs = zeros(1,0);

                this.GroupedDataToVisibleMap = this.FilteredDataToVisibleMap;
                this.GroupedVisibleToDataMap = this.FilteredVisibleToDataMap;
                return
            end

            if isempty(groupingController)
                error("GraphicsWidgets:Table:GroupingController", ...
                    "Grouping controller is required when grouping is active.");
            end

            result = groupingController.group(this.Table, this.Filtered, this.FilteredDataToVisibleMap, ...
                this.FilteredVisibleToDataMap, groupController.By, groupController.RawOpen, groupController.Hidden);

            this.GroupedVisible = result.GroupedVisibleData;
            this.GroupedVariables = result.GroupedDataVariables;
            groupController.applyGroupingResult(result);
            this.GroupHeaderRowIdx = result.GroupHeaderRowIdx;
            this.GroupColumnIdx = result.GroupColumnIdx;
            this.GroupFilteredCount = result.GroupFilteredCount;
            this.GroupIdxs = result.GroupIdxs;
            this.GroupedDataToVisibleMap = result.GroupedDataToVisibleMap;
            this.GroupedVisibleToDataMap = result.GroupedVisibleToDataMap;
        end

        function updateSorting(this, sortingController, sortController, groupController, columnController)
            arguments
                this (1,1) gwidgets.internal.table.DataController
                sortingController (1,:) gwidgets.internal.table.SortingController {mustBeScalarOrEmpty}
                sortController (1,1) gwidgets.internal.table.SortController
                groupController (1,1) gwidgets.internal.table.GroupController
                columnController (1,1) gwidgets.internal.table.ColumnController
            end

            this.SortedVisible = this.GroupedVisible;
            this.SortedDataToVisibleMap = this.GroupedDataToVisibleMap;
            this.SortedVisibleToDataMap = this.GroupedVisibleToDataMap;
            this.SortedGroupHeaderRowIdx = this.GroupHeaderRowIdx;
            this.SortedGroupValues = groupController.Groups;

            if sortController.Direction == "None" || isempty(sortController.ByData)
                return
            end

            if isempty(sortingController)
                error("GraphicsWidgets:Table:SortingController", ...
                    "Sorting controller is required when sorting is active.");
            end

            result = sortingController.sort(this.Filtered, this.Table, this.GroupedVisible, ...
                this.GroupedVariables, groupController.By, groupController.Groups, this.GroupHeaderRowIdx, ...
                this.GroupedVisibleToDataMap, this.GroupedDataToVisibleMap, columnController.DataSortable, ...
                sortController.ByData, sortController.Direction);

            this.SortedVisible = result.SortedVisibleData;
            this.SortedDataToVisibleMap = result.SortedDataToVisibleMap;
            this.SortedVisibleToDataMap = result.SortedVisibleToDataMap;
            this.SortedGroupHeaderRowIdx = result.SortedGroupHeaderRowIdx;
            this.SortedGroupValues = result.SortedGroupValues;
        end

        function updateFolding(this, groupingController, groupController)
            arguments
                this (1,1) gwidgets.internal.table.DataController
                groupingController (1,:) gwidgets.internal.table.GroupingController {mustBeScalarOrEmpty}
                groupController (1,1) gwidgets.internal.table.GroupController
            end

            if isempty(groupController.By)
                groupController.clearDisplayGroups();
                this.FoldedVisibleToDataMap = this.SortedVisibleToDataMap;
                this.FoldedDataToVisibleMap = this.SortedDataToVisibleMap;
                this.VisibleGroupHeaderRowIdx = zeros(1,0);
                this.Visible = cell2table(this.SortedVisible, ...
                    VariableNames=string(this.Table.Properties.VariableNames));
                return
            end

            if isempty(groupingController)
                error("GraphicsWidgets:Table:GroupingController", ...
                    "Grouping controller is required when folding grouped data.");
            end

            result = groupingController.fold(this.SortedVisible, this.SortedGroupHeaderRowIdx, ...
                this.SortedGroupValues, this.SortedVisibleToDataMap, this.SortedDataToVisibleMap, ...
                this.GroupFilteredCount, groupController.By, groupController.Groups, groupController.Open, ...
                groupController.ShowEmpty, string(this.Table.Properties.VariableNames));

            this.Visible = result.VisibleData;
            owner = this.owner();
            owner.addControllerUpdateSuppression("HiddenGroups", Times=1);
            groupController.applyFoldingResult(result);
            this.VisibleGroupHeaderRowIdx = result.VisibleGroupHeaderRowIdx;
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

        function onFilterHelpRequested(this, ~, ~)
            owner = this.owner();
            if isempty(owner)
                return
            end

            owner.Grid.ColumnWidth = {"1x", "1x"};
        end

        function onFilterHelpClosed(this, ~, ~)
            owner = this.owner();
            if isempty(owner)
                return
            end

            owner.Grid.ColumnWidth = {"1x", 0};
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
