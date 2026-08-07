classdef tTooltipParity < test.WithExampleTables
    % Tooltip behaviour that both table backends must satisfy.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tStaticTooltipUsesAppropriateRenderer(testCase, Backend)
            t = test.unit.gwidgets.Table.tTooltipParity.createTable(testCase, Backend);
            t.Tooltip = "Inspect values";

            if Backend == "UITable"
                state = testCase.hoverState(t, 1, 1);

                testCase.verifyTrue(state.Visible)
                testCase.verifyEqual(state.Texts, "Inspect values")
                testCase.verifyEqual(string(t.UITable.Graphics.Backend.Tooltip), "")
                return
            end

            state = testCase.nativeTooltipState(t);

            testCase.verifyEqual(state.TableTitle, "Inspect values")
            testCase.verifyTrue(all(state.HeaderTitles == "Inspect values"))
            testCase.verifyTrue(all(state.CellTitles == "Inspect values"))
        end

        function tHoverRendersGroupedBlocks(testCase, Backend)
            t = test.unit.gwidgets.Table.tTooltipParity.createTable(testCase, Backend);
            red = gwidgets.table.TooltipStyle(BackgroundColor="red", FontColor="white");
            blue = gwidgets.table.TooltipStyle(BackgroundColor="blue", FontColor="black");

            t.addTooltip("cell-text", "cell", [2 3], Style=red);
            t.addTooltip("row-text", "row", 2, Style=blue);
            t.addTooltip("col-text", "column", 3, Style=red);
            t.addTooltip("tbl-text", "table");

            state = testCase.hoverState(t, 2, 3);

            testCase.verifyTrue(state.Visible)
            testCase.verifyEqual(state.Texts, ["cell-text", "col-text", "row-text", "tbl-text"])
            testCase.verifyThat(testCase.compactCss(state.BlockCssTexts), ...
                matlab.unittest.constraints.ContainsSubstring("background-color"))
            testCase.verifyThat(testCase.compactCss(state.LineCssTexts), ...
                matlab.unittest.constraints.ContainsSubstring("color"))
        end

        function tHeaderHoverResolvesColumnTooltip(testCase, Backend)
            t = test.unit.gwidgets.Table.tTooltipParity.createTable(testCase, Backend);
            t.addTooltip("Numerical column", "column", 1);

            state = testCase.hoverState(t, 0, 1);

            testCase.verifyTrue(state.Visible)
            testCase.verifyEqual(state.Texts, "Numerical column")
        end

        function tFunctionTooltipUsesContext(testCase, Backend)
            t = test.unit.gwidgets.Table.tTooltipParity.createTable(testCase, Backend);
            t.HiddenColumnNames = "String";
            t.addTooltip(@(ctx)"s=" + ctx.Row.String, "row", 2);

            state = testCase.hoverState(t, 2, 1);

            testCase.verifyTrue(state.Visible)
            testCase.verifyEqual(state.Texts, "s=x")
        end

        function tTooltipAfterFilterSort(testCase, Backend)
            data = table( ...
                [3; 1; 4; 2], ...
                ["three"; "one"; "four"; "two"], ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tTooltipParity.createTable(testCase, Backend, data);

            t.Filter = "Value>1";
            t.ColumnSortable = true;
            t.Sort.By = "Value";
            t.Sort.Direction = "Ascend";
            t.addTooltip( ...
                @(ctx)"display=" + string(ctx.DisplayRow) + ",data=" + string(ctx.DataRow) + ...
                ",value=" + string(ctx.Value), ...
                "cell", [1 1], SelectionMode=gwidgets.table.SelectionMode.Display);

            state = testCase.hoverState(t, 1, 1);

            testCase.verifyTrue(state.Visible)
            testCase.verifyEqual(state.Texts, "display=1,data=4,value=2")
        end

        function tVirtualizedRowHoverResolvesTooltip(testCase, Backend)
            data = table( ...
                (1:200)', ...
                "row_" + string((1:200)'), ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tTooltipParity.createTable(testCase, Backend, data);
            t.addTooltip(@(ctx)"row=" + string(ctx.DisplayRow) + ",value=" + string(ctx.Value), "row", 180);

            testCase.scrollToDisplayRow(t, 180);
            state = testCase.hoverState(t, 180, 1);

            testCase.verifyTrue(state.Visible)
            testCase.verifyEqual(state.Texts, "row=180,value=180")
        end

        function tTransposedTooltipUsesLogicalCell(testCase, Backend)
            data = table( ...
                [10; 20], ...
                ["A"; "B"], ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tTooltipParity.createTable(testCase, Backend, data);
            t.DisplayOrientation = "Transposed";
            t.addTooltip( ...
                @(ctx)"display=" + string(ctx.DisplayRow) + "," + string(ctx.DisplayColumn) + ...
                ";data=" + string(ctx.DataRow) + "," + string(ctx.DataColumn) + ...
                ";value=" + string(ctx.Value), ...
                "cell", [2 1], SelectionMode=gwidgets.table.SelectionMode.Display);

            state = testCase.hoverState(t, 1, 3);

            testCase.verifyTrue(state.Visible)
            testCase.verifyEqual(state.Texts, "display=2,1;data=2,1;value=20")
        end

        function tTransposedTooltipMatchesRowsAndColumns(testCase, Backend)
            data = table( ...
                [10; 20], ...
                ["A"; "B"], ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tTooltipParity.createTable(testCase, Backend, data);
            t.DisplayOrientation = "Transposed";
            t.addTooltip("row 2", "row", 2, SelectionMode=gwidgets.table.SelectionMode.Display);
            t.addTooltip("column 1", "column", 1, SelectionMode=gwidgets.table.SelectionMode.Display);

            state = testCase.hoverState(t, 1, 3);

            testCase.verifyTrue(state.Visible)
            testCase.verifyEqual(state.Texts, ["row 2", "column 1"])
        end

        function tRemovingTooltipsClearsHover(testCase, Backend)
            t = test.unit.gwidgets.Table.tTooltipParity.createTable(testCase, Backend);
            t.addTooltip("cell-text", "cell", [2 1]);

            t.removeTooltip();
            state = testCase.hoverState(t, 2, 1);

            testCase.verifyFalse(state.Visible)
            testCase.verifyEmpty(state.Texts)
        end

        function tJavaScriptCellLeaveHidesTooltipLocally(testCase)
            t = test.unit.gwidgets.Table.tTooltipParity.createTable(testCase, "JavaScript");
            t.addTooltip("cell-text", "cell", [1 1]);

            shown = t.UITable.Graphics.Backend.probeBrowser( ...
                "HoverCell", struct("row", 1, "col", 1));
            hidden = t.UITable.Graphics.Backend.probeBrowser( ...
                "LeaveCell", struct("row", 1, "col", 1));

            testCase.verifyTrue(logical(shown.tooltipVisible))
            testCase.verifyFalse(logical(hidden.tooltipVisible))
        end
    end

    methods
        function state = nativeTooltipState(testCase, t)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tTooltipParity
                t (1,1) gwidgets.Table
            end

            switch t.Backend
                case "JavaScript"
                    snapshot = t.UITable.Graphics.Backend.probeBrowser("Snapshot");
                    state = struct( ...
                        "TableTitle", string(snapshot.tableTitle), ...
                        "HeaderTitles", testCase.rowString(snapshot.headerTitles), ...
                        "CellTitles", testCase.rowString(snapshot.cellTitles));
                otherwise
                    tooltipText = string(t.UITable.Graphics.Backend.Tooltip);
                    state = struct( ...
                        "TableTitle", tooltipText, ...
                        "HeaderTitles", repmat(tooltipText, 1, width(t.DisplayData)), ...
                        "CellTitles", repmat(tooltipText, 1, height(t.DisplayData)*width(t.DisplayData)));
            end
        end

        function state = hoverState(testCase, t, row, col)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tTooltipParity
                t (1,1) gwidgets.Table
                row (1,1) double
                col (1,1) double
            end

            switch t.Backend
                case "JavaScript"
                    snapshot = t.UITable.Graphics.Backend.probeBrowser( ...
                        "HoverCell", struct("row", row, "col", col));
                    state = struct( ...
                        "Visible", logical(snapshot.tooltipVisible), ...
                        "Texts", testCase.rowString(snapshot.tooltipLineTexts), ...
                        "BlockCssTexts", testCase.rowString(snapshot.tooltipBlockCssTexts), ...
                        "LineCssTexts", testCase.rowString(snapshot.tooltipLineCssTexts));
                otherwise
                    blocks = t.simulateTooltipBlocks(row, col);
                    state = testCase.stateFromBlocks(blocks);
            end
        end

        function scrollToDisplayRow(testCase, t, row)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tTooltipParity %#ok<INUSA>
                t (1,1) gwidgets.Table
                row (1,1) double
            end

            if t.Backend == "JavaScript"
                t.UITable.Graphics.Backend.probeBrowser("ScrollToRow", struct("row", row));
            end
        end

        function state = stateFromBlocks(~, blocks)
            arguments
                ~
                blocks (1,:) cell
            end

            nBlocks = numel(blocks);
            lineCounts = zeros(1, nBlocks);
            blockCssTexts = strings(1, nBlocks);
            for iBlock = 1:nBlocks
                blockCssTexts(iBlock) = string(blocks{iBlock}.containerCss);
                lineCounts(iBlock) = numel(blocks{iBlock}.lines);
            end

            texts = strings(1, sum(lineCounts));
            lineCssTexts = strings(1, sum(lineCounts));
            lineIndex = 0;
            for iBlock = 1:nBlocks
                lines = blocks{iBlock}.lines;
                for iLine = 1:numel(lines)
                    lineIndex = lineIndex + 1;
                    texts(lineIndex) = string(lines{iLine}.text);
                    lineCssTexts(lineIndex) = string(lines{iLine}.css);
                end
            end

            state = struct( ...
                "Visible", nBlocks > 0, ...
                "Texts", texts, ...
                "BlockCssTexts", blockCssTexts, ...
                "LineCssTexts", lineCssTexts);
        end

        function value = rowString(~, value)
            arguments
                ~
                value
            end

            value = reshape(string(value), 1, []);
        end

        function css = compactCss(~, css)
            arguments
                ~
                css (1,:) string
            end

            css = erase(strjoin(css, ";"), " ");
        end
    end

    methods (Static, Access = private)
        function t = createTable(testCase, backend, data)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                backend (1,1) string
                data (:,:) table = test.WithExampleTables.multivariableData()
            end

            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            t = gwidgets.Table( ...
                Parent=fig, ...
                Backend=backend, ...
                Data=data);
            testCase.addTeardown(@()delete(t));
        end
    end
end
