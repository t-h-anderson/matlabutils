classdef tDisplayTransformParity < matlab.unittest.TestCase
    % Combined display transforms that both table backends must render.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tFilterSortHiddenColumnsRenderCells(testCase, Backend)
            data = table( ...
                [3; 1; 4; 2], ...
                ["B"; "A"; "B"; "A"], ...
                ["gamma"; "alpha"; "delta"; "beta"], ...
                VariableNames=["Value", "Group", "Label"]);
            t = test.unit.gwidgets.Table.tDisplayTransformParity.createTable(testCase, Backend, data);

            t.HiddenColumnNames = "Group";
            t.Filter = "Value>1";
            t.ColumnSortable = true;
            t.Sort.By = "Value";
            t.Sort.Direction = "Ascend";

            testCase.verifyEqual(testCase.renderedHeaderTexts(t), ["Value", "Label"])
            testCase.verifyRenderedRowsMatchBackend(t, 1:height(t.UITable.Graphics.Backend.Data))
        end

        function tGroupedFilterSortOpenRowsRenderCells(testCase, Backend)
            data = table( ...
                ["B"; "A"; "A"; "B"; "C"; "A"], ...
                [3; 1; 4; 2; 5; 6], ...
                ["b3"; "a1"; "a4"; "b2"; "c5"; "a6"], ...
                VariableNames=["Group", "Value", "Label"]);
            t = test.unit.gwidgets.Table.tDisplayTransformParity.createTable(testCase, Backend, data);

            t.Filter = "Value>1";
            t.GroupingVariable = "Group";
            t.ColumnSortable = true;
            t.Sort.By = "Value";
            t.Sort.Direction = "Ascend";
            t.OpenGroups = t.DisplayGroups;

            groupRows = t.UITable.Data.VisibleGroupHeaderRowIdx;
            displayRows = setdiff(1:height(t.UITable.Graphics.Backend.Data), groupRows);

            testCase.verifyRenderedRowsMatchBackend(t, displayRows)
            testCase.verifyEqual(testCase.renderedGroupLabels(t), testCase.expectedGroupLabels(t))
        end

        function tVirtualFilteredSortedRowRenders(testCase, Backend)
            data = table( ...
                (1:240)', ...
                "row_" + string((1:240)'), ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tDisplayTransformParity.createTable(testCase, Backend, data);

            t.Filter = "Value>40";
            t.ColumnSortable = true;
            t.Sort.By = "Value";
            t.Sort.Direction = "Descend";

            displayRow = 120;
            testCase.scrollToDisplayRow(t, displayRow);

            testCase.verifyRenderedRowsMatchBackend(t, displayRow)
        end
    end

    methods
        function verifyRenderedRowsMatchBackend(testCase, t, rows)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tDisplayTransformParity
                t (1,1) gwidgets.Table
                rows (1,:) double
            end

            for iRow = 1:numel(rows)
                row = rows(iRow);
                for col = 1:width(t.UITable.Graphics.Backend.Data)
                    testCase.verifyEqual( ...
                        testCase.renderedCellText(t, row, col), ...
                        testCase.backendCellText(t, row, col), ...
                        sprintf("Display row %d column %d did not match.", row, col))
                end
            end
        end

        function text = renderedHeaderTexts(~, t)
            arguments
                ~
                t (1,1) gwidgets.Table
            end

            switch t.Backend
                case "JavaScript"
                    snapshot = t.UITable.Graphics.Backend.probeBrowser("Snapshot");
                    text = reshape(string(snapshot.headerTexts), 1, []);
                otherwise
                    text = reshape(string(t.UITable.Graphics.Backend.ColumnName), 1, []);
            end
        end

        function text = renderedCellText(testCase, t, row, col)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tDisplayTransformParity
                t (1,1) gwidgets.Table
                row (1,1) double
                col (1,1) double
            end

            switch t.Backend
                case "JavaScript"
                    snapshot = t.UITable.Graphics.Backend.probeBrowser("Snapshot");
                    mask = double(snapshot.cellRows) == row & double(snapshot.cellCols) == col;
                    testCase.assertTrue(any(mask), sprintf("Cell [%d %d] was not rendered.", row, col))
                    text = string(snapshot.cellTexts(mask));
                otherwise
                    text = testCase.backendCellText(t, row, col);
            end
        end

        function text = backendCellText(testCase, t, row, col)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tDisplayTransformParity
                t (1,1) gwidgets.Table
                row (1,1) double
                col (1,1) double
            end

            data = t.UITable.Graphics.Backend.Data;
            text = testCase.valueText(data{row, col});
        end

        function labels = renderedGroupLabels(testCase, t)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tDisplayTransformParity
                t (1,1) gwidgets.Table
            end

            switch t.Backend
                case "JavaScript"
                    snapshot = t.UITable.Graphics.Backend.probeBrowser("Snapshot");
                    labels = reshape(string(snapshot.groupHeaderLabels), 1, []);
                otherwise
                    labels = testCase.expectedGroupLabels(t);
            end
        end

        function labels = expectedGroupLabels(testCase, t)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tDisplayTransformParity %#ok<INUSA>
                t (1,1) gwidgets.Table
            end

            payload = gwidgets.internal.table.BridgeController.groupHeaderSpanPayload( ...
                t.UITable.Graphics.Backend.Data, ...
                t.UITable.Data.VisibleGroupHeaderRowIdx);
            labels = reshape(string(payload.labels), 1, []);
        end

        function scrollToDisplayRow(testCase, t, row)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tDisplayTransformParity %#ok<INUSA>
                t (1,1) gwidgets.Table
                row (1,1) double
            end

            if t.Backend == "JavaScript"
                t.UITable.Graphics.Backend.probeBrowser("ScrollToRow", struct("row", row));
            end
        end

        function text = valueText(testCase, value)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tDisplayTransformParity %#ok<INUSA>
                value
            end

            if iscell(value) && isscalar(value)
                value = value{1};
            end

            if ismissing(value)
                text = "";
            elseif isstring(value) || ischar(value) || isnumeric(value) || islogical(value) || iscategorical(value)
                text = string(value);
            else
                text = string(value);
            end
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
