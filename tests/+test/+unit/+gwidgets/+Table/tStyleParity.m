classdef tStyleParity < matlab.unittest.TestCase
    % Style mapping that both table backends must satisfy.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tCellStyleAfterFilterSort(testCase, Backend)
            data = table( ...
                [3; 1; 4; 2], ...
                ["three"; "one"; "four"; "two"], ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tStyleParity.createTable(testCase, Backend, data);

            t.addStyle(uistyle(BackgroundColor=[1 0 0]), "cell", [4 1]);
            t.Filter = "Value>1";
            t.ColumnSortable = true;
            t.Sort.By = "Value";
            t.Sort.Direction = "Ascend";

            testCase.verifyStyleIndex(t, "cell", [1 1])
            testCase.verifyRenderedBackground(t, 1, 1, "rgb(255,0,0)")
        end

        function tColumnStyleAfterHiddenColumn(testCase, Backend)
            data = table( ...
                [1; 2], ...
                ["A"; "B"], ...
                ["one"; "two"], ...
                VariableNames=["Value", "Group", "Label"]);
            t = test.unit.gwidgets.Table.tStyleParity.createTable(testCase, Backend, data);

            t.addStyle(uistyle(FontColor=[0 0 1]), "column", 3);
            t.HiddenColumnNames = "Group";

            testCase.verifyStyleIndex(t, "column", 2)
            testCase.verifyRenderedFontColor(t, 1, 2, "rgb(0,0,255)")
        end

        function tTransposedCellStyleUsesLogicalCell(testCase, Backend)
            data = table( ...
                [10; 20], ...
                ["A"; "B"], ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tStyleParity.createTable(testCase, Backend, data);
            t.DisplayOrientation = "Transposed";

            t.addStyle(uistyle(BackgroundColor=[1 0 0]), "cell", [2 1]);

            testCase.verifyStyleIndex(t, "cell", [1 3])
            testCase.verifyRenderedBackground(t, 1, 3, "rgb(255,0,0)")
        end

        function tTransposedRowStyleUsesLogicalRow(testCase, Backend)
            data = table( ...
                [10; 20], ...
                ["A"; "B"], ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tStyleParity.createTable(testCase, Backend, data);
            t.DisplayOrientation = "Transposed";

            t.addStyle(uistyle(FontColor=[0 0 1]), "row", 2);

            testCase.verifyStyleIndex(t, "column", 3)
            testCase.verifyRenderedFontColor(t, 1, 3, "rgb(0,0,255)")
        end
    end

    methods
        function verifyStyleIndex(testCase, t, target, expected)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tStyleParity
                t (1,1) gwidgets.Table
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])}
                expected double
            end

            configs = t.UITable.Graphics.Backend.StyleConfigurations;
            match = string(configs.Target) == target;
            testCase.assertTrue(any(match))
            testCase.verifyEqual(configs.TargetIndex{find(match, 1)}, expected)
        end

        function verifyRenderedBackground(testCase, t, row, col, expected)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tStyleParity
                t (1,1) gwidgets.Table
                row (1,1) double
                col (1,1) double
                expected (1,1) string
            end

            if t.Backend ~= "JavaScript"
                return
            end

            snapshot = t.UITable.Graphics.Backend.probeBrowser("Snapshot");
            color = testCase.cellSnapshotValue(snapshot, "cellBackgroundColors", row, col);
            testCase.verifyEqual(testCase.compactCssColor(color), expected)
        end

        function verifyRenderedFontColor(testCase, t, row, col, expected)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tStyleParity
                t (1,1) gwidgets.Table
                row (1,1) double
                col (1,1) double
                expected (1,1) string
            end

            if t.Backend ~= "JavaScript"
                return
            end

            snapshot = t.UITable.Graphics.Backend.probeBrowser("Snapshot");
            color = testCase.cellSnapshotValue(snapshot, "cellColors", row, col);
            testCase.verifyEqual(testCase.compactCssColor(color), expected)
        end

        function value = cellSnapshotValue(testCase, snapshot, fieldName, row, col)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tStyleParity
                snapshot (1,1) struct
                fieldName (1,1) string
                row (1,1) double
                col (1,1) double
            end

            mask = double(snapshot.cellRows) == row & double(snapshot.cellCols) == col;
            testCase.assertTrue(any(mask), sprintf("Cell [%d %d] was not rendered.", row, col))
            values = snapshot.(fieldName);
            value = string(values(mask));
        end

        function color = compactCssColor(testCase, color)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tStyleParity %#ok<INUSA>
                color (1,1) string
            end

            color = erase(color, " ");
        end
    end

    methods (Static, Access = private)
        function t = createTable(testCase, backend, data)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                backend (1,1) string
                data (:,:) table
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
