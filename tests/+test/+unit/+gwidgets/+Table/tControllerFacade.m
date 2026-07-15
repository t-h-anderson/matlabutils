classdef tControllerFacade < matlab.unittest.TestCase

    methods (Test)
        function tControllerPropertiesAreVisible(testCase)
            t = gwidgets.Table();

            propNames = string(properties(t));

            testCase.verifyTrue(ismember("Column", propNames))
            testCase.verifyTrue(ismember("Group", propNames))
            testCase.verifyTrue(ismember("Sort", propNames))
            testCase.verifyTrue(ismember("Style", propNames))
            testCase.verifyTrue(ismember("SelectionControl", propNames))
            testCase.verifyFalse(ismember("ColumnWidth", propNames))
            testCase.verifyFalse(ismember("GroupingVariable", propNames))
            testCase.verifyFalse(ismember("SortByColumn", propNames))
            testCase.verifyFalse(ismember("StyleConfigurations", propNames))
        end

        function tHiddenLegacyApiRemainsCallable(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.ColumnWidth = 120;
            t.GroupingVariable = string.empty(1,0);
            t.SortDirection = "None";

            testCase.verifyEqual(t.ColumnWidth, {120, 120, 120, 120})
            testCase.verifyEqual(t.GroupingVariable, string.empty(1,0))
            testCase.verifyEqual(t.SortDirection, "None")
        end

        function tColumnFacadeDelegatesToLegacyState(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.Column.Width = {100, "2x", "1x", 80};
            t.Column.Visible = [true false true true];
            t.Column.Names = ["One", "Two", "Three", "Four"];
            t.Column.Editable = [true false true];

            testCase.verifyEqual(t.Column.Width, {100, "1x", 80})
            testCase.verifyEqual(t.Column.DataWidth, {100, "2x", "1x", 80})
            testCase.verifyEqual(t.Column.VisibleNames, ["One", "Three", "Four"])
            testCase.verifyEqual(t.Column.HiddenNames, "Two")
            testCase.verifyEqual(t.Column.Editable, [true false true])
            testCase.verifyEqual(t.Column.DataEditable, [true false false true])
        end

        function tGroupAndSortFacadesDelegate(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.Column.DataSortable = true;
            t.Group.By = "Var1";
            t.Sort.By = "Var2";
            t.Sort.Direction = "Ascend";

            testCase.verifyEqual(t.Group.By, "Var1")
            testCase.verifyEqual(t.Group.ByName, "Var1")
            testCase.verifyTrue(t.Group.IsGrouped)
            testCase.verifyEqual(t.Sort.By, "Var2")
            testCase.verifyEqual(t.Sort.ByData, "Var2")
            testCase.verifyEqual(t.Sort.Direction, "Ascend")
        end

        function tStyleFacadeDelegates(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            s = uistyle(BackgroundColor=[0.2 0.3 0.4]);
            nBaseStyles = height(t.Style.Configurations);

            t.Style.add(s, "row", 1);

            testCase.verifyGreaterThan(height(t.Style.Configurations), nBaseStyles)

            t.Style.remove();

            testCase.verifyEqual(height(t.Style.Configurations), nBaseStyles)
        end

        function tSelectionControlDelegates(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.SelectionControl.Type = "row";
            t.SelectionControl.Value = 2;

            testCase.verifyEqual(t.SelectionControl.Type, 'row')
            testCase.verifyEqual(t.SelectionControl.Value, 2)
            testCase.verifyEqual(t.Selection, 2)

            t.SelectionControl.DisplayValue = 3;

            testCase.verifyEqual(t.SelectionControl.DisplayValue, 3)
            testCase.verifyEqual(t.DisplaySelection, 3)
        end
    end

    methods (Static, Access = private)
        function t = createTable()
            data = table( ...
                (1:4).', ...
                [4; 3; 2; 1], ...
                ["A"; "A"; "B"; "B"], ...
                [true; false; true; false], ...
                VariableNames=["Var1", "Var2", "Group", "Flag"]);
            t = gwidgets.Table();
            t.Data = data;
        end
    end
end
