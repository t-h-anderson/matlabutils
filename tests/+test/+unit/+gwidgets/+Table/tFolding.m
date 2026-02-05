classdef tFolding < test.WithExampleTables
    % Test grouping rows in a headless table.

    methods (Test)

        function tOpenOneGroup(testCase)
            data = testCase.categoricalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            t.OpenGroups = "b";
            testCase.verifyEqual(t.OpenGroups, "b")
            testCase.verifyEqual(t.ClosedGroups, ["a", "c"])
            testCase.assertSize(t.DisplayData, [5 1])
            testCase.verifyEqual(t.DisplayData.Var1(1), "⮞ a (4/4)")
            testCase.verifyEqual(t.DisplayData.Var1(2), "⮟ b (2/2)")
            testCase.verifyEqual(t.DisplayTable.Data, t.DisplayData)
        end

        function tOpenTwoGroups(testCase)
            data = testCase.categoricalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            t.OpenGroups = ["a", "b"];
            testCase.verifyEqual(t.OpenGroups, ["a", "b"])
            testCase.verifyEqual(t.ClosedGroups, "c")
            testCase.assertSize(t.DisplayData, [9 1])
            testCase.verifyEqual(t.DisplayData.Var1(1), "⮟ a (4/4)")
            testCase.verifyEqual(t.DisplayData.Var1(6), "⮟ b (2/2)")
        end

        function tCloseAllGroups(testCase)
            data = testCase.categoricalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            t.OpenGroups = ["a", "c"];
            t.closeAllGroups();

            testCase.verifyEmpty(t.OpenGroups)
            testCase.verifyEqual(t.ClosedGroups, ["a", "b", "c"])
            testCase.verifySize(t.DisplayData, [3 1])
            testCase.verifyEqual(t.DisplayTable.Data, t.DisplayData)
        end

        function tOpenAllGroups(testCase)
            data = testCase.categoricalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            t.openAllGroups();

            testCase.verifyEmpty(t.ClosedGroups)
            testCase.verifyEqual(t.OpenGroups, ["a", "b", "c"])
            testCase.verifySize(t.DisplayData, [13 1])
        end

        function tCloseSomeGroups(testCase)
            data = testCase.categoricalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            t.openAllGroups();
            t.ClosedGroups = "a";

            testCase.verifyEqual(t.ClosedGroups, "a")
            testCase.verifyEqual(t.OpenGroups, ["b", "c"])
            testCase.verifySize(t.DisplayData, [9 1])
            testCase.verifyEqual(t.DisplayData.Var1(1), "⮞ a (4/4)")
        end

        function tInvalidFolding(testCase)
            data = testCase.categoricalData();
            t = gwidgets.Table(Data=data);
            
            fcn = @() t.set("OpenGroups", "nonexistent");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:NonexistentGroupingVariable")

            fcn = @() t.set("ClosedGroups", "nonexistent");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:NonexistentGroupingVariable")

            t.GroupingVariable = "Var2";
            fcn = @() t.set("OpenGroups", "nonexistent");
            testCase.verifyError(fcn, "GraphicsWidgets:Table:NonexistentGroupingVariable")
        end

        function tOpenAlreadyOpenedGroup(testCase)
            data = testCase.categoricalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            t.OpenGroups = "b";
            t.OpenGroups = "b";

            testCase.verifyEqual(t.OpenGroups, "b")
            testCase.verifyEqual(t.ClosedGroups, ["a", "c"])
            testCase.assertSize(t.DisplayData, [5 1])
        end

        function tCloseAlreadyClosedGroup(testCase)
            data = testCase.categoricalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";
            t.openAllGroups();

            t.ClosedGroups = "b";
            t.ClosedGroups = "b";

            testCase.verifyEqual(t.OpenGroups, ["a", "c"])
            testCase.verifyEqual(t.ClosedGroups, "b")
            testCase.assertSize(t.DisplayData, [11 1])
        end

        function tFoldEmptyTable(testCase)
            t = gwidgets.Table(Data=table.empty(0,2));
            t.GroupingVariable = "Var1";

            t.openAllGroups();
            testCase.verifyEmpty(t.OpenGroups)
            testCase.verifyEmpty(t.ClosedGroups)
            
            t.closeAllGroups();
            testCase.verifyEmpty(t.OpenGroups)
            testCase.verifyEmpty(t.ClosedGroups)
        end

        function tSortedGroupHeaderRowIdx(testCase)
            data = testCase.categoricalData();
            t = gwidgets.Table(Data=data);
            t.GroupingVariable = "Var2";

            testCase.verifyEqual(t.SortedGroupHeaderRowIdx, [1 6 9])

            t.openAllGroups()
            testCase.verifyEqual(t.SortedGroupHeaderRowIdx, [1 6 9])
        end


    end


end