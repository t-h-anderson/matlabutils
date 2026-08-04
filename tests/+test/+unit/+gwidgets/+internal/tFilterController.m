classdef tFilterController < matlab.unittest.TestCase

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tEmptyFilterReturnsAllRows(testCase)
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            [idx, str, isOk, details] = gwidgets.internal.FilterController.filterIndices("", data);

            testCase.verifyEqual(idx, true(height(data), 1))
            testCase.verifyEqual(str, "")
            testCase.verifyTrue(isOk)
            testCase.verifyEmpty(details)
        end

        function tNumericComparatorsAndConjunctions(testCase)
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            [idx, str, isOk] = gwidgets.internal.FilterController.filterIndices("Value>=2&Value<4", data);

            testCase.verifyEqual(idx, [false; true; true; false])
            testCase.verifyEqual(str, "Value>=2 & Value<4")
            testCase.verifyTrue(isOk)
        end

        function tNumericOrComparatorReusesPreviousOperator(testCase)
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            [idx, str, isOk] = gwidgets.internal.FilterController.filterIndices("Value=1|4", data);

            testCase.verifyEqual(idx, [true; false; false; true])
            testCase.verifyEqual(str, "Value=1|4")
            testCase.verifyTrue(isOk)
        end

        function tApproximateNumericComparator(testCase)
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            [idx, ~, isOk] = gwidgets.internal.FilterController.filterIndices("Value?=2", data);

            testCase.verifyEqual(idx, [false; true; false; false])
            testCase.verifyTrue(isOk)
        end

        function tLogicalAndNotComparators(testCase)
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            [idx, str, isOk] = gwidgets.internal.FilterController.filterIndices("Flag~=false", data);

            testCase.verifyEqual(idx, [true; false; true; false])
            testCase.verifyEqual(str, "Flag~=false")
            testCase.verifyTrue(isOk)
        end

        function tInvalidLogicalValueMarksFilterInvalid(testCase)
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            [idx, str, isOk] = gwidgets.internal.FilterController.filterIndices("Flag=maybe", data);

            testCase.verifyEqual(idx, true(height(data), 1))
            testCase.verifyFalse(isOk)
            testCase.verifyTrue(endsWith(str, "Flag=maybe"))
        end

        function tStringContainsAndNotMatches(testCase)
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            [idx, str, isOk] = gwidgets.internal.FilterController.filterIndices("Name?=a&Name~=alphabet", data);

            testCase.verifyEqual(idx, [true; true; false; true])
            testCase.verifyEqual(str, "Name?=a & Name~=alphabet")
            testCase.verifyTrue(isOk)
        end

        function tCategoricalMatchesAsString(testCase)
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            [idx, str, isOk] = gwidgets.internal.FilterController.filterIndices("Group=A", data);

            testCase.verifyEqual(idx, [true; false; true; false])
            testCase.verifyEqual(str, "Group=A")
            testCase.verifyTrue(isOk)
        end

        function tDatetimeAndDurationComparators(testCase)
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            [idx, str, isOk] = gwidgets.internal.FilterController.filterIndices( ...
                "When>=02-Jan-2024&Elapsed<=3", data);

            testCase.verifyEqual(idx, [false; true; true; false])
            testCase.verifyEqual(str, "When>=02-Jan-2024 & Elapsed<=3")
            testCase.verifyTrue(isOk)
        end

        function tAmbiguousColumnMarksFilterInvalid(testCase)
            data = table([1; 2], [3; 4], VariableNames=["Alpha", "Alpine"]);

            [idx, str, isOk, details] = gwidgets.internal.FilterController.filterIndices("Al>1", data);

            testCase.verifyEqual(idx, true(height(data), 1))
            testCase.verifyFalse(isOk)
            testCase.verifyTrue(endsWith(str, "Al>1"))
            testCase.verifyEqual(nnz(details.ColumnIdx), 2)
        end

        function tUnsupportedStringOperatorMarksFilterInvalid(testCase)
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            [idx, str, isOk] = gwidgets.internal.FilterController.filterIndices("Name>alpha", data);

            testCase.verifyEqual(idx, true(height(data), 1))
            testCase.verifyFalse(isOk)
            testCase.verifyTrue(endsWith(str, "Name>alpha"))
        end

        function tUiApplyFilterAllColumnsAndColumnFilter(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            controller = gwidgets.internal.FilterController(Parent=fig);
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            controller.AllColumnsCheckBox.Value = true;
            [filteredAll, idxAll, statusAll] = controller.applyFilter(data, "alp");

            testCase.verifyEqual(idxAll, [true; false; true; false])
            testCase.verifyEqual(filteredAll.Name, ["alpha"; "alphabet"])
            testCase.verifyTrue(statusAll)
            testCase.verifyEqual(string(controller.MatchesLabel.Text), "2/4 matches found")

            controller.AllColumnsCheckBox.Value = false;
            [filteredColumn, idxColumn, statusColumn] = controller.applyFilter(data, "Value>2");

            testCase.verifyEqual(idxColumn, [false; false; true; true])
            testCase.verifyEqual(filteredColumn.Value, [3; 4])
            testCase.verifyTrue(statusColumn)
            testCase.verifyTrue(ismember("Value>2", string(controller.FilterDropDown.Items)))
        end

        function tUiCategoricalDateHelpAndFilterEditedCallbacks(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            helpGrid = uigridlayout(fig, [1, 1]);
            controller = gwidgets.internal.FilterController(Parent=fig, HelpParent=helpGrid);
            changed = listener(controller, "FilterChanged", @(~, ~)setappdata(fig, "FilterChanged", true));
            requested = listener(controller, "FilterHelpRequested", @(~, ~)setappdata(fig, "HelpRequested", true));
            closed = listener(controller, "FilterHelpClosed", @(~, ~)setappdata(fig, "HelpClosed", true));
            testCase.addTeardown(@()delete([changed, requested, closed]));

            controller.CategoricalVariables = ["A", "B"];
            controller.Datepicker.Value = datetime(2024, 1, 2);
            controller.onDateSelected([], []);
            controller.FilterDropDown.Value = "Value>2";
            controller.onFilterEdited([], []);
            controller.HelpButton.ButtonPushedFcn([], []);
            controller.CloseHelpButton.ButtonPushedFcn([], []);

            testCase.verifyEqual(controller.ShowCategoriesButton.Enable, matlab.lang.OnOffSwitchState.on)
            testCase.verifyEqual(string(controller.CategoriesListBox.Items), ["A", "B"])
            testCase.verifyEqual(controller.FilterValue, "Value>2")
            testCase.verifyEqual(getappdata(fig, "FilterChanged"), true)
            testCase.verifyEqual(getappdata(fig, "HelpRequested"), true)
            testCase.verifyEqual(getappdata(fig, "HelpClosed"), true)
            testCase.verifyEmpty(controller.HelpPanel.Parent)
        end

        function tUiCategoryCallbackAppendsValue(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            controller = gwidgets.internal.FilterController(Parent=fig);

            controller.CategoricalVariables = ["A", "B"];
            controller.FilterDropDown.Value = "Group=";
            controller.CategoriesListBox.Value = "B";
            controller.CategoriesListBox.ValueChangedFcn([], []);
            controller.expand(true);
            controller.expand(false);

            testCase.verifyEqual(string(controller.FilterDropDown.Value), "Group=B")
            testCase.verifyEqual(controller.ShowCategoriesButton.Enable, matlab.lang.OnOffSwitchState.on)
        end

        function tUiCallbacksReturnWhenUnparented(testCase)
            controller = gwidgets.internal.FilterController();

            testCase.verifyWarningFree(@()controller.onClearHistoryButtonPushed([], []))
            testCase.verifyWarningFree(@()controller.onSaveHistoryButtonPushed([], []))
            testCase.verifyWarningFree(@()controller.onLoadHistoryButtonPushed([], []))
        end

        function tTableFilterAdapterDetachedState(testCase)
            controller = gwidgets.internal.table.FilterController();

            controller.FilterValue = "Value>2";
            controller.CategoricalVariables = ["A", "B"];

            testCase.verifyEqual(controller.FilterValue, "Value>2")
            testCase.verifyEqual(controller.CategoricalVariables, ["A", "B"])
            testCase.verifyEmpty(controller.FilterDropDown)
        end

        function tTableFilterAdapterDelegatesToComponent(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            parentGrid = uigridlayout(fig, [1, 1]);
            helpGrid = uigridlayout(fig, [1, 1]);
            component = gwidgets.internal.FilterController(Parent=parentGrid, HelpParent=helpGrid);
            controller = gwidgets.internal.table.FilterController(gwidgets.UITable.empty(1,0), component);
            data = test.unit.gwidgets.internal.tFilterController.exampleData();

            controller.setLayout(1, 1);
            controller.expand(true);
            controller.FilterValue = "Value>2";
            controller.CategoricalVariables = ["A", "B"];
            [filteredData, idx, status] = controller.applyFilter(data);

            testCase.verifyEqual(filteredData.Value, [3; 4])
            testCase.verifyEqual(idx, [false; false; true; true])
            testCase.verifyTrue(status)
            testCase.verifyEqual(controller.FilterValue, "Value>2")
            testCase.verifyNotEmpty(controller.FilterDropDown)
            testCase.verifyEqual(controller.CategoricalVariables, ["A", "B"])
        end

        function tTableFilterAdapterForwardsEvents(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            component = gwidgets.internal.FilterController(Parent=fig);
            controller = gwidgets.internal.table.FilterController(gwidgets.UITable.empty(1,0), component);
            changed = listener(controller, "FilterChanged", @(~, ~)setappdata(fig, "FilterChanged", true));
            requested = listener(controller, "FilterHelpRequested", @(~, ~)setappdata(fig, "HelpRequested", true));
            closed = listener(controller, "FilterHelpClosed", @(~, ~)setappdata(fig, "HelpClosed", true));
            testCase.addTeardown(@()delete([changed, requested, closed]));

            component.FilterDropDown.Value = "Value>1";
            component.onFilterEdited([], []);
            component.HelpButton.ButtonPushedFcn([], []);
            component.CloseHelpButton.ButtonPushedFcn([], []);

            testCase.verifyEqual(getappdata(fig, "FilterChanged"), true)
            testCase.verifyEqual(getappdata(fig, "HelpRequested"), true)
            testCase.verifyEqual(getappdata(fig, "HelpClosed"), true)
        end
    end

    methods (Static, Access = private)
        function data = exampleData()
            data = table( ...
                [1; 2; 3; 4], ...
                ["alpha"; "beta"; "alphabet"; "delta"], ...
                categorical(["A"; "B"; "A"; "B"]), ...
                [true; false; true; false], ...
                datetime(2024, 1, (1:4)'), ...
                days([1; 2; 3; 4]), ...
                VariableNames=["Value", "Name", "Group", "Flag", "When", "Elapsed"]);
            data.Elapsed.Format = "d";
        end
    end
end
