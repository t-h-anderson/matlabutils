classdef tMetrics < matlab.unittest.TestCase
    % Tests for optional table and group metric tooltips.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tDefaultsAndAliases(testCase, Backend)
            t = test.unit.gwidgets.Table.tMetrics.createTable(testCase, Backend);

            testCase.verifyFalse(t.ShowMetrics)
            testCase.verifyEqual(t.MetricLocation, "Tooltip")
            testCase.verifyInstanceOf(t.MetricControl, "gwidgets.internal.table.MetricController")
            testCase.verifyNotEmpty(t.MetricDefinitions)

            definition = gwidgets.table.MetricDefinition(Name="rows", Function=@(ctx)height(ctx.Data));
            t.addMetric(definition);
            testCase.verifyEqual(t.MetricDefinitions(end).Name, "rows")

            t.removeMetric();
            testCase.verifyFalse(any([t.MetricDefinitions.Name] == "rows"))
        end

        function tBuiltInMetricsCoverCommonTypes(testCase, Backend)
            data = table( ...
                [1; 2; NaN; 4], ...
                [true; false; true; true], ...
                ["a"; "b"; "a"; missing], ...
                categorical(["x"; "x"; "y"; "y"]), ...
                datetime(2020, 1, (1:4)', Format="yyyy-MM-dd"), ...
                days([1; 2; 3; 4]), ...
                VariableNames=["Num", "Flag", "Text", "Cat", "Time", "Dur"]);
            t = test.unit.gwidgets.Table.tMetrics.createTable(testCase, Backend, data);
            t.ShowMetrics = true;

            numericText = testCase.hoverText(t, 0, 1);
            logicalText = testCase.hoverText(t, 0, 2);
            textText = testCase.hoverText(t, 0, 3);
            categoricalText = testCase.hoverText(t, 0, 4);
            datetimeText = testCase.hoverText(t, 0, 5);
            durationText = testCase.hoverText(t, 0, 6);

            testCase.verifyThat(numericText, matlab.unittest.constraints.ContainsSubstring("Metrics: Num"))
            testCase.verifyThat(numericText, matlab.unittest.constraints.ContainsSubstring("n: All=4"))
            testCase.verifyThat(numericText, matlab.unittest.constraints.ContainsSubstring("missing: All=1"))
            testCase.verifyThat(numericText, matlab.unittest.constraints.ContainsSubstring("nan: All=1"))
            testCase.verifyThat(numericText, matlab.unittest.constraints.ContainsSubstring("mean: All=2.333"))
            testCase.verifyThat(logicalText, matlab.unittest.constraints.ContainsSubstring("true: All=3"))
            testCase.verifyThat(logicalText, matlab.unittest.constraints.ContainsSubstring("false: All=1"))
            testCase.verifyThat(textText, matlab.unittest.constraints.ContainsSubstring("unique: All=2"))
            testCase.verifyThat(categoricalText, matlab.unittest.constraints.ContainsSubstring("mode: All=x"))
            testCase.verifyThat(datetimeText, matlab.unittest.constraints.ContainsSubstring("min: All=2020-01-01"))
            testCase.verifyThat(durationText, matlab.unittest.constraints.ContainsSubstring("mean: All=2.5 days"))
        end

        function tDataCellHoverDoesNotShowMetrics(testCase, Backend)
            data = table([1; 2; 3], VariableNames="Value");
            t = test.unit.gwidgets.Table.tMetrics.createTable(testCase, Backend, data);
            t.ShowMetrics = true;

            blocks = t.simulateTooltipBlocks(1, 1);

            testCase.verifyEmpty(blocks)
        end

        function tCustomMetricUsesContextAndFormatter(testCase, Backend)
            data = table([10; 20; 30], VariableNames="Value");
            t = test.unit.gwidgets.Table.tMetrics.createTable(testCase, Backend, data);
            t.MetricDefinitions = gwidgets.table.MetricDefinition( ...
                Name="rows", ...
                Label="rows", ...
                AppliesTo="numeric", ...
                Function=@(ctx)height(ctx.Data), ...
                Formatter=@(ctx, value)ctx.Scope + ":" + ctx.VariableName + ":" + string(value));
            t.ShowMetrics = true;

            text = testCase.hoverText(t, 0, 1);

            testCase.verifyThat(text, matlab.unittest.constraints.ContainsSubstring("rows: All=Overall:Value:3"))
        end

        function tGroupHeaderHoverComparesHoveredColumn(testCase, Backend)
            data = table( ...
                ["A"; "A"; "B"; "B"], ...
                [1; 2; 3; 4], ...
                [10; 20; 30; 40], ...
                VariableNames=["Group", "Value", "Other"]);
            t = test.unit.gwidgets.Table.tMetrics.createTable(testCase, Backend, data);
            t.GroupingVariable = "Group";
            t.ShowMetrics = true;

            blocks = t.simulateTooltipBlocks(1, 2);
            text = testCase.blocksText(blocks);
            tableHeaders = testCase.rowString(blocks{1}.metricTable.headers);

            testCase.verifyNumElements(blocks, 1)
            testCase.verifyEqual(tableHeaders, ["Metric", "A", "All"])
            testCase.verifyThat(text, matlab.unittest.constraints.ContainsSubstring("Metrics: Other"))
            testCase.verifyThat(text, matlab.unittest.constraints.ContainsSubstring("mean: A=15, All=25"))
            testCase.verifyFalse(contains(text, "Metrics: Value"))
        end

        function tNestedGroupHeaderIncludesParentScopes(testCase, Backend)
            data = table( ...
                ["A"; "A"; "A"; "B"], ...
                ["x"; "x"; "y"; "x"], ...
                [1; 3; 5; 9], ...
                VariableNames=["G1", "G2", "Value"]);
            t = test.unit.gwidgets.Table.tMetrics.createTable(testCase, Backend, data);
            t.GroupingVariable = ["G1", "G2"];
            t.GroupingMode = "Nested";
            t.OpenGroups = "A";
            t.ShowMetrics = true;

            blocks = t.simulateTooltipBlocks(2, 1);
            text = testCase.blocksText(blocks);
            tableHeaders = testCase.rowString(blocks{1}.metricTable.headers);

            testCase.verifyEqual(tableHeaders, ["Metric", "G2: x", "G1: A", "All"])
            testCase.verifyThat(text, matlab.unittest.constraints.ContainsSubstring("mean: G2: x=2"))
            testCase.verifyThat(text, matlab.unittest.constraints.ContainsSubstring("G1: A=3"))
            testCase.verifyThat(text, matlab.unittest.constraints.ContainsSubstring("All=4.5"))
        end

        function tTransposedHoverUsesOriginalVariable(testCase, Backend)
            data = table([10; 20; 30], ["a"; "b"; "c"], VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tMetrics.createTable(testCase, Backend, data);
            t.DisplayOrientation = "Transposed";
            t.ShowMetrics = true;

            text = testCase.hoverText(t, 1, 1);

            testCase.verifyThat(text, matlab.unittest.constraints.ContainsSubstring("Metrics: Value"))
            testCase.verifyThat(text, matlab.unittest.constraints.ContainsSubstring("mean: All=20"))
        end

        function tJavaScriptRendersHistogramChart(testCase)
            data = table([1; 2; 2; 3; 4], VariableNames="Value");
            [t, backend] = test.unit.gwidgets.Table.tMetrics.createJavaScriptTable(testCase, data);
            t.ShowMetrics = true;

            snapshot = backend.probeBrowser("HoverCell", struct("row", 0, "col", 1));

            testCase.verifyTrue(logical(snapshot.tooltipVisible))
            testCase.verifyEqual(testCase.rowString(snapshot.tooltipMetricTableHeaders), ["Metric", "All"])
            testCase.verifyTrue(any(testCase.rowString(snapshot.tooltipMetricTableTexts) == "Metrics: Value"))
            testCase.verifyTrue(any(testCase.rowString(snapshot.tooltipChartTypes) == "histogram"))
        end

        function tJavaScriptGroupHeaderMetricTableComparesScopes(testCase)
            data = table( ...
                ["A"; "A"; "A"; "B"], ...
                ["x"; "x"; "y"; "x"], ...
                [1; 3; 5; 9], ...
                VariableNames=["G1", "G2", "Value"]);
            [t, backend] = test.unit.gwidgets.Table.tMetrics.createJavaScriptTable(testCase, data);
            t.GroupingVariable = ["G1", "G2"];
            t.GroupingMode = "Nested";
            t.OpenGroups = "A";
            t.ShowMetrics = true;

            snapshot = backend.probeBrowser("HoverCell", struct("row", 2, "col", 1));

            testCase.verifyTrue(logical(snapshot.tooltipVisible))
            testCase.verifyEqual( ...
                testCase.rowString(snapshot.tooltipMetricTableHeaders), ...
                ["Metric", "G2: x", "G1: A", "All"])
            testCase.verifyTrue(any(testCase.rowString(snapshot.tooltipMetricTableTexts) == "distribution"))
            testCase.verifyTrue(any(testCase.rowString(snapshot.tooltipChartTypes) == "histogram"))
        end
    end

    methods
        function text = hoverText(testCase, t, row, column)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tMetrics
                t (1,1) gwidgets.Table
                row (1,1) double
                column (1,1) double
            end

            text = testCase.blocksText(t.simulateTooltipBlocks(row, column));
        end

        function text = blocksText(testCase, blocks)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tMetrics
                blocks (1,:) cell
            end

            nBlocks = numel(blocks);
            lineCounts = zeros(1, nBlocks);
            for iBlock = 1:numel(blocks)
                lineCounts(iBlock) = numel(blocks{iBlock}.lines);
            end

            lines = strings(1, sum(lineCounts));
            nextLine = 0;
            for iBlock = 1:nBlocks
                blockLines = testCase.blockLines(blocks{iBlock});
                lines(nextLine+1:nextLine+lineCounts(iBlock)) = blockLines;
                nextLine = nextLine + lineCounts(iBlock);
            end
            text = strjoin(lines, newline);
        end

        function lines = blockLines(~, block)
            arguments
                ~
                block (1,1) struct
            end

            nLines = numel(block.lines);
            lines = strings(1, nLines);
            for iLine = 1:nLines
                lines(iLine) = string(block.lines{iLine}.text);
            end
        end

        function value = rowString(~, value)
            arguments
                ~
                value
            end

            value = reshape(string(value), 1, []);
        end
    end

    methods (Static, Access = private)
        function t = createTable(testCase, backend, data)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                backend (1,1) string
                data (:,:) table = table([1; 2], VariableNames="Value")
            end

            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            t = gwidgets.Table(Parent=fig, Backend=backend, Data=data);
            testCase.addTeardown(@()delete(t));
        end

        function [t, backend] = createJavaScriptTable(testCase, data)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                data (:,:) table
            end

            t = test.unit.gwidgets.Table.tMetrics.createTable(testCase, "JavaScript", data);
            backend = t.UITable.Graphics.Backend;
        end
    end
end
