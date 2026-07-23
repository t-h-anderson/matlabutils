classdef tEditingParity < matlab.unittest.TestCase
    % Cell-edit behaviour that both table backends must satisfy.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (Test)
        function tNumericEditUpdatesData(testCase, Backend)
            data = table([1; 2; 3], VariableNames="Value");
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = true;
            editEvent = [];
            t.CellEditCallback = @(~, evt)captureEdit(evt);

            testCase.simulateBackendEdit(t, [2 1], 42);

            testCase.verifyEqual(t.Data.Value(2), 42)
            testCase.verifyEqual(editEvent.DisplayIndices, [2 1])
            testCase.verifyEqual(editEvent.PreviousData, 2)
            testCase.verifyEqual(editEvent.NewData, 42)

            function captureEdit(evt)
                editEvent = evt;
            end
        end

        function tStringEditUpdatesHiddenColumnMapping(testCase, Backend)
            data = table([1; 2; 3], ["a"; "b"; "c"], VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = true;
            t.ColumnVisible = [false true];

            testCase.simulateBackendEdit(t, [2 1], "z");

            testCase.verifyEqual(t.Data.Label(2), "z")
            testCase.verifyEqual(t.Data.Value, [1; 2; 3])
        end

        function tLogicalEditCoercesValue(testCase, Backend)
            data = table([true; false; false], VariableNames="Flag");
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = true;

            testCase.simulateBackendEdit(t, [2 1], true);

            testCase.verifyEqual(t.Data.Flag, [true; true; false])
        end

        function tSortedDisplayEditMapsToSourceRow(testCase, Backend)
            data = table([3; 1; 2], VariableNames="Value");
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = true;
            t.ColumnSortable = true;
            t.Sort.By = "Value";
            t.Sort.Direction = "Ascend";

            testCase.simulateBackendEdit(t, [1 1], 10);

            testCase.verifyEqual(t.Data.Value, [3; 10; 2])
            testCase.verifyEqual(t.DisplayData.Value, [2; 3; 10])
        end
    end

    methods
        function simulateBackendEdit(testCase, t, displayIdx, newData)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tEditingParity
                t (1,1) gwidgets.Table
                displayIdx (1,2) double
                newData
            end

            switch t.Backend
                case "JavaScript"
                    t.UITable.Graphics.Backend.handleBrowserEvent(struct( ...
                        "event", "CellEdited", ...
                        "row", displayIdx(1), ...
                        "col", displayIdx(2), ...
                        "value", string(newData)));
                otherwise
                    previousData = t.DisplayData{displayIdx(1), displayIdx(2)};
                    editEvent = struct( ...
                        "Indices", displayIdx, ...
                        "DisplayIndices", displayIdx, ...
                        "PreviousData", previousData, ...
                        "EditData", newData, ...
                        "NewData", newData);
                    t.UITable.Callback.onCellEdit([], editEvent);
            end
            testCase.verifyEqual(string(t.Backend), string(t.UITable.Backend))
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
            t = gwidgets.Table(Parent=fig, Backend=backend, Data=data);
            testCase.addTeardown(@()delete(t));
        end
    end
end
