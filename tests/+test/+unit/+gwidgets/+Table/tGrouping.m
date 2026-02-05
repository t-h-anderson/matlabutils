classdef tGrouping < test.WithExampleTables
    % Test grouping rows in a headless table.

    methods (Test)

        function tUngroupedTable(testCase)
            data = testCase.stringData();
            t = gwidgets.Table(Data=data);

            testCase.verifyFalse(t.IsGroupTable)
            testCase.verifyEqual(t.DisplayData, data)
            testCase.verifyEmpty(t.GroupingVariable)
            testCase.verifyEqual(t.GroupingVariableName, "")
            testCase.verifyEmpty(t.Groups)
            testCase.verifyEmpty(t.ClosedGroups)
            testCase.verifyEmpty(t.OpenGroups)
            testCase.verifyEmpty(t.HiddenGroups)
        end

        function tGroupByString(testCase)
            data = testCase.stringData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            testCase.assertTrue(t.IsGroupTable)
            testCase.assertSize(t.DisplayData, [3 1])
            testCase.verifyEqual(t.DisplayData.Var1(3), "⮞ c (4/4)")
            testCase.verifyEqual(t.Data, data)
            testCase.verifyEqual(t.Groups, ["a", "b", "c"])
            testCase.verifyEqual(t.DisplayGroups, ["a", "b", "c"])
            testCase.verifyEqual(t.GroupingVariableName, "Var2")
            testCase.verifyEmpty(t.OpenGroups)
            testCase.verifyEqual(t.ClosedGroups, ["a", "b", "c"])
            testCase.verifyEqual(t.HiddenGroups, ["a", "b", "c"]) % ???
        end

        function tGroupByNumerical(testCase)
            data = testCase.numericalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            testCase.assertSize(t.DisplayData, [3 2])
            testCase.verifyEqual(t.DisplayGroups, ["1", "2", "3"])
            testCase.verifyEqual(t.DisplayData.Var1(2), "⮞ 2 (5/5)")
            testCase.verifyEqual(t.DisplayData.Var3(3), {double.empty})
        end

        function tGroupByCategorical(testCase)
            data = testCase.categoricalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            testCase.verifyEqual(t.DisplayGroups, ["a", "b", "c"])
            testCase.assertSize(t.DisplayData, [3 1])
            testCase.verifyEqual(t.DisplayData.Var1(3), "⮞ c (4/4)")
        end

        function tGroupByLogical(testCase)
            data = testCase.logicalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            testCase.verifyEqual(t.DisplayGroups, ["false", "true"])
            testCase.assertSize(t.DisplayData, [2 1])
            testCase.verifyEqual(t.DisplayData.Var1(1), "⮞ false (3/3)")
        end

        function tGroupEmptyTable(testCase)
            t = gwidgets.Table(Data=table.empty(0,2));
            t.GroupingVariable = "Var1";

            testCase.verifyEqual(t.DisplayData, t.Data(:,2))
            testCase.verifyTrue(t.IsGroupTable)
        end

        function tGroupByMultipleVariables(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = ["Logical", "String", "Categorical"];

            testCase.verifyEqual(t.GroupingVariable, ["Logical", "String", "Categorical"])
            testCase.assertSize(t.DisplayData, [4 1])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ false|x|a (1/1)")
            testCase.verifyEqual(t.DisplayData.Numerical(4), "⮞ true|y|a (2/2)")
            testCase.verifyEqual(t.Groups, ["false|x|a", "false|x|b", "true|x|b", "true|y|a"])
            testCase.verifyEqual(t.GroupingVariableName, "Logical|String|Categorical")
            testCase.verifyEmpty(t.OpenGroups)
            testCase.verifyEqual(t.ClosedGroups, t.Groups)
        end

        function tSequentialGrouping(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = ["Categorical", "String"];

            testCase.verifySize(t.DisplayData, [3 2])
            testCase.verifyEqual(t.GroupingVariableName, "Categorical|String")
            testCase.verifyEqual(t.DisplayData.Properties.VariableNames, {'Numerical', 'Logical'})

            t.GroupingVariable = ["String", "Categorical"];
            testCase.verifySize(t.DisplayData, [3 2])
            testCase.verifyEqual(t.GroupingVariableName, "String|Categorical")
            testCase.verifyEqual(t.DisplayData.Properties.VariableNames, {'Numerical', 'Logical'})

            t.GroupingVariable = "Categorical";
            testCase.verifySize(t.DisplayData, [2 3])
            testCase.verifyEqual(t.GroupingVariableName, "Categorical")
            testCase.verifyEqual(t.DisplayData.Properties.VariableNames, {'Numerical', 'Logical', 'String'})
        end

        function tNonExistentGroupingVariable(testCase)
            t = gwidgets.Table(Data=testCase.stringData());
            
            fcn = @() t.set("GroupingVariable", "Var3");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:NonexistentGroupingVariable")

            fcn = @() t.set("GroupingVariable", ["Var1", "Var3"]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:NonexistentGroupingVariable")
        end

        function tGroupByAllVariables(testCase)
            t = gwidgets.Table(Data=testCase.collapsibleData());
            t.GroupingVariable = ["Var1", "Var2"];
            
            testCase.verifyEqual(t.GroupingVariableName, "Var1|Var2")
            testCase.assertSize(t.DisplayData, [4 1])
            testCase.verifyEqual(t.DisplayData.Properties.VariableNames, {'Group'})
        end

        function tGroupByRepeatedVariables(testCase)
            t = gwidgets.Table(Data=testCase.collapsibleData());

            t.GroupingVariable = ["Var1", "Var1", "Var1"];
            testCase.verifyEqual(t.GroupingVariable, "Var1");
        end

        function tUndoGrouping(testCase)
            t = gwidgets.Table(Data=testCase.collapsibleData());
            t.GroupingVariable = "Var1";

            testCase.verifySize(t.DisplayData, [3 1])

            t.GroupingVariable = "";
            testCase.verifyEqual(t.DisplayData, t.Data)
            testCase.verifyFalse(t.IsGroupTable)
            testCase.verifyEmpty(t.Groups)
            testCase.verifyEqual(t.GroupingVariableName, "")
        end

        function tGroupTableWithOneColumn(testCase)
            data = table([1 2 1 2]');
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var1";

            testCase.verifyEqual(t.GroupingVariableName, "Var1");
            testCase.verifySize(t.DisplayData, [2 1])
            testCase.verifyEqual(t.DisplayData.Group(1), "⮞ 1 (2/2)")
            testCase.verifyEqual(t.DisplayData.Group(2), "⮞ 2 (2/2)")
        end

        function tEditDataAfterGrouping(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = "String";
            
            t.Data.String = repelem("x", 5, 1);
            testCase.verifySize(t.DisplayData, [1 3])
            testCase.verifyEqual(t.DisplayData.Numerical(1), "⮞ x (5/5)")
        end

        function tReplaceDataAfterGrouping(testCase)
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = ["String", "Logical"];

            newdata = [data; data];
            newdata.Properties.VariableNames{1} = 'Number';
            newdata.Logical = repelem(false, 10, 1);
            t.Data = newdata;

            testCase.verifySize(t.DisplayData, [2 2])
            testCase.verifyEqual(t.Groups, ["x|false", "y|false"])
        end

    end

end