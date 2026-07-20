classdef tGrouping < test.WithExampleTables
    % Test grouping rows in a headless table.

    methods (Test)

        function tGroupingControllerApiAvailable(testCase)
            data = testCase.stringData();
            t = gwidgets.Table(Data=data);

            testCase.verifyInstanceOf(t.Group, "gwidgets.internal.table.GroupController")

            t.ShowEmptyGroups = true;
            testCase.verifyTrue(t.Group.ShowEmpty)

            t.GroupingVariable = "Var2";
            testCase.verifyEqual(t.Group.By, "Var2")
        end

        function tGroupingModeFacadeDelegates(testCase)
            t = gwidgets.Table(Data=testCase.stringData());

            testCase.verifyEqual(t.GroupingMode, "Flat")

            t.GroupingMode = "Nested";

            testCase.verifyEqual(t.GroupingMode, "Nested")
        end

        function tUITableUsesNestedGroupingModeApi(testCase)
            u = gwidgets.UITable(Data=testCase.stringData());
            testCase.addTeardown(@()delete(u));

            testCase.verifyFalse(ismember("GroupingMode", string(properties(u))))
            testCase.verifyEqual(u.Group.Mode, "Flat")

            u.Group.Mode = "Nested";

            testCase.verifyEqual(u.Group.Mode, "Nested")
        end

        function tGroupControllerAddsAndRemovesVariables(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.Group.addBy("Categorical");
            t.Group.addBy(["String", "Categorical"]);

            testCase.verifyEqual(t.GroupingVariable, ["Categorical", "String"])

            t.Group.removeBy("Categorical");
            testCase.verifyEqual(t.GroupingVariable, "String")

            t.Group.clearBy();
            testCase.verifyEmpty(t.GroupingVariable)
        end

        function tNestedGroupingRendersRecursiveHeaders(testCase)
            data = table( ...
                ["B"; "A"; "A"; "B"], ...
                ["x"; "x"; "y"; "x"], ...
                [1; 2; 3; 4], ...
                'VariableNames', {'G1', 'G2', 'Value'});
            t = gwidgets.Table(Data=data, GroupingVariable=["G1", "G2"], GroupingMode="Nested");

            labels = string(t.DisplayData{:,1});
            testCase.verifyEqual(labels, ["⮞ G1: A (2/2)"; "⮞ G1: B (2/2)"])
            testCase.verifyEqual(t.DisplayGroups, ["A", "B"])

            t.OpenGroups = "A";

            indent = string(repmat(char(160), 1, 4));
            labels = string(t.DisplayData{:,1});
            testCase.verifyEqual(labels, [ ...
                "⮟ G1: A (2/2)"; ...
                indent + "⮞ G2: x (1/1)"; ...
                indent + "⮞ G2: y (1/1)"; ...
                "⮞ G1: B (2/2)"])
            testCase.verifyEqual(t.DisplayGroups, ["A", "A|x", "A|y", "B"])
        end

        function tNestedGroupingIndentsEachHeaderLevel(testCase)
            data = table( ...
                ["A"; "A"], ...
                ["x"; "x"], ...
                ["p"; "q"], ...
                [1; 2], ...
                'VariableNames', {'G1', 'G2', 'G3', 'Value'});
            t = gwidgets.Table(Data=data, GroupingVariable=["G1", "G2", "G3"], GroupingMode="Nested");

            t.OpenGroups = ["A", "A|x"];

            indent = string(repmat(char(160), 1, 4));
            labels = string(t.DisplayData{:,1});
            testCase.verifyEqual(labels, [ ...
                "⮟ G1: A (2/2)"; ...
                indent + "⮟ G2: x (2/2)"; ...
                indent + indent + "⮞ G3: p (1/1)"; ...
                indent + indent + "⮞ G3: q (1/1)"])
        end

        function tNestedGroupingMapsOpenedLeafRows(testCase)
            data = table( ...
                ["B"; "A"; "A"; "B"], ...
                ["x"; "x"; "y"; "x"], ...
                [1; 2; 3; 4], ...
                'VariableNames', {'G1', 'G2', 'Value'});
            t = gwidgets.Table(Data=data, GroupingVariable=["G1", "G2"], GroupingMode="Nested");

            t.OpenGroups = ["A", "A|x"];

            testCase.verifyEqual(t.UITable.Data.FoldedVisibleToDataMap, [NaN, NaN, 2, NaN, NaN])
            testCase.verifyEqual(t.UITable.Data.FoldedDataToVisibleMap, [NaN, 3, NaN, NaN])
        end

        function tGroupHeaderSpanPayloadUsesDisplayLabels(testCase)
            data = table( ...
                ["B"; "A"; "A"; "B"], ...
                ["x"; "x"; "y"; "x"], ...
                [1; 2; 3; 4], ...
                'VariableNames', {'G1', 'G2', 'Value'});
            t = gwidgets.Table(Data=data, GroupingVariable=["G1", "G2"], GroupingMode="Nested");

            t.OpenGroups = "A";

            payload = gwidgets.internal.table.BridgeController.groupHeaderSpanPayload( ...
                t.DisplayTable.Data, t.UITable.Data.VisibleGroupHeaderRowIdx);

            indent = string(repmat(char(160), 1, 4));
            testCase.verifyEqual(payload.rows, [1 2 3 4])
            testCase.verifyEqual(string(payload.labels), [ ...
                "⮟ G1: A (2/2)", ...
                indent + "⮞ G2: x (1/1)", ...
                indent + "⮞ G2: y (1/1)", ...
                "⮞ G1: B (2/2)"])
        end

        function tGroupColumnSpanPayloadUsesTransposedLabels(testCase)
            data = table( ...
                ["B"; "A"; "A"; "B"], ...
                ["x"; "x"; "y"; "x"], ...
                [1; 2; 3; 4], ...
                'VariableNames', {'G1', 'G2', 'Value'});
            t = gwidgets.Table(Data=data, GroupingVariable=["G1", "G2"], GroupingMode="Nested");

            t.OpenGroups = "A";
            t.DisplayOrientation = "Transposed";

            payload = gwidgets.internal.table.BridgeController.groupColumnSpanPayload( ...
                t.DisplayTable.Data, t.UITable.Data.VisibleGroupHeaderRowIdx);
            t.DisplayOrientation = "Normal";
            rowPayload = gwidgets.internal.table.BridgeController.groupHeaderSpanPayload( ...
                t.DisplayTable.Data, t.UITable.Data.VisibleGroupHeaderRowIdx);

            testCase.verifyEqual(payload.columns, [2 3 4 5])
            testCase.verifyEqual(string(payload.labels), string(rowPayload.labels))
        end

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
            testCase.verifyEmpty(t.HiddenGroups)
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

        function tGroupEmptyTableOneColumn(testCase)
            t = gwidgets.Table(Data=table.empty(0,1));
            t.GroupingVariable = "Var1";
            testCase.verifyEqual(t.DisplayData, table(string.empty(0,1), 'VariableNames', "Group"))
            testCase.verifyTrue(t.IsGroupTable)
        end

        function tGroupEmptyTableMultipleColumns(testCase)
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

        function tHiddenGroupsEmptyAfterFilter(testCase)
            % When ShowEmptyGroups=false (default) and all groups have data,
            % HiddenGroups is empty.
            data = testCase.stringData();
            t = gwidgets.Table(Data=data, ShowEmptyGroups=false);
            t.GroupingVariable = "Var2";

            testCase.verifyEmpty(t.HiddenGroups)
        end

        function tHiddenGroupsPopulatedByFilter(testCase)
            % When ShowEmptyGroups=false and a filter removes all rows from
            % a group, that group appears in HiddenGroups. ClosedGroups is
            % the set-theoretic complement of OpenGroups within Groups
            % (matching set.ClosedGroups), so hidden groups still count as
            % closed if they aren't open.
            data = testCase.stringData();
            t = gwidgets.Table(Data=data, ShowEmptyGroups=false);
            t.GroupingVariable = "Var2";
            t.Filter = "Var2=a";

            testCase.verifyEqual(sort(t.HiddenGroups), ["b", "c"])
            testCase.verifyEmpty(t.OpenGroups)
            testCase.verifyEqual(sort(t.ClosedGroups), ["a", "b", "c"])
        end

        function tClosedGroupsComplementWithinGroupsNotDisplayGroups(testCase)
            % Regression: get.ClosedGroups must compute the complement of
            % OpenGroups within Groups, not within DisplayGroups. With a
            % filter that hides some groups the two have different
            % lengths, so the buggy form would either error or return the
            % wrong slice of Groups.
            data = testCase.stringData();
            t = gwidgets.Table(Data=data, ShowEmptyGroups=false);
            t.GroupingVariable = "Var2";
            t.OpenGroups = "a";
            t.Filter = "Var2=a";

            testCase.verifyEqual(t.Groups, ["a", "b", "c"])
            testCase.verifyEqual(t.DisplayGroups, "a")
            testCase.verifyEqual(t.OpenGroups, "a")
            testCase.verifyEqual(sort(t.ClosedGroups), ["b", "c"])
        end

    end

end
