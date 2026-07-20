classdef GroupController < gwidgets.internal.table.TableController
    % GroupController owns grouping-related table state.

    properties (Dependent)
        By
        ByName
        HeaderStyle
        Open
        RawOpen
        Closed
        Hidden
        ShowEmpty
        Mode
        IsGrouped
        Groups
        DisplayGroups
    end

    properties (Access = private)
        By_ (1,:) string = string.empty(1,0)
        Groups_ (1,:) string = string.empty(1,0)
        DisplayGroups_ (1,:) string = string.empty(1,0)
        Open_ (1,:) string = string.empty(1,0)
        Hidden_ (1,:) string = string.empty(1,0)
        Order_ (1,:) string = string.empty(1,0)
        ShowEmpty_ (1,1) logical = false
        Mode_ (1,1) string {mustBeMember(Mode_, ["Flat", "Nested"])} = "Flat"
        GroupingEngine (1,:) gwidgets.internal.table.GroupingController {mustBeScalarOrEmpty}
    end

    methods
        function this = GroupController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
            this.GroupingEngine = gwidgets.internal.table.GroupingController();
        end

        function delete(this)
            delete(this.GroupingEngine);
        end

        function openAll(this)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
            end

            this.Open = this.Groups_;
        end

        function closeAll(this)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
            end

            this.Open = string.empty(1,0);
        end

        function requestUngroup(this)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
            end

            this.clearBy();
        end

        function requestToggleShowEmpty(this)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
            end

            this.ShowEmpty = ~this.ShowEmpty;
        end

        function requestGroupBy(this, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                displayColumn (1,1) double
            end

            this.replaceBy(this.groupingVariablesFromContext(displayColumn));
        end

        function requestAddGroupBy(this, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                displayColumn (1,1) double
            end

            this.addBy(this.groupingVariablesFromContext(displayColumn));
        end

        function requestRemoveGroupBy(this, groupingVariable)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                groupingVariable (1,:) string
            end

            this.removeBy(groupingVariable);
        end

        function requestToggleMode(this)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
            end

            if this.Mode == "Flat"
                this.Mode = "Nested";
            else
                this.Mode = "Flat";
            end
        end

        function replaceBy(this, groupingVariable)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                groupingVariable (1,:) string
            end

            this.owner().Selection.clear();
            try
                this.By = groupingVariable;
            catch
                this.By = string.empty(1,0);
            end
        end

        function addBy(this, groupingVariable)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                groupingVariable (1,:) string
            end

            groupingVariable = this.validateGroupingVariables(groupingVariable);
            if isempty(groupingVariable)
                return
            end

            this.owner().Selection.clear();
            this.By = [this.By_, groupingVariable];
        end

        function removeBy(this, groupingVariable)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                groupingVariable (1,:) string
            end

            groupingVariable = this.validateGroupingVariables(groupingVariable);
            if isempty(groupingVariable)
                return
            end

            this.owner().Selection.clear();
            this.By = this.By_(~ismember(this.By_, groupingVariable));
        end

        function clearBy(this)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
            end

            this.owner().Selection.clear();
            this.By = string.empty(1,0);
        end

        function toggleOpenStateForRows(this, rowIdx, groupHeaderRowIdx)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                rowIdx (1,:) double
                groupHeaderRowIdx (1,:) double
            end

            idxHeader = ismember(groupHeaderRowIdx, rowIdx);
            if ~any(idxHeader)
                return
            end

            groups = this.DisplayGroups(idxHeader);
            for iGroup = 1:numel(groups)
                group = groups(iGroup);
                if ismember(group, this.Open)
                    this.Open(this.Open == group) = [];
                else
                    this.Open = [this.Open, group];
                end
            end
        end

        function updateLabel(this)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
            end

            owner = this.owner();
            nGroups = numel(this.Groups);
            nGroupsVisible = numel(owner.Data.VisibleGroupHeaderRowIdx);

            groupingVariableName = strjoin(owner.Column.dataToAliases(this.By), "|");
            if isempty(groupingVariableName)
                groupingVariableName = "";
            end

            if nGroups == nGroupsVisible
                owner.Graphics.GroupLabel.Text = "Group: " + groupingVariableName + " (" + nGroups + " groups)";
            else
                owner.Graphics.GroupLabel.Text = "Group: " + groupingVariableName + " (" ...
                    + nGroupsVisible + "/" + nGroups + " groups visible)";
            end

            if groupingVariableName == ""
                owner.Graphics.Grid.RowHeight{2} = 0;
            else
                owner.Graphics.Grid.RowHeight{2} = "fit";
            end
        end

        function result = groupData(this, dataController)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                dataController (1,1) gwidgets.internal.table.DataController
            end

            if this.Mode == "Nested"
                result = this.GroupingEngine.groupNested( ...
                    dataController.Table, ...
                    dataController.Filtered, ...
                    dataController.FilteredDataToVisibleMap, ...
                    dataController.FilteredVisibleToDataMap, ...
                    this.By, ...
                    this.RawOpen, ...
                    this.Hidden);
            else
                result = this.GroupingEngine.group( ...
                    dataController.Table, ...
                    dataController.Filtered, ...
                    dataController.FilteredDataToVisibleMap, ...
                    dataController.FilteredVisibleToDataMap, ...
                    this.By, ...
                    this.RawOpen, ...
                    this.Hidden);
                result = this.applyOrder(result);
            end
        end

        function reorder(this, sourceGroup, targetGroup, placement)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                sourceGroup (1,1) string
                targetGroup (1,1) string
                placement (1,1) string {mustBeMember(placement, ["before", "after"])} = "before"
            end

            if sourceGroup == targetGroup || isempty(sourceGroup) || isempty(targetGroup)
                return
            end

            if this.reorderCategorical(sourceGroup, targetGroup, placement)
                return
            end

            groups = this.Groups_;
            if isempty(groups)
                groups = [sourceGroup, targetGroup];
            end
            this.Order_ = gwidgets.internal.table.GroupController.moveLabels( ...
                groups, sourceGroup, targetGroup, placement);

            owner = this.owner();
            if owner.doControllerUpdate("GroupOrder")
                owner.requestControllerUpdate(StartFrom="Grouping");
            end
        end

        function result = foldData(this, dataController)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                dataController (1,1) gwidgets.internal.table.DataController
            end

            if this.Mode == "Nested"
                result = this.GroupingEngine.foldNested( ...
                    dataController.SortedVisible, ...
                    dataController.SortedGroupHeaderRowIdx, ...
                    dataController.SortedGroupValues, ...
                    dataController.SortedGroupHeaderLevels, ...
                    dataController.SortedVisibleToDataMap, ...
                    dataController.SortedDataToVisibleMap, ...
                    dataController.SortedGroupFilteredCount, ...
                    this.By, ...
                    this.Open, ...
                    this.ShowEmpty, ...
                    string(dataController.Table.Properties.VariableNames));
                return
            end

            result = this.GroupingEngine.fold( ...
                dataController.SortedVisible, ...
                dataController.SortedGroupHeaderRowIdx, ...
                dataController.SortedGroupValues, ...
                dataController.SortedVisibleToDataMap, ...
                dataController.SortedDataToVisibleMap, ...
                dataController.SortedGroupFilteredCount, ...
                this.By, ...
                this.Groups, ...
                this.Open, ...
                this.ShowEmpty, ...
                string(dataController.Table.Properties.VariableNames));
        end

        function clearGroupingState(this)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
            end

            this.Groups_ = string.empty(1,0);
            this.Open_ = string.empty(1,0);
            this.Hidden_ = string.empty(1,0);
            this.Order_ = string.empty(1,0);
        end

        function applyGroupingResult(this, result)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                result (1,1) struct
            end

            this.Groups_ = result.Groups;
            this.Open_ = result.OpenGroups;
            this.Hidden_ = result.HiddenGroups;
        end

        function applyFoldingResult(this, result)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                result (1,1) struct
            end

            this.DisplayGroups_ = result.DisplayGroups;
            this.Hidden = result.HiddenGroups;
        end

        function clearDisplayGroups(this)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
            end

            this.DisplayGroups_ = string.empty(1,0);
        end

        function val = get.By(this)
            val = this.By_;
        end

        function set.By(this, val)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                val (1,:) string
            end

            val = unique(val, "stable");
            val(val == "") = [];

            owner = this.owner();
            dataColumnNames = owner.Column.DataNames;
            if ~isempty(val) && any(~ismember(val, dataColumnNames))
                error("GraphicsWidgets:Table:NonexistentGroupingVariable", ...
                    "Grouping variable must either be """" or exist in the data table.")
            end

            this.By_ = val;
            owner.Selection.clear();

            if owner.doControllerUpdate("GroupingVariable")
                owner.requestControllerUpdate(StartFrom="Grouping");
            end
            owner.Menu.refresh();
        end

        function val = get.ByName(this)
            val = strjoin(this.By_, "|");
            if isempty(val)
                val = "";
            end
        end

        function val = get.HeaderStyle(this)
            val = this.owner().Style.GroupHeaderStyle;
        end

        function set.HeaderStyle(this, val)
            this.owner().Style.GroupHeaderStyle = val;
        end

        function val = get.Open(this)
            val = this.Open_;

            idx = ~ismember(val, this.Hidden_);
            val = val(idx);
        end

        function set.Open(this, val)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                val (1,:) string
            end

            idx = ismember(val, this.Groups_);
            if any(~idx)
                error("GraphicsWidgets:Table:NonexistentGroupingVariable", ...
                    "Grouping variables not found: " + strjoin(val(~idx), ", "));
            end

            idx = ismember(this.Groups_, val);
            this.Open_ = this.Groups_(idx);
            if this.owner().doControllerUpdate("OpenGroups")
                this.owner().requestControllerUpdate(StartFrom="Folding");
            end
        end

        function val = get.RawOpen(this)
            val = this.Open_;
        end

        function val = get.Closed(this)
            idx = ismember(this.Groups_, this.Open);
            val = this.Groups_(~idx);
        end

        function set.Closed(this, val)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                val (1,:) string
            end

            idx = ismember(val, this.Groups_);
            if any(~idx)
                error("GraphicsWidgets:Table:NonexistentGroupingVariable", ...
                    "Grouping variables not found: " + strjoin(val(~idx), ", "));
            end

            idx = ismember(this.Groups_, val);
            this.Open_ = this.Groups_(~idx);
            if this.owner().doControllerUpdate("ClosedGroups")
                this.owner().requestControllerUpdate(StartFrom="Folding");
            end
        end

        function val = get.Hidden(this)
            val = this.Hidden_;
        end

        function set.Hidden(this, val)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                val (1,:) string
            end

            idx = ismember(this.Groups_, val);
            this.Hidden_ = this.Groups_(idx);
            if this.owner().doControllerUpdate("HiddenGroups")
                this.owner().requestControllerUpdate(StartFrom="Folding");
            end
        end

        function val = get.ShowEmpty(this)
            val = this.ShowEmpty_;
        end

        function set.ShowEmpty(this, val)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                val (1,1) logical
            end

            this.ShowEmpty_ = val;

            if this.owner().doControllerUpdate("ShowEmptyGroups")
                this.owner().requestControllerUpdate(StartFrom="Folding");
            end
        end

        function val = get.Mode(this)
            val = this.Mode_;
        end

        function set.Mode(this, val)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                val (1,1) string {mustBeMember(val, ["Flat", "Nested"])}
            end

            this.Mode_ = val;
            if this.owner().doControllerUpdate("GroupingMode")
                this.owner().requestControllerUpdate(StartFrom="Grouping");
            end
            this.owner().Menu.refresh();
        end

        function val = get.IsGrouped(this)
            val = ~isempty(this.By_);
        end

        function val = get.Groups(this)
            val = this.Groups_;
        end

        function val = get.DisplayGroups(this)
            val = this.DisplayGroups_;
        end

    end

    methods (Access = private)
        function tf = reorderCategorical(this, sourceGroup, targetGroup, placement)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                sourceGroup (1,1) string
                targetGroup (1,1) string
                placement (1,1) string
            end

            tf = false;
            if numel(this.By_) ~= 1
                return
            end

            owner = this.owner();
            data = owner.Data.Table;
            groupingVariable = this.By_(1);
            if ~iscategorical(data.(groupingVariable))
                return
            end

            categoriesInOrder = string(categories(data.(groupingVariable)));
            if ~ismember(sourceGroup, categoriesInOrder) || ~ismember(targetGroup, categoriesInOrder)
                return
            end

            categoriesInOrder = gwidgets.internal.table.GroupController.moveLabels( ...
                categoriesInOrder, sourceGroup, targetGroup, placement);
            data.(groupingVariable) = reordercats(data.(groupingVariable), categoriesInOrder);
            this.Order_ = string.empty(1,0);
            owner.Data.Table = data;
            tf = true;
        end

        function result = applyOrder(this, result)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                result (1,1) struct
            end

            groups = result.Groups;
            order = this.Order_(ismember(this.Order_, groups));
            order = [order, groups(~ismember(groups, order))];
            [~, orderIdx] = ismember(order, groups);
            orderIdx(orderIdx == 0) = [];

            if isempty(orderIdx) || isequal(orderIdx, 1:numel(groups))
                return
            end

            result = gwidgets.internal.table.GroupController.reorderResult(result, orderIdx);
        end

        function groupingVariable = groupingVariablesFromContext(this, displayColumn)
            owner = this.owner();
            columnIdx = this.groupingColumnFromContext(displayColumn);
            groupingVariable = string(owner.Graphics.DisplayTable.Data.Properties.VariableNames(columnIdx));
            groupingVariable = owner.Column.aliasesToData(groupingVariable);
            groupingVariable = this.validateGroupingVariables(groupingVariable);
        end

        function groupingVariable = validateGroupingVariables(this, groupingVariable)
            owner = this.owner();
            groupingVariable = reshape(string(groupingVariable), 1, []);
            groupingVariable(groupingVariable == "") = [];
            groupingVariable = unique(groupingVariable, "stable");
            groupingVariable(~ismember(groupingVariable, owner.Column.DataNames)) = [];
        end

        function columnIdx = groupingColumnFromContext(this, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                displayColumn (1,1) double
            end

            selection = this.owner().Selection;
            if isempty(selection.DisplayValue)
                columnIdx = displayColumn;
                return
            end

            switch selection.Type
                case "cell"
                    columnIdx = unique(selection.DisplayValue(:, 2));
                case "column"
                    columnIdx = selection.DisplayValue;
                case "row"
                    columnIdx = displayColumn;
                otherwise
                    columnIdx = displayColumn;
            end
        end
    end

    methods (Static, Access = private)
        function labels = moveLabels(labels, sourceLabel, targetLabel, placement)
            labels = reshape(labels, 1, []);
            sourceIdx = find(labels == sourceLabel, 1);
            targetIdx = find(labels == targetLabel, 1);

            if isempty(sourceIdx) || isempty(targetIdx)
                return
            end

            movingLabel = labels(sourceIdx);
            labels(sourceIdx) = [];
            if sourceIdx < targetIdx
                targetIdx = targetIdx - 1;
            end
            if placement == "after"
                targetIdx = targetIdx + 1;
            end

            labels = [labels(1:targetIdx-1), movingLabel, labels(targetIdx:end)];
        end

        function result = reorderResult(result, orderIdx)
            groupHeaderRowIdxs = [result.GroupHeaderRowIdx, size(result.GroupedVisibleData, 1)+1];
            nGroups = numel(orderIdx);
            groupRows = cell(1, nGroups);
            groupSize = zeros(1, nGroups);
            dataToVisibleGroups = cell(1, nGroups);

            for iGroup = 1:nGroups
                groupStart = groupHeaderRowIdxs(iGroup);
                groupStop = groupHeaderRowIdxs(iGroup+1) - 1;
                groupRows{iGroup} = groupStart:groupStop;
                groupSize(iGroup) = numel(groupRows{iGroup}) - 1;

                idx = ismember(result.GroupedDataToVisibleMap, groupRows{iGroup});
                tmp = result.GroupedDataToVisibleMap;
                tmp = tmp - sum(groupSize(1:iGroup-1)) - iGroup;
                dataToVisibleGroups{iGroup} = tmp .* idx;
            end

            groupSize = groupSize(orderIdx);
            groupRows = groupRows(orderIdx);
            dataToVisibleGroups = dataToVisibleGroups(orderIdx);
            newRowOrder = [groupRows{:}];

            result.GroupedVisibleData = result.GroupedVisibleData(newRowOrder, :);
            result.GroupedVisibleToDataMap = result.GroupedVisibleToDataMap(newRowOrder);
            result.Groups = result.Groups(orderIdx);
            result.GroupKeys = result.GroupKeys(orderIdx, :);
            result.GroupFilteredCount = result.GroupFilteredCount(orderIdx);

            result.GroupedDataToVisibleMap = 0*result.GroupedDataToVisibleMap;
            cumSize = 1;
            for iGroup = 1:numel(dataToVisibleGroups)
                result.GroupedDataToVisibleMap = result.GroupedDataToVisibleMap + dataToVisibleGroups{iGroup} + ...
                    (dataToVisibleGroups{iGroup} ~= 0)*cumSize;
                cumSize = cumSize + groupSize(iGroup) + 1;
            end

            result.GroupHeaderRowIdx = [0, cumsum(groupSize)] + (1:(numel(groupSize)+1));
            result.GroupHeaderRowIdx = result.GroupHeaderRowIdx(1:end-1);
        end
    end
end

