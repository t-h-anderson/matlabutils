classdef tSorting < test.WithExampleTables
    % Test sorting values in a headless table.


    methods (Test)

        function tSortingControllerApiAvailable(testCase)
            t = gwidgets.Table(Data=testCase.sortableData());

            testCase.verifyInstanceOf(t.Sort, "gwidgets.internal.table.SortController")

            t.SortDirection = "Ascend";
            testCase.verifyEqual(t.Sort.Direction, "Ascend")

            t.SortDirection = "None";
            t.ColumnSortable = true;
            t.SortByColumn = "Var1";
            testCase.verifyEqual(t.Sort.By, "Var1")

            t.SortDirection = "Ascend";
            testCase.verifyEqual(t.Sort.Direction, "Ascend")
        end

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

        function tMultiColumnSortRespectsRequestedOrder(testCase)
            data = table([2; 1; 2; 1], [2; 2; 1; 1], ...
                'VariableNames', {'Var1', 'Var2'});
            t = gwidgets.Table(Data=data);
            t.SortDirection = "Ascend";
            t.ColumnSortable = true;
            t.SortByColumn = ["Var2", "Var1"];

            testCase.verifyEqual(t.DisplayData.Var1, [1; 2; 1; 2])
            testCase.verifyEqual(t.DisplayData.Var2, [1; 1; 2; 2])
        end

        function tGroupedMultiColumnSortUsesTypedColumns(testCase)
            data = table( ...
                ["g1"; "g1"; "g1"; "g2"; "g2"], ...
                categorical(["b"; "a"; "a"; "b"; "a"]), ...
                [2; 2; 1; 1; 2], ...
                'VariableNames', {'Group', 'Cat', 'Num'});
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Group";
            t.SortDirection = "Ascend";
            t.ColumnSortable = true;
            t.SortByColumn = ["Cat", "Num"];

            rowIdx = [2 3 4 6 7];
            actualCat = arrayfun(@(idx) string(t.SortedVisibleData{idx, 1}), rowIdx);
            actualNum = cell2mat(t.SortedVisibleData(rowIdx, 2));

            testCase.verifyEqual(actualCat, ["a", "a", "b", "a", "b"])
            testCase.verifyEqual(actualNum, [1; 2; 2; 2; 1])
            testCase.verifyEqual(t.SortedGroupHeaderRowIdx, [1 5])
            testCase.verifyEqual(t.SortedVisibleToDataMap(rowIdx), [3 2 1 5 4])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [4 3 2 7 6])
        end

        function tGroupedSortFallsBackForCharMatrixColumns(testCase)
            data = table( ...
                ["g1"; "g1"; "g2"; "g2"], ...
                char(["bb"; "aa"; "dd"; "cc"]), ...
                'VariableNames', {'Group', 'Text'});
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Group";
            t.SortDirection = "Ascend";
            t.ColumnSortable = true;
            t.SortByColumn = "Text";

            rowIdx = [2 3 5 6];
            actualText = arrayfun(@(idx) string(t.SortedVisibleData{idx, 1}), rowIdx);

            testCase.verifyEqual(actualText, ["aa", "bb", "cc", "dd"])
            testCase.verifyEqual(t.SortedGroupHeaderRowIdx, [1 4])
            testCase.verifyEqual(t.SortedVisibleToDataMap(rowIdx), [2 1 4 3])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [3 2 6 5])
        end

        function tMultiGroupSortRespectsRequestedGroupVariableOrder(testCase)
            data = table( ...
                ["b"; "a"; "b"; "a"; "a"], ...
                ["x"; "y"; "y"; "x"; "x"], ...
                [1; 2; 3; 4; 5], ...
                'VariableNames', {'G1', 'G2', 'Value'});
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = ["G1", "G2"];
            t.SortDirection = "Ascend";
            t.ColumnSortable = true;
            testCase.verifyWarningFree(@() t.set("SortByColumn", ["G2", "G1"]))

            headerLabels = arrayfun(@(idx) string(t.SortedVisibleData{idx, 1}), t.SortedGroupHeaderRowIdx);

            testCase.verifyEqual(t.DisplayGroups, ["a|x", "b|x", "a|y", "b|y"])
            testCase.verifyEqual(headerLabels, ["a|x (2/2)", "b|x (1/1)", "a|y (1/1)", "b|y (1/1)"])

            testCase.verifyWarningFree(@() t.set("SortDirection", "Descend"))
            headerLabels = arrayfun(@(idx) string(t.SortedVisibleData{idx, 1}), t.SortedGroupHeaderRowIdx);

            testCase.verifyEqual(t.DisplayGroups, ["b|y", "a|y", "b|x", "a|x"])
            testCase.verifyEqual(headerLabels, ["b|y (1/1)", "a|y (1/1)", "b|x (1/1)", "a|x (2/2)"])
        end

        function tMultiGroupSortUsesStoredKeysForDelimiterValues(testCase)
            data = table( ...
                ["a|1"; "a"; "b"], ...
                ["b"; "1|b"; "a"], ...
                [1; 2; 3], ...
                'VariableNames', {'G1', 'G2', 'Value'});
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = ["G1", "G2"];
            t.SortDirection = "Ascend";
            t.ColumnSortable = true;
            t.SortByColumn = ["G2", "G1"];

            testCase.verifyEqual(t.Groups, ["a|1\|b", "a\|1|b", "b|a"])
            testCase.verifyEqual(t.DisplayGroups, ["a|1\|b", "b|a", "a\|1|b"])
        end

        function tSortedEmptyGroupCountsFollowSortedGroupOrder(testCase)
            data = table( ...
                ["w"; "x"; "y"], ...
                [1; 2; 3], ...
                'VariableNames', {'Group', 'Value'});
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Group";
            t.Filter = "Value>1";
            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "Group";

            testCase.verifyEqual(t.DisplayGroups, ["y", "x"])
        end

    end

end
