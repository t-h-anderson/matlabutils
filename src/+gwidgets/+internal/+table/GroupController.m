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
            owner.clearGroupSelection();

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
end

