classdef tJavaScriptRender < matlab.unittest.TestCase
    % Tests for the uihtml-backed table renderer.

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tSnapshotContainsHeadersAndCells(testCase)
            data = table([1; 2], ["a"; "b"], VariableNames=["Value", "Label"]);
            [~, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);

            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(double(snapshot.rowCount), 2)
            testCase.verifyEqual(double(snapshot.columnCount), 2)
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.headerTexts), ...
                ["Value", "Label"])
            testCase.verifyEqual(test.unit.gwidgets.Table.tJavaScriptRender.cellText(snapshot, 1, 1), "1")
            testCase.verifyEqual(test.unit.gwidgets.Table.tJavaScriptRender.cellText(snapshot, 2, 2), "b")
        end

        function tSnapshotReflectsSelectionEditingAndStyles(testCase)
            data = table([1; 2], ["a"; "b"], VariableNames=["Value", "Label"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnEditable = [true false];
            t.Selection = [2 1];
            t.addStyle(uistyle(BackgroundColor=[1 0 0]), "cell", [2 1]);

            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyTrue(test.unit.gwidgets.Table.tJavaScriptRender.hasPair( ...
                snapshot.selectedCellRows, snapshot.selectedCellCols, 2, 1))
            testCase.verifyTrue(test.unit.gwidgets.Table.tJavaScriptRender.hasPair( ...
                snapshot.editableRows, snapshot.editableCols, 1, 1))
            testCase.verifyFalse(test.unit.gwidgets.Table.tJavaScriptRender.hasPair( ...
                snapshot.editableRows, snapshot.editableCols, 1, 2))
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.cellBackground(snapshot, 2, 1), ...
                "rgb(255, 0, 0)")
        end

        function tClickCellUsesDomEventPath(testCase)
            data = table([1; 2], ["a"; "b"], VariableNames=["Value", "Label"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);

            backend.probeBrowser("ClickCell", struct("row", 2, "col", 1));

            testCase.verifyEqual(t.Selection, [2 1])
        end

        function tEditCellUsesDomBlurPath(testCase)
            data = table([1; 2], VariableNames="Value");
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnEditable = true;

            backend.probeBrowser("EditCell", struct("row", 2, "col", 1, "value", "42"));

            testCase.verifyEqual(t.Data.Value(2), 42)
        end

        function tClickHeaderSelectsCellsInColumn(testCase)
            data = table([3; 1; 2], VariableNames="Value");
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnSortable = true;

            backend.probeBrowser("ClickHeader", struct("col", 1));
            test.unit.gwidgets.Table.tJavaScriptRender.waitForSelection(t, [1 1; 2 1; 3 1]);
            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(string(t.SelectionType), "cell")
            testCase.verifyEqual(t.Selection, [1 1; 2 1; 3 1])
            testCase.verifyEqual(t.Sort.By, string.empty(1,0))
            testCase.verifyEqual(t.Sort.Direction, "None")
            testCase.verifyEqual(t.DisplayData.Value, [3; 1; 2])
            testCase.verifyTrue(test.unit.gwidgets.Table.tJavaScriptRender.hasPair( ...
                snapshot.selectedCellRows, snapshot.selectedCellCols, 1, 1))
            testCase.verifyTrue(test.unit.gwidgets.Table.tJavaScriptRender.hasPair( ...
                snapshot.selectedCellRows, snapshot.selectedCellCols, 2, 1))
            testCase.verifyTrue(test.unit.gwidgets.Table.tJavaScriptRender.hasPair( ...
                snapshot.selectedCellRows, snapshot.selectedCellCols, 3, 1))
        end

        function tClickHeaderSelectsColumnInColumnMode(testCase)
            data = table([3; 1; 2], ["a"; "b"; "c"], VariableNames=["Value", "Label"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.SelectionType = "column";

            backend.probeBrowser("ClickHeader", struct("col", 2));
            test.unit.gwidgets.Table.tJavaScriptRender.waitForSelection(t, 2);
            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(string(t.SelectionType), "column")
            testCase.verifyEqual(t.Selection, 2)
            testCase.verifyEqual(double(snapshot.selectedColumns), 2)
        end

        function tClickHeaderSelectsRowsInRowMode(testCase)
            data = table([3; 1; 2], ["a"; "b"; "c"], VariableNames=["Value", "Label"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.SelectionType = "row";

            backend.probeBrowser("ClickHeader", struct("col", 2));
            test.unit.gwidgets.Table.tJavaScriptRender.waitForSelection(t, [1 2 3]);
            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(string(t.SelectionType), "row")
            testCase.verifyEqual(t.Selection, [1 2 3])
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.selectedRows), ...
                [1 2 3])
        end

        function tHeaderSortButtonCyclesSortDirection(testCase)
            data = table([3; 1; 2], VariableNames="Value");
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnSortable = true;

            snapshot = backend.probeBrowser("Snapshot");
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.headerButtonTexts), ...
                "-")

            backend.probeBrowser("ClickHeaderSortButton", struct("col", 1));
            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(t.Sort.By, "Value")
            testCase.verifyEqual(t.Sort.Direction, "Ascend")
            testCase.verifyEqual(t.DisplayData.Value, [1; 2; 3])
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.headerButtonTexts), ...
                "^")

            backend.probeBrowser("ClickHeaderSortButton", struct("col", 1));
            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(t.Sort.Direction, "Descend")
            testCase.verifyEqual(t.DisplayData.Value, [3; 2; 1])
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.headerButtonTexts), ...
                "v")

            backend.probeBrowser("ClickHeaderSortButton", struct("col", 1));
            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(t.Sort.Direction, "None")
            testCase.verifyEqual(t.DisplayData.Value, [3; 1; 2])
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.headerButtonTexts), ...
                "-")
        end

        function tHeaderSortButtonDisablesUnsortableColumn(testCase)
            data = table([1; 2], ["a"; "b"], VariableNames=["Value", "Label"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnSortable = [true false];

            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(reshape(logical(snapshot.headerButtonDisabled), 1, []), [false true])
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.headerButtonTexts), ...
                ["-", ""])

            backend.probeBrowser("ClickHeaderSortButton", struct("col", 2));

            testCase.verifyEqual(t.Sort.By, string.empty(1,0))
            testCase.verifyEqual(t.Sort.Direction, "None")
        end

        function tTransposedRowHeaderSortButtonCyclesSortDirection(testCase)
            data = table([3; 1; 2], ["b"; "c"; "a"], VariableNames=["ID", "Group"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.DisplayOrientation = "Transposed";
            t.ColumnSortable = true;

            snapshot = backend.probeBrowser("Snapshot");
            labels = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.rowHeaderLabels);
            buttons = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.rowHeaderButtonTexts);
            groupRow = test.unit.gwidgets.Table.tJavaScriptRender.rowHeaderRow(snapshot, "Group");
            testCase.assertNotEmpty(groupRow)
            testCase.verifyEqual(labels, ["ID", "Group"])
            testCase.verifyEqual(buttons, ["-", "-"])

            backend.probeBrowser("ClickRowHeaderSortButton", struct("row", groupRow));
            snapshot = backend.probeBrowser("Snapshot");
            idRow = find(string(t.DisplayData.Variable) == "ID", 1);
            testCase.assertNotEmpty(idRow)
            displayedIDs = t.DisplayData{idRow, 2:end};
            if iscell(displayedIDs)
                displayedIDs = cell2mat(displayedIDs);
            end
            displayedIDs = str2double(string(displayedIDs));

            testCase.verifyEqual(t.Sort.By, "Group")
            testCase.verifyEqual(t.Sort.Direction, "Ascend")
            testCase.verifyEqual(displayedIDs, [2 3 1])
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowHeaderButtonText(snapshot, "Group"), ...
                "<")

            backend.probeBrowser("ClickRowHeaderSortButton", struct("row", groupRow));
            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(t.Sort.Direction, "Descend")
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowHeaderButtonText(snapshot, "Group"), ...
                ">")
        end

        function tTransposedRowHeaderSortButtonHidesUnsortableRows(testCase)
            data = table([1; 2], ["a"; "b"], VariableNames=["ID", "Group"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.DisplayOrientation = "Transposed";
            t.ColumnSortable = [false true];

            snapshot = backend.probeBrowser("Snapshot");
            labels = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.rowHeaderLabels);
            buttons = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.rowHeaderButtonTexts);
            disabled = reshape(logical(snapshot.rowHeaderButtonDisabled), 1, []);

            testCase.verifyEqual(labels, ["ID", "Group"])
            testCase.verifyEqual(buttons, ["", "-"])
            testCase.verifyEqual(disabled, [true false])
        end

        function tHorizontalScrollClampsAtTableEnd(testCase)
            data = array2table(reshape(1:30, 3, 10), VariableNames="V" + string(1:10));
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnWidth = num2cell(repelem(120, 1, 10));
            backend.probeBrowser("SetRootSize", struct("width", 260, "height", 100));

            snapshot = backend.probeBrowser("Snapshot");
            testCase.assumeGreaterThan(double(snapshot.rootMaxScrollLeft), 0)

            first = backend.probeBrowser("ScrollHorizontal", struct("left", 1e6));
            startTime = tic;
            while toc(startTime) < 5 && double(first.rootScrollLeft) == 0
                drawnow()
                first = backend.probeBrowser("ScrollHorizontal", struct("left", 1e6));
            end
            second = backend.probeBrowser("ScrollHorizontal", struct("left", 1e6));

            testCase.verifyEqual(double(first.rootScrollLeft), double(first.rootMaxScrollLeft), AbsTol=1)
            testCase.verifyEqual(double(second.rootScrollLeft), double(first.rootScrollLeft), AbsTol=1)
            testCase.verifyEqual(double(second.rootScrollWidth), double(first.rootScrollWidth), AbsTol=1)
        end

        function tContextMenuSubmenusPopOut(testCase)
            data = table(["A"; "B"], ["x"; "y"], VariableNames=["Group", "Label"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.GroupingVariable = "Group";
            t.HasChangeGroupingVariable = true;

            backend.probeBrowser("OpenContextMenu", struct("row", 1, "col", 1));
            snapshot = backend.probeBrowser( ...
                "HoverContextMenuItem", struct("row", 1, "col", 1, "path", "Grouping > Set"));

            openPaths = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.contextMenuOpenPaths);
            displays = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.contextMenuSubmenuDisplays);
            positions = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.contextMenuSubmenuPositions);

            testCase.verifyTrue(any(openPaths == "Grouping > Set"))
            testCase.verifyTrue(any(displays == "block"))
            testCase.verifyTrue(any(positions == "absolute"))
        end

        function tContextMenuSubmenusPaintAboveSiblings(testCase)
            data = table(["A"; "B"], ["x"; "y"], VariableNames=["Group", "Label"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.GroupingVariable = "Group";
            t.HasChangeGroupingVariable = true;
            t.HasColumnSorting = true;
            t.ColumnSortable = true;

            backend.probeBrowser("OpenContextMenu", struct("row", 1, "col", 1));
            snapshot = backend.probeBrowser( ...
                "HoverContextMenuItem", struct("row", 1, "col", 1, "path", "Grouping > Add"));

            backgrounds = test.unit.gwidgets.Table.tJavaScriptRender.rowString( ...
                snapshot.contextMenuSubmenuBackgroundColors);
            zIndexes = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.contextMenuSubmenuZIndexes);

            testCase.verifyTrue(any( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.contextMenuOpenPaths) == ...
                "Grouping > Add"))
            testCase.verifyTrue(all(backgrounds == string(snapshot.contextMenuBackgroundColor)))
            testCase.verifyTrue(all(str2double(zIndexes) >= 10001))
        end

        function tUsesFigureThemeStatus(testCase)
            data = table([1; 2], VariableNames="Value");
            [~, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable( ...
                testCase, data, Theme="dark");

            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(string(snapshot.theme), "dark")
            testCase.verifyNotEqual(string(snapshot.tableBackgroundColor), "rgb(255, 255, 255)")
        end

        function tCustomTooltipSuppressesNativeTitle(testCase)
            data = table([1; 2], VariableNames="Value");
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.TooltipControl.Text = "Hover any cell for details";
            t.TooltipControl.add("Specific cell", "cell", [1 1]);

            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(string(snapshot.tableTitle), "")
            testCase.verifyTrue(all(test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.headerTitles) == ""))
            testCase.verifyTrue(all(test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.cellTitles) == ""))

            snapshot = backend.probeBrowser("HoverCell", struct("row", 1, "col", 1));

            testCase.verifyTrue(logical(snapshot.tooltipVisible))
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.tooltipLineTexts), ...
                "Specific cell")
        end

        function tGroupHeaderTooltipsCanBeDisabled(testCase)
            data = table( ...
                ["A long group label"; "A long group label"; "B"], ...
                [1; 2; 3], ...
                VariableNames=["Group", "Value"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.GroupingVariable = "Group";

            snapshot = backend.probeBrowser("Snapshot");
            labels = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.groupHeaderLabels);
            titles = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.groupHeaderTitles);

            testCase.assertNotEmpty(labels)
            testCase.verifyEqual(titles, labels)

            t.ShowGroupHeaderTooltips = false;
            snapshot = backend.probeBrowser("Snapshot");
            titles = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.groupHeaderTitles);

            testCase.verifyTrue(all(titles == ""))

            t.Tooltip = "Inspect table";
            snapshot = backend.probeBrowser("Snapshot");
            titles = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.groupHeaderTitles);

            testCase.verifyEqual(titles, repelem("Inspect table", 1, numel(titles)))
        end

        function tTransposedGroupHeaderTooltipsCanBeDisabled(testCase)
            data = table( ...
                ["A long group label"; "A long group label"; "B"], ...
                [1; 2; 3], ...
                VariableNames=["Group", "Value"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.GroupingVariable = "Group";
            t.DisplayOrientation = "Transposed";

            snapshot = backend.probeBrowser("Snapshot");
            labels = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.groupHeaderColumnLabels);
            titles = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.groupHeaderColumnTitles);

            testCase.assertNotEmpty(labels)
            testCase.verifyEqual(titles, labels)

            t.ShowGroupHeaderTooltips = false;
            snapshot = backend.probeBrowser("Snapshot");
            titles = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.groupHeaderColumnTitles);

            testCase.verifyTrue(all(titles == ""))
        end

        function tDragSelectCellsSelectsRectangle(testCase)
            data = array2table(reshape(1:9, 3, 3), VariableNames=["A", "B", "C"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);

            backend.probeBrowser("DragSelectCells", struct( ...
                "startRow", 1, ...
                "startCol", 1, ...
                "endRow", 2, ...
                "endCol", 2));

            testCase.verifyEqual(t.Selection, [1 1; 1 2; 2 1; 2 2])
        end

        function tFitColumnWidthsUseContent(testCase)
            data = table( ...
                ["a"; "b"], ...
                ["short"; "a much longer cell value"], ...
                VariableNames=["A", "LongTextColumn"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnWidth = {"fit", "fit"};

            snapshot = backend.probeBrowser("Snapshot");
            widths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(snapshot.colStyleWidths);

            testCase.verifyEqual(t.ColumnWidth, {"fit", "fit"})
            testCase.verifyGreaterThan(widths(2), widths(1))
        end

        function tAutoResizeColumnsUsesMinimumContentWidth(testCase)
            nRows = 80;
            descriptions = "tiny_" + string((1:nRows)');
            descriptions(end) = "a longer off screen value that should fit without ellipsis";
            data = table((1:nRows)', descriptions, VariableNames=["ID", "Description"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            backend.probeBrowser("SetRootSize", struct("width", 900, "height", 120));

            t.UITable.Display.requestAutoResize();
            startTime = tic;
            while toc(startTime) < 5 && ~isequal(t.ColumnWidthTypes, ["Pixel", "Pixel"])
                drawnow()
            end
            testCase.assertEqual(t.ColumnWidthTypes, ["Pixel", "Pixel"])
            snapshot = backend.probeBrowser("Snapshot");
            measured = backend.probeBrowser("MeasureAutoResizeWidths");
            widths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(snapshot.colStyleWidths);
            measuredWidths = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(measured.autoResizeWidths);

            testCase.verifyEqual(widths, measuredWidths, AbsTol=1)
            testCase.verifyLessThan(sum(widths), double(snapshot.rootClientWidth))

            scrolled = backend.probeBrowser("ScrollToRow", struct("row", nRows));
            mask = test.unit.gwidgets.Table.tJavaScriptRender.cellMask(scrolled, nRows, 2);

            testCase.assertTrue(any(mask))
            testCase.verifyLessThanOrEqual( ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(scrolled.cellScrollWidths(mask)), ...
                test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(scrolled.cellClientWidths(mask)) + 1)
        end

        function tColumnMinAndMaxClampRenderedWidths(testCase)
            data = table([1; 2], [3; 4], VariableNames=["A", "B"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnWidth = {"1x", "1x"};
            t.TableMinWidth = 400;
            t.ColumnMinWidth = [180, 24];
            t.ColumnMaxWidth = [200, 80];

            snapshot = backend.probeBrowser("Snapshot");
            widths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(snapshot.colStyleWidths);

            testCase.verifyGreaterThanOrEqual(widths(1), 180)
            testCase.verifyLessThanOrEqual(widths(1), 200)
            testCase.verifyLessThanOrEqual(widths(2), 80)
        end

        function tTableMinWidthAllowsHorizontalScroll(testCase)
            data = table([1; 2], [3; 4], VariableNames=["A", "B"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.TableMinWidth = 800;

            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyGreaterThanOrEqual(double(snapshot.tableWidth), 800)
            testCase.verifyGreaterThanOrEqual(double(snapshot.rootScrollWidth), double(snapshot.tableWidth) - 1)
        end

        function tRelativeColumnsRelayoutWhenRootResizes(testCase)
            data = table([1; 2], [3; 4], VariableNames=["A", "B"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnWidth = {"1x", "3x"};

            wide = backend.probeBrowser("SetRootSize", struct("width", 640, "height", 200));
            narrow = backend.probeBrowser("SetRootSize", struct("width", 320, "height", 200));

            wideWidths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(wide.colStyleWidths);
            narrowWidths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(narrow.colStyleWidths);

            testCase.verifyEqual(sum(wideWidths), 640, AbsTol=4)
            testCase.verifyEqual(sum(narrowWidths), 320, AbsTol=4)
            testCase.verifyEqual(wideWidths/sum(wideWidths), [0.25, 0.75], AbsTol=0.02)
            testCase.verifyEqual(narrowWidths/sum(narrowWidths), [0.25, 0.75], AbsTol=0.02)
        end

        function tCellAndHeaderHeightsAreFixed(testCase)
            data = table( ...
                ["short"; "a very long value that should be clipped instead of increasing row height"], ...
                [1; 2], ...
                VariableNames=["Text", "Value"]);
            [~, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);

            snapshot = backend.probeBrowser("Snapshot");

            headerHeights = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.headerHeights);
            cellHeights = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.cellHeights);

            testCase.verifyEqual(headerHeights, repelem(24, 1, numel(headerHeights)), AbsTol=1)
            testCase.verifyEqual(cellHeights, repelem(24, 1, numel(cellHeights)), AbsTol=1)
        end

        function tGroupHeaderHeightsAreFixed(testCase)
            data = table(["A"; "A"; "B"], [1; 2; 3], VariableNames=["Group", "Value"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.GroupingVariable = "Group";

            snapshot = backend.probeBrowser("Snapshot");
            groupHeights = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.groupHeaderHeights);

            testCase.verifyNotEmpty(groupHeights)
            testCase.verifyEqual(groupHeights, repelem(24, 1, numel(groupHeights)), AbsTol=1)
        end

        function tTransposedGroupHeaderColumnsDefaultToPixels(testCase)
            data = table(["A"; "A"; "B"], [1; 2; 3], VariableNames=["Group", "Value"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.GroupingVariable = "Group";
            t.DisplayOrientation = "Transposed";

            snapshot = backend.probeBrowser("Snapshot");
            groupColumns = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.groupHeaderColumns);
            widths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(snapshot.colStyleWidths);

            testCase.verifyNotEmpty(groupColumns)
            testCase.verifyGreaterThanOrEqual(widths(groupColumns), repelem(36, 1, numel(groupColumns)))
        end

        function tAutoResizeTransposedGroupHeadersUseRotatedTextThickness(testCase)
            data = table( ...
                ["A very long group label"; "A very long group label"; "B"; "B"], ...
                [1; 2; 3; 4], ...
                VariableNames=["Group", "Value"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.GroupingVariable = "Group";
            t.DisplayOrientation = "Transposed";

            snapshot = backend.probeBrowser("Snapshot");
            measured = backend.probeBrowser("MeasureAutoResizeWidths");
            groupColumns = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.groupHeaderColumns);
            widths = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(measured.autoResizeWidths);

            testCase.verifyNotEmpty(groupColumns)
            testCase.verifyLessThan(max(widths(groupColumns)), 60)
            testCase.verifyGreaterThanOrEqual(min(widths(groupColumns)), 24)
        end

        function tTransposedGroupHeaderColumnWidthPersistsWhenFolding(testCase)
            data = table( ...
                ["A"; "A"; "B"; "B"; "C"; "C"], ...
                (1:6)', ...
                VariableNames=["Group", "Value"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.GroupingVariable = "Group";
            t.DisplayOrientation = "Transposed";
            snapshot = backend.probeBrowser("Snapshot");
            labels = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.groupHeaderColumnLabels);
            groupColumns = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.groupHeaderColumns);
            targetIdx = find(contains(labels, "B"), 1);
            testCase.assertNotEmpty(targetIdx)

            resized = backend.probeBrowser("DragColumnResize", struct("col", groupColumns(targetIdx), "delta", 48));
            resizedWidths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(resized.colStyleWidths);
            resizedWidth = resizedWidths(groupColumns(targetIdx));

            backend.probeBrowser("ClickCell", struct("row", 1, "col", groupColumns(1)));
            opened = backend.probeBrowser("Snapshot");
            openedLabels = test.unit.gwidgets.Table.tJavaScriptRender.rowString(opened.groupHeaderColumnLabels);
            openedColumns = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(opened.groupHeaderColumns);
            openedTargetIdx = find(contains(openedLabels, "B"), 1);
            openedWidths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(opened.colStyleWidths);

            testCase.assertNotEmpty(openedTargetIdx)
            testCase.verifyEqual(openedWidths(openedColumns(openedTargetIdx)), resizedWidth, AbsTol=2)

            openedFirstIdx = find(contains(openedLabels, "A"), 1);
            testCase.assertNotEmpty(openedFirstIdx)
            backend.probeBrowser("ClickCell", struct("row", 1, "col", openedColumns(openedFirstIdx)));
            closed = backend.probeBrowser("Snapshot");
            closedLabels = test.unit.gwidgets.Table.tJavaScriptRender.rowString(closed.groupHeaderColumnLabels);
            closedColumns = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(closed.groupHeaderColumns);
            closedTargetIdx = find(contains(closedLabels, "B"), 1);
            closedWidths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(closed.colStyleWidths);

            testCase.assertNotEmpty(closedTargetIdx)
            testCase.verifyEqual(closedWidths(closedColumns(closedTargetIdx)), resizedWidth, AbsTol=2)
        end

        function tTransposedGroupElementColumnWidthPersistsWhenReopened(testCase)
            data = table( ...
                ["A"; "A"; "B"; "B"; "C"; "C"], ...
                (1:6)', ...
                VariableNames=["Group", "Value"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.GroupingVariable = "Group";
            t.DisplayOrientation = "Transposed";
            collapsed = backend.probeBrowser("Snapshot");
            groupColumns = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(collapsed.groupHeaderColumns);
            groupLabels = test.unit.gwidgets.Table.tJavaScriptRender.rowString(collapsed.groupHeaderColumnLabels);
            groupIdx = find(contains(groupLabels, "A"), 1);
            testCase.assertNotEmpty(groupIdx)
            variableWidth = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues( ...
                collapsed.colStyleWidths);
            variableWidth = variableWidth(1);

            backend.probeBrowser("ClickCell", struct("row", 1, "col", groupColumns(groupIdx)));
            opened = backend.probeBrowser("Snapshot");
            openedWidths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(opened.colStyleWidths);
            testCase.verifyEqual(openedWidths(1), variableWidth, AbsTol=2)
            dataColumn = test.unit.gwidgets.Table.tJavaScriptRender.cellColumnWithText(opened, "1");
            testCase.assertNotEmpty(dataColumn)

            resized = backend.probeBrowser("DragColumnResize", struct("col", dataColumn, "delta", 45));
            resizedWidths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(resized.colStyleWidths);
            resizedWidth = resizedWidths(dataColumn);

            backend.probeBrowser("ClickCell", struct("row", 1, "col", groupColumns(groupIdx)));
            closed = backend.probeBrowser("Snapshot");
            closedWidths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(closed.colStyleWidths);
            testCase.verifyEqual(closedWidths(1), variableWidth, AbsTol=2)

            backend.probeBrowser("ClickCell", struct("row", 1, "col", groupColumns(groupIdx)));
            reopened = backend.probeBrowser("Snapshot");
            reopenedWidths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(reopened.colStyleWidths);
            reopenedDataColumn = test.unit.gwidgets.Table.tJavaScriptRender.cellColumnWithText(reopened, "1");
            testCase.assertNotEmpty(reopenedDataColumn)

            testCase.verifyEqual(reopenedWidths(1), variableWidth, AbsTol=2)
            testCase.verifyEqual(reopenedWidths(reopenedDataColumn), resizedWidth, AbsTol=2)
        end

        function tLargeTablesRenderVisibleWindow(testCase)
            data = table((1:200)', "row_" + string((1:200)'), VariableNames=["Value", "Label"]);
            [~, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);

            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(double(snapshot.rowCount), 200)
            testCase.verifyLessThan(double(snapshot.renderedRowCount), 200)
            testCase.verifyGreaterThan(double(snapshot.renderedRowCount), 0)
        end

        function tVirtualRowsRenderAfterScroll(testCase)
            data = table((1:200)', "row_" + string((1:200)'), VariableNames=["Value", "Label"]);
            [~, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);

            snapshot = backend.probeBrowser("ScrollToRow", struct("row", 180));
            renderedRows = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.renderedRows);
            diagnostic = sprintf( ...
                "Rendered rows: %s, scrollTop: %.1f, scrollHeight: %.1f, clientHeight: %.1f", ...
                mat2str(renderedRows), ...
                double(snapshot.rootScrollTop), ...
                double(snapshot.rootScrollHeight), ...
                double(snapshot.rootClientHeight));

            testCase.verifyTrue(any(renderedRows == 180), diagnostic)
            testCase.verifyEqual(test.unit.gwidgets.Table.tJavaScriptRender.cellText(snapshot, 180, 1), "180")
            testCase.verifyEqual(test.unit.gwidgets.Table.tJavaScriptRender.cellText(snapshot, 180, 2), "row_180")
        end

        function tDragRelativeColumnResizePreservesWidthType(testCase)
            data = table([1; 2], [3; 4], [5; 6], VariableNames=["A", "B", "C"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnWidth = {"1x", "2x", "1x"};
            t.TableMinWidth = 400;
            snapshot = backend.probeBrowser("Snapshot");
            widthsBefore = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(snapshot.colStyleWidths);

            snapshot = backend.probeBrowser("DragColumnResize", struct("col", 2, "delta", 40));
            widthsAfter = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(snapshot.colStyleWidths);
            stable = backend.probeBrowser("Snapshot");
            stableWidths = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(stable.colStyleWidths);
            resizedWeight = str2double(erase(string(t.ColumnWidth{2}), "x"));
            expectedWeight = 2*widthsAfter(2)/widthsBefore(2);

            testCase.verifyEqual(t.ColumnWidthTypes, ["Relative", "Relative", "Relative"])
            testCase.verifyEqual(t.ColumnWidth([1, 3]), {"1x", "1x"})
            testCase.verifyEqual(resizedWeight, expectedWeight, AbsTol=1e-6)
            testCase.verifyTrue(isfinite(t.PixelColumnWidths(2)))
            testCase.verifyGreaterThan(t.PixelColumnWidths(2), widthsBefore(2))
            testCase.verifyClass(t.ColumnWidth{2}, "string")
            testCase.verifyGreaterThan(widthsAfter(2), widthsBefore(2))
            testCase.verifyEqual(stableWidths, widthsAfter, AbsTol=2)
        end

        function tDragPixelColumnResizePreservesWidthType(testCase)
            data = table([1; 2], [3; 4], VariableNames=["A", "B"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnWidth = {120, "1x"};

            backend.probeBrowser("DragColumnResize", struct("col", 1, "delta", 30));

            testCase.verifyEqual(t.ColumnWidthTypes(1), "Pixel")
            testCase.verifyGreaterThan(t.ColumnWidth{1}, 120)
        end

        function tDragTransposedGroupHeaderColumnResizesColumn(testCase)
            data = table(["A"; "A"; "B"], [1; 2; 3], VariableNames=["Group", "Value"]);
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.GroupingVariable = "Group";
            t.DisplayOrientation = "Transposed";
            snapshot = backend.probeBrowser("Snapshot");
            groupColumns = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.groupHeaderColumns);
            testCase.assertNotEmpty(groupColumns)
            widthsBefore = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(snapshot.colStyleWidths);

            snapshot = backend.probeBrowser( ...
                "DragColumnResize", struct("col", groupColumns(1), "delta", 40));
            widthsAfter = test.unit.gwidgets.Table.tJavaScriptRender.stylePixelValues(snapshot.colStyleWidths);

            testCase.verifyGreaterThan(widthsAfter(groupColumns(1)), widthsBefore(groupColumns(1)))
            testCase.verifyTrue(any(test.unit.gwidgets.Table.tJavaScriptRender.rowString( ...
                snapshot.groupHeaderColumnTransforms) == "translate(-50%, -50%) rotate(-90deg)"))
        end
    end

    methods (Static, Access = private)
        function [t, backend, fig] = createTable(testCase, data, nvp)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                data (:,:) table
                nvp.Theme (1,1) string = ""
            end

            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            if nvp.Theme ~= ""
                test.unit.gwidgets.Table.tJavaScriptRender.setFigureTheme(testCase, fig, nvp.Theme);
            end
            t = gwidgets.Table(Parent=fig, Backend="JavaScript", Data=data);
            testCase.addTeardown(@()delete(t));
            backend = t.UITable.Graphics.Backend;
        end

        function setFigureTheme(testCase, fig, theme)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                fig (1,1) matlab.ui.Figure
                theme (1,1) string {mustBeMember(theme, ["light", "dark"])}
            end

            if ~isprop(fig, "Theme")
                testCase.assumeFail("Figure themes are not available in this MATLAB release.")
            end

            fig.Theme = theme;
            drawnow()
        end

        function value = rowString(value)
            value = reshape(string(value), 1, []);
        end

        function value = rowDouble(value)
            value = reshape(double(value), 1, []);
        end

        function pixels = stylePixelValues(value)
            tokens = test.unit.gwidgets.Table.tJavaScriptRender.rowString(value);
            pixels = zeros(1, numel(tokens));
            for iToken = 1:numel(tokens)
                pixels(iToken) = str2double(erase(tokens(iToken), "px"));
            end
        end

        function text = cellText(snapshot, row, col)
            idx = test.unit.gwidgets.Table.tJavaScriptRender.cellMask(snapshot, row, col);
            text = string(snapshot.cellTexts(idx));
        end

        function color = cellBackground(snapshot, row, col)
            idx = test.unit.gwidgets.Table.tJavaScriptRender.cellMask(snapshot, row, col);
            color = string(snapshot.cellBackgroundColors(idx));
        end

        function tf = hasPair(rows, cols, row, col)
            tf = any(double(rows) == row & double(cols) == col);
        end

        function idx = cellMask(snapshot, row, col)
            idx = double(snapshot.cellRows) == row & double(snapshot.cellCols) == col;
        end

        function col = cellColumnWithText(snapshot, text)
            rows = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.cellRows);
            cols = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.cellCols);
            texts = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.cellTexts);
            idx = find(rows == 1 & texts == string(text), 1);
            if isempty(idx)
                col = double.empty(1,0);
            else
                col = cols(idx);
            end
        end

        function row = rowHeaderRow(snapshot, label)
            labels = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.rowHeaderLabels);
            rows = test.unit.gwidgets.Table.tJavaScriptRender.rowDouble(snapshot.rowHeaderRows);
            idx = find(labels == string(label), 1);
            if isempty(idx)
                row = double.empty(1,0);
            else
                row = rows(idx);
            end
        end

        function text = rowHeaderButtonText(snapshot, label)
            labels = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.rowHeaderLabels);
            buttons = test.unit.gwidgets.Table.tJavaScriptRender.rowString(snapshot.rowHeaderButtonTexts);
            idx = find(labels == string(label), 1);
            if isempty(idx)
                text = string.empty(1,0);
            else
                text = buttons(idx);
            end
        end

        function waitForSelection(t, expected)
            startTime = tic;
            while toc(startTime) < 5 && ~isequal(t.Selection, expected)
                drawnow()
            end
        end
    end
end
