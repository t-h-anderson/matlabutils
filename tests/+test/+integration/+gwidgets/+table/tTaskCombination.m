classdef tTaskCombination < test.WithExampleTables
    % Test combinations of tasks (e.g. filter > sort, filter > group >
    % fold), in different order where that matters.

    methods (Test)

        function tFilter_Sort(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Filter = "Numerical>2"; % leaves rows 3, 4, 5

            % First sort by the filtered column.
            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "Numerical";
            testCase.assertSize(t.DisplayData, [3 4])
            testCase.verifyEqual(t.DisplayData.Numerical, [5 4 3]')
            testCase.verifyEqual(t.SortedVisibleData, table2cell(t.DisplayData))
            testCase.verifyEqual(t.SortedVisibleToDataMap, [5 4 3])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [NaN NaN 3 2 1])

            % Then sort by another column.
            t.SortByColumn = "String";
            testCase.verifyEqual(t.DisplayData.String, ["y" "x" "x"]')
            testCase.verifyEqual(t.SortedVisibleToDataMap, [5 3 4])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [NaN NaN 2 3 1])
        end

        function tFilter_Group_Fold(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Filter = "String=x"; % leaves rows 2, 3, 4
            t.GroupingVariable = "Categorical"; % results in 2 groups
            t.OpenGroups = "a"; % group 'a' has 1/3 entries

            testCase.assertSize(t.DisplayData, [3 3])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮟ a (1/3)")
            testCase.verifyEqual(t.DisplayData.Numerical(2), "4")
            testCase.verifyEqual(t.DisplayData.Logical(2), {false})
            testCase.verifyEqual(t.DisplayData.String(2), {"x"})

            testCase.verifyEqual(t.SortedGroupHeaderRowIdx, [1 3])
            testCase.verifyEqual(t.SortedVisibleToDataMap, [NaN 4 NaN 2 3])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [NaN 4 5 2 NaN])

            % Opening all groups doesn't change maps.
            t.openAllGroups()
            testCase.verifyEqual(t.SortedVisibleToDataMap, [NaN 4 NaN 2 3])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [NaN 4 5 2 NaN])
        end

        function tGroup_Filter(testCase)
            % Filter out a whole group.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = "Logical"; % results in 2 groups

            testCase.verifyEqual(t.Groups, ["false" "true"])
            t.Filter = "String=x & Categorical=a"; % filters out the 'true' group entirely

            testCase.assertSize(t.DisplayData, [1 3])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ false (1/2)")
            
            % Groups that are filtered still show up if show empty groups
            % are set to true
            t.ShowEmptyGroups = true;
            testCase.assertSize(t.DisplayData, [2 3])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ false (1/2)")
            testCase.verifyEqual(t.DisplayData.Numerical(2), "⮞ true (0/3)")

        end

        function tGroup_Sort(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Make more complex as issues found here
            t.Data = [t.Data; {...
                6 categorical("c") false "z"; ...
                7 categorical("w") true "w"; ...
                8 categorical("c") true "z" ; ...
                9 categorical("w") true "w" ...
                }];

            t.ShowEmptyGroups = false;

            t.GroupingVariable = "String"; % results in 4 groups
            testCase.assertSize(t.DisplayData, [4,3]);

            t.Filter = "String=x|y|z";
            testCase.assertSize(t.DisplayData, [3,3]);

            t.ShowEmptyGroups = true;
            testCase.assertSize(t.DisplayData, [4,3]);

            testCase.verifyEqual(t.SortedVisibleToDataMap, [NaN NaN 2 3 4 NaN 1 5 NaN 6 8])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [7 3 4 5 8 10 NaN 11 NaN])
            
            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "String";
           
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ z (2/2)")
            testCase.verifyEqual(t.DisplayData.Numerical(2), "⮞ y (2/2)")
            testCase.verifyEqual(t.DisplayData.Numerical(3), "⮞ x (3/3)")
            testCase.verifyEqual(t.DisplayData.Numerical(4), "⮞ w (0/2)")

            testCase.verifyEqual(t.SortedVisibleToDataMap, [NaN 6 8 NaN 1 5 NaN 2 3 4 NaN])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [5 8 9 10 6 2 NaN 3 NaN])

            t.SortByColumn = "Numerical";
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ w (0/2)")
            testCase.verifyEqual([t.SortedVisibleData{3:5}], [4 3 2])
            testCase.verifyEqual([t.SortedVisibleData{7:8}], [5 1])
        end

        function tSort_Filter(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "Numerical";

            t.Filter = "Numerical>2 & Categorical=a"; % leaves rows 4, 5

            testCase.assertSize(t.DisplayData, [2 4])
            testCase.verifyEqual(t.DisplayData.Numerical, [5 4]')
            testCase.verifyEqual(t.DisplayData.Categorical, categorical(["a" "a"]'))
            testCase.verifyEqual(t.SortedVisibleToDataMap, [5 4])
            testCase.verifyEqual(t.SortedDataToVisibleMap, [NaN NaN NaN 2 1])
        end

        function tFilter_Group_Sort_Fold(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Filter = "Numerical > 2"; % leaves rows 3, 4, 5
            t.GroupingVariable = "String"; % results in 2 groups
            
            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "Categorical";
            
            t.OpenGroups = "x"; % group 'x' has 2/3 entries

            testCase.assertSize(t.DisplayData, [4 3])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮟ x (2/3)")
            testCase.verifyEqual(t.DisplayData.Numerical(4), "⮞ y (1/2)")
            testCase.verifyEqual(t.Groups, ["x", "y"])
            testCase.verifyEqual(t.OpenGroups, "x")
            testCase.verifyEqual([t.DisplayData.Categorical{2:3}], categorical(["b", "a"]))
            testCase.verifyEqual([t.DisplayData.Logical{2:3}], [true false])
            testCase.verifyEqual(t.SortedGroupHeaderRowIdx, [1 4])
        end

        function tFilter_HideColumn_Sort(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Filter = "Categorical=a"; % leaves rows 1, 4, 5
            t.HiddenColumnNames = "Logical";
            
            t.SortDirection = "Ascend";
            t.ColumnSortable = true;
            t.SortByColumn = "String";

            testCase.assertSize(t.DisplayTable.Data, [3 3])
            testCase.verifyEqual(t.DisplayTable.Data.Numerical, [4 1 5]')
            testCase.verifyEqual(t.DisplayTable.Data.String, ["x" "y" "y"]')
        end

        function tGroup_HideColumns_Fold(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = "String"; % results in 2 groups
            t.HiddenColumnNames = ["Numerical", "Categorical"];
            t.OpenGroups = "y";

            testCase.assertSize(t.DisplayTable.Data, [4, 1])
            testCase.verifyEqual(t.DisplayTable.Data.Logical{1}, "⮞ x (3/3)")
            testCase.verifyEqual([t.DisplayTable.Data.Logical{3:4}], [true true])
        end

        function tFilter_Group_ShowEmptyGroups_Fold(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Filter = "Categorical = b"; % leaves rows 2, 3
            t.GroupingVariable = "String"; % results in 2 groups, 1 empty
            
            testCase.verifyFalse(t.ShowEmptyGroups)
            testCase.verifySize(t.DisplayData, [1 3])
            testCase.verifyEqual(t.DisplayTable.Data, t.DisplayData)

            t.ShowEmptyGroups = true;
            testCase.assertSize(t.DisplayData, [2 3])
            testCase.verifyEqual(t.DisplayTable.Data.Numerical(1), "⮞ x (2/3)")
            testCase.verifyEqual(t.DisplayTable.Data.Numerical(2), "⮞ y (0/2)")

            t.openAllGroups();
            testCase.assertSize(t.DisplayData, [4 3])
            testCase.verifyEqual(t.DisplayTable.Data.Numerical(1), "⮟ x (2/3)")
            testCase.verifyEqual(t.DisplayTable.Data.Numerical(4), "⮟ y (0/2)")
        end

        function tSort_Group_Filter(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            
            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "Numerical";

            t.GroupingVariable = "Categorical"; % results in 2 groups
            t.Filter = "String = x";

            testCase.verifySize(t.DisplayData, [2 3])
            testCase.verifySize(t.SortedVisibleData, [5 3])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ a (1/3)")
            testCase.verifyEqual(t.DisplayData.Numerical(2), "⮞ b (2/2)")

            t.Filter = "String = y";
            testCase.verifySize(t.DisplayData, [1 3])
            testCase.verifySize(t.SortedVisibleData, [4 3])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ a (2/3)")
        end

        function tGroup_Sort_EditData_Fold(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = "String"; % results in 2 groups
            
            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "Numerical";

            t.Data.Numerical = (6:10)';
            testCase.verifySize(t.DisplayData, [2 3])
            testCase.verifyEqual([t.SortedVisibleData{2:4,1}], [9 8 7])
            testCase.verifyEqual([t.SortedVisibleData{6:7,1}], [10 6])

            t.Data.String = ["a" "b" "c" "d" "a"]';
            testCase.verifySize(t.DisplayData, [4 3])
            testCase.verifyEqual(t.DisplayData.Numerical(3), "⮞ c (1/1)")
            testCase.verifyEqual([t.SortedVisibleData{2:3,1}], [10 6])
        end

        function tFilter_ReplaceData_Group(testCase)
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.Filter = "Numerical > 3";

            newdata = [data; data];
            newdata.Numerical = repelem(10, 10, 1);
            t.Data = newdata;

            t.GroupingVariable = "Categorical"; % results in 2 groups
            
            testCase.verifySize(t.DisplayData, [2 3]);
            testCase.verifySize(t.SortedVisibleData, [12 3])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ a (6/6)")
            testCase.verifyEqual(t.DisplayTable.Data.Numerical(2), "⮞ b (4/4)")
        end

        function tAlias_Sort(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.ColumnNames = ["Numerical_2", "Categorical_2", "Logical_2", "String_2"];

            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByDataColumn = "Numerical";

            testCase.verifyEqual(t.DisplayTable.Data.Numerical_2, [5 4 3 2 1]')
        end

        function tGroup_Alias_Filter(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = "Categorical"; % results in 2 groups
            t.ColumnNames = ["Numerical_2", "Categorical_2", "Logical_2", "String_2"];
            t.Filter = "String = y";

            testCase.assertSize(t.DisplayTable.Data, [1 3])
            testCase.verifyEqual(t.DisplayTable.Data.Numerical_2, "⮞ a (2/3)")
        end

        function tAllRowsFilteredOut_Group(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Filter = "Categorical = c";
            t.GroupingVariable = "String";

            testCase.verifySize(t.DisplayData, [0 3])
            testCase.verifySize(t.SortedVisibleData, [2 3])
            testCase.verifySize(t.DisplayTable.Data, [0 3])
            testCase.verifyEqual(t.GroupingVariableName, "String")
            testCase.verifyEqual(t.Groups, ["x", "y"])
        end

        function tGroupByHiddenColumn(testCase)
            % Group by hidden column does nothing
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.HiddenColumnNames = ["Categorical", "Logical"];
            
            t.GroupingVariable = "Categorical";
            testCase.verifySize(t.DisplayData, [2 2])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ a (3/3)")
            testCase.verifyEqual(t.DisplayData.Numerical(2), "⮞ b (2/2)")

            t.GroupingVariable = ["Categorical", "String"];

            testCase.verifySize(t.DisplayData, [3 1])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ a|x (1/1)")
            testCase.verifyEqual(t.DisplayData.Numerical(2), "⮞ a|y (2/2)")
        end

        function tSortByHiddenColumn(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.HiddenColumnNames = ["Numerical", "Logical"];

            t.SortDirection = "Descend";
            t.DataColumnSortable = true;
            t.SortByColumn = "Numerical";
            
            testCase.assertSize(t.DisplayTable.Data, [5 2])
            testCase.verifyEqual(t.DisplayTable.Data.Categorical, categorical(["a" "a" "b" "b" "a"]'))
        end

        function tGroup_RenameColumn_Filter(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = ["Logical", "String"];
            t.ColumnNames(3) = "Boolean";
            t.Filter = "Boolean = true";

            % TODO: add verification when this doesn't error any more.
        end


    end

end