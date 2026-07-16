classdef StyleController < gwidgets.internal.table.TableController
    % StyleController owns custom table style registration and application.

    properties (Dependent)
        Configurations
        GroupHeaderStyle
    end

    properties (Access = private)
        Styles_ (1,:) gwidgets.internal.table.TableStyle
        GroupHeaderStyle_ (1,:) gwidgets.internal.table.TableStyle {mustBeScalarOrEmpty} = ...
            gwidgets.internal.table.StyleController.defaultGroupHeaderStyle()
    end

    methods
        function this = StyleController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
        end

        function add(this, style, tableTarget, targetIndicesOrFunction, nvp)
            arguments
                this (1,1) gwidgets.internal.table.StyleController
                style (1,1) matlab.ui.style.Style
                tableTarget (1,1) string {mustBeMember(tableTarget, ["table", "row", "column", "cell"])} = "table"
                targetIndicesOrFunction (:,:) = []
                nvp.SelectionMode (1,1) gwidgets.table.SelectionMode = gwidgets.table.SelectionMode.Data
            end

            newStyle = gwidgets.internal.table.StyleController.createStyle( ...
                style, tableTarget, targetIndicesOrFunction, nvp.SelectionMode);
            this.Styles_(end+1) = newStyle;

            if this.owner().doControllerUpdate("UpdateStyle")
                this.owner().requestControllerUpdate(StartFrom="Style");
            end
        end

        function remove(this, orderNum)
            arguments
                this (1,1) gwidgets.internal.table.StyleController
                orderNum (1,:) double = []
            end

            this.Styles_ = gwidgets.internal.table.StyleController.removeStyle(this.Styles_, orderNum);

            if this.owner().doControllerUpdate("UpdateStyle")
                this.owner().requestControllerUpdate(StartFrom="Style");
            end
        end

        function val = get.Configurations(this)
            val = this.owner().Graphics.DisplayTable.StyleConfigurations;
        end

        function set.Configurations(this, val)
            this.owner().Graphics.DisplayTable.StyleConfigurations = val;
        end

        function val = get.GroupHeaderStyle(this)
            val = this.GroupHeaderStyle_;
        end

        function set.GroupHeaderStyle(this, val)
            this.GroupHeaderStyle_ = val;
            if this.owner().doControllerUpdate("GroupHeaderStyle")
                this.owner().requestControllerUpdate(StartFrom="Style");
            end
        end

        function applyToDisplay(this)
            displayTable = this.owner().Graphics.DisplayTable;
            displayTable.removeStyle();
            styles = [this.Styles_, this.GroupHeaderStyle_];

            for iStyle = 1:numel(styles)
                thisStyle = styles(iStyle);
                style = thisStyle.Style;
                target = thisStyle.Target;
                index = thisStyle.indices(this.owner());
                if thisStyle.SelectionMode == gwidgets.table.SelectionMode.Data
                    index = this.owner().Selection.dataToDisplay(index, target);
                end
                displayTable.addStyle(style, target, index);
            end

            this.owner().forceRefresh();
        end
    end

    methods (Static)
        function newStyle = createStyle(style, tableTarget, targetIndicesOrFunction, selectionMode)
            arguments
                style (1,1) matlab.ui.style.Style
                tableTarget (1,1) string {mustBeMember(tableTarget, ["table", "row", "column", "cell"])}
                targetIndicesOrFunction (:,:) = []
                selectionMode (1,1) gwidgets.table.SelectionMode = gwidgets.table.SelectionMode.Data
            end

            if isa(targetIndicesOrFunction, "function_handle")
                newStyle = gwidgets.internal.table.TableStyle( ...
                    style, tableTarget, ...
                    "TargetFunction", targetIndicesOrFunction, ...
                    "SelectionMode", selectionMode);
            elseif isa(targetIndicesOrFunction, "string")
                targetFunction = @(t)t.find(targetIndicesOrFunction, tableTarget);
                newStyle = gwidgets.internal.table.TableStyle( ...
                    style, tableTarget, ...
                    "TargetFunction", targetFunction, ...
                    "SelectionMode", selectionMode);
            elseif isnumeric(targetIndicesOrFunction)
                newStyle = gwidgets.internal.table.TableStyle( ...
                    style, tableTarget, ...
                    "TargetIndices", targetIndicesOrFunction, ...
                    "SelectionMode", selectionMode);
            else
                error("GraphicsWidgets:Table:StyleTarget", ...
                    "Style target must be an index array, string query, or function that takes the table object.");
            end
        end

        function style = defaultGroupHeaderStyle(style)
            arguments
                style (1,1) matlab.ui.style.Style = matlab.ui.style.Style( ...
                    "BackgroundColor", [0.1 0.1 0.8], ...
                    "FontColor", [0.9 0.9 0.9])
            end

            style = gwidgets.internal.table.TableStyle( ...
                style, "row", ...
                SelectionMode="Display", ...
                TargetFunction=@(this)this.Data.VisibleGroupHeaderRowIdx);
        end

        function styles = removeStyle(styles, orderNum)
            arguments
                styles (1,:) gwidgets.internal.table.TableStyle
                orderNum (1,:) double = []
            end

            if isempty(orderNum)
                styles(:) = [];
            else
                styles(orderNum) = [];
            end
        end

        function apply(displayTable, owner, styles, groupHeaderStyle, dataToDisplayFcn)
            arguments
                displayTable (1,1) matlab.ui.control.Table
                owner (1,1) gwidgets.UITable
                styles (1,:) gwidgets.internal.table.TableStyle
                groupHeaderStyle (1,:) gwidgets.internal.table.TableStyle
                dataToDisplayFcn (1,1) function_handle
            end

            displayTable.removeStyle();
            styles = [styles, groupHeaderStyle];

            for iStyle = 1:numel(styles)
                thisStyle = styles(iStyle);
                style = thisStyle.Style;
                target = thisStyle.Target;
                index = thisStyle.indices(owner);
                if thisStyle.SelectionMode == gwidgets.table.SelectionMode.Data
                    index = dataToDisplayFcn(index, thisStyle.Target);
                end
                displayTable.addStyle(style, target, index);
            end
        end
    end

end

