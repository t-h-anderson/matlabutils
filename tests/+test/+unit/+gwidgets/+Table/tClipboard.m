classdef tClipboard < matlab.unittest.TestCase
    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (TestMethodSetup)
        function preserveFigures(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tSelectedRowsFollowDisplayedSortOrder(testCase, Backend)
            t = createTable(testCase, Backend);
            t.Sort.By = "Name";
            t.Sort.Direction = "Descend";
            t.Selection = [1 3];

            text = t.Clipboard.copySelection();

            testCase.verifyEqual(text, string(sprintf('C\t30\nB\t20')));
            testCase.verifyEqual(getappdata(ancestor(t.UITable, 'figure'), "CopiedText"), text);
        end

        function tVisibleCopyUsesFilterAndHidesInternalColumns(testCase, Backend)
            t = createTable(testCase, Backend);
            t.Filter = "Value>10";
            t.Column.HiddenDataNames = "Value";
            t.Column.Names = ["Display Name", "Value"];

            text = t.Clipboard.selectionText(AllVisible=true, IncludeHeaders=true);

            testCase.verifyEqual(text, "Display Name" + newline + "B" + newline + "C");
        end

        function tSparseCellSelectionLeavesOtherCellsEmpty(testCase, Backend)
            t = createTable(testCase, Backend);
            t.SelectionType = "cell";
            t.Sort.By = "Name";
            t.Sort.Direction = "Ascend";
            t.Selection = [2 1; 1 2];

            text = t.Clipboard.selectionText();

            testCase.verifyEqual(text, string(sprintf('A\t\n\t20')));
        end

        function tCopyEscapesTabsNewlinesAndQuotes(testCase, Backend)
            t = createTable(testCase, Backend);
            t.Data = table(["A" + char(9) + "B"; "Line1" + newline + "Line2"; 'He said "Hi"'], ...
                [1; 2; 3], VariableNames=["Name", "Value"]);
            t.Selection = [1 2 3];

            text = t.Clipboard.selectionText();

            testCase.verifyEqual(text, string(sprintf('"A\tB"\t1\n"Line1\nLine2"\t2\n"He said ""Hi"""\t3')));
        end

        function tVectorValuedVariableStaysInOneCell(testCase, Backend)
            t = createTable(testCase, Backend);
            t.Data = table(["A"; "B"], [1 2; 3 4], VariableNames=["Name", "Value"]);

            text = t.Clipboard.selectionText(AllVisible=true, IncludeHeaders=true);

            testCase.verifyEqual(text, string(sprintf('Name\tValue\nA\t1 2\nB\t3 4')));
        end

        function tNoSelectionLeavesClipboardUntouched(testCase, Backend)
            t = createTable(testCase, Backend);
            figure = ancestor(t.UITable, 'figure');
            setappdata(figure, "CopiedText", "Existing clipboard");

            text = t.Clipboard.copySelection();

            testCase.verifyEqual(text, "");
            testCase.verifyEqual(getappdata(figure, "CopiedText"), "Existing clipboard");
        end

        function tControlCDoesNotReplaceUserKeyCallback(testCase, Backend)
            t = createTable(testCase, Backend);
            figure = ancestor(t.UITable, 'figure');
            t.Selection = 2;
            t.Callback.KeyPress = @(~,~) setappdata(figure, "UserKeyCallback", true);

            t.UITable.Callback.onKeyPress([], ...
                struct('Key', 'c', 'Character', 'c', 'Modifier', {{'control'}}));

            testCase.verifyEqual(getappdata(figure, "CopiedText"), string(sprintf('A\t10')));
            testCase.verifyTrue(getappdata(figure, "UserKeyCallback"));
        end

        function tContextMenuCopiesSelection(testCase, Backend)
            t = createTable(testCase, Backend);
            t.Selection = 1;

            selectCopyMenu(t, "Copy selection");

            testCase.verifyEqual(getappdata(ancestor(t.UITable, 'figure'), "CopiedText"), ...
                string(sprintf('B\t20')));
        end

        function tContextMenuCopiesVisibleTableWithHeaders(testCase, Backend)
            t = createTable(testCase, Backend);

            selectCopyMenu(t, "Copy visible table");

            testCase.verifyEqual(getappdata(ancestor(t.UITable, 'figure'), "CopiedText"), ...
                string(sprintf('Name\tValue\nB\t20\nA\t10\nC\t30')));
        end
    end
end

function selectCopyMenu(t, text)
switch t.Backend
    case "JavaScript"
        t.UITable.Graphics.Backend.probeBrowser("SelectContextMenuItem", ...
            struct("row", 1, "col", 1, "path", text));
    otherwise
        item = findall(t.ContextMenu, Text=text);
        callback = item.MenuSelectedFcn;
        callback(item, []);
end
end

function t = createTable(testCase, backend)
figure = uifigure(Visible="off");
testCase.addTeardown(@() delete(figure));
t = gwidgets.Table(Parent=uigridlayout(figure, [1 1]), Render=backend, ...
    Data=table(["B"; "A"; "C"], [20; 10; 30], VariableNames=["Name", "Value"]), ...
    SelectionType="row", Multiselect="on");
testCase.addTeardown(@() delete(t));
t.Clipboard.WriteFcn = @(value) setappdata(figure, "CopiedText", value);
t.Column.Sortable = true;
end
