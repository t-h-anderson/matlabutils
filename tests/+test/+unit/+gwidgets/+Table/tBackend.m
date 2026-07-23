classdef tBackend < matlab.unittest.TestCase
    % Tests for swappable table rendering backends.

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tDefaultBackendUsesUITable(testCase)
            t = gwidgets.Table();

            testCase.verifyEqual(t.Backend, "UITable")
            testCase.verifyInstanceOf(t.UITable.Graphics.Backend, ...
                "gwidgets.internal.table.backend.UITableBackend")
            testCase.verifyInstanceOf(t.DisplayTable, "matlab.ui.control.Table")
        end

        function tJavaScriptBackendUsesHTMLComponent(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            data = table((1:3)', ["a"; "b"; "c"], VariableNames=["Value", "Label"]);

            t = gwidgets.Table(Parent=fig, Backend="JavaScript", Data=data);

            testCase.verifyEqual(t.Backend, "JavaScript")
            testCase.verifyInstanceOf(t.UITable.Graphics.Backend, ...
                "gwidgets.internal.table.backend.JSTableBackend")
            testCase.verifyInstanceOf(t.DisplayTable, "matlab.ui.control.HTML")
            testCase.verifyEqual(t.DisplayData, data)
        end

        function tJavaScriptSelectionEventMapsRows(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            data = table((1:4)', VariableNames="Value");
            t = gwidgets.Table(Parent=fig, Backend="JavaScript", Data=data);
            backend = t.UITable.Graphics.Backend;

            t.SelectionType = "row";
            backend.handleBrowserEvent(struct( ...
                "event", "SelectionChanged", ...
                "indices", [2 1; 3 1]));

            testCase.verifyEqual(t.DisplaySelection, [2 3])
            testCase.verifyEqual(backend.Selection, [2 3])
        end

        function tJavaScriptEditEventCoercesNumericData(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            data = table([1; 2; 3], VariableNames="Value");
            t = gwidgets.Table(Parent=fig, Backend="JavaScript", Data=data);
            backend = t.UITable.Graphics.Backend;
            editEvent = [];
            t.CellEditCallback = @(~, evt)captureEdit(evt);

            backend.handleBrowserEvent(struct( ...
                "event", "CellEdited", ...
                "row", 2, ...
                "col", 1, ...
                "value", "42"));

            testCase.verifyEqual(t.Data.Value(2), 42)
            testCase.verifyEqual(editEvent.DisplayIndices, [2 1])
            testCase.verifyEqual(editEvent.PreviousData, 2)
            testCase.verifyEqual(editEvent.NewData, 42)

            function captureEdit(evt)
                editEvent = evt;
            end
        end

        function tJavaScriptSortEventUsesDisplayVariable(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            data = table([3; 1; 2], VariableNames="Value");
            t = gwidgets.Table(Parent=fig, Backend="JavaScript", Data=data);
            backend = t.UITable.Graphics.Backend;
            t.ColumnSortable = true;

            backend.handleBrowserEvent(struct( ...
                "event", "DisplayDataChanged", ...
                "interaction", "sort", ...
                "variable", "Value"));

            testCase.verifyEqual(t.Sort.By, "Value")
            testCase.verifyEqual(t.Sort.Direction, "Ascend")
            testCase.verifyEqual(t.DisplayData.Value, [1; 2; 3])
        end
    end
end
