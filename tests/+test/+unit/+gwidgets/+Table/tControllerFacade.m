classdef tControllerFacade < matlab.unittest.TestCase

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tControllerPropertiesAreVisible(testCase)
            t = gwidgets.Table();

            propNames = string(properties(t));

            testCase.verifyTrue(ismember("Column", propNames))
            testCase.verifyTrue(ismember("Group", propNames))
            testCase.verifyTrue(ismember("Sort", propNames))
            testCase.verifyTrue(ismember("Style", propNames))
            testCase.verifyTrue(ismember("Menu", propNames))
            testCase.verifyTrue(ismember("Callback", propNames))
            testCase.verifyTrue(ismember("FilterControl", propNames))
            testCase.verifyTrue(ismember("SelectionControl", propNames))
            testCase.verifyTrue(ismember("TooltipControl", propNames))
            testCase.verifyTrue(ismember("Drag", propNames))
            testCase.verifyFalse(ismember("ColumnWidth", propNames))
            testCase.verifyFalse(ismember("GroupingVariable", propNames))
            testCase.verifyFalse(ismember("SortByColumn", propNames))
            testCase.verifyFalse(ismember("StyleConfigurations", propNames))
        end

        function tCreationAndCustomisationDoNotForceDrawnow(testCase)
            drawnowState = gwidgets.internal.Drawnow.make(true);
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));

            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            t.Parent = fig;
            t.Column.Width = {100, "2x", "1x", 80};
            t.FilterControl.FilterValue = "Var2>2";
            t.SelectionControl.Type = "row";
            t.SelectionControl.Value = 1;
            t.Style.add(uistyle(BackgroundColor=[0.8 0.9 1.0]), "row", 1);
            t.TooltipControl.Text = "row";

            testCase.verifyEqual(drawnowState.Total, 0)
            testCase.verifyEqual(drawnowState.Skipped, 0)
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

        function tGroupFacadeIsPrimaryApi(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.Group.By = "Group";
            t.Group.openAll();
            t.Group.ShowEmpty = true;

            testCase.verifyEqual(t.GroupingVariable, "Group")
            testCase.verifyEqual(t.GroupingVariableName, "Group")
            testCase.verifyEqual(t.Groups, ["A", "B"])
            testCase.verifyEqual(t.OpenGroups, ["A", "B"])
            testCase.verifyTrue(t.ShowEmptyGroups)
            testCase.verifyEqual(t.DisplayGroups, ["A", "B"])
            testCase.verifyEqual(t.DisplayData.Var1([2 3 5 6]), ["1"; "2"; "3"; "4"])
        end

        function tGroupControllerRequestMethodsAreLive(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.Group.requestGroupBy(3);
            t.Group.requestToggleShowEmpty();
            t.Group.updateLabel();

            testCase.verifyEqual(t.Group.By, "Group")
            testCase.verifyTrue(t.Group.ShowEmpty)
            testCase.verifyThat(t.GroupLabel.Text, ...
                matlab.unittest.constraints.ContainsSubstring("Group: Group"))

            t.Group.requestUngroup();

            testCase.verifyEmpty(t.Group.By)
        end

        function tGroupControllerUsesSelectionContext(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.SelectionControl.Type = "column";
            t.SelectionControl.DisplayValue = 3;
            t.Group.requestGroupBy(1);

            testCase.verifyEqual(t.Group.By, "Group")

            t.SelectionControl.Type = "cell";
            t.SelectionControl.DisplayValue = [1 1; 2 1];
            t.Group.requestGroupBy(3);

            testCase.verifyEqual(t.Group.By, "Var1")

            t.SelectionControl.Type = "row";
            t.SelectionControl.DisplayValue = 1;
            t.Group.requestGroupBy(3);

            testCase.verifyEqual(t.Group.By, "Flag")
        end

        function tGroupControllerTogglesHeaderRows(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            t.Group.By = "Group";
            t.Group.openAll();

            headerRows = t.UITable.Data.VisibleGroupHeaderRowIdx;
            t.Group.toggleOpenStateForRows(headerRows(1), headerRows);

            testCase.verifyEqual(t.Group.Open, "B")

            t.Group.toggleOpenStateForRows(999, headerRows);

            testCase.verifyEqual(t.Group.Open, "B")
        end

        function tSortFacadeIsPrimaryApi(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.Column.DataSortable = true;
            t.Sort.Direction = "Ascend";
            t.Sort.By = "Var2";

            testCase.verifyEqual(t.SortByColumn, "Var2")
            testCase.verifyEqual(t.SortDirection, "Ascend")
            testCase.verifyEqual(t.DisplayData.Var2, [1; 2; 3; 4])
            testCase.verifyEqual(t.DisplayData.Var1, [4; 3; 2; 1])
        end

        function tSortControllerContextRequestsAreLive(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            t.Column.DataSortable = true;

            t.SelectionControl.Type = "column";
            t.SelectionControl.DisplayValue = 2;
            t.Sort.requestSortByContext(1, 1, "Ascend");

            testCase.verifyEqual(t.Sort.By, "Var2")
            testCase.verifyEqual(t.Sort.Direction, "Ascend")

            t.SelectionControl.Type = "row";
            t.SelectionControl.DisplayValue = 1;
            t.Sort.requestSortByContext(1, 1, "Descend");

            testCase.verifyEqual(t.Sort.By, "Var1")
            testCase.verifyEqual(t.Sort.Direction, "Descend")
        end

        function tSortControllerByDataAndMissingInputsAreLive(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            t.Column.DataSortable = true;

            t.Sort.ByData = ["Var2", missing];

            testCase.verifyEqual(t.Sort.ByData, "Var2")
            testCase.verifyEqual(t.Sort.By, "Var2")
            testCase.verifyError( ...
                @()test.unit.gwidgets.Table.tControllerFacade.setSortByData(t.Sort, "MissingColumn"), ...
                "GraphicsWidgets:Table:NotASortableColumn")
        end

        function tFilterControlIsPrimaryApi(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.FilterControl.FilterValue = "Var2>2";

            testCase.verifyEqual(t.Filter, "Var2>2")
            testCase.verifyEqual(t.DisplayData.Var1, [1; 2])
            testCase.verifyEqual(t.DisplayData.Var2, [4; 3])
        end

        function tSelectionControlIsPrimaryApi(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.SelectionControl.Type = "row";
            t.SelectionControl.Value = 2;

            testCase.verifyEqual(t.SelectionType, 'row')
            testCase.verifyEqual(t.Selection, 2)

            t.SelectionControl.DisplayValue = 3;

            testCase.verifyEqual(t.DisplaySelection, 3)
        end

        function tTooltipControlIsPrimaryApi(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.TooltipControl.Text = "Default tooltip";
            t.TooltipControl.add("First value", "cell", [1 1]);

            testCase.verifyEqual(t.Tooltip, "Default tooltip")
            testCase.verifyNumElements(t.Tooltips, 1)

            t.TooltipControl.remove();

            testCase.verifyEmpty(t.Tooltips)
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

        function tUITableSelectionControllerDelegates(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            t.UITable.Selection.Type = "row";
            t.UITable.Selection.Value = 2;

            testCase.verifyEqual(t.UITable.Selection.Type, 'row')
            testCase.verifyEqual(t.UITable.Selection.Value, 2)
            testCase.verifyEqual(t.Selection, 2)

            t.UITable.Selection.DisplayValue = 3;

            testCase.verifyEqual(t.UITable.Selection.DisplayValue, 3)
            testCase.verifyEqual(t.DisplaySelection, 3)
        end

        function tCallbackFacadeDelegates(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            clicked = @(src, evt)disp(evt);
            edited = @(src, evt)disp(src);

            t.Callback.CellClicked = clicked;
            testCase.verifyEqual(t.CellClickedCallback, clicked)

            t.CellEditCallback = edited;
            testCase.verifyEqual(t.Callback.CellEdit, edited)
        end

        function tCallbackControllerInvokesDoubleClickAndEdit(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            t.Callback.CellDoubleClick = @(src, evt)setappdata(t.DisplayTable, "DoubleClickEvent", evt);
            t.Callback.CellEdit = @(src, evt)setappdata(t.DisplayTable, "EditEvent", evt);

            doubleClickEvent = struct( ...
                InteractionInformation=struct(DisplayRow=2, DisplayColumn=3));
            editEvent = struct( ...
                Indices=[1 2], ...
                DisplayIndices=[1 2], ...
                PreviousData=4, ...
                EditData=42, ...
                NewData=42);

            t.UITable.Callback.onCellDoubleClicked([], doubleClickEvent);
            t.UITable.Callback.onCellEdit([], editEvent);

            doubleClickData = getappdata(t.DisplayTable, "DoubleClickEvent");
            editData = getappdata(t.DisplayTable, "EditEvent");
            testCase.verifyEqual(doubleClickData.DisplayIndices, [2 3])
            testCase.verifyEqual(doubleClickData.Indices, [2 3])
            testCase.verifyEqual(editData.DisplayIndices, [1 2])
            testCase.verifyEqual(editData.NewData, 42)
            testCase.verifyEqual(t.Data.Var2(1), 42)
        end

        function tCallbackControllerAppliesDisplaySort(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            t.Column.DataSortable = true;
            t.Callback.DisplayDataChanged = @(src, evt)setappdata(t.DisplayTable, "DisplayChangedEvent", evt);
            eventData = struct(Interaction="sort", InteractionVariable="Var2");

            t.UITable.Callback.onDisplayDataChanged(t.UITable, eventData);
            testCase.verifyEqual(t.Sort.By, "Var2")
            testCase.verifyEqual(t.Sort.Direction, "Ascend")

            t.UITable.Callback.onDisplayDataChanged(t.UITable, eventData);
            testCase.verifyEqual(t.Sort.Direction, "Descend")

            t.UITable.Callback.onDisplayDataChanged(t.UITable, eventData);
            testCase.verifyEqual(t.Sort.Direction, "None")
            testCase.verifyEqual(getappdata(t.DisplayTable, "DisplayChangedEvent").InteractionVariable, "Var2")
        end

        function tCallbackControllerHandlesEmptyInteractionIndex(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            t.Callback.CellClicked = @(src, evt)setappdata(t.DisplayTable, "ClickedEvent", evt);
            eventData = struct( ...
                InteractionInformation=struct(DisplayRow=[], DisplayColumn=[]));

            t.UITable.Callback.onCellClicked([], eventData);

            clickedData = getappdata(t.DisplayTable, "ClickedEvent");
            testCase.verifyEqual(clickedData.DisplayIndices, zeros(0,2))
            testCase.verifyEqual(clickedData.Indices, zeros(0,2))
        end

        function tCallbackControllerInvokesSelection(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));

            t.Parent = fig;
            t.Callback.CellSelection = @(src, evt)setappdata(t.DisplayTable, "SelectionEvent", evt);
            source = struct(SelectionType="cell");
            eventData = struct(Indices=[2 3]);

            t.UITable.Callback.onSelection(source, eventData);

            selectionData = getappdata(t.DisplayTable, "SelectionEvent");
            testCase.verifyEqual(selectionData.DisplayIndices, [2 3])
            testCase.verifyEqual(selectionData.Indices, [2 3])
            testCase.verifyEqual(t.SelectionControl.DisplayValue, [2 3])
        end

        function tCallbackControllerSelectionWithoutCallback(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));

            t.Parent = fig;
            source = struct(SelectionType="cell");
            eventData = struct(Indices=[1 2]);

            t.UITable.Callback.onSelection(source, eventData);

            testCase.verifyEqual(t.SelectionControl.DisplayValue, [1 2])
            testCase.verifyFalse(isappdata(t.DisplayTable, "SelectionEvent"))
        end

        function tLegacyFacadeAccessorsRemainLive(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));

            t.Parent = fig;
            t.Units = "pixels";
            t.Position = [10 20 300 200];
            t.Visible = "off";
            t.DefaultTooltipStyle = gwidgets.table.TooltipStyle(BackgroundColor="#123");
            t.CellDoubleClickCallback = @(src, evt)disp(evt);
            t.DisplayDataChangedCallback = @(src, evt)disp(src);

            testCase.verifyEqual(t.Parent, fig)
            testCase.verifyEqual(t.Position, [10 20 300 200])
            testCase.verifyEqual(t.Units, 'pixels')
            testCase.verifyEqual(t.Visible, matlab.lang.OnOffSwitchState.off)
            testCase.verifyEqual(t.DefaultTooltipStyle.BackgroundColor, "#123")
            testCase.verifyNotEmpty(t.CellDoubleClickCallback)
            testCase.verifyNotEmpty(t.DisplayDataChangedCallback)
            testCase.verifyEqual(t.VisibleData, t.UITable.Data.Visible)
            testCase.verifyEmpty(t.Layout)
            testCase.verifyNotEmpty(t.Grid)
            testCase.verifyNotEmpty(t.GroupLabel)
            testCase.verifyNotEmpty(t.HelpPanel)
        end

        function tLegacyColumnAndMenuAccessorsRemainLive(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));

            t.Parent = fig;
            t.Column.Width = {100, "2x", "1x", 80};
            t.Column.Visible = [true false true true];
            t.Column.Editable = [true false true];
            t.Column.DataSortable = true;
            t.HasToggleFilter = false;
            t.HasToggleShowEmptyGroups = false;
            t.HasAutoResizeColumns = false;
            t.SupportedSelectionTypes = ["row", "cell"];
            item = uimenu(fig, Text="Export");
            t.addContextMenuItem(item);

            testCase.verifyEqual(t.RelativeDataColumnWidths, [missing, "2x", "1x", missing])
            testCase.verifyEqual(t.DataColumnEditable, [true false false true])
            testCase.verifyEqual(t.ColumnEditable, [true false true])
            testCase.verifyEqual(t.DataColumnSortable, true(1, 4))
            testCase.verifyEqual(t.HasToggleFilter, false)
            testCase.verifyEqual(t.HasToggleShowEmptyGroups, false)
            testCase.verifyEqual(t.HasAutoResizeColumns, false)
            testCase.verifyEqual(t.SupportedSelectionTypes, ["row", "cell"])
            testCase.verifyEqual(t.CustomContextMenuItems, item)
        end

        function tLegacyGroupingSortingAndBridgeAccessorsRemainLive(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();
            style = gwidgets.Table.defaultGroupHeaderStyle( ...
                uistyle(BackgroundColor=[0.3 0.4 0.5]));

            t.Group.By = "Group";
            t.Group.openAll();
            testCase.verifyEqual(t.Groups, ["A", "B"])
            t.HiddenGroups = "A";
            t.GroupHeaderStyle = style;
            t.Column.DataSortable = true;
            t.Sort.By = "Var2";
            t.BridgeDiagEnabled = true;

            testCase.verifyEmpty(t.HiddenGroups)
            testCase.verifyEqual(t.GroupHeaderStyle, style)
            testCase.verifyEqual(t.SortByDataColumn, "Var2")
            testCase.verifyTrue(t.BridgeDiagEnabled)
            testCase.verifyEqual(gwidgets.Table.gcdPixelWidths([12 18 24]), 6)
        end

        function tFindAndResetFacadeRemainLive(testCase)
            t = test.unit.gwidgets.Table.tControllerFacade.createTable();

            result = t.find("A", "table");
            t.Filter = "Var2>2";

            testCase.verifyNotEmpty(result)
            testCase.verifyWarningFree(@()t.reset())
            testCase.verifyEqual(t.Filter, "Var2>2")
            testCase.verifySize(t.Data, [4 4])
        end

        function tDataFacadeSplitsUITableAndLegacyTable(testCase)
            data = table((1:3).', ["a"; "b"; "c"], VariableNames=["Value", "Name"]);

            uiTable = gwidgets.UITable(Data=data);
            testCase.verifyInstanceOf(uiTable.Data, "gwidgets.internal.table.DataController")
            testCase.verifyEqual(uiTable.Data.Table, data)

            legacyTable = gwidgets.Table(Data=data);
            testCase.verifyInstanceOf(legacyTable.Data, "table")
            testCase.verifyEqual(legacyTable.Data, data)
            testCase.verifyEqual(legacyTable.UITable.Data.Table, data)
        end

        function tUITableControllerSurface(testCase)
            uiTable = gwidgets.UITable();
            propNames = string(properties(uiTable));

            testCase.verifyTrue(ismember("Filter", propNames))
            testCase.verifyTrue(ismember("Graphics", propNames))
            testCase.verifyFalse(ismember("Bridge", propNames))
            testCase.verifyFalse(ismember("Display", propNames))
            testCase.verifyFalse(ismember("DisplayTable", propNames))
            testCase.verifyFalse(ismember("Grid", propNames))
            testCase.verifyFalse(ismember("GroupLabel", propNames))
            testCase.verifyFalse(ismember("HelpPanel", propNames))
            testCase.verifyInstanceOf(uiTable.Filter, "gwidgets.internal.table.FilterController")
            testCase.verifyInstanceOf(uiTable.Graphics, "gwidgets.internal.table.GraphicsController")
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

        function setSortByData(sortController, value)
            sortController.ByData = value;
        end
    end
end
