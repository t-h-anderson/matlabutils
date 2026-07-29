classdef tEditingParity < matlab.unittest.TestCase
    % Cell-edit behaviour that both table backends must satisfy.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (Test)
        function tNumericEditUpdatesData(testCase, Backend)
            data = table([1; 2; 3], VariableNames="Value");
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = true;
            editEvent = [];
            t.CellEditCallback = @(~, evt)captureEdit(evt);

            testCase.simulateBackendEdit(t, [2 1], 42);

            testCase.verifyEqual(t.Data.Value(2), 42)
            testCase.verifyEqual(editEvent.DisplayIndices, [2 1])
            testCase.verifyEqual(editEvent.PreviousData, 2)
            testCase.verifyEqual(editEvent.NewData, 42)

            function captureEdit(evt)
                editEvent = evt;
            end
        end

        function tStringEditUpdatesHiddenColumnMapping(testCase, Backend)
            data = table([1; 2; 3], ["a"; "b"; "c"], VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = true;
            t.ColumnVisible = [false true];

            testCase.simulateBackendEdit(t, [2 1], "z");

            testCase.verifyEqual(t.Data.Label(2), "z")
            testCase.verifyEqual(t.Data.Value, [1; 2; 3])
        end

        function tLogicalEditCoercesValue(testCase, Backend)
            data = table([true; false; false], VariableNames="Flag");
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = true;

            testCase.simulateBackendEdit(t, [2 1], true);

            testCase.verifyEqual(t.Data.Flag, [true; true; false])
        end

        function tSortedDisplayEditMapsToSourceRow(testCase, Backend)
            data = table([3; 1; 2], VariableNames="Value");
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = true;
            t.ColumnSortable = true;
            t.Sort.By = "Value";
            t.Sort.Direction = "Ascend";

            testCase.simulateBackendEdit(t, [1 1], 10);

            testCase.verifyEqual(t.Data.Value, [3; 10; 2])
            testCase.verifyEqual(t.DisplayData.Value, [2; 3; 10])
        end

        function tFilteredSortedEditMapsSource(testCase, Backend)
            data = table( ...
                [3; 1; 4; 2], ...
                ["three"; "one"; "four"; "two"], ...
                VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = [false true];
            t.Filter = "Value>1";
            t.ColumnSortable = true;
            t.Sort.By = "Value";
            t.Sort.Direction = "Ascend";

            testCase.simulateBackendEdit(t, [1 2], "edited");

            testCase.verifyEqual(t.Data.Label, ["three"; "one"; "four"; "edited"])
            testCase.verifyEqual(t.DisplayData.Label, ["edited"; "three"; "four"])
        end

        function tScrolledDisplayEditUpdatesData(testCase, Backend)
            data = table((1:200)', "row_" + string((1:200)'), VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = [false true];

            testCase.simulateBackendEdit(t, [180 2], "edited");

            testCase.verifyEqual(t.Data.Label(180), "edited")
            testCase.verifyEqual(t.Data.Value(180), 180)
        end

        function tCopyCellSelectionUsesTabDelimitedRectangle(testCase, Backend)
            data = table(["a"; "b"; "c"], [1; 2; 3], VariableNames=["Label", "Value"]);
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.Selection = [1 1; 1 2; 2 1; 2 2];

            text = testCase.copySelection(t);

            testCase.verifyEqual(text, testCase.tabText(["a", "1"; "b", "2"]))
        end

        function tCopyRowSelectionUsesAllColumns(testCase, Backend)
            data = table(["a"; "b"; "c"], [1; 2; 3], VariableNames=["Label", "Value"]);
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.SelectionType = "row";
            t.Selection = [2 3];

            text = testCase.copySelection(t);

            testCase.verifyEqual(text, testCase.tabText(["b", "2"; "c", "3"]))
        end

        function tCopyColumnSelectionUsesAllRows(testCase, Backend)
            data = table(["a"; "b"; "c"], [1; 2; 3], VariableNames=["Label", "Value"]);
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.SelectionType = "column";
            t.Selection = [1 2];

            text = testCase.copySelection(t);

            testCase.verifyEqual(text, testCase.tabText(["a", "1"; "b", "2"; "c", "3"]))
        end

        function tPasteTabDelimitedTextAtCellSelection(testCase, Backend)
            data = table([1; 2; 3], ["a"; "b"; "c"], VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = true;
            t.Selection = [2 1];

            testCase.pasteText(t, testCase.tabText(["10", "x"; "20", "y"]));

            testCase.verifyEqual(t.Data.Value, [1; 10; 20])
            testCase.verifyEqual(t.Data.Label, ["a"; "x"; "y"])
        end

        function tPasteSkipsUneditableColumns(testCase, Backend)
            data = table([1; 2], ["a"; "b"], VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tEditingParity.createTable(testCase, Backend, data);
            t.ColumnEditable = [true false];
            t.Selection = [1 1];

            testCase.pasteText(t, testCase.tabText(["10", "x"]));

            testCase.verifyEqual(t.Data.Value, [10; 2])
            testCase.verifyEqual(t.Data.Label, ["a"; "b"])
        end
    end

    methods
        function simulateBackendEdit(testCase, t, displayIdx, newData)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tEditingParity
                t (1,1) gwidgets.Table
                displayIdx (1,2) double
                newData
            end

            switch t.Backend
                case "JavaScript"
                    t.UITable.Graphics.Backend.probeBrowser("ScrollToRow", struct("row", displayIdx(1)));
                    t.UITable.Graphics.Backend.probeBrowser("EditCell", struct( ...
                        "row", displayIdx(1), ...
                        "col", displayIdx(2), ...
                        "value", string(newData)));
                otherwise
                    previousData = t.DisplayData{displayIdx(1), displayIdx(2)};
                    editEvent = struct( ...
                        "Indices", displayIdx, ...
                        "DisplayIndices", displayIdx, ...
                        "PreviousData", previousData, ...
                        "EditData", newData, ...
                        "NewData", newData);
                    t.UITable.Callback.onCellEdit([], editEvent);
            end
            testCase.verifyEqual(string(t.Backend), string(t.UITable.Backend))
        end

        function text = copySelection(testCase, t)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tEditingParity
                t (1,1) gwidgets.Table
            end

            switch t.Backend
                case "JavaScript"
                    result = t.UITable.Graphics.Backend.probeBrowser("CopySelection");
                    text = string(result.clipboardText);
                otherwise
                    text = testCase.copyDisplaySelection(t);
            end
        end

        function pasteText(testCase, t, text)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tEditingParity
                t (1,1) gwidgets.Table
                text (1,1) string
            end

            switch t.Backend
                case "JavaScript"
                    t.UITable.Graphics.Backend.probeBrowser("PasteText", struct("text", text));
                otherwise
                    testCase.pasteDisplayText(t, text);
            end
            drawnow();
        end

        function text = copyDisplaySelection(testCase, t)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tEditingParity
                t (1,1) gwidgets.Table
            end

            cells = testCase.displaySelectionCells(t);
            text = testCase.cellsToText(t, cells);
        end

        function pasteDisplayText(testCase, t, text)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tEditingParity
                t (1,1) gwidgets.Table
                text (1,1) string
            end

            values = testCase.parseText(text);
            anchor = testCase.pasteAnchor(t);
            editable = testCase.editableColumns(t);
            for iRow = 1:size(values, 1)
                for iCol = 1:size(values, 2)
                    displayIdx = anchor + [iRow - 1, iCol - 1];
                    if displayIdx(1) > height(t.DisplayData) || displayIdx(2) > width(t.DisplayData) || ...
                            ~editable(displayIdx(2))
                        continue
                    end

                    previousData = t.DisplayData{displayIdx(1), displayIdx(2)};
                    editData = values(iRow, iCol);
                    newData = testCase.coerceEditData(editData, previousData);
                    editEvent = struct( ...
                        "Indices", displayIdx, ...
                        "DisplayIndices", displayIdx, ...
                        "PreviousData", previousData, ...
                        "EditData", editData, ...
                        "NewData", newData);
                    t.UITable.Callback.onCellEdit([], editEvent);
                end
            end
        end
    end

    methods (Static, Access = private)
        function t = createTable(testCase, backend, data)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                backend (1,1) string
                data (:,:) table
            end

            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            t = gwidgets.Table(Parent=fig, Backend=backend, Data=data);
            testCase.addTeardown(@()delete(t));
        end

        function text = tabText(values)
            arguments
                values (:,:) string
            end

            rows = strings(size(values, 1), 1);
            for iRow = 1:size(values, 1)
                rows(iRow) = strjoin(values(iRow, :), string(char(9)));
            end
            text = strjoin(rows, newline);
        end

        function values = parseText(text)
            arguments
                text (1,1) string
            end

            rows = splitlines(text);
            if ~isempty(rows) && rows(end) == ""
                rows(end) = [];
            end
            nCols = max(count(rows, char(9)) + 1);
            values = strings(numel(rows), nCols);
            for iRow = 1:numel(rows)
                rowValues = split(rows(iRow), char(9)).';
                values(iRow, 1:numel(rowValues)) = rowValues;
            end
        end

        function cells = displaySelectionCells(t)
            arguments
                t (1,1) gwidgets.Table
            end

            switch string(t.SelectionType)
                case "row"
                    rows = reshape(t.DisplaySelection, 1, []);
                    [rowGrid, colGrid] = ndgrid(rows, 1:width(t.DisplayData));
                    cells = [rowGrid(:), colGrid(:)];
                case "column"
                    cols = reshape(t.DisplaySelection, 1, []);
                    [rowGrid, colGrid] = ndgrid(1:height(t.DisplayData), cols);
                    cells = [rowGrid(:), colGrid(:)];
                otherwise
                    cells = t.DisplaySelection;
            end
        end

        function text = cellsToText(t, cells)
            arguments
                t (1,1) gwidgets.Table
                cells (:,2) double
            end

            if isempty(cells)
                text = "";
                return
            end

            rows = unique(cells(:, 1)).';
            cols = unique(cells(:, 2)).';
            selected = string(cells(:, 1)) + ":" + string(cells(:, 2));
            values = strings(numel(rows), numel(cols));
            for iRow = 1:numel(rows)
                for iCol = 1:numel(cols)
                    key = string(rows(iRow)) + ":" + string(cols(iCol));
                    if any(selected == key)
                        values(iRow, iCol) = test.unit.gwidgets.Table.tEditingParity.valueText( ...
                            t.DisplayData{rows(iRow), cols(iCol)});
                    end
                end
            end
            text = test.unit.gwidgets.Table.tEditingParity.tabText(values);
        end

        function anchor = pasteAnchor(t)
            arguments
                t (1,1) gwidgets.Table
            end

            switch string(t.SelectionType)
                case "row"
                    rows = reshape(t.DisplaySelection, 1, []);
                    anchor = [min(rows), 1];
                case "column"
                    cols = reshape(t.DisplaySelection, 1, []);
                    anchor = [1, min(cols)];
                otherwise
                    selection = t.DisplaySelection;
                    if isempty(selection)
                        anchor = [1, 1];
                    else
                        anchor = [min(selection(:, 1)), min(selection(:, 2))];
                    end
            end
        end

        function editable = editableColumns(t)
            arguments
                t (1,1) gwidgets.Table
            end

            editable = logical(t.ColumnEditable);
            if isscalar(editable)
                editable = repelem(editable, 1, width(t.DisplayData));
            end
        end

        function text = valueText(value)
            if iscell(value) && isscalar(value)
                value = value{1};
            end
            if isstring(value)
                text = value(1);
            elseif ischar(value)
                text = string(value);
            elseif isnumeric(value) || islogical(value)
                if isscalar(value)
                    text = string(value);
                else
                    text = string(mat2str(value));
                end
            else
                text = string(value);
            end
        end

        function newData = coerceEditData(editData, previousData)
            editText = string(editData);
            if isstring(previousData)
                newData = editText;
            elseif ischar(previousData)
                newData = char(editText);
            elseif isnumeric(previousData)
                newData = str2double(editText);
                if ~isa(previousData, "double")
                    newData = cast(newData, class(previousData));
                end
            elseif islogical(previousData)
                newData = ismember(lower(strtrim(editText)), ["true", "1", "yes", "on"]);
            else
                newData = editText;
            end
        end
    end
end
