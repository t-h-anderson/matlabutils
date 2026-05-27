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

        function tFunctionTooltipReceivesColumnSlice(testCase)
            % Two-arg function on a column target gets the whole column.
            data = testCase.multivariableData();  % Numerical is [1..5]
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(~, col) "max=" + max(col), "column", 1);

            testCase.verifyEqual(t.simulateBridgeHover(3, 1), "max=5")
        end

        function tFunctionTooltipReceivesRowSliceDefault(testCase)
            % Default row context is "Table" (1xN), so name access works
            % on any table.
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(~, row) "n=" + row.Numerical, "row", 2);

            testCase.verifyEqual(t.simulateBridgeHover(2, 3), "n=2")
        end

        function tFunctionTooltipRowSliceValuesShape(testCase)
            % ContextShape="Values" extracts the row as a vector — works
            % for homogeneous tables.
            m = magic(5);
            t = gwidgets.Table(Data=array2table(m));
            t.addTooltip(@(~, row) "max=" + max(row), "row", 2, ...
                "ContextShape", "Values");

            testCase.verifyEqual(t.simulateBridgeHover(2, 1), ...
                "max=" + string(max(m(2, :))))
        end

        function tFunctionTooltipReceivesWholeTable(testCase)
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(~, tbl) "rows=" + height(tbl), "table");

            testCase.verifyEqual(t.simulateBridgeHover(1, 1), "rows=5")
        end

        function tFunctionTooltipTableValuesShape(testCase)
            % ContextShape="Values" on a homogeneous table returns the
            % underlying numeric array.
            m = magic(5);
            t = gwidgets.Table(Data=array2table(m));
            t.addTooltip(@(~, arr) "max=" + max(arr, [], "all"), "table", ...
                "ContextShape", "Values");

            testCase.verifyEqual(t.simulateBridgeHover(1, 1), "max=25")
        end

        function tFunctionTooltipCellTableShape(testCase)
            % ContextShape="Table" on a cell target gives a 1x1 table at
            % the hovered cell — useful for extracting the column name.
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(~, cellTbl) "col=" + string(cellTbl.Properties.VariableNames{1}), ...
                "cell", [2 1], "ContextShape", "Table");

            testCase.verifyEqual(t.simulateBridgeHover(2, 1), "col=Numerical")
        end

        function tFunctionTooltipSeesHiddenColumns(testCase)
            % Hiding a column doesn't remove it from the data; tooltip
            % functions get the full underlying Data so aggregates can
            % reach hidden columns and filtered-out rows.
            m = magic(5);
            t = gwidgets.Table(Data=array2table(m));
            t.HiddenColumnNames = "Var2";
            t.addTooltip(@(~, tbl) strjoin(string(tbl.Var2), ","), "table");

            expected = strjoin(string(m(:, 2)), ",");
            testCase.verifyEqual(t.simulateBridgeHover(1, 1), expected)
        end

        function tFunctionTooltipRowIncludesHiddenColumns(testCase)
            % Row slice is taken from the underlying Data, so hidden
            % columns are still part of the slice. Use a mixed-type table
            % to force the 1xN-table fallback so we can address by name.
            data = testCase.multivariableData(); % Numerical, Categorical, Logical, String
            t = gwidgets.Table(Data=data);
            t.HiddenColumnNames = "String";
            t.addTooltip(@(~, row) "s=" + row.String, "row", 2);

            testCase.verifyEqual(t.simulateBridgeHover(2, 1), "s=x")
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

        function tTableTooltipMatchesShape(testCase)
            % Sanity-check TableTooltip.matches for each target shape.
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

        function tAddFunctionTooltipStoresHandle(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            fn = @(v) "Cell: " + string(v);
            t.addTooltip(fn, "column", 1);
            testCase.assertNumElements(t.Tooltips, 1)
            testCase.verifyEqual(t.Tooltips(1).Text, "")
            testCase.verifyEqual(t.Tooltips(1).TextFunction, fn)
        end

        function tFunctionTooltipColumnSliceIsHoveredColumn(testCase)
            % When a column tooltip targets multiple columns, the slice
            % passed to the function is the column the user is actually
            % hovering — not all configured columns concatenated.
            data = testCase.multivariableData(); % Numerical=1..5, Logical=[1 0 1 0 1]
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(~, col) "sum=" + sum(col), "column", [1 3]);

            testCase.verifyEqual(t.simulateBridgeHover(1, 1), "sum=15") % Numerical
            testCase.verifyEqual(t.simulateBridgeHover(1, 3), "sum=3")  % Logical
        end

        function tFunctionTooltipCellTargetGetsValueTwice(testCase)
            % For "cell" target, both args of a two-arg function receive
            % the hovered cell value.
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(v, ctx) "v=" + string(v) + " ctx=" + string(ctx), ...
                "cell", [2 1]);

            testCase.verifyEqual(t.simulateBridgeHover(2, 1), "v=2 ctx=2")
        end

    end

end
