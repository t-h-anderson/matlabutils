classdef tConstructionSetGet < test.WithExampleTables
    % Test construction and setting/getting key properties in a headless
    % table.

    methods (Test)
        
        function tCreation(testCase)
            t = testCase.verifyWarningFree(@() gwidgets.Table());
            testCase.verifyEqual(t.Data, table.empty(0,0));
        end

        function tDefaultValue(testCase)
            % Test default values that are not tested in the unit tests.
            t = testCase.verifyWarningFree(@() gwidgets.Table());

            testCase.verifyEqual(t.Multiselect, matlab.lang.OnOffSwitchState.on)
            testCase.verifyFalse(t.HasToggleFilter)
            testCase.verifyFalse(t.HasChangeGroupingVariable)
            testCase.verifyFalse(t.HasColumnSorting)
            testCase.verifyFalse(t.HasToggleShowEmptyGroups)
            testCase.verifyFalse(t.ShowRowFilter)
            testCase.verifyEqual(t.SelectionType, 'cell')
            testCase.verifyEmpty(t.CellSelectionCallback)
            testCase.verifyEmpty(t.CellClickedCallback)
            testCase.verifyEmpty(t.CellEditCallback)
            testCase.verifyEmpty(t.CellDoubleClickCallback)
            testCase.verifyEmpty(t.DisplayDataChangedCallback)
        end

        function tAssignData(testCase)
            data = testCase.stringData();
            t = gwidgets.Table(Data=data);

            testCase.verifyEqual(t.Data, data);
        end

        function tEmptyTable(testCase)
            t = gwidgets.Table(Data=table.empty(0,2));

            testCase.verifyEqual(t.Data, table.empty(0,2))
            testCase.verifyEqual(t.ColumnNames, ["Var1", "Var2"])

            t = gwidgets.Table(Data=table.empty(1,0));
            testCase.verifyEqual(t.Data, table.empty(1,0))
            testCase.verifyEqual(t.DisplayData, table.empty(1,0))
            testCase.verifyEmpty(t.ColumnNames)
        end

        function tChangeColumnNames(testCase)
            t = gwidgets.Table(Data=testCase.stringData());

            testCase.verifyEqual(t.ColumnNames, ["Var1", "Var2"])
            testCase.verifyEqual(t.VisibleColumnNames, ["Var1", "Var2"])
            testCase.verifyEqual(t.VisibleDataColumnNames, ["Var1", "Var2"])
            testCase.verifyEqual(t.DataColumnNames, ["Var1", "Var2"])

            t.ColumnNames = ["X", "Y"];

            testCase.verifyEqual(t.ColumnNames, ["X", "Y"])
            testCase.verifyEqual(t.VisibleColumnNames, ["X", "Y"])
            testCase.verifyEqual(t.VisibleDataColumnNames, ["Var1", "Var2"])
            testCase.verifyEqual(t.DataColumnNames, ["Var1", "Var2"])
        end

        function tInvalidColumnNames(testCase)
            t = gwidgets.Table(Data=testCase.stringData());
            fcn = @() t.set("ColumnNames", ["x", "y", "z"]);
            
            testCase.verifyError(fcn, "GraphicsWidgets:Table:InvalidColumnAliases")
        end

        function tChangeData(testCase)
            t = gwidgets.Table(Data=testCase.stringData());
            newdata = array2table(magic(3), VariableNames=["x", "y", "z"]);
            t.Data = newdata;

            testCase.verifyEqual(t.Data, newdata)
            testCase.verifyEqual(t.ColumnNames, ["x", "y", "z"])
            testCase.verifySize(t.ColumnVisible, [1 3])
        end

        function tChangeColumnWidth(testCase)
            % stringData has 2 columns → ColumnWidth always has 2 entries
            t = gwidgets.Table(Data=testCase.stringData());
            testCase.verifyEqual(t.ColumnWidth, {"1x", "1x"})  % uitable default

            % Numeric array — one entry per visible column
            t.ColumnWidth = [10, 20];
            testCase.verifyEqual(t.ColumnWidth, {10, 20})

            % String array
            t.ColumnWidth = ["auto", "auto"];
            testCase.verifyEqual(t.ColumnWidth, {"1x", "1x"})

            % Scalar expands to cover every visible column
            t.ColumnWidth = 10;
            testCase.verifyEqual(t.ColumnWidth, {10, 10})

            % Wrong count → error
            fn = @() set(t, "ColumnWidth", [1 2 3]);
            testCase.verifyError(fn, "GraphicsWidgets:Table:ColumnWidthSize")

            % Mixed cell
            t.ColumnWidth = {10, "auto"};
            testCase.verifyEqual(t.ColumnWidth, {10, "1x"})

            % Scalar string expands
            t.ColumnWidth = "auto";
            testCase.verifyEqual(t.ColumnWidth, {"1x", "1x"})

            % Empty restores to default (reads from display table)
            t.ColumnWidth = {};
            testCase.verifyEqual(t.ColumnWidth, {"1x", "1x"})
        end

        function tChangeColumnVisible(testCase)
            t = gwidgets.Table(Data=testCase.stringData());
            testCase.verifyEqual(t.ColumnVisible, [true, true])
            testCase.verifyEmpty(t.HiddenColumnNames)

            t.ColumnVisible = [false, false];
            testCase.verifyEqual(t.ColumnVisible, [false, false])
            testCase.verifyEqual(t.HiddenColumnNames, ["Var1", "Var2"])

            t.ColumnVisible = [true, true];
            testCase.verifyEmpty(t.HiddenColumnNames)

            t.set("ColumnVisible", true);
            testCase.verifyEqual(t.ColumnVisible, [true, true]);
            
            fcn = @() t.set("ColumnVisible", [true false true]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:InvalidColumnVisibility")
        end

        function tMultipleDataTypes(testCase)
            % Store a table with a mixed dataset.
            data = testCase.complexData();
            t = gwidgets.Table(Data=data);
            testCase.verifyEqual(t.Data, data)
            testCase.verifyEqual(t.DisplayTable.Data, data)
        end

        function tChangeColumnEditable(testCase)
            data = testCase.stringData();
            t = gwidgets.Table(Data=data);

            t.ColumnEditable = [false, true];
            testCase.verifyEqual(t.DisplayTable.ColumnEditable, [false, true])

            t.ColumnEditable = false;
            testCase.verifyEqual(t.DisplayTable.ColumnEditable, [false, false])

            fn = @() set(t, "ColumnEditable", [false, true, false]);
            testCase.verifyError(fn, "GraphicsWidgets:Table:ColumnEditableSize")
        end

    end

end