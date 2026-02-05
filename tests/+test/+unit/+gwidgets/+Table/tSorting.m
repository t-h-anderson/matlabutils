classdef tSorting < test.WithExampleTables
    % Test sorting values in a headless table.


    methods (Test)

        function tUnsortedTable(testCase)
            t = gwidgets.Table(Data=testCase.sortableData());

            testCase.verifyEmpty(t.SortByColumn)
            testCase.verifyEqual(t.SortDirection, "None")
            testCase.verifyEqual(t.ColumnSortable, [false, false, false])
            testCase.verifyEmpty(t.SortedGroupHeaderRowIdx)
            testCase.verifyEqual(t.SortedVisibleData, table2cell(t.Data))
            testCase.verifyEqual(t.SortedVisibleToDataMap, 1:4)
            testCase.verifyEqual(t.SortedDataToVisibleMap, 1:4)
        end

        function tNumericalSortAscend(testCase)
            data = testCase.sortableData();
            t = gwidgets.Table(Data=data);

            t.SortDirection = "Ascend";
            t.ColumnSortable = [true, true, true];
            t.SortByColumn = "Var1";

            testCase.assertEqual(t.DisplayData.Var1, [1 2 3 4]')
            testCase.verifyEqual(t.DisplayData{1,:}, ["1", "true", "b"])
            testCase.verifyEqual(t.DisplayData{3,:}, ["3", "true", "a"])
            testCase.verifyEqual(t.SortedVisibleData, table2cell(t.DisplayData))
            testCase.verifyEqual(t.SortedVisibleToDataMap, [4 2 3 1])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [4 2 3 1])
        end

        function tNumericalSortDescend(testCase)
            data = testCase.sortableData();
            t = gwidgets.Table(Data=data);

            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "Var2";

            testCase.assertEqual(t.DisplayData.Var2, [true true true false]')
            testCase.verifyEqual(t.SortedVisibleData, table2cell(t.DisplayData))
            testCase.verifyEqual(t.SortedVisibleToDataMap, [1 3 4 2])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [1 4 2 3])
        end

        function tSortDirectionNone(testCase)
            t = gwidgets.Table(Data=testCase.sortableData());

            t.ColumnSortable = true;
            t.SortByColumn = "Var1";

            testCase.verifyEqual(t.DisplayData, t.Data)
        end

        function tUndoSorting(testCase)
            data = testCase.sortableData();
            t = gwidgets.Table(Data=data);

            t.SortDirection = "Ascend";
            t.ColumnSortable = true;
            t.SortByColumn = "Var1";

            testCase.verifyNotEqual(t.DisplayData, data)

            t.SortDirection = "None";
            testCase.verifyEqual(t.DisplayData, data)
        end

        function tNoSortableColumns(testCase)
            t = gwidgets.Table(Data=testCase.sortableData());

            t.ColumnSortable = false;
            t.SortDirection = "Descend";

            fcn = @() t.set("SortByColumn", "Var1");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:NotASortableColumn")

            testCase.verifyEqual(t.DisplayData, t.Data)
        end

        function tSortNonSortableColumn(testCase)
            t = gwidgets.Table(Data=testCase.sortableData());

            t.ColumnSortable = [true, false, true];
            t.SortDirection = "Descend";
            
            fcn = @() t.set("SortByColumn", "Var2");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:NotASortableColumn")
            
            testCase.verifyEqual(t.DisplayData, t.Data)
        end

        function tInvalidColumnSortable(testCase)
            data = testCase.sortableData();
            t = gwidgets.Table(Data=data);
            
            t.SortDirection = "Ascend";            
            t.ColumnSortable = [false, true, false];
            
            fcn = @() t.set("SortByColumn", "Var1");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:NotASortableColumn")
        end

        function tSequentialSorting(testCase)
            % Apply sorting multiple times, consecutively. Subsequent
            % sorting operations start from scratch. 
            t = gwidgets.Table(Data=testCase.sortableData());
            
            t.SortDirection = "Ascend";            
            t.ColumnSortable = [true, true, false];
            
            t.SortByColumn = "Var1";
            testCase.verifyEqual(t.DisplayData.Var1, [1 2 3 4]')
            testCase.verifyEqual(t.DisplayData.Var2, [true false true true]')

            t.SortByColumn = "Var2";
            testCase.verifyEqual(t.DisplayData.Var1, [2 4 3 1]')
            testCase.verifyEqual(t.DisplayData.Var2, [false true true true]')
        end

        function tInvalidSortByColumn(testCase)
            t = gwidgets.Table(Data=testCase.sortableData());

            t.SortDirection = "Ascend";            
            t.ColumnSortable = true;

            fcn = @() t.set("SortByColumn", "NonExistentColumn");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:NotASortableColumn")
        end

        function tSortEmptyTable(testCase)
            t = gwidgets.Table(Data=table.empty(0,2));

            t.SortDirection = "Ascend";            
            t.ColumnSortable = true;
            t.SortByColumn = "Var2";

            testCase.verifyEqual(t.DisplayData, table.empty(0,2))
        end

        function tSortCategorical(testCase)
            t = gwidgets.Table(Data=testCase.categoricalData());

            t.SortDirection = "Ascend";            
            t.ColumnSortable = true;
            t.SortByColumn = "Var2";

            testCase.verifyEqual(t.DisplayData.Var2, categorical(["a" "a" "a" "a" "b" "b" "c" "c" "c" "c"]'))
        end

        function tEditDataAfterSorting(testCase)
            data = testCase.sortableData();
            t = gwidgets.Table(Data=data);
            t.SortDirection = "Ascend";            
            t.ColumnSortable = true;
            t.SortByColumn = "Var1";

            t.Data.Var1(2) = 10;
            
            testCase.verifySize(t.DisplayData, [4 3])
            testCase.verifyEqual(t.DisplayData{4,:}, ["10", "false", "b"])
        end

        function tReplaceDataAfterSorting(testCase)
            data = testCase.sortableData();
            t = gwidgets.Table(Data=data);
            t.SortDirection = "Ascend";            
            t.ColumnSortable = true;
            t.SortByColumn = "Var1";

            newdata = [data; data];
            t.Data = newdata;

            testCase.verifyEqual(t.DisplayData.Var1, [1 1 2 2 3 3 4 4]')
        end

        function tRenameColumnAfterSorting(testCase)
            t = gwidgets.Table(Data=testCase.sortableData());
            t.SortDirection = "Ascend";            
            t.ColumnSortable = true;
            t.SortByColumn = ["Var1", "Var2"];

            t.ColumnNames(1) = 'Numerical';

            testCase.verifyEqual(t.DisplayData.Numerical, [1 2 3 4]')
            testCase.verifyEqual(t.SortByColumn, ["Numerical","Var2"])
            testCase.verifyEqual(t.SortDirection, "Ascend")
            testCase.verifyEqual(t.ColumnSortable, true(1,3))
        end

    end

end