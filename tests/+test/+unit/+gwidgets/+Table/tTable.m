classdef tTable < matlab.uitest.TestCase & test.WithFigureFixture

    properties (TestParameter)
        GroupVariable = struct("NoGrouping", "", "Group1", "Var1", "Group2", "Var2")
        Filtering = struct("NoFilter", "", "LargeVar1", "Var1>5")
        Selection = struct("Row", "row", "Cell", "cell", "Column", "column")

        StyleTarget = struct("table", "table", "row", "row", "column", "column", "cell", "cell")
        SelectionMode = struct("Data", "Data", "Display", "Display")
    end

    properties
        ExpectedSelectionDict
    end

    methods (TestClassSetup)

        function setup(this)
            this.ExpectedSelectionDict = dictionary();

            groups = struct2cell(this.GroupVariable);
            filters = struct2cell(this.Filtering);
            selections = struct2cell(this.Selection);

            dataSelection = [3,2];

            %% Row selection
            selection = "row";

            group = "";
            filter = "";
            displaySelection = [3,2];
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "";
            filter = "Var1>5";
            displaySelection = zeros(1,0);
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var1";
            filter = "";
            displaySelection = [6,4];
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var1";
            filter = "Var1>5";
            displaySelection = zeros(1,0);
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var2";
            filter = "";
            displaySelection = [3,7];
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var2";
            filter = "Var1>5";
            displaySelection = zeros(1,0);
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            %% Cell selection
            selection = "cell";

            group = "";
            filter = "";
            displaySelection = [3,2];
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "";
            filter = "Var1>5";
            displaySelection = zeros(0,2);
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var1";
            filter = "";
            displaySelection = [6,1];
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var1";
            filter = "Var1>5";
            displaySelection = zeros(0,2);
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var2";
            filter = "";
            displaySelection = zeros(0,2);
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var2";
            filter = "Var1>5";
            displaySelection = zeros(0,2);
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            %% Column selection
            selection = "column";
            dataSelection = 2;

            group = "";
            filter = "";
            displaySelection = 2;
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "";
            filter = "Var1>5";
            displaySelection = 2;
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var1";
            filter = "";
            displaySelection = 1;
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var1";
            filter = "Var1>5";
            displaySelection = 1;
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var2";
            filter = "";
            displaySelection = zeros(1,0);
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            group = "Var2";
            filter = "Var1>5";
            displaySelection = zeros(1,0);
            this.ExpectedSelectionDict({[dataSelection, group, filter, selection]}) = {displaySelection};

            % Ensure everything is defined
            for iGroup = 1:numel(groups)
                for iFilter = 1:numel(filters)
                    for iSelection = 1:numel(selections)
                        group = groups{iGroup};
                        filter = filters{iFilter};
                        selection = selections{iSelection};

                        switch selection
                            case {"row", "cell"}
                                dataSelection = [3,2];
                            case "column"
                                dataSelection = 2;
                        end

                        try
                            val = this.ExpectedSelectionDict({[dataSelection, group, filter, selection]});
                        catch
                            warning("Combination [Group: %s, Filter: %s, Selection: %s] not defined", group, filter, selection);
                        end
                    end
                end
            end
        end
    end

    % Creation and destruction
    methods (Test)
        
        function tCreationNoParent(testCase)
            
            t = testCase.verifyWarningFree(@() gwidgets.Table());
            testCase.verifyEqual(t.Data, table.empty(0,0));

        end

        function tDeletionClearsUpChildren(testCase)
            
            fh = testCase.figureFixture(Type="uifigure");

            t = gwidgets.Table("Parent", fh);

            delete(t);

            % All children should be cleaned up from the figure
            children = findobj(fh, "-not", "Type", "figure");
            testCase.verifyEmpty(children);

        end

    end

    % Standard interaction
    methods (Test)

        function tSetGetData(testCase)

            tbl = gwidgets.Table();

            data = testCase.defaultData();
            tbl.Data = data;

            testCase.verifyEqual(tbl.Data, data);
        end

        function tSetGetColumnWidth(testCase)

            numericWidths = {100 100};

            fh = testCase.figureFixture("Type", "uifigure");
            tbl = testCase.defaultTable("Parent", fh);
            tbl.ColumnWidth = numericWidths;

            testCase.verifyEqual(tbl.ColumnWidth, numericWidths);

        end

        function tSetGetColumnNames(testCase)

            names = ["test1", "test2"];

            fh = testCase.figureFixture("Type", "uifigure");
            tbl = testCase.defaultTable("Parent", fh);
            tbl.ColumnNames = names;

            testCase.verifyEqual(tbl.ColumnNames, names);

        end

        function tSetGetColumnVisible(testCase)

            fh = testCase.figureFixture("Type", "uifigure");
            tbl = testCase.defaultTable("Parent", fh);

            % Set visibility for all columns
            tf = false(1, width(tbl.Data));
            tbl.ColumnVisible = tf;

            % Verify behaviour
            testCase.verifyEqual(tbl.ColumnVisible, tf);

            % Set visibility for all columns
            tf = [true,false(1, (width(tbl.Data))-1)];
            tbl.ColumnVisible = tf;

            % Verify behaviour
            testCase.verifyEqual(tbl.ColumnVisible, tf);

        end

        function tSetGetHiddenColumnNames(testCase)

            fh = testCase.figureFixture("Type", "uifigure");
            tbl = testCase.defaultTable("Parent", fh);

            % Hide first column
            hiddenCols = "Var1";
            tbl.HiddenColumnNames = hiddenCols;

            testCase.verifyEqual(tbl.HiddenColumnNames, hiddenCols);

            % Hide multiple columns 
            hiddenCols = ["Var1", "Var2"];
            tbl.HiddenColumnNames = hiddenCols;

            testCase.verifyEqual(tbl.HiddenColumnNames, hiddenCols);

        end

        function tCanOpenAndCloseGroups(testCase)

            fh = testCase.figureFixture("Type", "uifigure");
            tbl = testCase.defaultTable("Parent", fh);
            % Table already has GroupingVariable="Var2" set in defaultTable

            % How many groups are there?
            nGroups = numel(unique(tbl.Data.Var2));

            % Close all groups first
            tbl.closeAllGroups();

            % Verify all groups are closed - DisplayData should equal number of groups
            testCase.verifyEqual(height(tbl.DisplayData), nGroups);

            % Open all groups
            tbl.openAllGroups();

            % Verify all groups are open - DisplayData should contain all data rows
            testCase.verifyEqual(height(tbl.DisplayData), height(tbl.Data)+ nGroups);

        end
        
    end

    % Data selection interplay with grouping and filtering
    methods (Test)

        function tSetGetSelection_groupsOpen(testCase, GroupVariable, Filtering, Selection)
 
            fh = testCase.figureFixture("Type", "uifigure");
            tbl = testCase.defaultTable("Parent", fh);
            tbl.GroupingVariable = GroupVariable;
            tbl.Filter = Filtering;
            tbl.SelectionType = Selection;
            tbl.openAllGroups();

            switch Selection
                case {"row", "cell"}
                    dataSelection = [3,2];
                case "column"
                    dataSelection = 2;
            end
            
            tbl.Selection = dataSelection;

             % Verify expected display selection is set when data selection is set
             val = testCase.ExpectedSelectionDict({[dataSelection, GroupVariable, Filtering, Selection]});
             displaySelection = val{1};
            
            testCase.verifyEqual(tbl.Selection, dataSelection, "Data selection not as expected");
            testCase.verifyEqual(tbl.DisplaySelection, displaySelection, "Display selection not as expected");

            % Verify expected data selection is set when display selection is set

            if ~isempty(displaySelection)

                tbl.DisplaySelection = displaySelection;

                testCase.verifyEqual(tbl.Selection, dataSelection, "Data selection not as expected");
                testCase.verifyEqual(tbl.DisplaySelection, displaySelection, "Display selection not as expected");

            end

        end 

    end

    methods (Static)

        function tbl = defaultTable(nvp)
            arguments
                nvp.Parent = []
            end

            data = test.unit.gwidgets.Table.tTable.defaultData();
            tbl = gwidgets.Table(Parent=nvp.Parent, Data=data, SelectionType="row", ShowRowFilter=true, ShowEmptyGroups=false, GroupingVariable="Var2");

        end

        function data = defaultData()
            data = table((1:10)', ["a","b","a","b","c","a","c", "c", "c", "a"]');
        end

    end

end