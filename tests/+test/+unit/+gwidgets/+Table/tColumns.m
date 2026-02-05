classdef tColumns < test.WithExampleTables
    % Test hiding columns and applying column aliases in a headless table.

    methods (Test)

        function tUnHiddenColumnNames(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            testCase.verifyEmpty(t.HiddenColumnNames)
            testCase.verifyEqual(t.ColumnVisible, [true true true true])
            testCase.verifyEqual(t.VisibleColumnNames, ...
                ["Numerical", "Categorical", "Logical", "String"])
            testCase.verifyEmpty(t.HiddenColumnNames)
        end

        function tSetSingleHiddenColumn(testCase)
            % Hide a single column by setting 'HiddenColumnNames'
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.HiddenColumnNames = "Categorical";

            testCase.verifyEqual(t.HiddenColumnNames, "Categorical")
            testCase.verifyEqual(t.VisibleColumnNames, ["Numerical", "Logical", "String"])
            testCase.verifyEqual(t.ColumnVisible, [true false true true])
            testCase.verifyEqual(string(t.DisplayData.Properties.VariableNames), ...
                ["Numerical", "Logical", "String"])
        end

        function tSetDisplayColumns(testCase)
            % Hide a single column by setting 'DisplayColumns'
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.VisibleColumnNames = ["Numerical", "Logical", "String"];

            testCase.verifyEqual(t.HiddenColumnNames, "Categorical")
            testCase.verifyEqual(t.VisibleColumnNames, ["Numerical", "Logical", "String"])
            testCase.verifyEqual(t.ColumnVisible, [true false true true])
            testCase.verifyEqual(string(t.DisplayTable.Data.Properties.VariableNames), ...
                ["Numerical", "Logical", "String"])
        end

        function tHideSingleColumnByIndex(testCase)
            % Hide a single column by setting 'ColumnVisible'
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.ColumnVisible = [true false true true];

            testCase.verifyEqual(t.HiddenColumnNames, "Categorical")
            testCase.verifyEqual(t.VisibleColumnNames, ["Numerical", "Logical", "String"])
            testCase.verifyEqual(t.ColumnVisible, [true false true true])
            testCase.verifyEqual(string(t.DisplayTable.Data.Properties.VariableNames), ...
                ["Numerical", "Logical", "String"])
        end

        function tHideMultipleColumns(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.HiddenColumnNames = ["String", "Numerical"];

            testCase.verifyEqual(t.HiddenColumnNames, ["Numerical", "String"])
            testCase.verifyEqual(t.VisibleColumnNames, ["Categorical", "Logical"])
            testCase.verifyEqual(t.ColumnVisible, [false true true false])
            testCase.verifyEqual(string(t.DisplayTable.Data.Properties.VariableNames), ...
                ["Categorical", "Logical"])
        end

        function tInvalidHiddenColumnNames(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            fcn = @() t.set("HiddenColumnNames", "NonExistentColumn");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:NonexistentColumnName")
        end

        function tInvalidDisplayColumns(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            fcn = @() t.set("ColumnVisible", [-1,Inf]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:InvalidColumnVisibility")
        end

        function tInvalidColumnVisible(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            fcn = @() t.set("ColumnVisible", [true false]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:InvalidColumnVisibility")
        end

        function tHideAllColumns(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.ColumnVisible = [false false false false];

            testCase.verifyEqual(t.HiddenColumnNames, ["Numerical", "Categorical", "Logical", "String"])
            testCase.verifyEmpty(t.VisibleColumnNames)
            testCase.verifyEqual(t.ColumnVisible, [false false false false])
            testCase.verifyEmpty(t.DisplayData)
        end

        function tEmptyTable(testCase)
            t = gwidgets.Table(Data=table.empty(0,2));
            t.VisibleColumnNames = "Var2";

            testCase.verifyEqual(t.HiddenColumnNames, "Var1")
            testCase.verifyEqual(t.VisibleColumnNames, "Var2")
            testCase.verifyEqual(t.ColumnVisible, [false true])

            expected = table.empty(0,1);
            expected.Properties.VariableNames = "Var2";
            testCase.verifyEqual(t.DisplayData, expected);
            
            t = gwidgets.Table(Data=table.empty(0,0));
            testCase.verifyEmpty(t.HiddenColumnNames)
            testCase.verifyEmpty(t.ColumnVisible)
            testCase.verifyEmpty(t.VisibleColumnNames)
        end

        function tApplyColumnAliases(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.ColumnNames = ["a" "b" "c" "d"];

            testCase.verifyEqual(t.ColumnNames, ["a" "b" "c" "d"])
            testCase.verifyEqual(t.DataColumnNames, ["Numerical", "Categorical", "Logical", "String"])
            testCase.verifyEqual(t.VisibleColumnNames, ["a", "b", "c", "d"])
            testCase.verifyEqual(string(t.DisplayTable.Data.Properties.VariableNames), ...
                ["a" "b" "c" "d"])
        end

        function tInvalidColumnAliases(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            fcn = @() t.set("ColumnNames", ["a", "b"]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:InvalidColumnAliases")
        end

        function tRenameColumn(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.ColumnNames(3) = "Boolean";

            testCase.verifyEqual(t.ColumnNames, ["Numerical", "Categorical", "Boolean", "String"])
            testCase.verifyEqual(string(t.DisplayTable.Data.Properties.VariableNames), ...
                ["Numerical", "Categorical", "Boolean", "String"])
        end

    end

end