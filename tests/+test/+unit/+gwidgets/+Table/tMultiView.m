classdef tMultiView < matlab.unittest.TestCase
    % Internal tests for one table presenter driving multiple views.

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tAttachViewSynchronizesCurrentState(testCase)
            [t, jsView] = test.unit.gwidgets.Table.tMultiView.createDualViewTable(testCase);

            testCase.verifyEqual(t.UITable.Graphics.views(), ["primary", "js"])
            testCase.verifyEqual(jsView.Data, t.DisplayData)
            testCase.verifyEqual(reshape(string(jsView.ColumnName), 1, []), ...
                reshape(string(t.UITable.Graphics.Backend.ColumnName), 1, []))
            testCase.verifyEqual(jsView.SelectionType, t.UITable.Graphics.Backend.SelectionType)
        end

        function tProgrammaticUpdatesRenderInBothViews(testCase)
            [t, jsView] = test.unit.gwidgets.Table.tMultiView.createDualViewTable(testCase);

            t.ColumnNames = ["Number", "Label"];
            t.ColumnEditable = [true false];
            t.ColumnWidth = {120, "2x"};
            t.Selection = [2 1];
            style = uistyle(BackgroundColor=[1 0 0]);
            t.addStyle(style, "cell", [1 1]);

            primary = t.UITable.Graphics.Backend;
            testCase.verifyEqual(primary.Data, jsView.Data)
            testCase.verifyEqual( ...
                reshape(string(primary.ColumnName), 1, []), ...
                reshape(string(jsView.ColumnName), 1, []))
            testCase.verifyEqual(primary.ColumnEditable, jsView.ColumnEditable)
            testCase.verifyEqual( ...
                gwidgets.Table.normalizeColumnWidths(primary.ColumnWidth), ...
                gwidgets.Table.normalizeColumnWidths(jsView.ColumnWidth))
            testCase.verifyEqual(primary.Selection, [2 1])
            testCase.verifyEqual(jsView.Selection, [2 1])
            testCase.verifyEqual( ...
                test.unit.gwidgets.Table.tMultiView.withoutRowNames(primary.StyleConfigurations), ...
                test.unit.gwidgets.Table.tMultiView.withoutRowNames(jsView.StyleConfigurations))
        end

        function tMatlabSelectionUpdatesJavaScriptView(testCase)
            [t, jsView] = test.unit.gwidgets.Table.tMultiView.createDualViewTable(testCase);
            source = struct("SelectionType", "cell", "ViewId", "primary");
            eventData = struct("Indices", [2 1]);

            t.UITable.Callback.onSelection(source, eventData);

            testCase.verifyEqual(t.Selection, [2 1])
            testCase.verifyEqual(jsView.Selection, [2 1])
        end

        function tJavaScriptSelectionUpdatesMatlabView(testCase)
            [t, jsView] = test.unit.gwidgets.Table.tMultiView.createDualViewTable(testCase);

            jsView.handleBrowserEvent(struct( ...
                "event", "SelectionChanged", ...
                "indices", [3 2]));

            testCase.verifyEqual(t.Selection, [3 2])
            testCase.verifyEqual(t.UITable.Graphics.Backend.Selection, [3 2])
        end

        function tJavaScriptEditUpdatesCanonicalDataAndBothViews(testCase)
            [t, jsView] = test.unit.gwidgets.Table.tMultiView.createDualViewTable(testCase);
            t.ColumnEditable = [true false];

            jsView.handleBrowserEvent(struct( ...
                "event", "CellEdited", ...
                "row", 2, ...
                "col", 1, ...
                "value", "42"));

            testCase.verifyEqual(t.Data.Value(2), 42)
            testCase.verifyEqual(t.UITable.Graphics.Backend.Data.Value(2), 42)
            testCase.verifyEqual(jsView.Data.Value(2), 42)
        end

        function tProgrammaticSelectionDoesNotFireUserCallback(testCase)
            [t, jsView] = test.unit.gwidgets.Table.tMultiView.createDualViewTable(testCase);
            callbackCount = 0;
            t.CellSelectionCallback = @(~, ~)incrementCallbackCount();

            jsView.handleBrowserEvent(struct( ...
                "event", "SelectionChanged", ...
                "indices", [2 1]));
            t.Selection = [1 1];

            testCase.verifyEqual(callbackCount, 1)

            function incrementCallbackCount()
                callbackCount = callbackCount + 1;
            end
        end

        function tAttachedJavaScriptViewReceivesCurrentContextActions(testCase)
            t = test.unit.gwidgets.Table.tMultiView.createTable(testCase);
            t.HasToggleFilter = true;
            jsView = t.UITable.Graphics.attachView("js", "JavaScript");

            jsView.handleBrowserEvent(struct( ...
                "event", "ContextMenuAction", ...
                "action", "ToggleRowFilter"));

            testCase.verifyTrue(t.ShowRowFilter)
        end

        function tAttachViewReturnsPositionableComponent(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            gl = uigridlayout(fig, [1,3]);
            data = table([1; 2; 3], ["a"; "b"; "c"], VariableNames=["Value", "Label"]);
            t = gwidgets.Table(Parent=gl, Data=data);
            testCase.addTeardown(@()delete(t));

            matlabView = t.UITable.Graphics.attachView("matlab", "UITable", gl);
            matlabView.Component.Layout.Row = 1;
            matlabView.Component.Layout.Column = 2;

            jsView = t.UITable.Graphics.attachView("js", "JavaScript", gl);
            jsView.Component.Layout.Row = 1;
            jsView.Component.Layout.Column = 3;

            testCase.verifyInstanceOf(matlabView, "gwidgets.internal.table.view.TableView")
            testCase.verifyInstanceOf(jsView, "gwidgets.internal.table.view.TableView")
            testCase.verifyInstanceOf(matlabView.Component, "matlab.ui.control.Table")
            testCase.verifyInstanceOf(jsView.Component, "matlab.ui.control.HTML")
            testCase.verifyEqual(matlabView.Component.Layout.Column, 2)
            testCase.verifyEqual(jsView.Component.Layout.Column, 3)
            testCase.verifyEqual(jsView.Data, t.DisplayData)
        end
    end

    methods (Static, Access = private)
        function [t, jsView] = createDualViewTable(testCase)
            arguments
                testCase (1,1) matlab.unittest.TestCase
            end

            t = test.unit.gwidgets.Table.tMultiView.createTable(testCase);
            jsView = t.UITable.Graphics.attachView("js", "JavaScript");
        end

        function t = createTable(testCase)
            arguments
                testCase (1,1) matlab.unittest.TestCase
            end

            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            data = table([1; 2; 3], ["a"; "b"; "c"], VariableNames=["Value", "Label"]);
            t = gwidgets.Table(Parent=fig, Data=data);
            testCase.addTeardown(@()delete(t));
        end

        function configs = withoutRowNames(configs)
            arguments
                configs (:,3) table
            end

            configs.Properties.RowNames = {};
        end
    end
end
