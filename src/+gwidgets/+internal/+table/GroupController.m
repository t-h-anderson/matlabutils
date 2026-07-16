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
        ShowEmpty_ (1,1) logical = false
    end

    methods
        function this = GroupController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
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

            this.By = string.empty(1,0);
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

            owner = this.owner();
            columnIdx = this.groupingColumnFromContext(displayColumn);
            groupingVariable = string(owner.Graphics.DisplayTable.Data.Properties.VariableNames(columnIdx));
            groupingVariable = owner.Column.aliasesToData(groupingVariable);
            groupingVariable(~ismember(groupingVariable, owner.Column.DataNames)) = [];

            if isempty(groupingVariable)
                groupingVariable = string.empty(1,0);
            end

            owner.Selection.clear();
            try
                this.By = groupingVariable;
            catch
                this.By = string.empty(1,0);
            end
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

        function updateLabel(this, label, grid, columnController, dataController)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
                label (1,1) matlab.ui.control.Label
                grid (1,1) matlab.ui.container.GridLayout
                columnController (1,1) gwidgets.internal.table.ColumnController
                dataController (1,1) gwidgets.internal.table.DataController
            end

            nGroups = numel(this.Groups);
            nGroupsVisible = numel(dataController.VisibleGroupHeaderRowIdx);

            groupingVariableName = strjoin(columnController.dataToAliases(this.By), "|");
            if isempty(groupingVariableName)
                groupingVariableName = "";
            end

            if nGroups == nGroupsVisible
                label.Text = "Group: " + groupingVariableName + " (" + nGroups + " groups)";
            else
                label.Text = "Group: " + groupingVariableName + " (" + nGroupsVisible + "/" + nGroups + " groups visible)";
            end

            if groupingVariableName == ""
                grid.RowHeight{2} = 0;
            else
                grid.RowHeight{2} = "fit";
            end
        end

        function clearGroupingState(this)
            arguments
                this (1,1) gwidgets.internal.table.GroupController
            end

            this.Groups_ = string.empty(1,0);
            this.Open_ = string.empty(1,0);
            this.Hidden_ = string.empty(1,0);
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
end

