classdef MetricController < gwidgets.internal.table.TableController
    % MetricController computes optional table and group metric tooltip blocks.

    properties (Dependent)
        Enabled (1,1) logical
        Location (1,1) string
        Definitions (1,:) gwidgets.table.MetricDefinition
        ShowVisuals (1,1) logical
    end

    properties (Access = private)
        Enabled_ (1,1) logical = false
        Location_ (1,1) string {mustBeMember(Location_, "Tooltip")} = "Tooltip"
        Definitions_ (1,:) gwidgets.table.MetricDefinition = gwidgets.table.MetricDefinition.empty(1,0)
        ShowVisuals_ (1,1) logical = true
    end

    methods
        function this = MetricController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
            this.Definitions_ = gwidgets.internal.table.MetricController.defaultDefinitions();
        end

        function val = get.Enabled(this)
            val = this.Enabled_;
        end

        function set.Enabled(this, val)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                val (1,1) logical
            end

            this.Enabled_ = val;
            this.refreshDisplay();
            this.refreshMenu();
        end

        function val = get.Location(this)
            val = this.Location_;
        end

        function set.Location(this, val)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                val (1,1) string {mustBeMember(val, "Tooltip")}
            end

            this.Location_ = val;
            this.refreshDisplay();
        end

        function val = get.Definitions(this)
            val = this.Definitions_;
        end

        function set.Definitions(this, val)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                val (1,:) gwidgets.table.MetricDefinition
            end

            this.Definitions_ = val;
            this.refreshDisplay();
        end

        function val = get.ShowVisuals(this)
            val = this.ShowVisuals_;
        end

        function set.ShowVisuals(this, val)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                val (1,1) logical
            end

            this.ShowVisuals_ = val;
            this.refreshDisplay();
        end

        function add(this, definition)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                definition (1,1) gwidgets.table.MetricDefinition
            end

            this.Definitions_(end+1) = definition;
            this.refreshDisplay();
        end

        function remove(this, orderNum)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                orderNum (1,:) double = []
            end

            if isempty(orderNum)
                this.Definitions_ = gwidgets.internal.table.MetricController.defaultDefinitions();
            else
                this.Definitions_(orderNum) = [];
            end
            this.refreshDisplay();
        end

        function blocks = resolveBlocks(this, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            blocks = cell(1,0);
            if ~this.Enabled_ || this.Location_ ~= "Tooltip" || isempty(this.Definitions_)
                return
            end

            owner = this.owner();
            if isempty(owner)
                return
            end

            group = this.groupForHover(owner, displayRow, displayColumn);
            if group.IsGroup
                variableName = this.groupHeaderVariableForHover(owner, displayRow, displayColumn);
                if variableName == ""
                    return
                end

                blocks = this.metricTableBlock( ...
                    owner, variableName, this.comparisonScopes(owner, group), displayRow, displayColumn);
                return
            end

            variableName = this.tableHeaderVariableForHover(owner, displayRow, displayColumn);
            if variableName == ""
                return
            end

            scopes = this.scopeDefinition("All", "Overall", "", this.overallRows(owner));
            blocks = this.metricTableBlock(owner, variableName, scopes, displayRow, displayColumn);
        end
    end

    methods (Access = private)
        function refreshDisplay(this)
            owner = this.owner();
            if isempty(owner) || isempty(owner.Graphics.Backend) || ~owner.Graphics.Backend.isReady()
                return
            end

            if this.Enabled_
                owner.Bridge.enableHover();
            elseif isempty(owner.Tooltip.Tooltips)
                owner.Bridge.disableHover();
            end
            owner.Graphics.Backend.refresh();
        end

        function refreshMenu(this)
            owner = this.owner();
            if isempty(owner) || isempty(owner.Menu) || ~owner.Menu.HasToggleTableMetrics
                return
            end

            owner.Menu.refresh();
        end

        function rows = overallRows(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
            end

            if isempty(owner.Data.RowFilterIndices)
                rows = 1:height(owner.Data.Table);
            else
                rows = find(owner.Data.RowFilterIndices);
            end
        end

        function data = overallData(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
            end

            data = owner.Data.Table;
            if isempty(owner.Data.RowFilterIndices) || numel(owner.Data.RowFilterIndices) ~= height(data)
                return
            end

            data = data(owner.Data.RowFilterIndices, :);
        end

        function scopes = comparisonScopes(this, owner, group)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                group (1,1) struct
            end

            template = this.scopeDefinition("", "Group", "", double.empty(1,0));
            scopes = repmat(template, 1, max(2, group.Level + 1));
            nScopes = 1;
            scopes(nScopes) = this.scopeDefinition( ...
                this.groupScopeLabel(owner, group.Index, group.Label), "Group", group.Label, group.Rows);

            for level = (group.Level - 1):-1:1
                parentIdx = this.parentGroupIndex(owner, group, level);
                if isempty(parentIdx)
                    continue
                end

                parentRows = this.filteredRows(owner, owner.Data.SortedGroupHeaderDataRows{parentIdx});
                parentLabel = owner.Data.SortedGroupValues(parentIdx);
                nScopes = nScopes + 1;
                scopes(nScopes) = this.scopeDefinition( ...
                    this.groupScopeLabel(owner, parentIdx, parentLabel), "Group", parentLabel, parentRows);
            end

            nScopes = nScopes + 1;
            scopes(nScopes) = this.scopeDefinition("All", "Overall", "", this.overallRows(owner));
            scopes = scopes(1:nScopes);
        end

        function variableName = tableHeaderVariableForHover(this, owner, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            variableName = "";
            if owner.Display.Orientation == "Transposed"
                if displayColumn == 1
                    variableName = this.transposedVariableForRow(owner, displayRow);
                end
            elseif displayRow == 0
                variableName = this.variableForHover(owner, displayRow, displayColumn);
            end

            if ~ismember(variableName, this.metricVariableNames(owner))
                variableName = "";
            end
        end

        function variableName = groupHeaderVariableForHover(this, owner, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            if owner.Display.Orientation == "Transposed"
                variableName = this.transposedVariableForRow(owner, displayRow);
            else
                variableName = this.variableForHover(owner, displayRow, displayColumn);
            end

            if ~ismember(variableName, this.metricVariableNames(owner))
                variableName = "";
            end
        end

        function blocks = metricTableBlock(this, owner, variableName, scopes, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                variableName (1,1) string
                scopes (1,:) struct
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            blocks = cell(1,0);
            if isempty(scopes) || ~ismember(variableName, string(owner.Data.Table.Properties.VariableNames))
                return
            end

            variableLabel = this.variableLabel(owner, variableName);
            variableType = this.variableType(owner.Data.Table.(variableName));
            [rows, fallbackLines] = this.metricRowsForScopes( ...
                owner, variableName, variableType, scopes, displayRow, displayColumn);
            histogramRow = this.histogramRowForScopes(owner, variableName, variableType, scopes);
            if ~isempty(histogramRow)
                rows{end+1} = histogramRow;
            end
            if isempty(rows)
                return
            end

            title = "Metrics: " + variableLabel;
            block = this.block(title, fallbackLines, []);
            block.metricTable = struct( ...
                "title", char(title), ...
                "variable", char(variableLabel), ...
                "headers", {cellstr(["Metric", this.scopeLabels(scopes)])}, ...
                "rows", {rows});
            blocks = {block};
        end

        function [rows, fallbackLines] = metricRowsForScopes(this, owner, variableName, variableType, scopes, ...
                displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                variableName (1,1) string
                variableType (1,1) string
                scopes (1,:) struct
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            rows = cell(1, numel(this.Definitions_));
            fallbackLines = strings(1, numel(this.Definitions_));
            scopeLabels = this.scopeLabels(scopes);
            nRows = 0;
            for iDefinition = 1:numel(this.Definitions_)
                definition = this.Definitions_(iDefinition);
                if ~definition.appliesTo(variableType)
                    continue
                end

                values = strings(1, numel(scopes));
                for iScope = 1:numel(scopes)
                    values(iScope) = this.metricTextForScope( ...
                        owner, variableName, variableType, definition, scopes(iScope), displayRow, displayColumn);
                end
                if all(values == "")
                    continue
                end

                nRows = nRows + 1;
                rows{nRows} = struct("label", char(definition.Label), "values", {cellstr(values)});
                nonempty = values ~= "";
                fallbackLines(nRows) = definition.Label + ": " ...
                    + strjoin(scopeLabels(nonempty) + "=" + values(nonempty), ", ");
            end
            rows = rows(1:nRows);
            fallbackLines = fallbackLines(1:nRows);
        end

        function text = metricTextForScope(this, owner, variableName, variableType, definition, scope, ...
                displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                variableName (1,1) string
                variableType (1,1) string
                definition (1,1) gwidgets.table.MetricDefinition
                scope (1,1) struct
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            data = this.dataForRows(owner, scope.Rows);
            columnData = data.(variableName);
            ctx = this.contextFor(owner, data, columnData, variableName, variableType, definition, ...
                scope.Scope, scope.GroupLabel, scope.Rows, displayRow, displayColumn);
            [didResolve, value] = this.metricValue(definition, ctx);
            if ~didResolve
                text = "";
                return
            end

            text = this.formatMetric(definition, ctx, value);
        end

        function row = histogramRowForScopes(this, owner, variableName, variableType, scopes)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                variableName (1,1) string
                variableType (1,1) string
                scopes (1,:) struct
            end

            row = struct.empty(1,0);
            if ~this.ShowVisuals_ || variableType ~= "numeric"
                return
            end

            counts = this.histogramCountsForScopes(owner, variableName, scopes);
            if isempty(counts)
                return
            end

            histograms = cell(1, numel(counts));
            for iScope = 1:numel(counts)
                histograms{iScope} = struct("type", "histogram", "counts", counts{iScope});
            end
            row = struct( ...
                "label", "distribution", ...
                "values", {repmat({""}, 1, numel(scopes))}, ...
                "histograms", {histograms});
        end

        function counts = histogramCountsForScopes(this, owner, variableName, scopes)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                variableName (1,1) string
                scopes (1,:) struct
            end

            valuesByScope = cell(1, numel(scopes));
            for iScope = 1:numel(scopes)
                data = this.dataForRows(owner, scopes(iScope).Rows);
                values = double(data.(variableName));
                valuesByScope{iScope} = values(isfinite(values(:)));
            end
            allValues = vertcat(valuesByScope{:});
            if isempty(allValues)
                counts = cell(1,0);
                return
            end

            counts = cell(1, numel(scopes));
            minValue = min(allValues);
            maxValue = max(allValues);
            if abs(maxValue - minValue) <= eps(max(abs([minValue, maxValue, 1])))
                for iScope = 1:numel(scopes)
                    counts{iScope} = numel(valuesByScope{iScope});
                end
                return
            end

            nBins = min(8, max(1, numel(unique(allValues))));
            [~, edges] = histcounts(allValues, nBins);
            for iScope = 1:numel(scopes)
                counts{iScope} = histcounts(valuesByScope{iScope}, edges);
            end
        end

        function data = dataForRows(this, owner, rows)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                rows (1,:) double
            end

            if isempty(rows)
                data = owner.Data.Table([], :);
            else
                data = owner.Data.Table(rows, :);
            end
        end

        function rows = filteredRows(this, owner, rows)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                rows (1,:) double
            end

            rows = reshape(double(rows), 1, []);
            if isempty(rows) || isempty(owner.Data.RowFilterIndices) || numel(owner.Data.RowFilterIndices) < max(rows)
                return
            end

            rows = rows(owner.Data.RowFilterIndices(rows));
        end

        function idx = parentGroupIndex(this, owner, group, level)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                group (1,1) struct
                level (1,1) double
            end

            idx = double.empty(1,0);
            groupVars = owner.Group.By;
            groupKeys = owner.Data.SortedGroupKeys;
            if level < 1 || level > numel(groupVars) || height(groupKeys) == 0 || isempty(group.Key)
                return
            end

            isMatch = owner.Data.SortedGroupHeaderLevels == level;
            for iVar = 1:level
                variableName = groupVars(iVar);
                if ~ismember(variableName, string(groupKeys.Properties.VariableNames))
                    return
                end

                isMatch = isMatch & (string(groupKeys.(variableName)) == string(group.Key.(variableName)));
            end
            idx = find(isMatch, 1);
        end

        function label = groupScopeLabel(this, owner, groupIdx, fallback)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                groupIdx (1,1) double
                fallback (1,1) string
            end

            label = fallback;
            if isempty(groupIdx) || groupIdx < 1 || groupIdx > height(owner.Data.SortedGroupKeys) ...
                    || groupIdx > numel(owner.Data.SortedGroupHeaderLevels)
                return
            end

            level = owner.Data.SortedGroupHeaderLevels(groupIdx);
            if level < 1 || level > numel(owner.Group.By)
                return
            end

            variableName = owner.Group.By(level);
            aliases = owner.Column.dataToAliases(variableName);
            if isempty(aliases) || ~ismember(variableName, string(owner.Data.SortedGroupKeys.Properties.VariableNames))
                return
            end

            label = aliases(1) + ": " + string(owner.Data.SortedGroupKeys.(variableName)(groupIdx));
        end

        function labels = scopeLabels(this, scopes)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                scopes (1,:) struct
            end

            labels = strings(1, numel(scopes));
            for iScope = 1:numel(scopes)
                labels(iScope) = string(scopes(iScope).Label);
            end
        end

        function scope = scopeDefinition(this, label, scopeName, groupLabel, rows)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                label (1,1) string
                scopeName (1,1) string {mustBeMember(scopeName, ["Overall", "Group"])}
                groupLabel (1,1) string
                rows (1,:) double
            end

            scope = struct( ...
                "Label", label, ...
                "Scope", scopeName, ...
                "GroupLabel", groupLabel, ...
                "Rows", reshape(double(rows), 1, []));
        end

        function blocks = tableBlock(this, owner, data, scope, groupLabel, rawRows, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                data (:,:) table
                scope (1,1) string
                groupLabel (1,1) string
                rawRows (1,:) double
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            variableNames = this.metricVariableNames(owner);
            lines = strings(1, numel(variableNames));
            nLines = 0;
            for iVariable = 1:numel(variableNames)
                variableName = variableNames(iVariable);
                line = this.columnSummaryLine(owner, data, variableName, scope, groupLabel, rawRows, ...
                    displayRow, displayColumn);
                if line ~= ""
                    nLines = nLines + 1;
                    lines(nLines) = line;
                end
            end
            lines = lines(1:nLines);

            if isempty(lines)
                blocks = cell(1,0);
                return
            end

            title = "Metrics: " + scope;
            if groupLabel ~= ""
                title = title + " " + groupLabel;
            end
            title = title + " (" + height(data) + " rows)";
            blocks = {this.block(title, lines, [])};
        end

        function blocks = columnBlock(this, owner, data, variableName, scope, groupLabel, rawRows, ...
                displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                data (:,:) table
                variableName (1,1) string
                scope (1,1) string
                groupLabel (1,1) string
                rawRows (1,:) double
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            line = this.columnSummaryLine(owner, data, variableName, scope, groupLabel, rawRows, ...
                displayRow, displayColumn);
            if line == ""
                blocks = cell(1,0);
                return
            end

            label = this.variableLabel(owner, variableName);
            chart = this.chartForColumn(data, variableName);
            blocks = {this.block("Metrics: " + label + " (" + height(data) + " rows)", line, chart)};
        end

        function line = columnSummaryLine(this, owner, data, variableName, scope, groupLabel, rawRows, ...
                displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                data (:,:) table
                variableName (1,1) string
                scope (1,1) string
                groupLabel (1,1) string
                rawRows (1,:) double
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            line = "";
            if width(data) == 0 || ~ismember(variableName, string(data.Properties.VariableNames))
                return
            end

            columnData = data.(variableName);
            variableType = this.variableType(columnData);
            metricTexts = strings(1, numel(this.Definitions_));
            nMetricTexts = 0;
            for iDefinition = 1:numel(this.Definitions_)
                definition = this.Definitions_(iDefinition);
                if ~definition.appliesTo(variableType)
                    continue
                end

                ctx = this.contextFor(owner, data, columnData, variableName, variableType, ...
                    definition, scope, groupLabel, rawRows, displayRow, displayColumn);
                [didResolve, value] = this.metricValue(definition, ctx);
                if ~didResolve
                    continue
                end
                text = this.formatMetric(definition, ctx, value);
                if text == ""
                    continue
                end
                nMetricTexts = nMetricTexts + 1;
                metricTexts(nMetricTexts) = definition.Label + "=" + text;
            end
            metricTexts = metricTexts(1:nMetricTexts);

            if isempty(metricTexts)
                return
            end

            line = this.variableLabel(owner, variableName) + ": " + strjoin(metricTexts, ", ");
        end

        function ctx = contextFor(this, owner, data, columnData, variableName, variableType, definition, ...
                scope, groupLabel, rawRows, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                data (:,:) table
                columnData
                variableName (1,1) string
                variableType (1,1) string
                definition (1,1) gwidgets.table.MetricDefinition
                scope (1,1) string
                groupLabel (1,1) string
                rawRows (1,:) double
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            ctx = gwidgets.table.MetricContext;
            ctx.Data = data;
            ctx.ColumnData = columnData;
            ctx.VariableName = variableName;
            ctx.VariableLabel = this.variableLabel(owner, variableName);
            ctx.VariableType = variableType;
            ctx.Scope = scope;
            ctx.GroupLabel = groupLabel;
            ctx.GroupRows = rawRows;
            ctx.DisplayRow = displayRow;
            ctx.DisplayColumn = displayColumn;
            ctx.MetricName = definition.Name;
            ctx.MetricLabel = definition.Label;
        end

        function [didResolve, value] = metricValue(this, definition, ctx)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                definition (1,1) gwidgets.table.MetricDefinition
                ctx (1,1) gwidgets.table.MetricContext
            end

            didResolve = true;
            try
                if ~isempty(definition.Function)
                    value = definition.Function(ctx);
                else
                    value = this.builtinMetric(definition.Name, ctx.ColumnData, ctx.VariableType);
                end
            catch
                didResolve = false;
                value = missing;
            end

            if isempty(value)
                didResolve = false;
            elseif isscalar(value) && this.isMissingValue(value)
                didResolve = false;
            end
        end

        function value = builtinMetric(this, name, columnData, variableType)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                name (1,1) string
                columnData
                variableType (1,1) string
            end

            values = this.columnVector(columnData);
            missingMask = this.missingMask(values);
            nonmissing = values(~missingMask);
            switch name
                case "n"
                    value = numel(values);
                case "missing"
                    value = nnz(missingMask);
                case "nan"
                    value = this.nanCount(values);
                case "mean"
                    value = this.meanValue(nonmissing, variableType);
                case "median"
                    value = this.statValue(@median, nonmissing);
                case "mode"
                    value = this.modeValue(nonmissing);
                case "std"
                    value = this.stdValue(nonmissing, variableType);
                case "min"
                    value = this.statValue(@min, nonmissing);
                case "max"
                    value = this.statValue(@max, nonmissing);
                case "true"
                    value = nnz(logical(nonmissing));
                case "false"
                    value = nnz(~logical(nonmissing));
                case "unique"
                    value = numel(unique(string(nonmissing)));
                otherwise
                    value = missing;
            end
        end

        function value = meanValue(this, values, variableType)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                values
                variableType (1,1) string
            end

            if isempty(values)
                value = missing;
            elseif variableType == "duration" || variableType == "datetime"
                value = mean(values);
            else
                value = mean(double(values), "omitnan");
            end
        end

        function value = stdValue(this, values, variableType)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                values
                variableType (1,1) string
            end

            if isempty(values)
                value = missing;
            elseif variableType == "duration"
                value = std(values);
            else
                value = std(double(values), "omitnan");
            end
        end

        function value = statValue(this, fcn, values)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                fcn (1,1) function_handle
                values
            end

            if isempty(values)
                value = missing;
                return
            end

            value = fcn(values);
            if ~isscalar(value)
                value = value(1);
            end
        end

        function value = modeValue(this, values)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                values
            end

            if isempty(values)
                value = missing;
                return
            end

            try
                value = mode(values);
                if ~isscalar(value)
                    value = value(1);
                end
                return
            catch
                % Text-bin fallback covers types where mode is not implemented.
            end

            textValues = string(values);
            uniqueValues = unique(textValues, "stable");
            counts = zeros(1, numel(uniqueValues));
            for iValue = 1:numel(uniqueValues)
                counts(iValue) = nnz(textValues == uniqueValues(iValue));
            end
            [~, idx] = max(counts);
            value = uniqueValues(idx);
        end

        function text = formatMetric(this, definition, ctx, value)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                definition (1,1) gwidgets.table.MetricDefinition
                ctx (1,1) gwidgets.table.MetricContext
                value
            end

            if ~isempty(definition.Formatter)
                text = string(definition.Formatter(ctx, value));
            else
                text = this.formatValue(value);
            end

            if ~isscalar(text)
                text = strjoin(reshape(text, 1, []), " ");
            end
            text(ismissing(text)) = "";
        end

        function text = formatValue(this, value)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                value
            end

            if iscell(value) && isscalar(value)
                value = value{1};
            end

            if this.isMissingValue(value)
                text = "";
            elseif isnumeric(value)
                text = string(sprintf("%.4g", double(value)));
            elseif islogical(value)
                text = string(value);
            else
                text = string(value);
            end
        end

        function variableNames = metricVariableNames(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
            end

            variableNames = owner.Column.VisibleDataNames;
            variableNames = variableNames(ismember(variableNames, owner.Column.DataNames));
        end

        function label = variableLabel(this, owner, variableName)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                variableName (1,1) string
            end

            idx = find(owner.Column.DataNames == variableName, 1);
            if isempty(idx)
                label = variableName;
            else
                label = owner.Column.Names(idx);
            end
        end

        function variableName = variableForHover(this, owner, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            variableName = "";
            if owner.Display.Orientation == "Transposed"
                variableName = this.transposedVariableForRow(owner, displayRow);
                return
            end

            if displayColumn < 1
                return
            end

            try
                dataColumn = owner.Selection.displayToData(displayColumn, "column");
            catch
                return
            end
            if isempty(dataColumn) || ~isscalar(dataColumn) || isnan(dataColumn) || dataColumn < 1 ...
                    || dataColumn > numel(owner.Column.DataNames)
                return
            end
            variableName = owner.Column.DataNames(dataColumn);
        end

        function variableName = transposedVariableForRow(this, owner, displayRow)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
            end

            variableName = "";
            if displayRow < 1 || displayRow > height(owner.Data.Display) || width(owner.Data.Display) < 1
                return
            end

            label = string(owner.Data.Display{displayRow, 1});
            if ismissing(label) || label == ""
                return
            end

            dataName = owner.Column.aliasesToData(label);
            if isempty(dataName) || ~ismember(dataName, owner.Column.DataNames)
                return
            end
            variableName = dataName(1);
        end

        function group = groupForHover(this, owner, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                owner (1,1) gwidgets.UITable
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            group = struct( ...
                "IsGroup", false, ...
                "Label", "", ...
                "Rows", double.empty(1,0), ...
                "Index", NaN, ...
                "Level", 0, ...
                "Key", table.empty(0,0));
            if owner.Display.Orientation == "Transposed"
                headerPositions = owner.Data.VisibleGroupHeaderRowIdx + 1;
                idx = find(headerPositions == displayColumn, 1);
            else
                idx = find(owner.Data.VisibleGroupHeaderRowIdx == displayRow, 1);
            end

            if isempty(idx) || idx > numel(owner.Group.DisplayGroups)
                return
            end

            label = owner.Group.DisplayGroups(idx);
            sortedIdx = find(owner.Data.SortedGroupValues == label, 1);
            if isempty(sortedIdx) || sortedIdx > numel(owner.Data.SortedGroupHeaderDataRows)
                return
            end

            rows = this.filteredRows(owner, owner.Data.SortedGroupHeaderDataRows{sortedIdx});

            group.IsGroup = true;
            group.Label = label;
            group.Rows = rows;
            group.Index = sortedIdx;
            group.Level = owner.Data.SortedGroupHeaderLevels(sortedIdx);
            if height(owner.Data.SortedGroupKeys) >= sortedIdx
                group.Key = owner.Data.SortedGroupKeys(sortedIdx, :);
            end
        end

        function type = variableType(this, values)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                values
            end

            if isnumeric(values)
                type = "numeric";
            elseif islogical(values)
                type = "logical";
            elseif iscategorical(values)
                type = "categorical";
            elseif isdatetime(values)
                type = "datetime";
            elseif isduration(values)
                type = "duration";
            elseif isstring(values) || ischar(values) || iscellstr(values) || iscell(values)
                type = "text";
            else
                type = "text";
            end
        end

        function mask = missingMask(this, values)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                values
            end

            try
                values = this.columnVector(values);
                mask = ismissing(values);
            catch
                mask = false(numel(values), 1);
            end
            mask = reshape(mask, [], 1);
        end

        function n = nanCount(this, values)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                values
            end

            if isnumeric(values)
                n = nnz(isnan(values));
            else
                n = 0;
            end
        end

        function chart = chartForColumn(this, data, variableName)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                data (:,:) table
                variableName (1,1) string
            end

            chart = [];
            if ~this.ShowVisuals_ || ~ismember(variableName, string(data.Properties.VariableNames))
                return
            end

            values = data.(variableName);
            if ~isnumeric(values)
                return
            end

            values = double(values(:));
            values = values(isfinite(values));
            if isempty(values)
                return
            end

            if max(values) == min(values)
                counts = numel(values);
            else
                counts = histcounts(values, min(8, max(1, numel(unique(values)))));
            end
            chart = struct("type", "histogram", "counts", counts);
        end

        function values = columnVector(this, values)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                values
            end

            if istable(values)
                values = table2cell(values);
            end

            if ischar(values)
                values = string(values);
                values = values(:);
                return
            end

            if iscell(values)
                values = values(:);
                if all(cellfun(@(value)this.isTextCellValue(value), values))
                    values = string(values);
                end
                return
            end

            values = values(:);
        end

        function tf = isTextCellValue(this, value)
            arguments
                this (1,1) gwidgets.internal.table.MetricController
                value
            end

            tf = ischar(value) || isstring(value) || this.isMissingValue(value);
        end

        function tf = isMissingValue(this, value)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                value
            end

            try
                tf = isscalar(value) && ismissing(value);
            catch
                tf = false;
            end
        end

        function block = block(this, title, lines, chart)
            arguments
                this (1,1) gwidgets.internal.table.MetricController %#ok<INUSA>
                title (1,1) string
                lines (1,:) string
                chart = []
            end

            baseStyle = gwidgets.table.TooltipStyle.default();
            titleStyle = gwidgets.table.TooltipStyle(FontWeight="bold");
            lineCells = cell(1, numel(lines) + 1);
            lineCells{1} = struct("text", char(title), "css", char(titleStyle.lineCss()));
            for iLine = 1:numel(lines)
                lineCells{iLine+1} = struct("text", char(lines(iLine)), "css", char(baseStyle.lineCss()));
            end

            block = struct( ...
                "containerCss", char(baseStyle.containerCss()), ...
                "lines", {lineCells});
            if ~isempty(chart)
                block.chart = chart;
            end
        end
    end

    methods (Static)
        function definitions = defaultDefinitions()
            definitions = [ ...
                gwidgets.table.MetricDefinition(Name="n", Label="n", AppliesTo="all"), ...
                gwidgets.table.MetricDefinition(Name="missing", Label="missing", AppliesTo="all"), ...
                gwidgets.table.MetricDefinition(Name="nan", Label="nan", AppliesTo="numeric"), ...
                gwidgets.table.MetricDefinition(Name="mean", Label="mean", AppliesTo=["numeric", "duration"]), ...
                gwidgets.table.MetricDefinition(Name="median", Label="median", ...
                    AppliesTo=["numeric", "datetime", "duration"]), ...
                gwidgets.table.MetricDefinition(Name="mode", Label="mode", AppliesTo="all"), ...
                gwidgets.table.MetricDefinition(Name="std", Label="std", AppliesTo=["numeric", "duration"]), ...
                gwidgets.table.MetricDefinition(Name="min", Label="min", ...
                    AppliesTo=["numeric", "datetime", "duration"]), ...
                gwidgets.table.MetricDefinition(Name="max", Label="max", ...
                    AppliesTo=["numeric", "datetime", "duration"]), ...
                gwidgets.table.MetricDefinition(Name="true", Label="true", AppliesTo="logical"), ...
                gwidgets.table.MetricDefinition(Name="false", Label="false", AppliesTo="logical"), ...
                gwidgets.table.MetricDefinition(Name="unique", Label="unique", AppliesTo=["text", "categorical"])];
        end
    end
end
