classdef tTooltips < test.WithExampleTables
    % Test cell-level tooltip configuration on a headless table.

    methods (Test)

        function tDefaultTooltipEmpty(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            testCase.verifyEqual(t.Tooltip, "")
            testCase.verifyEmpty(t.Tooltips)
        end

        function tAddTooltipWithStaticStyle(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            sty = gwidgets.table.TooltipStyle( ...
                BackgroundColor="#222", FontColor="white");
            t.addTooltip("hi", "cell", [2 3], "Style", sty);

            testCase.assertNumElements(t.Tooltips, 1)
            testCase.verifyEqual(t.Tooltips(1).Style.BackgroundColor, "#222")
            testCase.verifyEmpty(t.Tooltips(1).StyleFunction)
        end

        function tAddTooltipWithStyleFunction(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            fn = @(ctx) gwidgets.table.TooltipStyle(BackgroundColor="red");
            t.addTooltip("hi", "column", 1, "Style", fn);

            testCase.assertNumElements(t.Tooltips, 1)
            testCase.verifyEmpty(t.Tooltips(1).Style)
            testCase.verifyEqual(t.Tooltips(1).StyleFunction, fn)
        end

        function tStyleResolvesMostSpecific(testCase)
            % Cell-style wins over row-style wins over column-style wins
            % over table-style; widget DefaultTooltipStyle is the base.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("col", "column", 1, "Style", ...
                gwidgets.table.TooltipStyle(BackgroundColor="#aaa"));
            t.addTooltip("row", "row", 2, "Style", ...
                gwidgets.table.TooltipStyle(BackgroundColor="#bbb"));
            t.addTooltip("cell", "cell", [2 1], "Style", ...
                gwidgets.table.TooltipStyle(BackgroundColor="#ccc"));

            [~, sty] = t.simulateBridgeHover(2, 1);
            testCase.verifyEqual(sty.BackgroundColor, "#ccc")
        end

        function tBlocksGroupByStyle(testCase)
            % Three tooltips, two distinct styles. The cell and column
            % tooltips share "red" so they group together (cell line
            % first, column line after); the row tooltip is "blue" alone;
            % the table tooltip has no per-tooltip style so it falls into
            % the (base) default-style group on its own.
            t = gwidgets.Table(Data=testCase.multivariableData());
            red  = gwidgets.table.TooltipStyle(BackgroundColor="red");
            blue = gwidgets.table.TooltipStyle(BackgroundColor="blue");

            t.addTooltip("cell-text", "cell", [2 3], "Style", red);
            t.addTooltip("row-text",  "row",  2,     "Style", blue);
            t.addTooltip("col-text",  "column", 3,   "Style", red);
            t.addTooltip("tbl-text",  "table");

            blocks = t.resolveTooltipBlocks(2, 3);
            testCase.assertNumElements(blocks, 3)
            testCase.verifyEqual(string(blocks{1}.text), ...
                "cell-text" + newline + "col-text")
            testCase.verifyEqual(string(blocks{2}.text), "row-text")
            testCase.verifyEqual(string(blocks{3}.text), "tbl-text")
            % Group 1 + 2 carry an explicit color; group 3 uses the base
            % (no explicit BackgroundColor override beyond the default).
            testCase.verifyThat(blocks{1}.css, ...
                matlab.unittest.constraints.ContainsSubstring("background-color:red"))
            testCase.verifyThat(blocks{2}.css, ...
                matlab.unittest.constraints.ContainsSubstring("background-color:blue"))
        end

        function tBlocksGroupOrderIsMostSpecificFirst(testCase)
            % Group order = first-appearance, which is most-specific-first
            % (cell > row > column > table). If the row tooltip uses red
            % and a cell tooltip uses red, the red group still leads
            % because the cell match appears first in the iteration.
            t = gwidgets.Table(Data=testCase.multivariableData());
            red = gwidgets.table.TooltipStyle(BackgroundColor="red");

            t.addTooltip("col",  "column", 1, "Style", red);   % rank 3
            t.addTooltip("cell", "cell", [2 1], "Style", red); % rank 1

            blocks = t.resolveTooltipBlocks(2, 1);
            testCase.assertNumElements(blocks, 1)
            % Cell line first, column line after.
            testCase.verifyEqual(string(blocks{1}.text), ...
                "cell" + newline + "col")
        end

        function tBlocksEmptyWhenNothingToShow(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            blocks = t.resolveTooltipBlocks(2, 1);
            testCase.verifyEmpty(blocks)
        end

        function tBlocksFallBackToTableTooltipWithBaseStyle(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Tooltip = "table-wide";
            blocks = t.resolveTooltipBlocks(2, 1);
            testCase.assertNumElements(blocks, 1)
            testCase.verifyEqual(string(blocks{1}.text), "table-wide")
        end

        function tStyleFunctionReceivesContext(testCase)
            % StyleFunction takes the same TooltipContext as TextFunction.
            makeStyle = @(ctx) gwidgets.table.TooltipStyle( ...
                BackgroundColor=string(sprintf("#%02x%02x%02x", ctx.Value, ctx.Value, ctx.Value)));
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("col", "column", 1, "Style", makeStyle);

            % Row 3 -> Numerical=3 -> "#030303"
            [~, sty] = t.simulateBridgeHover(3, 1);
            testCase.verifyEqual(sty.BackgroundColor, "#030303")
        end

        function tDefaultTooltipStyleAppliesAsFallback(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DefaultTooltipStyle = gwidgets.table.TooltipStyle( ...
                BackgroundColor="#123");
            t.addTooltip("col", "column", 1);

            [~, sty] = t.simulateBridgeHover(1, 1);
            testCase.verifyEqual(sty.BackgroundColor, "#123")
        end

        function tStyleFunctionErrorFallsBackToDefault(testCase)
            % Broken style function shouldn't crash hover; tooltip still
            % renders, just with the base style.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip("col", "column", 1, "Style", @(ctx) error("boom"));

            [text, sty] = t.simulateBridgeHover(1, 1);
            testCase.verifyEqual(text, "col")
            testCase.verifyEqual(sty.BackgroundColor, ...
                gwidgets.table.TooltipStyle.default().BackgroundColor)
        end

        function tTooltipStyleMergeOverridesNonMissing(testCase)
            base = gwidgets.table.TooltipStyle( ...
                BackgroundColor="#aaa", FontSize=10, Padding=4);
            override = gwidgets.table.TooltipStyle( ...
                FontSize=14);
            merged = base.merge(override);

            testCase.verifyEqual(merged.BackgroundColor, "#aaa")
            testCase.verifyEqual(merged.FontSize, 14)
            testCase.verifyEqual(merged.Padding, 4)
        end

        function tTooltipStyleToCssOmitsUnset(testCase)
            sty = gwidgets.table.TooltipStyle( ...
                BackgroundColor="red", FontColor=[0 0 0]);
            css = sty.toCss();
            testCase.verifyThat(css, ...
                matlab.unittest.constraints.ContainsSubstring("background-color:red"))
            testCase.verifyThat(css, ...
                matlab.unittest.constraints.ContainsSubstring("color:rgb(0,0,0)"))
            testCase.verifyThat(css, ...
                ~matlab.unittest.constraints.ContainsSubstring("padding"))
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
            t.addTooltip(@(ctx) "Value: " + string(ctx.Value), "column", 1);

            % Row 3, column 1 (Numerical) holds the value 3.
            testCase.verifyEqual(t.simulateBridgeHover(3, 1), "Value: 3")
            testCase.verifyEqual(t.simulateBridgeHover(1, 1), "Value: 1")
        end

        function tFunctionTooltipJoinsWithStaticTooltip(testCase)
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip("a row", "row", 2);
            t.addTooltip(@(ctx) "val=" + string(ctx.Value), "column", 1);

            testCase.verifyEqual(t.simulateBridgeHover(2, 1), ...
                strjoin(["a row", "val=2"], newline))
        end

        function tFunctionTooltipReceivesColumnSlice(testCase)
            % column target -> ctx.Column populated as a vector.
            data = testCase.multivariableData();  % Numerical is [1..5]
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(ctx) "max=" + max(ctx.Column), "column", 1);

            testCase.verifyEqual(t.simulateBridgeHover(3, 1), "max=5")
        end

        function tFunctionTooltipReceivesRowSliceDefault(testCase)
            % row target default ContextShape="Table" — ctx.Row is a 1xN
            % table, so name access works on any table.
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(ctx) "n=" + ctx.Row.Numerical, "row", 2);

            testCase.verifyEqual(t.simulateBridgeHover(2, 3), "n=2")
        end

        function tFunctionTooltipRowSliceValuesShape(testCase)
            % ContextShape="Values" extracts ctx.Row as a vector — works
            % for homogeneous tables.
            m = magic(5);
            t = gwidgets.Table(Data=array2table(m));
            t.addTooltip(@(ctx) "max=" + max(ctx.Row), "row", 2, ...
                "ContextShape", "Values");

            testCase.verifyEqual(t.simulateBridgeHover(2, 1), ...
                "max=" + string(max(m(2, :))))
        end

        function tFunctionTooltipReceivesWholeTable(testCase)
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(ctx) "rows=" + height(ctx.Table), "table");

            testCase.verifyEqual(t.simulateBridgeHover(1, 1), "rows=5")
        end

        function tFunctionTooltipCellTargetExposesPosition(testCase)
            % Cell target gets the DisplayRow/DisplayColumn/DataRow/...
            % via the context, useful for printing the cell location.
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(ctx) sprintf("(%d,%d)", ctx.DisplayRow, ctx.DisplayColumn), ...
                "cell", [2 1]);

            testCase.verifyEqual(t.simulateBridgeHover(2, 1), "(2,1)")
        end

        function tFunctionTooltipSeesHiddenColumns(testCase)
            % Hiding a column doesn't remove it from the data; the
            % context's Table is the full underlying Data, hidden
            % columns reachable by name.
            m = magic(5);
            t = gwidgets.Table(Data=array2table(m));
            t.HiddenColumnNames = "Var2";
            t.addTooltip(@(ctx) strjoin(string(ctx.Table.Var2), ","), "table");

            expected = strjoin(string(m(:, 2)), ",");
            testCase.verifyEqual(t.simulateBridgeHover(1, 1), expected)
        end

        function tFunctionTooltipRowIncludesHiddenColumns(testCase)
            % ctx.Row is a slice of the underlying Data so hidden columns
            % are still reachable by name. Use a mixed-type table so the
            % default Table shape applies and named access works.
            data = testCase.multivariableData(); % Numerical, Categorical, Logical, String
            t = gwidgets.Table(Data=data);
            t.HiddenColumnNames = "String";
            t.addTooltip(@(ctx) "s=" + ctx.Row.String, "row", 2);

            testCase.verifyEqual(t.simulateBridgeHover(2, 1), "s=x")
        end

        function tFunctionTooltipErrorIsContained(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.addTooltip(@(ctx) error("boom"), "cell", [2 1]);

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
            fn = @(ctx) "Cell: " + string(ctx.Value);
            t.addTooltip(fn, "column", 1);
            testCase.assertNumElements(t.Tooltips, 1)
            testCase.verifyEqual(t.Tooltips(1).Text, "")
            testCase.verifyEqual(t.Tooltips(1).TextFunction, fn)
        end

        function tFunctionTooltipColumnSliceIsHoveredColumn(testCase)
            % When a column tooltip targets multiple columns, ctx.Column
            % is the column the user is actually hovering — not all
            % configured columns concatenated.
            data = testCase.multivariableData(); % Numerical=1..5, Logical=[1 0 1 0 1]
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(ctx) "sum=" + sum(ctx.Column), "column", [1 3]);

            testCase.verifyEqual(t.simulateBridgeHover(1, 1), "sum=15") % Numerical
            testCase.verifyEqual(t.simulateBridgeHover(1, 3), "sum=3")  % Logical
        end

        function tFunctionTooltipContextReportsTarget(testCase)
            % ctx.Target is the firing tooltip's target.
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.addTooltip(@(ctx) "tgt=" + ctx.Target, "row", 2);

            testCase.verifyEqual(t.simulateBridgeHover(2, 1), "tgt=row")
        end

    end

end
