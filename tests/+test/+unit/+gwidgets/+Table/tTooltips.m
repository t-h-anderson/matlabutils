classdef tTooltips < test.WithExampleTables
    % Test cell-level tooltip configuration on a headless table.

    methods (Test)

        function tDefaultTooltipEmpty(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            testCase.verifyEqual(t.Tooltip, "")
            testCase.verifyEmpty(t.Tooltips)
        end

        function tSetTableTooltip(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Tooltip = "Click a row to inspect";
            testCase.verifyEqual(t.Tooltip, "Click a row to inspect")
        end

        function tAddTableTooltip(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("Whole table hint");
            testCase.assertNumElements(t.Tooltips, 1)
            testCase.verifyEqual(t.Tooltips(1).Text, "Whole table hint")
            testCase.verifyEqual(t.Tooltips(1).Target, "table")
        end

        function tAddColumnTooltip(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("Numerical column", "column", 1);
            testCase.assertNumElements(t.Tooltips, 1)
            testCase.verifyEqual(t.Tooltips(1).Target, "column")
            testCase.verifyEqual(t.Tooltips(1).TargetIndices, 1)
        end

        function tAddRowTooltip(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("Second row", "row", 2);
            testCase.assertNumElements(t.Tooltips, 1)
            testCase.verifyEqual(t.Tooltips(1).Target, "row")
            testCase.verifyEqual(t.Tooltips(1).TargetIndices, 2)
        end

        function tAddCellTooltip(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("Outlier", "cell", [2 3; 4 1]);
            testCase.assertNumElements(t.Tooltips, 1)
            testCase.verifyEqual(t.Tooltips(1).Target, "cell")
            testCase.verifyEqual(t.Tooltips(1).TargetIndices, [2 3; 4 1])
        end

        function tAddMultipleTooltips(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("A", "column", 1);
            t.addTooltip("B", "row", 2);
            t.addTooltip("C", "cell", [3 3]);
            testCase.assertNumElements(t.Tooltips, 3)
            testCase.verifyEqual([t.Tooltips.Text], ["A","B","C"])
        end

        function tRemoveSingleTooltip(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("A", "column", 1);
            t.addTooltip("B", "row", 2);
            t.removeTooltip(1);
            testCase.assertNumElements(t.Tooltips, 1)
            testCase.verifyEqual(t.Tooltips(1).Text, "B")
        end

        function tRemoveAllTooltips(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("A");
            t.addTooltip("B", "column", 1);
            t.removeTooltip();
            testCase.verifyEmpty(t.Tooltips)
        end

        function tAddTooltipOutOfRangeErrors(testCase)
            % magic(5) becomes a 5x1 table (one variable holding the matrix),
            % so cell [2,3] is out of range and addTooltip should say so up
            % front rather than crashing later in the hover callback.
            t = gwidgets.Table(Data=table(magic(5)));
            fcn = @() t.addTooltip("hello", "cell", [2 3]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:SelectionOutOfRange")
        end

        function tHoverSkipsTooltipsThatNoLongerFit(testCase)
            % If data shape changes after a tooltip is registered so its
            % configured indices no longer resolve, the hover path must not
            % throw — that tooltip is just skipped.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("col 3", "column", 3);

            % Reassign data to a single-column table; column 3 no longer exists.
            t.Data = table((1:5)');

            % Hover must not error.
            testCase.verifyWarningFree(@() t.simulateBridgeHover(1, 1));
        end

        function tInvalidTooltipTarget(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            fcn = @() t.addTooltip("X", "cell", "not_numeric_or_function");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:TooltipTarget")
        end

        function tHoverJoinsMatchesMostSpecificFirst(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("table-wide");
            t.addTooltip("row 2", "row", 2);
            t.addTooltip("col 3", "column", 3);
            t.addTooltip("cell (2,3)", "cell", [2 3]);

            testCase.verifyEqual(t.simulateBridgeHover(2, 3), ...
                strjoin(["cell (2,3)", "row 2", "col 3", "table-wide"], newline))
            testCase.verifyEqual(t.simulateBridgeHover(2, 1), ...
                strjoin(["row 2", "table-wide"], newline))
            testCase.verifyEqual(t.simulateBridgeHover(4, 3), ...
                strjoin(["col 3", "table-wide"], newline))
            testCase.verifyEqual(t.simulateBridgeHover(4, 1), "table-wide")
        end

        function tFunctionTooltipReceivesCellValue(testCase)
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(v) "Value: " + string(v), "column", 1);

            % Row 3, column 1 (Numerical) holds the value 3.
            testCase.verifyEqual(t.simulateBridgeHover(3, 1), "Value: 3")
            testCase.verifyEqual(t.simulateBridgeHover(1, 1), "Value: 1")
        end

        function tFunctionTooltipJoinsWithStaticTooltip(testCase)
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip("a row", "row", 2);
            t.addTooltip(@(v) "val=" + string(v), "column", 1);

            testCase.verifyEqual(t.simulateBridgeHover(2, 1), ...
                strjoin(["a row", "val=2"], newline))
        end

        function tFunctionTooltipErrorIsContained(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip(@(v) error("boom"), "cell", [2 1]);

            % Hovering the broken tooltip's cell still returns text rather
            % than throwing out of the hover callback.
            result = t.simulateBridgeHover(2, 1);
            testCase.verifyThat(result, ...
                matlab.unittest.constraints.ContainsSubstring("tooltip error"));
        end

        function tHoverJoinsCellAndRow(testCase)
            % The motivating example: cell + row both match.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("hello", "cell", [2 3]);
            t.addTooltip("test", "row", 2);
            testCase.verifyEqual(t.simulateBridgeHover(2, 3), ...
                strjoin(["hello", "test"], newline))
            testCase.verifyEqual(t.simulateBridgeHover(2, 1), "test")
        end

        function tHoverFallsBackToTableTooltip(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Tooltip = "default";
            t.addTooltip("col 1", "column", 1);

            testCase.verifyEqual(t.simulateBridgeHover(1, 1), "col 1")
            % Cursor outside any cell (bridge sends 0,0).
            testCase.verifyEqual(t.simulateBridgeHover(0, 0), "default")
        end

        function tTooltipMatchesPrecedence(testCase)
            % cell match wins over row, which wins over column, which
            % wins over table.
            tt = gwidgets.internal.table.TableTooltip("col", "column", "TargetIndices", 2);
            tt.TargetIndices = 2;
            testCase.verifyTrue(tt.matches(1, 2))
            testCase.verifyFalse(tt.matches(1, 3))

            ttRow = gwidgets.internal.table.TableTooltip("row", "row", "TargetIndices", 4);
            ttRow.TargetIndices = 4;
            testCase.verifyTrue(ttRow.matches(4, 1))
            testCase.verifyFalse(ttRow.matches(5, 1))

            ttCell = gwidgets.internal.table.TableTooltip("cell", "cell", "TargetIndices", [2 3; 4 5]);
            ttCell.TargetIndices = [2 3; 4 5];
            testCase.verifyTrue(ttCell.matches(2, 3))
            testCase.verifyTrue(ttCell.matches(4, 5))
            testCase.verifyFalse(ttCell.matches(2, 5))
        end

    end

end
