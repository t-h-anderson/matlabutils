classdef TooltipController < gwidgets.internal.table.TableController
    % TooltipController owns tooltip registration and hover resolution.

    properties (Dependent)
        Text (1,1) string
        DefaultStyle (1,1) gwidgets.table.TooltipStyle
        TooltipText (1,1) string
        DefaultTooltipStyle (1,1) gwidgets.table.TooltipStyle
    end

    properties (SetAccess = private)
        Tooltips (1,:) gwidgets.internal.table.TableTooltip = gwidgets.internal.table.TableTooltip.empty(1,0)
    end

    properties (Access = private)
        Text_ (1,1) string = ""
        DefaultStyle_ (1,1) gwidgets.table.TooltipStyle = gwidgets.table.TooltipStyle.default()
    end

    methods
        function this = TooltipController(owner, nvp)
            arguments
                owner (1,:) gwidgets.UITable = gwidgets.UITable.empty(1,0)
                nvp.Text (1,1) string = ""
                nvp.DefaultStyle (1,1) gwidgets.table.TooltipStyle = gwidgets.table.TooltipStyle.default()
            end

            this@gwidgets.internal.table.TableController(owner);
            this.Text_ = nvp.Text;
            this.DefaultStyle_ = nvp.DefaultStyle;
        end

        function didEnableHover = add(this, text, tableTarget, targetIndicesOrFunction, nvp)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                text
                tableTarget (1,1) string {mustBeMember(tableTarget, ["table", "row", "column", "cell"])} = "table"
                targetIndicesOrFunction (:,:) = []
                nvp.SelectionMode (1,1) gwidgets.table.SelectionMode = gwidgets.table.SelectionMode.Data
                nvp.ContextShape (1,1) string {mustBeMember(nvp.ContextShape, ["Values", "Table"])} = ...
                    gwidgets.internal.table.TableTooltip.defaultContextShape(tableTarget)
                nvp.Style = []
            end

            owner = this.requireOwner();
            newTooltip = this.createTooltip(text, tableTarget, targetIndicesOrFunction, ...
                SelectionMode=nvp.SelectionMode, ...
                ContextShape=nvp.ContextShape, ...
                Style=nvp.Style);

            % Validate indices upfront so registration errors surface here,
            % not later inside the hover callback.
            if tableTarget ~= "table"
                idx = newTooltip.indices(owner);
                if newTooltip.SelectionMode == gwidgets.table.SelectionMode.Data && ~isempty(idx)
                    owner.Selection.dataToDisplay(idx, tableTarget);
                end
            end

            wasEmpty = isempty(this.Tooltips);
            this.Tooltips(end+1) = newTooltip;
            didEnableHover = wasEmpty;
            if didEnableHover
                owner.Bridge.enableHover();
            end
            this.refreshDisplayState(owner);
        end

        function didDisableHover = remove(this, orderNum)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                orderNum (1,:) double = []
            end

            owner = this.owner();
            wasNotEmpty = ~isempty(this.Tooltips);
            if isempty(orderNum)
                this.Tooltips(:) = [];
            else
                this.Tooltips(orderNum) = [];
            end
            didDisableHover = wasNotEmpty && isempty(this.Tooltips);
            if didDisableHover && ~isempty(owner) && ~owner.Metric.Enabled && this.Text_ == ""
                owner.Bridge.disableHover();
            end
            this.refreshDisplayState(owner);
        end

        function didEnableHover = addTooltip(this, text, tableTarget, targetIndicesOrFunction, nvp)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                text
                tableTarget (1,1) string {mustBeMember(tableTarget, ["table", "row", "column", "cell"])} = "table"
                targetIndicesOrFunction (:,:) = []
                nvp.SelectionMode (1,1) gwidgets.table.SelectionMode = gwidgets.table.SelectionMode.Data
                nvp.ContextShape (1,1) string {mustBeMember(nvp.ContextShape, ["Values", "Table"])} = ...
                    gwidgets.internal.table.TableTooltip.defaultContextShape(tableTarget)
                nvp.Style = []
            end

            didEnableHover = this.add(text, tableTarget, targetIndicesOrFunction, ...
                SelectionMode=nvp.SelectionMode, ...
                ContextShape=nvp.ContextShape, ...
                Style=nvp.Style);
        end

        function didDisableHover = removeTooltip(this, orderNum)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                orderNum (1,:) double = []
            end

            didDisableHover = this.remove(orderNum);
        end

        function setTooltipText(this, text)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                text (1,1) string
            end

            this.Text = text;
        end

        function setDefaultTooltipStyle(this, style)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                style (1,1) gwidgets.table.TooltipStyle
            end

            this.DefaultStyle = style;
        end

        function initialize(this)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
            end

            this.applyTextToDisplay();
        end

        function blocks = resolveBlocks(this, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            owner = this.requireOwner();
            groups = this.resolveGroups(displayRow, displayColumn);
            blocks = cell(1, numel(groups));
            for k = 1:numel(groups)
                group = groups(k);
                lineCells = cell(1, numel(group.Lines));
                for j = 1:numel(group.Lines)
                    lineCells{j} = struct( ...
                        "text", this.textPayload(group.Lines(j).Text), ...
                        "css", this.textPayload(group.Lines(j).LineStyle.lineCss()));
                end
                blocks{k} = struct( ...
                    "containerCss", this.textPayload(group.ContainerStyle.containerCss()), ...
                    "lines", {lineCells});
            end
            blocks = [blocks, owner.Metric.resolveBlocks(displayRow, displayColumn)];
        end

        function groups = resolveGroups(this, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            owner = this.requireOwner();
            matches = this.collectMatches(owner, displayRow, displayColumn);
            if isempty(matches)
                groups = struct("ContainerStyle", {}, "Lines", {});
                if this.Text_ == ""
                    return
                end
                base = this.defaultStyle();
                groups(1).ContainerStyle = base;
                groups(1).Lines = struct("Text", this.Text_, "LineStyle", base);
                return
            end

            nMatches = numel(matches);
            emptyLine = struct("Text", "", "LineStyle", gwidgets.table.TooltipStyle.default());
            groups = repmat(struct("ContainerStyle", gwidgets.table.TooltipStyle.default(), ...
                "Lines", repmat(emptyLine, 1, nMatches)), 1, nMatches);
            nGroups = 0;
            groupLineCounts = zeros(1, nMatches);

            for k = 1:nMatches
                match = matches(k);
                key = match.Style.containerKey();
                groupIndex = [];
                for g = 1:nGroups
                    if isequaln(groups(g).ContainerStyle.containerKey(), key)
                        groupIndex = g;
                        break
                    end
                end
                if isempty(groupIndex)
                    nGroups = nGroups + 1;
                    groupIndex = nGroups;
                    groups(groupIndex).ContainerStyle = match.Style;
                end
                groupLineCounts(groupIndex) = groupLineCounts(groupIndex) + 1;
                groups(groupIndex).Lines(groupLineCounts(groupIndex)).Text = match.Text;
                groups(groupIndex).Lines(groupLineCounts(groupIndex)).LineStyle = match.Style;
            end

            groups = groups(1:nGroups);
            for g = 1:nGroups
                groups(g).Lines = groups(g).Lines(1:groupLineCounts(g));
            end
        end

        function [text, style] = resolveTextAndStyle(this, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            groups = this.resolveGroups(displayRow, displayColumn);
            if isempty(groups)
                text = "";
                style = this.defaultStyle();
                return
            end

            lineCounts = arrayfun(@(group) numel(group.Lines), groups);
            allLines = strings(sum(lineCounts), 1);
            lineIndex = 0;
            for k = 1:numel(groups)
                for j = 1:numel(groups(k).Lines)
                    lineIndex = lineIndex + 1;
                    allLines(lineIndex) = groups(k).Lines(j).Text;
                end
            end
            allLines(ismissing(allLines)) = "";
            text = strjoin(allLines, newline);
            style = groups(1).Lines(1).LineStyle;
        end

        function val = get.Text(this)
            val = this.Text_;
        end

        function set.Text(this, val)
            this.Text_ = val;
            this.applyTextToDisplay();
        end

        function val = get.DefaultStyle(this)
            val = this.DefaultStyle_;
        end

        function set.DefaultStyle(this, val)
            this.DefaultStyle_ = val;
        end

        function val = get.TooltipText(this)
            val = this.Text;
        end

        function set.TooltipText(this, val)
            this.Text = val;
        end

        function val = get.DefaultTooltipStyle(this)
            val = this.DefaultStyle;
        end

        function set.DefaultTooltipStyle(this, val)
            this.DefaultStyle = val;
        end
    end

    methods (Access = private)
        function applyTextToDisplay(this)
            owner = this.owner();
            if isempty(owner) || isempty(owner.Graphics.Backend) || ~owner.Graphics.Backend.isReady()
                return
            end

            owner.Graphics.setViewProperties({"Tooltip", this.Text_});
            this.refreshHoverState(owner);
        end

        function refreshDisplayState(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                owner (1,:) gwidgets.UITable
            end

            if isempty(owner) || isempty(owner.Graphics.Backend) || ~owner.Graphics.Backend.isReady()
                return
            end

            this.refreshHoverState(owner);
            owner.Graphics.refreshViews();
        end

        function refreshHoverState(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                owner (1,1) gwidgets.UITable
            end

            if this.Text_ ~= "" || ~isempty(this.Tooltips) || owner.Metric.Enabled
                owner.Bridge.enableHover();
            else
                owner.Bridge.disableHover();
            end
        end

        function owner = requireOwner(this)
            owner = this.owner();
            if isempty(owner)
                error("GraphicsWidgets:Table:TooltipOwner", ...
                    "Tooltip controller is no longer attached to a valid table.");
            end
        end

        function newTooltip = createTooltip(this, text, tableTarget, targetIndicesOrFunction, nvp)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController %#ok<INUSA>
                text
                tableTarget (1,1) string {mustBeMember(tableTarget, ["table", "row", "column", "cell"])}
                targetIndicesOrFunction (:,:) = []
                nvp.SelectionMode (1,1) gwidgets.table.SelectionMode = gwidgets.table.SelectionMode.Data
                nvp.ContextShape (1,1) string {mustBeMember(nvp.ContextShape, ["Values", "Table"])} = ...
                    gwidgets.internal.table.TableTooltip.defaultContextShape(tableTarget)
                nvp.Style = []
            end

            if tableTarget == "table"
                newTooltip = gwidgets.internal.table.TableTooltip( ...
                    text, tableTarget, ...
                    SelectionMode=nvp.SelectionMode, ...
                    ContextShape=nvp.ContextShape, ...
                    Style=nvp.Style);
            elseif isa(targetIndicesOrFunction, "function_handle")
                newTooltip = gwidgets.internal.table.TableTooltip( ...
                    text, tableTarget, ...
                    TargetFunction=targetIndicesOrFunction, ...
                    SelectionMode=nvp.SelectionMode, ...
                    ContextShape=nvp.ContextShape, ...
                    Style=nvp.Style);
            elseif isnumeric(targetIndicesOrFunction)
                newTooltip = gwidgets.internal.table.TableTooltip( ...
                    text, tableTarget, ...
                    TargetIndices=targetIndicesOrFunction, ...
                    SelectionMode=nvp.SelectionMode, ...
                    ContextShape=nvp.ContextShape, ...
                    Style=nvp.Style);
            else
                error("GraphicsWidgets:Table:TooltipTarget", ...
                    "Tooltip target must be an index array or a function that takes the table object as input.");
            end
        end

        function style = defaultStyle(this)
            style = gwidgets.table.TooltipStyle.default();
            style = style.merge(this.DefaultStyle_);
        end

        function matches = collectMatches(this, owner, displayRow, displayColumn)
            [displayRow, displayColumn] = this.logicalDisplayCoordinates(owner, displayRow, displayColumn);
            priorities = ["cell", "row", "column", "table"];
            nTooltips = numel(this.Tooltips);
            if nTooltips == 0
                matches = struct("Text", {}, "Style", {}, "Rank", {});
                return
            end

            baseStyle = this.defaultStyle();
            emptyMatch = struct("Text", "", "Style", baseStyle, "Rank", 0);
            entries = repmat(emptyMatch, 1, nTooltips);
            nEntries = 0;

            for i = 1:nTooltips
                tt = this.Tooltips(i);
                try
                    idx = tt.indices(owner);
                    if tt.Target ~= "table" && tt.SelectionMode == gwidgets.table.SelectionMode.Data && ~isempty(idx)
                        idx = owner.Selection.dataToDisplay(idx, tt.Target);
                        if owner.Display.Orientation == "Transposed" && tt.Target == "cell"
                            idx = this.transposedCellsToLogical(idx);
                        end
                    end
                catch ME
                    if owner.Bridge.DiagEnabled
                        warning("GraphicsWidgets:Table:TooltipTargetError", ...
                            "Tooltip target resolution failed: %s", ME.message);
                    end
                    continue
                end

                resolved = tt;
                resolved.TargetIndices = idx;
                if ~resolved.matches(displayRow, displayColumn)
                    continue
                end

                rank = find(priorities == tt.Target, 1);
                ctx = this.buildContext(owner, tt.Target, tt.ContextShape, displayRow, displayColumn);
                try
                    rendered = tt.textFor(ctx);
                catch ME
                    rendered = "[tooltip error: " + string(ME.message) + "]";
                end

                ttStyle = tt.styleFor(ctx);
                if isempty(ttStyle)
                    resolvedStyle = baseStyle;
                else
                    resolvedStyle = baseStyle.merge(ttStyle);
                end

                nEntries = nEntries + 1;
                entries(nEntries) = struct("Text", rendered, "Style", resolvedStyle, "Rank", rank);
            end

            if nEntries == 0
                matches = struct("Text", {}, "Style", {}, "Rank", {});
                return
            end

            entries = entries(1:nEntries);
            matches = repmat(emptyMatch, 1, nEntries);
            nMatches = 0;
            for rank = 1:numel(priorities)
                rankEntries = entries([entries.Rank] == rank);
                nRankEntries = numel(rankEntries);
                if nRankEntries == 0
                    continue
                end
                matches(nMatches+1:nMatches+nRankEntries) = rankEntries;
                nMatches = nMatches + nRankEntries;
            end
            matches = matches(1:nMatches);
        end

        function idx = transposedCellsToLogical(this, idx)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController %#ok<INUSA>
                idx (:,2) double
            end

            idx = [idx(:, 2) - 1, idx(:, 1)];
            idx(idx(:, 1) < 1 | idx(:, 2) < 1, :) = [];
        end

        function [row, column] = logicalDisplayCoordinates(this, owner, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            row = displayRow;
            column = displayColumn;
            if owner.Display.Orientation ~= "Transposed"
                return
            end

            row = displayColumn - 1;
            column = displayRow;
        end

        function value = cellValueForHover(this, owner, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            value = missing;
            if displayRow < 1 || displayColumn < 1
                return
            end

            data = this.logicalDisplayData(owner);
            if displayRow > size(data, 1) || displayColumn > width(data)
                return
            end

            value = data{displayRow, displayColumn};
            if iscell(value) && isscalar(value)
                value = value{1};
            end
        end

        function ctx = buildContext(this, owner, target, shape, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                owner (1,1) gwidgets.UITable
                target (1,1) string
                shape (1,1) string {mustBeMember(shape, ["Values", "Table"])}
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            data = owner.Data.Table;
            ctx = gwidgets.table.TooltipContext;
            ctx.Target = target;
            ctx.Table = data;
            ctx.DisplayRow = displayRow;
            ctx.DisplayColumn = displayColumn;
            ctx.Value = this.cellValueForHover(owner, displayRow, displayColumn);

            dataRow = this.safeDisplayToDataIndex(owner, displayRow, "row");
            dataCol = this.safeDisplayToDataIndex(owner, displayColumn, "column");
            ctx.DataRow = dataRow;
            ctx.DataColumn = dataCol;

            if ~isnan(dataRow) && dataRow >= 1 && dataRow <= height(data)
                if shape == "Values"
                    try
                        ctx.Row = data{dataRow, :};
                    catch
                        ctx.Row = missing; % Mixed-type rows cannot concatenate.
                    end
                else
                    ctx.Row = data(dataRow, :);
                end
            end

            if ~isnan(dataCol) && dataCol >= 1 && dataCol <= width(data)
                if shape == "Values"
                    ctx.Column = data{:, dataCol};
                else
                    ctx.Column = data(:, dataCol);
                end
            end
        end

        function dataIndex = safeDisplayToDataIndex(this, owner, displayIndex, target)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                displayIndex (1,1) double
                target (1,1) string {mustBeMember(target, ["row", "column"])}
            end

            if displayIndex < 1
                dataIndex = NaN;
                return
            end

            try
                dataIndex = owner.Selection.displayToData(displayIndex, target);
            catch ME
                if owner.Bridge.DiagEnabled
                    warning("GraphicsWidgets:Table:SelectionMapError", ...
                        "Display selection could not be mapped to data selection: %s", ME.message);
                end
                dataIndex = NaN;
                return
            end

            if isempty(dataIndex) || ~isscalar(dataIndex)
                dataIndex = NaN;
            end
        end

        function data = logicalDisplayData(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
            end

            state = struct( ...
                "VisibleDataColumnNames", owner.Column.VisibleDataNames, ...
                "GroupingVariable", owner.Group.By, ...
                "VisibleGroupHeaderRowIdx", owner.Data.VisibleGroupHeaderRowIdx, ...
                "DataColumnNames", owner.Column.DataNames, ...
                "ColumnNames", owner.Column.Names);
            data = gwidgets.internal.table.DisplayController.visibleDataForTable(owner.Data.Visible, state);
        end

        function text = textPayload(this, value)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController %#ok<INUSA>
                value
            end

            value = string(value);
            value(ismissing(value)) = "";
            if ~isscalar(value)
                value = strjoin(reshape(value, 1, []), newline);
            end

            text = char(value);
        end
    end

end
