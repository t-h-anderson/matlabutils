classdef tSelectionParity < test.WithExampleTables
    % Selection behaviour that both table backends must satisfy.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (Test)
        function tDefaultSelectionState(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);

            testCase.verifyEqual(t.SelectionType, 'cell')
            testCase.verifyEqual(t.Selection, zeros(0,2))
            testCase.verifyEqual(t.DisplaySelection, zeros(0,2))
            testCase.verifyEqual(testCase.backendSelection(t), zeros(0,2))
        end

        function tProgrammaticCellSelection(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);

            t.Selection = [2 2];

            testCase.verifyEqual(t.Selection, [2 2])
            testCase.verifyEqual(t.DisplaySelection, [2 2])
            testCase.verifyEqual(testCase.backendSelection(t), [2 2])
        end

        function tProgrammaticRowSelection(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);
            t.SelectionType = "row";

            t.Selection = [2 4];

            testCase.verifyEqual(t.Selection, [2 4])
            testCase.verifyEqual(t.DisplaySelection, [2 4])
            testCase.verifyEqual(testCase.backendSelection(t), [2 4])
        end

        function tProgrammaticColumnSelection(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);
            t.SelectionType = "column";

            t.Selection = [1 3];

            testCase.verifyEqual(t.Selection, [1 3])
            testCase.verifyEqual(t.DisplaySelection, [1 3])
            testCase.verifyEqual(testCase.backendSelection(t), [1 3])
        end

        function tHiddenColumnsMapDataSelection(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);
            t.ColumnVisible = [true false true true];

            t.Selection = [2 3];

            testCase.verifyEqual(t.Selection, [2 3])
            testCase.verifyEqual(t.DisplaySelection, [2 2])
            testCase.verifyEqual(testCase.backendSelection(t), [2 2])
        end

        function tSelectionAfterFilterSort(testCase, Backend)
            data = table( ...
                [3; 1; 4; 2], ...
                ["three"; "one"; "four"; "two"], ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend, data);

            t.Filter = "Value>1";
            t.ColumnSortable = true;
            t.Sort.By = "Value";
            t.Sort.Direction = "Ascend";
            t.Selection = [4 1];

            testCase.verifyEqual(t.Selection, [4 1])
            testCase.verifyEqual(t.DisplaySelection, [1 1])
            testCase.verifyEqual(testCase.backendSelection(t), [1 1])
            testCase.verifyBrowserSelection(t, [1 1])
        end

        function tSelectionEventMapsCells(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);

            testCase.simulateBackendSelection(t, [4 2]);

            testCase.verifyEqual(t.Selection, [4 2])
            testCase.verifyEqual(t.DisplaySelection, [4 2])
            testCase.verifyEqual(testCase.backendSelection(t), [4 2])
        end

        function tSelectionEventMapsRows(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);
            t.SelectionType = "row";

            testCase.simulateBackendSelection(t, [2 1; 4 1]);

            testCase.verifyEqual(t.Selection, [2 4])
            testCase.verifyEqual(t.DisplaySelection, [2 4])
            testCase.verifyEqual(testCase.backendSelection(t), [2 4])
        end

        function tSelectionEventMapsColumns(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);
            t.SelectionType = "column";

            testCase.simulateBackendSelection(t, [1 2; 1 4]);

            testCase.verifyEqual(t.Selection, [2 4])
            testCase.verifyEqual(t.DisplaySelection, [2 4])
            testCase.verifyEqual(testCase.backendSelection(t), [2 4])
        end

        function tClickSelectsCellThroughBackend(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);

            testCase.clickDisplayCell(t, 4, 2);

            testCase.verifyEqual(t.Selection, [4 2])
            testCase.verifyEqual(t.DisplaySelection, [4 2])
            testCase.verifyEqual(testCase.backendSelection(t), [4 2])
            testCase.verifyBrowserSelection(t, [4 2])
        end

        function tCtrlClickAddsCellThroughBackend(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);

            testCase.clickDisplayCell(t, 2, 1);
            testCase.clickDisplayCell(t, 4, 3, Ctrl=true);

            expected = [2 1; 4 3];
            testCase.verifyEqual(t.Selection, expected)
            testCase.verifyEqual(t.DisplaySelection, expected)
            testCase.verifyEqual(testCase.backendSelection(t), expected)
            testCase.verifyBrowserSelection(t, expected)
        end

        function tClickSelectsRowThroughBackend(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);
            t.SelectionType = "row";

            testCase.clickDisplayCell(t, 4, 2);

            testCase.verifyEqual(t.Selection, 4)
            testCase.verifyEqual(t.DisplaySelection, 4)
            testCase.verifyEqual(testCase.backendSelection(t), 4)
            testCase.verifyBrowserSelection(t, 4)
        end

        function tCtrlClickAddsRowThroughBackend(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);
            t.SelectionType = "row";

            testCase.clickDisplayCell(t, 2, 1);
            testCase.clickDisplayCell(t, 4, 1, Ctrl=true);

            testCase.verifyEqual(t.Selection, [2 4])
            testCase.verifyEqual(t.DisplaySelection, [2 4])
            testCase.verifyEqual(testCase.backendSelection(t), [2 4])
            testCase.verifyBrowserSelection(t, [2 4])
        end

        function tClickSelectsColumnThroughBackend(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);
            t.SelectionType = "column";

            testCase.clickDisplayCell(t, 2, 3);

            testCase.verifyEqual(t.Selection, 3)
            testCase.verifyEqual(t.DisplaySelection, 3)
            testCase.verifyEqual(testCase.backendSelection(t), 3)
            testCase.verifyBrowserSelection(t, 3)
        end

        function tVirtualizedRowClickSelectsRenderedCell(testCase, Backend)
            data = table( ...
                (1:200)', ...
                "row_" + string((1:200)'), ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend, data);

            testCase.scrollToDisplayRow(t, 180);
            testCase.clickDisplayCell(t, 180, 1);

            testCase.verifyEqual(t.Selection, [180 1])
            testCase.verifyEqual(t.DisplaySelection, [180 1])
            testCase.verifyEqual(testCase.backendSelection(t), [180 1])
            testCase.verifyBrowserSelection(t, [180 1])
        end

        function tMultiselectOffRejectsMultipleCells(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);
            t.Multiselect = "off";

            testCase.verifyError( ...
                @()set(t, "Selection", [2 2; 4 1]), ...
                "GraphicsWidgets:Table:InvalidSingleSelection")
            testCase.verifyEqual(t.Selection, zeros(0,2))
            testCase.verifyEqual(testCase.backendSelection(t), zeros(0,2))
        end

        function tChangingSelectionTypeClearsSelection(testCase, Backend)
            t = test.unit.gwidgets.Table.tSelectionParity.createTable(testCase, Backend);
            t.Selection = [2 2];

            t.SelectionType = "row";

            testCase.verifyEqual(t.Selection, zeros(1,0))
            testCase.verifyEqual(t.DisplaySelection, zeros(1,0))
            testCase.verifyEqual(testCase.backendSelection(t), zeros(1,0))
        end
    end

    methods
        function selection = backendSelection(testCase, t)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tSelectionParity %#ok<INUSA>
                t (1,1) gwidgets.Table
            end

            selection = t.UITable.Graphics.Backend.Selection;
            if isempty(selection)
                selection = gwidgets.internal.table.SelectionController.emptySelection(string(t.SelectionType));
            end
        end

        function simulateBackendSelection(testCase, t, indices)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tSelectionParity
                t (1,1) gwidgets.Table
                indices (:,2) double
            end

            switch t.Backend
                case "JavaScript"
                    t.UITable.Graphics.Backend.handleBrowserEvent(struct( ...
                        "event", "SelectionChanged", ...
                        "indices", indices));
                otherwise
                    source = struct("SelectionType", char(t.SelectionType));
                    eventData = struct("Indices", indices);
                    t.UITable.Callback.onSelection(source, eventData);
            end
            testCase.verifyEqual(string(t.SelectionType), string(t.UITable.Graphics.Backend.SelectionType))
        end

        function clickDisplayCell(testCase, t, row, col, nvp)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tSelectionParity
                t (1,1) gwidgets.Table
                row (1,1) double
                col (1,1) double
                nvp.Ctrl (1,1) logical = false
            end

            switch t.Backend
                case "JavaScript"
                    t.UITable.Graphics.Backend.probeBrowser("ClickCell", struct( ...
                        "row", row, ...
                        "col", col, ...
                        "ctrlKey", nvp.Ctrl));
                otherwise
                    indices = testCase.selectionIndicesAfterClick(t, row, col, Ctrl=nvp.Ctrl);
                    testCase.simulateBackendSelection(t, indices);
            end
        end

        function scrollToDisplayRow(testCase, t, row)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tSelectionParity %#ok<INUSA>
                t (1,1) gwidgets.Table
                row (1,1) double
            end

            if t.Backend == "JavaScript"
                t.UITable.Graphics.Backend.probeBrowser("ScrollToRow", struct("row", row));
            end
        end

        function indices = selectionIndicesAfterClick(~, t, row, col, nvp)
            arguments
                ~
                t (1,1) gwidgets.Table
                row (1,1) double
                col (1,1) double
                nvp.Ctrl (1,1) logical = false
            end

            allowMulti = nvp.Ctrl && string(t.Multiselect) ~= "off";
            switch string(t.SelectionType)
                case "row"
                    rows = row;
                    if allowMulti
                        rows = toggleLinearSelection(reshape(t.DisplaySelection, 1, []), row);
                    end
                    indices = [rows(:), repelem(col, numel(rows), 1)];
                case "column"
                    cols = col;
                    if allowMulti
                        cols = toggleLinearSelection(reshape(t.DisplaySelection, 1, []), col);
                    end
                    indices = [repelem(row, numel(cols), 1), cols(:)];
                otherwise
                    indices = [row col];
                    if allowMulti
                        indices = toggleCellSelection(t.DisplaySelection, indices);
                    end
            end
        end

        function verifyBrowserSelection(testCase, t, expected)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tSelectionParity
                t (1,1) gwidgets.Table
                expected double
            end

            if t.Backend ~= "JavaScript"
                return
            end

            snapshot = t.UITable.Graphics.Backend.probeBrowser("Snapshot");
            switch string(t.SelectionType)
                case "row"
                    actual = reshape(double(snapshot.selectedRows), 1, []);
                    testCase.verifyEqual(sort(actual), sort(reshape(expected, 1, [])))
                case "column"
                    actual = reshape(double(snapshot.selectedColumns), 1, []);
                    testCase.verifyEqual(sort(actual), sort(reshape(expected, 1, [])))
                otherwise
                    actual = [double(snapshot.selectedCellRows(:)), double(snapshot.selectedCellCols(:))];
                    testCase.verifyEqual(sortrows(actual), sortrows(expected))
            end
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

function values = toggleLinearSelection(values, value)
    arguments
        values (1,:) double
        value (1,1) double
    end

    if any(values == value)
        values(values == value) = [];
    else
        values(end+1) = value;
    end
end

function pairs = toggleCellSelection(pairs, pair)
    arguments
        pairs (:,2) double
        pair (1,2) double
    end

    isSelected = pairs(:,1) == pair(1) & pairs(:,2) == pair(2);
    if any(isSelected)
        pairs(isSelected, :) = [];
    else
        pairs(end+1, :) = pair;
    end
end
