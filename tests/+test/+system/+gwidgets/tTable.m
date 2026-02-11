classdef tTable < matlab.uitest.TestCase & test.WithFigureFixture & test.WithExampleTables
    % UI system tests for Table to test complex end-to-end workflows.

    methods (Test)

        function tInstantiateTable(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;
            
            testCase.verifyEqual(tab.DisplayData, t.Data)
        end

        function tSimpleGroupAndFold(testCase)
            % Group and fold, first programmatically then interactively.
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;

            t.GroupingVariable = "Gender";
            testCase.assertSize(tab.DisplayData, [2 9])
            testCase.verifyEqual(tab.DisplayData{1,1}, "⮞ Female (53/53)")

            t.OpenGroups = "Male";
            testCase.verifySize(tab.DisplayData, [49 9])
            testCase.verifyEmpty(findall(fh, Type="uimenu"));

            t.HasChangeGroupingVariable = true;
            groupmenu = findall(fh, Type="uimenu", Text="Group");
            ungroupmenu = findall(fh, Type="uimenu", Text="Ungroup");

            % Ungroup by right click on a cell.
            testCase.chooseContextMenu(tab, ungroupmenu, [5 5])
            testCase.verifySize(tab.DisplayData, [100 10])

            % Group via right click on a cell.
            testCase.chooseContextMenu(tab, groupmenu, [3 1])
            testCase.verifySize(tab.DisplayData, [3 9])

            % Ungroup by right click on a header.
            testCase.chooseContextMenu(fh, ungroupmenu, [360 340])
            testCase.verifySize(tab.DisplayData, [100 10])

            % Group by right click on a header.
            testCase.chooseContextMenu(fh, groupmenu, [350 360])
            testCase.verifySize(tab.DisplayData, [4 9])
        end

        function tSimpleFiltering(testCase)
            % Apply a filter, first programmatically then interactively.
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;

            t.Filter = "Gender=Male";
            testCase.verifySize(tab.DisplayData, [47 10])
            testCase.verifyTrue(all(tab.DisplayData.Gender == "Male"))
            
            t.expandFilterController();

            testCase.type(t.FilterController.FilterDropDown, "Gender=Female")
            testCase.verifySize(tab.DisplayData, [53 10])

            testCase.type(t.FilterController.FilterDropDown, "IncorrectFilter")
            testCase.verifySize(tab.DisplayData, [100 10])

            testCase.type(t.FilterController.FilterDropDown, "LastName=X")
            testCase.verifySize(tab.DisplayData, [0 10])

            testCase.type(t.FilterController.FilterDropDown, "LastName=Johnson")
            testCase.verifySize(tab.DisplayData, [1 10])            

            testCase.type(t.FilterController.FilterDropDown, "Age<30")
            testCase.verifySize(tab.DisplayData, [15 10])

            testCase.type(t.FilterController.FilterDropDown, "SelfAssessedHealthStatus=Fair")
            testCase.verifySize(tab.DisplayData, [15 10])

            testCase.type(t.FilterController.FilterDropDown, "Weight>190")
            testCase.verifySize(tab.DisplayData, [6 10])

            testCase.type(t.FilterController.FilterDropDown, "Smoker=true")
            testCase.verifySize(tab.DisplayData, [34 10])
        end

        function tSimpleSelection(testCase)
            % Select cells / rows / columns, both interactively and
            % programmatically.
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;

            t.Selection = [2 2];
            testCase.verifyEqual(tab.SelectionType, 'cell')
            testCase.verifyEqual(tab.Selection, [2 2])
            testCase.verifyEqual(t.DisplaySelection, [2 2])

            testCase.choose(tab, [4 4]) % select cell
            testCase.verifyEqual(t.Selection, [4 4])
            testCase.verifyEqual(t.DisplaySelection, [4 4])

            t.SelectionType = "column";
            testCase.verifyEmpty(tab.Selection);
            testCase.verifyEqual(tab.SelectionType, 'column')

            testCase.choose(tab, [3 3]) % select column by clicking on cell
            testCase.verifyEqual(t.Selection, 3)
            testCase.verifyEqual(t.DisplaySelection, 3)
            testCase.verifyEqual(tab.Selection, 3)

            % TODO: Unstable with different resolutions
            % Need to enhance uitable for click on column header
            % testCase.press(fh, [350 355]) % select column by clicking on header
            % testCase.verifyEqual(t.Selection, 5)
            % testCase.verifyEqual(t.DisplaySelection, 5)
            % testCase.verifyEqual(tab.Selection, 5)

            t.Selection = 1; % select column programmatically
            testCase.verifyEqual(tab.Selection, 1)
            testCase.verifyEqual(t.DisplaySelection, 1)

            t.SelectionType = "row";
            testCase.verifyEmpty(tab.Selection);
            testCase.verifyEqual(tab.SelectionType, 'row')

            testCase.choose(tab, [4 4]) % select row by clicking on cell
            testCase.verifyEqual(t.Selection, 4)
            testCase.verifyEqual(t.DisplaySelection, 4)
            testCase.verifyEqual(tab.Selection, 4)

            t.Selection = 3; % select row programmatically
            testCase.verifyEqual(tab.Selection, 3)
            testCase.verifyEqual(t.DisplaySelection, 3)
        end

        function tMultiSelect(testCase)
            % Test switching between selection modes from the context menus
            % and multi-selecting rows / cells / columns both
            % programmatically and interactively.
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;

            testCase.verifyEmpty(findall(fh, Type="uimenu"));
            t.SupportedSelectionTypes = ["cell", "row"];
            testCase.verifyEmpty(findall(fh, Type="uimenu", Text="Column"));
            testCase.verifyNotEmpty(findall(fh, Type="uimenu", Text="Row"));
            t.SupportedSelectionTypes = ["cell", "row", "column"];

            testCase.verifyEqual(tab.Multiselect, matlab.lang.OnOffSwitchState.on)
            testCase.choose(tab, [2 2; 3 3], SelectionMode="contiguous") % select 2 cells (shift+click)
            testCase.verifyEqual(t.Selection, [2 2; 2 3; 3 2; 3 3])
            testCase.verifyEqual(t.DisplaySelection, [2 2; 2 3; 3 2; 3 3])
            testCase.verifyEqual(tab.Selection, [2 2; 2 3; 3 2; 3 3])

            t.Selection = [2 2; 4 4]; % select 2 cells programmatically
            testCase.verifyEqual(t.DisplaySelection, [2 2; 4 4])
            testCase.verifyEqual(tab.Selection, [2 2; 4 4])

            columnmenu = findall(fh, Type="uimenu", Text="Column");
            testCase.chooseContextMenu(fh, columnmenu, [350 360])
            testCase.verifyEqual(tab.SelectionType, 'column')

            % TODO: Unstable with different resolutions
            % Need to enhance uitable for click on column header
            % testCase.press(fh, [100 360]) % select 4 columns by shift+click on headers
            % testCase.press(fh, [350 360], SelectionType="extend")
            % testCase.verifyEqual(t.Selection, [2 3 4 5])
            % testCase.verifyEqual(t.DisplaySelection, [2 3 4 5])
            % testCase.verifyEqual(tab.Selection, [2 3 4 5])

            t.Selection = [1; 3]; % select 2 columns programmatically
            testCase.verifyEqual(t.DisplaySelection, [1 3])
            testCase.verifyEqual(tab.Selection, [1 3])
            
            rowmenu = findall(fh, Type="uimenu", Text="Row");
            testCase.chooseContextMenu(tab, rowmenu, [3 3])
            testCase.verifyEqual(tab.SelectionType, 'row')

            testCase.choose(tab, [2 2; 4 4], SelectionMode="contiguous") % select 3 rows (shift+click)
            testCase.verifyEqual(t.Selection, [2 3 4])
            testCase.verifyEqual(t.DisplaySelection, [2 3 4])
            testCase.verifyEqual(tab.Selection, [2 3 4])

            t.Selection = [1; 5]; % select 2 rows programmatically
            testCase.verifyEqual(t.DisplaySelection, [1 5])
            testCase.verifyEqual(tab.Selection, [1 5])
        end

        function tSimpleSorting(testCase)
            % Test sorting table columns, both programmatically and
            % interactively.
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;

            t.SortDirection = "Ascend";            
            t.ColumnSortable = true;
            t.HasColumnSorting = true;
            t.SortByColumn = "Age"; % sort programmatically
            testCase.verifyEqual(tab.DisplayData.Age(1:3), int16([25 25 25])')

            ascendmenu = findall(fh, Type="uimenu", Text="Descending");
            testCase.choose(tab, [1,4])
            testCase.chooseContextMenu(tab, ascendmenu, [1 4])

            testCase.verifyEqual(t.SortDirection, "Descend")
            testCase.verifyEqual(tab.DisplayData.Age(1:3), int16([50 50 49])')
            testCase.verifyEqual(t.DisplayData.Age(1:3), int16([50 50 49])')

            nonemenu = findall(fh, Type="uimenu", Text="None");
            testCase.chooseContextMenu(tab, nonemenu, [1 4])
            testCase.verifyEqual(t.SortDirection, "None")
            testCase.verifyEqual(tab.DisplayData.Age(1:3), t.Data.Age(1:3))
            testCase.verifyEqual(t.DisplayData.Age(1:3), t.Data.Age(1:3))
        end

        function tMultiVariableGrouping(testCase)
            % Test grouping mulitple variables, both programmatically and
            % interactively.
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;

            t.GroupingVariable = ["Gender", "Location"]; % programmatic grouping
            testCase.verifyEqual(tab.DisplayData.Properties.VariableNames{1}, 'LastName')
            testCase.verifyEqual(tab.DisplayData.LastName(3), "⮞ Female|VA Hospital (19/19)")
            testCase.verifyEqual(tab.DisplayData.Age(2), {double.empty(0,0)})
            testCase.verifySize(tab.DisplayData, [6 8])

            t.HasChangeGroupingVariable = true;
            groupmenu = findall(fh, Type="uimenu", Text="Group");
            ungroupmenu = findall(fh, Type="uimenu", Text="Ungroup");

            testCase.chooseContextMenu(tab, ungroupmenu, [2,3]); % ungroup interactively
            testCase.verifyEmpty(t.Groups)
            testCase.verifySize(tab.DisplayData, [100 10])

            testCase.choose(tab, [2 2; 3 5]) % multiselect
            testCase.chooseContextMenu(tab, groupmenu, [3,5]); % group interactively
            testCase.verifyEqual(t.GroupingVariableName, "Gender|SelfAssessedHealthStatus")
            testCase.verifySize(tab.DisplayData, [8 8])

            % TODO: Unstable with different resolutions
            % Need to enhance uitable for click on column header
            % pause(1)
            % t.SelectionType = "column";
            % testCase.press(fh, [280 330]) % select 2 columns by shift+click on headers
            % testCase.press(fh, [350 330], SelectionType="extend")
            % testCase.chooseContextMenu(fh, groupmenu, [280 330]); % group interactively
            % testCase.verifyEqual(t.GroupingVariableName, "Age|Height")
            % testCase.verifySize(tab.DisplayData, [80 8])
        end

        function tApplyStyles(testCase)
            % Apply table styles, in combination with grouping, sorting and
            % filtering.
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;

            s1 = uistyle(FontColor="blue", BackgroundColor="red");
            t.addStyle(s1, "cell", [10 3; 1 2]); % add cell style programmatically
            testCase.verifyEqual(tab.StyleConfigurations.Target(1), categorical("cell"))
            testCase.verifyEqual(tab.StyleConfigurations.TargetIndex{1}, [10 3; 1 2])
            testCase.verifyEqual(tab.DisplayData{10,3}, "Turner")

            t.GroupingVariable = "Gender"; % results in 2 rows
            t.OpenGroups = "Male";
            testCase.verifyEqual(tab.DisplayData{12,2}{1}, "Turner")
            testCase.verifyEqual(tab.StyleConfigurations.TargetIndex{1}, [12 2])

            s2 = uistyle(FontColor="red", BackgroundColor="green");
            t.addStyle(s2, "column", [1, 2]); % add column style programmatically
            testCase.verifyEqual(tab.StyleConfigurations.TargetIndex{2}, 1) % Column 2 is the group Gender so no styling

            tab.addStyle(s2, "column", [1 4]); % add temp column style directly to uitable
            testCase.verifyEqual(tab.StyleConfigurations.TargetIndex{4}, [1 4])
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{4}, [1 4])

            tab.addStyle(s2, "column", 5); % add another temp column style directly to uitable
            testCase.verifyEqual(tab.StyleConfigurations.TargetIndex{4}, [1 4]) % unchanged
            testCase.verifyEqual(tab.StyleConfigurations.TargetIndex{5}, 5)

            s3 = uistyle(FontColor="blue", BackgroundColor="blue");
            t.addStyle(s3, "column", 3); % add column style programmatically, this overrides the uitable styles
            testCase.verifySize(tab.StyleConfigurations, [4 3])
            testCase.verifyEqual(tab.StyleConfigurations.TargetIndex{3}, 2) % One group changes the index

            % Hiding the first column decrements each column index
            t.HiddenColumnNames = "Location";
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, double.empty(1,0));
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{3}, 1);
        end

        function tColumnChanges(testCase)
            % Change column aliases and hide columns.
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);

            t.HiddenColumnNames = ["Location", "Age"];
            t.ColumnNames(1) = "NotLocation";

            testCase.verifyEqual(t.HiddenColumnNames, ["NotLocation", "Age"]);
            testCase.verifyEqual(t.HiddenDataColumnNames, ["Location", "Age"]);
        end

        function tEditTableDataWithStyling(testCase)
            % Change the data in the table programmatically and from the
            % UI.
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);

            s1 = uistyle(FontColor="blue", BackgroundColor="red");
            t.addStyle(s1, "row", "Age>49"); % add cell style programmatically

            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [13 64]);

            t.Data.Age(13) = 20;

            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, 64);
        end

        function tCellSelectionCallback(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;
            
            t.CellSelectionCallback = @(s,e) groupbycolumn(s, e, t, "Gender");            
            testCase.choose(tab, [4 4]) % select cell

            testCase.verifyEqual(t.GroupingVariable, "Gender");
            testCase.verifySize(tab.DisplayData, [2 9])
        end

        function tCellClickedCallback(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;
            
            t.CellClickedCallback = @(s,e) groupbycolumn(s, e, t, "Smoker");            
            testCase.choose(tab, [10 2]) % select cell

            testCase.verifyEqual(t.GroupingVariable, "Smoker");
            testCase.verifySize(tab.DisplayData, [2 9])
        end

        function tCellEditCallback(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;
            
            t.ColumnEditable = true;            
            t.CellEditCallback = @(s,e) groupbycolumn(s, e, t, "Gender");            
            
            testCase.choose(tab, [6 2], "Female") % change cell value

            testCase.verifyEqual(t.GroupingVariable, "Gender");
            testCase.verifySize(tab.DisplayData, [2 9])
        end

        function tDisplayDataChangedCallback(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;
            
            t.DisplayDataChangedCallback = @(s,e) groupbycolumn(s, e, t, "Smoker");            
            
            t.ColumnSortable = true;

            % TODO: Unstable with different resolutions
            % Need to enhance uitable for click on column header
            % testCase.press(fh, [330 360]) % sort by clicking button on header
            % testCase.verifyEqual(t.GroupingVariable, "Smoker");
            % testCase.verifySize(tab.DisplayData, [2 9])
        end

        function tFilter_Select_HideColumn_Sort_RenameColumn_Group(testCase)
            % Complex system test combining many different operations.
            fh = testCase.figureFixture("Type", "uifigure");
            t = testCase.defaultTable(fh);
            tab = fh.Children(end).DisplayTable;

            t.expandFilterController();
            testCase.type(t.FilterController.FilterDropDown, "Gender=Male")
            testCase.verifySize(tab.DisplayData, [47, 10])

            t.SupportedSelectionTypes = ["cell", "row"];
            rowmenu = findall(fh, Type="uimenu", Text="Row");
            testCase.chooseContextMenu(tab, rowmenu, [3 3])
            testCase.choose(tab, [2 2; 4 4]) % select 2 rows (ctrl+click)
            testCase.verifyEqual(tab.Selection, [2 4])

            t.HiddenColumnNames = "Age";
            testCase.verifyFalse(ismember("Age", tab.DisplayData.Properties.VariableNames))

            t.ColumnSortable = true;
            t.HasColumnSorting = true;

            ascendmenu = findall(fh, Type="uimenu", Text="Ascending");
            testCase.choose(tab, [1 3]);
            testCase.chooseContextMenu(tab, ascendmenu, [1 3])
            testCase.verifyEqual(tab.DisplayData.LastName(1:2), ["Alexander", "Baker"]')

            t.ColumnNames(5) = "Health";
            testCase.verifyEqual(tab.DisplayData.Properties.VariableNames{4}, 'Health')

            t.HasChangeGroupingVariable = true;
            groupmenu = findall(fh, Type="uimenu", Text="Group");
            testCase.chooseContextMenu(tab, groupmenu, [3 4])
            testCase.verifyEqual(height(tab.DisplayData), 4)
        end

    end

end

function groupbycolumn(s, e, tab, column)
% e.Indices 
tab.GroupingVariable = column;
end