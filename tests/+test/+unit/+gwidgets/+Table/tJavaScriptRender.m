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

        function tClickHeaderSortsSortableColumn(testCase)
            data = table([3; 1; 2], VariableNames="Value");
            [t, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable(testCase, data);
            t.ColumnSortable = true;

            backend.probeBrowser("ClickHeader", struct("col", 1));

            testCase.verifyEqual(t.Sort.By, "Value")
            testCase.verifyEqual(t.Sort.Direction, "Ascend")
            testCase.verifyEqual(t.DisplayData.Value, [1; 2; 3])
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

        function tUsesFigureThemeStatus(testCase)
            data = table([1; 2], VariableNames="Value");
            [~, backend] = test.unit.gwidgets.Table.tJavaScriptRender.createTable( ...
                testCase, data, Theme="dark");

            snapshot = backend.probeBrowser("Snapshot");

            testCase.verifyEqual(string(snapshot.theme), "dark")
            testCase.verifyNotEqual(string(snapshot.tableBackgroundColor), "rgb(255, 255, 255)")
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
    end
end
