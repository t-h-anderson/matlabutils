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
    end

    methods (Static, Access = private)
        function t = createTable(testCase, backend)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                backend (1,1) string
            end

            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            t = gwidgets.Table( ...
                Parent=fig, ...
                Backend=backend, ...
                Data=test.WithExampleTables.multivariableData());
            testCase.addTeardown(@()delete(t));
        end
    end
end
