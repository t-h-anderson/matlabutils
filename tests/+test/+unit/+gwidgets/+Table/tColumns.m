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

        % --- Column width tests -----------------------------------------------

        function tDataColumnWidthDefault(testCase)
            % DataColumnWidth returns one "1x" entry per data column when
            % no width has been set explicitly.
            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 columns
            testCase.verifyEqual(t.DataColumnWidth, {"1x","1x","1x","1x"})
        end

        function tSetDataColumnWidth(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, 200, 150, 80};
            testCase.verifyEqual(t.DataColumnWidth, {100, 200, 150, 80})
            testCase.verifyEqual(t.ColumnWidth, {100, 200, 150, 80})
        end

        function tDataColumnWidthScalarExpands(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = 120;
            testCase.verifyEqual(t.DataColumnWidth, {120, 120, 120, 120})
        end

        function tDataColumnWidthWrongSizeErrors(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            fn = @() set(t, "DataColumnWidth", {100, 200});
            testCase.verifyError(fn, "GraphicsWidgets:Table:DataColumnWidthSize")
        end

        function tColumnWidthOnlyCoversVisibleColumns(testCase)
            % ColumnWidth reflects only visible columns; DataColumnWidth
            % covers all data columns including hidden ones.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, 200, 150, 80};
            t.HiddenColumnNames = "Categorical";   % hide col 2

            testCase.verifyEqual(t.ColumnWidth, {100, 150, 80})
            testCase.verifyEqual(t.DataColumnWidth, {100, 200, 150, 80})
        end

        function tSetColumnWidthWithHiddenColumns(testCase)
            % Setting ColumnWidth for the 3 visible columns must not disturb
            % the stored width for the hidden column.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, 200, 150, 80};
            t.HiddenColumnNames = "Categorical";

            t.ColumnWidth = {50, 60, 70};

            % Hidden column width (200) must be preserved
            testCase.verifyEqual(t.DataColumnWidth, {50, 200, 60, 70})
            testCase.verifyEqual(t.ColumnWidth, {50, 60, 70})
        end

        function tColumnWidthPreservedAcrossHideShow(testCase)
            % Widths set before hiding a column are restored when it is
            % made visible again.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, 200, 150, 80};

            % Hide then show column 2
            t.HiddenColumnNames = "Categorical";
            t.HiddenColumnNames = string.empty(1,0);

            testCase.verifyEqual(t.ColumnWidth, {100, 200, 150, 80})
        end

        function tColumnWidthUpdatedInDisplayAfterHide(testCase)
            % After hiding a column the display table must receive the
            % correct (shorter) width array.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, 200, 150, 80};

            t.HiddenColumnNames = "Categorical";

            testCase.verifyEqual(t.DisplayTable.ColumnWidth, {100, 150, 80})
        end

        function tColumnWidthClearedByEmpty(testCase)
            % Setting ColumnWidth to [] or {} resets all widths to "1x".
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, 200, 150, 80};
            t.ColumnWidth = {};

            % DataColumnWidth now returns per-column "1x" defaults (no explicit widths)
            testCase.verifyEqual(t.DataColumnWidth, {"1x","1x","1x","1x"})
            % get.ColumnWidth falls back to the display table default ("1x")
            testCase.verifyEqual(t.ColumnWidth, {"1x", "1x", "1x", "1x"})
        end

        function tDataColumnWidthClearedByReset(testCase)
            % reset() must clear explicitly stored column widths so they
            % don't carry over to a table with a different column count.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, 200, 150, 80};

            % Replace data with a different column count to force reset()
            t.Data = testCase.stringData();  % 2 columns

            % DataColumnWidth should now reflect defaults for the new column count
            testCase.verifyEqual(t.DataColumnWidth, {"1x", "1x"})
            testCase.verifyEqual(t.ColumnWidth, {"1x", "1x"})  % display table default
        end

        function tColumnWidthInputTypes(testCase)
            % set.ColumnWidth must accept numeric arrays, string arrays,
            % char, and cell arrays.
            t = gwidgets.Table(Data=testCase.stringData());  % 2 columns

            t.ColumnWidth = [50, 100];
            testCase.verifyEqual(t.ColumnWidth, {50, 100})

            t.ColumnWidth = ["auto", "auto"];
            testCase.verifyEqual(t.ColumnWidth, {"1x", "1x"})

            t.ColumnWidth = 75;  % scalar → expands
            testCase.verifyEqual(t.ColumnWidth, {75, 75})

            t.ColumnWidth = "auto";  % scalar string → expands
            testCase.verifyEqual(t.ColumnWidth, {"1x", "1x"})
        end

    end

end