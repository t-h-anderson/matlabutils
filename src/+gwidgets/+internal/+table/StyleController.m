classdef StyleController < gwidgets.internal.table.TableController
    % StyleController owns custom table style registration and application.

    properties (Dependent)
        Configurations
        GroupHeaderStyle
    end

    properties (Access = private)
        Styles_ (1,:) gwidgets.internal.table.TableStyle
        Configurations_ (:,3) table = gwidgets.internal.table.backend.TableBackend.emptyStyleConfigurations()
        GroupHeaderStyle_ (1,:) gwidgets.internal.table.TableStyle = ...
            gwidgets.internal.table.StyleController.defaultGroupHeaderStyle()
        NestedGroupHeaderStyles_ (1,:) gwidgets.internal.table.TableStyle = ...
            gwidgets.internal.table.StyleController.defaultNestedGroupHeaderStyles()
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
            % Read from the live view rather than the cache: styles can be
            % applied straight to the underlying component, and those must be
            % visible here too.
            owner = this.owner();
            if isempty(owner)
                val = this.Configurations_;
                return
            end

            backend = owner.Graphics.Backend;
            if isempty(backend) || ~backend.isReady()
                val = this.Configurations_;
                return
            end

            val = backend.StyleConfigurations;
        end

        function set.Configurations(this, val)
            arguments
                this (1,1) gwidgets.internal.table.StyleController
                val (:,3) table
            end

            this.Configurations_ = val;
            this.owner().Graphics.setViewProperties({"StyleConfigurations", val});
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
            this.Configurations_ = gwidgets.internal.table.backend.TableBackend.emptyStyleConfigurations();
            this.owner().Graphics.removeStyle();
            styles = [this.Styles_, this.groupHeaderStylesForDisplay()];

            for iStyle = 1:numel(styles)
                thisStyle = styles(iStyle);
                style = thisStyle.Style;
                target = thisStyle.Target;
                index = thisStyle.indices(this.owner());
                isOriented = false;
                if thisStyle.SelectionMode == gwidgets.table.SelectionMode.Data
                    index = this.owner().Selection.dataToDisplay(index, target);
                    isOriented = this.owner().Display.Orientation == "Transposed" && target == "cell";
                end
                if ~isOriented
                    [target, index] = this.orientStyleTarget(target, index);
                end
                this.appendConfiguration(style, target, index);
                this.owner().Graphics.addStyle(style, target, index);
            end

            this.owner().forceRefresh();
            this.owner().Bridge.applyGroupHeaderSpans();
        end

        function css = groupHeaderOverlayCss(this, rowIdx)
            arguments
                this (1,1) gwidgets.internal.table.StyleController
                rowIdx (1,:) double
            end

            owner = this.owner();
            css = strings(1, numel(rowIdx));
            styles = this.groupHeaderStylesForDisplay();
            for iStyle = 1:numel(styles)
                thisStyle = styles(iStyle);
                styleCss = gwidgets.internal.table.StyleController.overlayCss(thisStyle.Style);
                if styleCss == ""
                    continue
                end

                index = thisStyle.indices(owner);
                if thisStyle.SelectionMode == gwidgets.table.SelectionMode.Data
                    index = owner.Selection.dataToDisplay(index, thisStyle.Target);
                end

                match = this.groupHeaderStyleMatch(rowIdx, thisStyle.Target, index);
                css(match) = css(match) + styleCss;
            end
        end
    end

    methods (Access = private)
        function styles = groupHeaderStylesForDisplay(this)
            owner = this.owner();
            styles = this.GroupHeaderStyle_;
            if numel(styles) ~= 1 || owner.Group.Mode ~= "Nested" || ~any(owner.Data.VisibleGroupHeaderLevels > 1)
                return
            end

            styles = [styles, this.NestedGroupHeaderStyles_];
        end

        function [target, index] = orientStyleTarget(this, target, index)
            arguments
                this (1,1) gwidgets.internal.table.StyleController
                target (1,1) string
                index
            end

            if this.owner().Display.Orientation ~= "Transposed" || isempty(index)
                return
            end

            switch target
                case "row"
                    target = "column";
                    index = index + 1;
                case "column"
                    target = "row";
                case "cell"
                    index = [index(:, 2), index(:, 1) + 1];
                otherwise
                    % Table-wide styles remain table-wide.
            end
        end

        function appendConfiguration(this, style, target, index)
            arguments
                this (1,1) gwidgets.internal.table.StyleController
                style (1,1) matlab.ui.style.Style
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])}
                index
            end

            if target == "table" && isempty(index)
                index = char.empty(0,0);
            end
            config = table(categorical(target), {index}, style, ...
                VariableNames=["Target", "TargetIndex", "Style"]);
            this.Configurations_ = [this.Configurations_; config];
        end

        function match = groupHeaderStyleMatch(this, rowIdx, target, index)
            arguments
                this (1,1) gwidgets.internal.table.StyleController %#ok<INUSA>
                rowIdx (1,:) double
                target (1,1) string
                index
            end

            match = false(1, numel(rowIdx));
            if isempty(rowIdx)
                return
            end

            switch target
                case "table"
                    match(:) = true;
                case "row"
                    match = ismember(rowIdx, reshape(index, 1, []));
                case "cell"
                    if size(index, 2) >= 1
                        match = ismember(rowIdx, reshape(index(:, 1), 1, []));
                    end
                otherwise
                    % Column styles do not apply to row-header text overlays.
            end
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
                TargetFunction=@(this)gwidgets.internal.table.StyleController.groupHeaderRowsAtLevel(this, 1));
        end

        function styles = defaultNestedGroupHeaderStyles()
            levelTwo = matlab.ui.style.Style( ...
                "BackgroundColor", [0.16 0.36 0.50], ...
                "FontColor", [0.95 0.95 0.95]);
            levelThree = matlab.ui.style.Style( ...
                "BackgroundColor", [0.24 0.42 0.38], ...
                "FontColor", [0.95 0.95 0.95]);

            styles = [ ...
                gwidgets.internal.table.TableStyle( ...
                levelTwo, "row", ...
                SelectionMode="Display", ...
                TargetFunction=@(this)gwidgets.internal.table.StyleController.groupHeaderRowsAtLevel(this, 2)), ...
                gwidgets.internal.table.TableStyle( ...
                levelThree, "row", ...
                SelectionMode="Display", ...
                TargetFunction=@(this)gwidgets.internal.table.StyleController.groupHeaderRowsFromLevel(this, 3))];
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

    methods (Static, Access = private)
        function css = overlayCss(style)
            arguments
                style (1,1) matlab.ui.style.Style
            end

            parts = strings(1,0);
            if ~isempty(style.BackgroundColor)
                parts(end+1) = "background-color:" + gwidgets.table.TooltipStyle.cssColor(style.BackgroundColor);
            end
            if ~isempty(style.FontColor)
                parts(end+1) = "color:" + gwidgets.table.TooltipStyle.cssColor(style.FontColor);
            end
            if gwidgets.internal.table.StyleController.hasTextValue(style.FontWeight)
                parts(end+1) = "font-weight:" + string(style.FontWeight);
            end
            if gwidgets.internal.table.StyleController.hasTextValue(style.FontAngle)
                parts(end+1) = "font-style:" + string(style.FontAngle);
            end
            if gwidgets.internal.table.StyleController.hasTextValue(style.FontName)
                parts(end+1) = "font-family:" + string(style.FontName);
            end
            if gwidgets.internal.table.StyleController.hasTextValue(style.HorizontalAlignment)
                alignment = string(style.HorizontalAlignment);
                parts(end+1) = "text-align:" + alignment;
                parts(end+1) = "justify-content:" + ...
                    gwidgets.internal.table.StyleController.flexAlignment(alignment);
            end

            if isempty(parts)
                css = "";
            else
                css = strjoin(parts, ";") + ";";
            end
        end

        function tf = hasTextValue(value)
            tf = ~isempty(value) && strlength(string(value)) > 0;
        end

        function value = flexAlignment(alignment)
            switch alignment
                case "center"
                    value = "center";
                case "right"
                    value = "flex-end";
                otherwise
                    value = "flex-start";
            end
        end

        function rowIdx = groupHeaderRowsAtLevel(tbl, level)
            arguments
                tbl (1,1) gwidgets.UITable
                level (1,1) double
            end

            rowIdx = tbl.Data.VisibleGroupHeaderRowIdx;
            levels = tbl.Data.VisibleGroupHeaderLevels;
            if isempty(rowIdx) || isempty(levels)
                rowIdx = zeros(1,0);
                return
            end

            if all(levels == 0)
                if level ~= 1
                    rowIdx = zeros(1,0);
                end
                return
            end

            rowIdx = rowIdx(levels == level);
        end

        function rowIdx = groupHeaderRowsFromLevel(tbl, minLevel)
            arguments
                tbl (1,1) gwidgets.UITable
                minLevel (1,1) double
            end

            rowIdx = tbl.Data.VisibleGroupHeaderRowIdx;
            levels = tbl.Data.VisibleGroupHeaderLevels;
            if isempty(rowIdx) || isempty(levels) || all(levels == 0)
                rowIdx = zeros(1,0);
                return
            end

            rowIdx = rowIdx(levels >= minLevel);
        end
    end

end

