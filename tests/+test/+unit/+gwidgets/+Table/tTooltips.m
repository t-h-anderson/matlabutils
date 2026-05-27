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

        function tInvalidTooltipTarget(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            fcn = @() t.addTooltip("X", "cell", "not_numeric_or_function");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:TooltipTarget")
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
