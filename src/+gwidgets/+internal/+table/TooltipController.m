classdef TooltipController < handle
    % TooltipController owns tooltip registration and hover resolution.

    properties (SetAccess = private)
        Tooltips (1,:) gwidgets.internal.table.TableTooltip = gwidgets.internal.table.TableTooltip.empty(1,0)
        TooltipText (1,1) string = ""
        DefaultTooltipStyle (1,1) gwidgets.table.TooltipStyle = gwidgets.table.TooltipStyle.default()
    end

    methods
        function this = TooltipController(nvp)
            arguments
                nvp.TooltipText (1,1) string = ""
                nvp.DefaultTooltipStyle (1,1) gwidgets.table.TooltipStyle = gwidgets.table.TooltipStyle.default()
            end

            this.TooltipText = nvp.TooltipText;
            this.DefaultTooltipStyle = nvp.DefaultTooltipStyle;
        end

        function didEnableHover = addTooltip(this, owner, text, tableTarget, targetIndicesOrFunction, nvp)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                owner (1,1) gwidgets.UITable
                text
                tableTarget (1,1) string {mustBeMember(tableTarget, ["table", "row", "column", "cell"])} = "table"
                targetIndicesOrFunction (:,:) = []
                nvp.SelectionMode (1,1) gwidgets.table.SelectionMode = gwidgets.table.SelectionMode.Data
                nvp.ContextShape (1,1) string {mustBeMember(nvp.ContextShape, ["Values", "Table"])} = ...
                    gwidgets.internal.table.TableTooltip.defaultContextShape(tableTarget)
                nvp.Style = []
            end

            newTooltip = this.createTooltip(text, tableTarget, targetIndicesOrFunction, ...
                SelectionMode=nvp.SelectionMode, ...
                ContextShape=nvp.ContextShape, ...
                Style=nvp.Style);

            % Validate indices upfront so registration errors surface here,
            % not later inside the hover callback.
            if tableTarget ~= "table"
                idx = newTooltip.indices(owner);
                if newTooltip.SelectionMode == gwidgets.table.SelectionMode.Data && ~isempty(idx)
                    owner.SelectionControl.dataToDisplay(idx, tableTarget);
                end
            end

            wasEmpty = isempty(this.Tooltips);
            this.Tooltips(end+1) = newTooltip;
            didEnableHover = wasEmpty;
        end

        function didDisableHover = removeTooltip(this, orderNum)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                orderNum (1,:) double = []
            end

            wasNotEmpty = ~isempty(this.Tooltips);
            if isempty(orderNum)
                this.Tooltips(:) = [];
            else
                this.Tooltips(orderNum) = [];
            end
            didDisableHover = wasNotEmpty && isempty(this.Tooltips);
        end

        function setTooltipText(this, text)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                text (1,1) string
            end
            this.TooltipText = text;
        end

        function setDefaultTooltipStyle(this, style)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                style (1,1) gwidgets.table.TooltipStyle
            end
            this.DefaultTooltipStyle = style;
        end

        function blocks = resolveBlocks(this, owner, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            groups = this.resolveGroups(owner, displayRow, displayColumn);
            blocks = cell(1, numel(groups));
            for k = 1:numel(groups)
                group = groups(k);
                lineCells = cell(1, numel(group.Lines));
                for j = 1:numel(group.Lines)
                    lineCells{j} = struct( ...
                        "text", char(group.Lines(j).Text), ...
                        "css", char(group.Lines(j).LineStyle.lineCss()));
                end
                blocks{k} = struct( ...
                    "containerCss", char(group.ContainerStyle.containerCss()), ...
                    "lines", {lineCells});
            end
        end

        function groups = resolveGroups(this, owner, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            matches = this.collectMatches(owner, displayRow, displayColumn);
            if isempty(matches)
                groups = struct("ContainerStyle", {}, "Lines", {});
                if this.TooltipText == ""
                    return
                end
                base = this.defaultStyle();
                groups(1).ContainerStyle = base;
                groups(1).Lines = struct("Text", this.TooltipText, "LineStyle", base);
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

        function [text, style] = resolveTextAndStyle(this, owner, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            groups = this.resolveGroups(owner, displayRow, displayColumn);
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
            text = strjoin(allLines, newline);
            style = groups(1).Lines(1).LineStyle;
        end
    end

    methods (Access = private)
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
            style = style.merge(this.DefaultTooltipStyle);
        end

        function matches = collectMatches(this, owner, displayRow, displayColumn)
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
                        idx = owner.SelectionControl.dataToDisplay(idx, tt.Target);
                    end
                catch ME
                    if owner.bridgeDiagnosticsEnabled()
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

        function value = cellValueForHover(this, owner, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.TooltipController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            value = missing;
            if displayRow < 1 || displayColumn < 1
                return
            end

            data = owner.DisplayData;
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

            data = owner.Data;
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
                dataIndex = owner.SelectionControl.displayToData(displayIndex, target);
            catch ME
                if owner.bridgeDiagnosticsEnabled()
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
    end

end

