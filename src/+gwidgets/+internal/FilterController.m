classdef FilterController < gwidgets.internal.Reparentable
    % Filter controller
    properties
        FilterValue (1,1) string
        CategoricalVariables
        HelpParent (1,:) {mustBeScalarOrEmpty}
    end

    properties (GetAccess = ?matlab.unittest.TestCase, ...
            SetAccess = private)
        Grid (1,:) matlab.ui.container.GridLayout {mustBeScalarOrEmpty}
        FilterLabel (1,:) matlab.ui.control.Label {mustBeScalarOrEmpty}
        FilterDropDown (1,:) matlab.ui.control.DropDown {mustBeScalarOrEmpty}
        ClearHistoryButton (1,:) matlab.ui.control.Button {mustBeScalarOrEmpty}
        SaveHistoryButton (1,:) matlab.ui.control.Button {mustBeScalarOrEmpty}
        LoadHistoryButton (1,:) matlab.ui.control.Button {mustBeScalarOrEmpty}
        HelpButton (1,:) matlab.ui.control.Button {mustBeScalarOrEmpty}
        MatchesLabel (1,:) matlab.ui.control.Label {mustBeScalarOrEmpty}
        Datepicker (1,:) matlab.ui.control.DatePicker {mustBeScalarOrEmpty}
        ShowCategoriesButton (1,:) matlab.ui.control.Button {mustBeScalarOrEmpty}
        CategoriesPopout (1,:) matlab.ui.container.internal.Popout {mustBeScalarOrEmpty}
        CategoriesListBox (1,:) matlab.ui.control.ListBox {mustBeScalarOrEmpty}
        AllColumnsCheckBox (1,:) matlab.ui.control.CheckBox {mustBeScalarOrEmpty}
        CloseHelpButton (1,:) matlab.ui.control.Button {mustBeScalarOrEmpty}
        HelpPanel (1,:) matlab.ui.container.Panel {mustBeScalarOrEmpty}
        PopoutHelpParent (1,:) {mustBeScalarOrEmpty}
    end

    events
        FilterChanged
        FilterHelpRequested
        FilterHelpClosed
    end

    methods

        function this = FilterController(namedArgs)
            arguments (Input)
                namedArgs.?gwidgets.internal.FilterController
            end

            this@gwidgets.internal.Reparentable();
            set(this, namedArgs)
        end

        function delete(this)
            delete(this.CategoriesPopout);
            delete(ancestor(this.PopoutHelpParent, "figure"));
            delete(this.PopoutHelpParent);
        end

        function [data, idx, status] = applyFilter(this, data, filter)
            arguments
                this (1,1)
                data table
                filter (1,1) string = this.FilterDropDown.Value
            end

            % Check whether we're performing a global search across the
            % text columns.
            if this.AllColumnsCheckBox.Value
                strData = convertvars(data, data.Properties.VariableNames, "string");
                idx = any(contains(...
                    strData{:,:}, filter, ...
                    IgnoreCase = true), 2);
                status = true;

            else
                % Retrieve the indices of the matching rows.
                [idx, newFilter, status] = ...
                    this.filterIndices(filter, data);

                % Update the filter dropdown.
                if newFilter ~= filter
                    filter = newFilter;
                    this.FilterDropDown.Value = newFilter;
                end

            end

            % Store the filter in the dropdown as long as it was valid.
            if status
                this.FilterDropDown.Items = unique(...
                    [filter, ...
                    this.FilterDropDown.Items], "stable");
            end

            % Return the filtered data
            data = data(idx, :);

            % Update the number of matches label.
            this.MatchesLabel.Text = sprintf("%d/%d matches found", ...
                nnz(idx), numel(idx));

        end

        function set.CategoricalVariables(this, val)
            this.CategoricalVariables = val;
            this.updateCategoricalControls();
        end

    end

    methods (Static)

        function [idx, str, isOk, s] = filterIndices(filter, data)
            %FILTERINDICES Return a logical index corresponding to the
            %table rows matched by the current search query in the filter
            %dropdown.
            arguments (Input)
                filter (1,1) string
                data (:,:) table
            end

            arguments (Output)
                idx (:,1) logical
                str (1,1) string
                isOk (1,1) logical
                s (1,:) struct
            end

            % There should be no overlap between Conjunctions and Comparators
            % Conjunctions
            andConj = "&";
            orConj = ";";

            % Comparators
            orComp = "|"; % e.g. A=1|2
            andComp = ""; % e.g. A<2>3
            eqComp = ["=", "=="];
            approxComp = ["?=", "?"];
            notComp = ["~=", "~"];
            gtComp = ">";
            ltComp = "<";
            gteComp = ">=";
            lteComp = "<=";

            conjs = [andConj, orConj];
            conjs = strjoin(conjs , "");
            conjs = string(unique(conjs{1}));

            comps = [orComp, andComp, eqComp, gteComp, lteComp, approxComp, gtComp, ltComp, notComp];
            comps = strjoin(comps, "");
            comps = string(unique(comps{1}));

            specials = comps + conjs;

            % Start with every row selected.
            idx = true(height(data), 1);
            str = "";
            isOk = true;
            s = struct("ColumnIdx", {}, "RowIdx", {});

            % Proceed only for nonempty filters and nonempty data.
            if isempty(filter) || isempty(data)
                return
            end

            % Remove special characters from the string.
            filter = erase(filter, "⚡");
            filter = erase(filter, "❓");

            % Split up the filter string on the semicolons.
            [splitParts, delim] = strsplit(filter, [andConj, orConj], "CollapseDelimiters", true);
            splitParts = strtrim(splitParts);
            splitParts(splitParts == "") = []; % Remove empty tags

            if numel(delim) < numel(splitParts)
                delim = [delim, ""];
            else
                if ~isempty(delim)
                    delim(end) = "";
                end
            end

            % If multiple delimiters are provided, collapse these to and,
            % then to or, e.g. &&| => &, || -> |
            delim(contains(delim, andConj)) = andConj;
            delim(contains(delim, orConj)) = orConj;

            conjunction = delim;
            conjunction = [andConj, conjunction]; % First is and with all true

            % Iterate over the filter conditions.
            for iPart = 1:numel(splitParts)
                errorFlag = 0;
                op = "";

                try

                    % Remove whitespace between the special characters
                    splitParts(iPart) = regexprep(splitParts(iPart), ...
                        "([" + specials + "])\s+([" + specials + "])", "$1$2");

                    % Find tagged groups:
                    % Any sequence of characters that does not include the characters >, |, &, =, <, or ~
                    % followed by any sequence of characters that do not include those characters.
                    tag = regexp(splitParts(iPart), ...
                        "[^" + specials + "]+|[" + specials + "]+[^" + specials + "]*", ...
                        "match");
                    tag(1) = strtrim(tag(1));

                    assert(numel(tag) > 0, "FilterableTable:FilterError:Unknown", "Something went wrong");

                    rowIdx = true(height(data), 1);

                    % Find a unique matching column
                    varNames = string(data.Properties.VariableNames);

                    indCol = startsWith(varNames, tag(1), "IgnoreCase", false);
                    if ~any(indCol)
                        % No identical column found, so try without
                        % capitalisation
                        indCol = startsWith(varNames, ...
                            tag(1), "IgnoreCase", true);
                    end

                    if nnz(indCol) ~= 1
                        errorFlag = -1;
                        error("FilterableTable:FilterError:ColumnsNotUnique", "Column matches not unique")
                    end

                    % Allows whole column selection
                    res = true(height(data), 1);

                    % Allow matching multiple tags in one section, e.g.
                    % A>1<10 works as 1<A<10
                    for iTag = 2:numel(tag)

                        thisTag = tag(iTag);

                        % Remove whitespace not enclosed in quotes
                        thisTag = regexprep(thisTag, ...
                            '\s+(?=(?:[^"]*"[^"]*")*[^"]*$)', "");

                        % Separate specific operators (&, |, >, <, =, ~) from other characters
                        splitTag = regexp(thisTag, ...
                            "[" + conjs + "]+|[|]+|[" + comps +"]+|[^" + comps + "]*", "match");

                        if numel(splitTag) ~= 2
                            errorFlag = -1;
                            error("FilterableTable:FilterError:TagError", "Column matches not unique")
                        end

                        prevOp = op;
                        op = splitTag(1);
                        val = splitTag(2);
                        val = strtrim(val);

                        % Update the tag so it can be displayed as parsed
                        tag(iTag) = sprintf("%s%s", op, val);

                        % If there are multiple parts to the statement,
                        % they are joined via conjunction which may omit
                        % the operation, e.g A=1|2 is the same as A=1 or A=2
                        switch op
                            case orComp
                                % E.g. A=1|2
                                compFlag = orComp;
                                op = prevOp;
                            case andComp
                                % E.g. A>1<2
                                compFlag = andComp;
                                op = prevOp;
                            otherwise
                                % e.g. A=1 - Default to and with "true"
                                compFlag = andComp;
                        end

                        % Action depends on the class of the data in the
                        % column
                        col = data{:, indCol};
                        c = class(col);
                        switch c
                            case "datetime"
                                val = datetime(val);
                            case "duration"
                                fmt = col.Format;
                                val = double(val);
                                switch fmt
                                    case "y"
                                        val = years(val);
                                    case "d"
                                        val = days(val);
                                    case "h"
                                        val = hours(val);
                                    case "m"
                                        val = minutes(val);
                                    case "s"
                                        val = seconds(val);
                                    otherwise
                                        val = seconds(val);
                                end

                            case {"int8", "int16", "int32", ...
                                    "int64", "uint8", "uint16", ...
                                    "uint32", "uint64", "single", ...
                                    "double"}
                                val = feval(c, str2double(val));
                            case "logical"
                                if strcmpi(val, "true") ...
                                        || strcmpi(val, "t") ...
                                        || strcmpi(val, "1")
                                    val = true;
                                elseif strcmpi(val, "false") ...
                                        || strcmpi(val, "f") ...
                                        || strcmpi(val, "0")
                                    val = false;
                                else
                                    error("Unrecognised logical expression");
                                end
                            case {"cell", "string", "char"}
                                val = string(val);
                            case "categorical"
                                val = string(val);
                                col = string(col);
                            otherwise
                                % Do nothing
                        end

                        switch class(col)
                            case {"datetime", "duration", ...
                                    "int8", "int16", "int32", ...
                                    "int64", "uint8", "uint16", ...
                                    "uint32", "uint64", "single", ...
                                    "double", "logical"}

                                % Using num2cell supports arrays of
                                % definitions
                                switch op
                                    case num2cell(eqComp)
                                        res = (col == val);
                                    case num2cell(approxComp)
                                        r = range(col);
                                        res = abs(col - val) < 0.05 * r;
                                    case num2cell(gtComp)
                                        res = (col > val);
                                    case num2cell(ltComp)
                                        res = (col < val);
                                    case num2cell(gteComp)
                                        res = (col >= val);
                                    case num2cell(lteComp)
                                        res = (col <= val);
                                    case num2cell(notComp)
                                        res = ~(col == val);
                                    otherwise
                                        errorFlag = -1;
                                        error("FilterableTable:FilterError:OpError", "Unsupported operation '" + op + "' on " + class(col));
                                end

                            case {"cell", "string", "char", "categorical"}
                                switch op
                                    case num2cell(eqComp)
                                        res = matches(col, val, "IgnoreCase", true);
                                    case num2cell(approxComp)
                                        res = contains(col, val, "IgnoreCase", true);
                                    case num2cell(notComp)
                                        res = ~matches(col, val, "IgnoreCase", true);
                                    otherwise
                                        errorFlag = -1;
                                        error("FilterableTable:FilterError:OpError", "Unsupported operation '" + op + "' on " + class(col));
                                end
                        end

                        switch compFlag
                            case andComp
                                rowIdx = and(rowIdx, res);
                            case orComp
                                rowIdx = or(rowIdx, res);
                            otherwise
                                rowIdx = and(rowIdx, res);
                        end
                    end

                    splitParts(iPart) = sprintf("%s", tag);

                catch me
                    isOk = false;
                    switch errorFlag
                        case 0
                            % Filter parse error
                            splitParts(iPart) = "⚡" + splitParts(iPart);
                        case -1
                            % Unrecognised filter
                            splitParts(iPart) = "❓" + splitParts(iPart);
                    end
                end

                s(iPart) = struct("ColumnIdx", indCol, "RowIdx", rowIdx);

                switch conjunction(iPart)
                    case andConj
                        idx = and(idx, rowIdx);
                    case orConj
                        idx = or(idx, rowIdx);
                end

            end

            str = strjoin(splitParts + " " + delim, " ");
            str = strtrim(str);
        end

    end

    methods (Access = protected)

        function setup(this)
            %SETUP Initialize the component's graphics.
            this.Grid = uigridlayout("Parent", this, "RowHeight", "fit", "ColumnWidth", "1x", "Padding", 0);
            
            % Add the card panel for the filter
            acc = matlab.ui.container.internal.Accordion(...
                "Parent", this.Grid);
            accPan = matlab.ui.container.internal.AccordionPanel(...
                "Parent", acc, ...
                "Title", "Filter Controls", ...
                "Tooltip", "Show/hide filter controls", ...
                "Collapsed", true);
            accGrid = uigridlayout(accPan, [2, 1], "Padding", 5);

            % Add a sub-grid for the filter label, dropdown and help
            % button.
            filterGrid = uigridlayout(accGrid, [1, 6], ...
                "ColumnWidth", {"fit", "1x", 22, 22, 22, 22}, ...
                "ColumnSpacing", 3, ...
                "Padding", 0);
            this.FilterLabel = uilabel(filterGrid, "Text", "Filter", ...
                "Tooltip", "Specify the required column filter", ...
                "HorizontalAlignment", "center");
            this.FilterDropDown = uidropdown(filterGrid, "Items", "", ...
                "Editable", "on", ...
                "Tooltip", "Specify the required column filter", ...
                "ValueChangedFcn", @this.onFilterEdited);
            this.ClearHistoryButton = uibutton(filterGrid, ...
                "Text", "", ...
                "Tooltip", "Clear filter history", ...
                "ButtonPushedFcn", @this.onClearHistoryButtonPushed);
            matlab.ui.control.internal.specifyIconID(...
                this.ClearHistoryButton, "clear", 16, 16)
            this.SaveHistoryButton = uibutton(filterGrid, ...
                "Text", "", ...
                "Tooltip", "Save filter history to a MAT-file", ...
                "ButtonPushedFcn", @this.onSaveHistoryButtonPushed);
            matlab.ui.control.internal.specifyIconID(...
                this.SaveHistoryButton, "unsaved", 16, 16)
            this.LoadHistoryButton = uibutton(filterGrid, ...
                "Text", "", ...
                "Tooltip", "Load filter history from a MAT-file", ...
                "ButtonPushedFcn", @this.onLoadHistoryButtonPushed);
            matlab.ui.control.internal.specifyIconID(...
                this.LoadHistoryButton, "openFolder", 16, 16)
            this.HelpButton = uibutton(filterGrid, ...
                "Text", "", ...
                "Tooltip", "Open the help for this filterable table", ...
                "ButtonPushedFcn", ...
                @(s, e) this.helpRequested(s,e));
            matlab.ui.control.internal.specifyIconID(...
                this.HelpButton, "help", 16, 16)

            % Add a sub-grid for the matches label, datepicker, show
            % categories button, and all rows checkbox.
            controlGrid = uigridlayout(accGrid, [1, 4], ...
                "ColumnWidth", repelem("fit", 4), ...
                "Padding", 0);
            this.MatchesLabel = uilabel(controlGrid, ...
                "Text", "0/0 matches found", ...
                "Tooltip", ...
                "Number of matching rows identified by the filter", ...
                "HorizontalAlignment", "left");
            this.Datepicker = uidatepicker(controlGrid, ...
                "Tooltip", "Use this datepicker to help enter " + ...
                "dates when filtering by date", ...
                "DisplayFormat", "dd-MMM-yyyy", ...
                "Placeholder", "dd-MMM-yyyy", ...
                "ValueChangedFcn", @this.onDateSelected);
            this.ShowCategoriesButton = uibutton(controlGrid, ...
                "Text", "Show Categories", ...
                "Tooltip", "Show the list of categories for " + ...
                "the selected categorical variable", ...
                "Enable", "off");
            this.AllColumnsCheckBox = uicheckbox(controlGrid, ...
                "Tooltip", "Enable this setting when searching for " + ...
                "matching text across all text columns in the table", ...
                "Text", "Apply filter to all text columns", ...
                "Value", false);

            % Add the help page.
            this.HelpPanel = uipanel("Parent", []);
            gl = uigridlayout(this.HelpPanel, [2, 2], ...
                "RowHeight", {22, "1x"}, ...
                "ColumnWidth", {"1x", 22});
            folder = fileparts(mfilename("fullpath"));
            htmlSource = fullfile(folder, "FilterControllerHelp.html");
            h = uihtml(gl, "HTMLSource", htmlSource);
            h.Layout.Row = [1, 2];
            h.Layout.Column = [1, 2];
            this.CloseHelpButton = uibutton(gl, ...
                "Text", "", ...
                "Tooltip", "Close the filter table help page", ...
                "ButtonPushedFcn", ...
                @(~, ~) this.detachHelp());
            matlab.ui.control.internal.specifyIconID(...
                this.CloseHelpButton, "close", 16, 16)
            this.CloseHelpButton.Layout.Row = 1;
            this.CloseHelpButton.Layout.Column = 2;


        end

        function helpRequested(this,~,~)
            if isempty(this.HelpParent)
                if isempty(this.PopoutHelpParent) || ~isvalid(this.PopoutHelpParent)
                    this.PopoutHelpParent = uigridlayout(uifigure("DeleteFcn", @(s,e) this.detachHelp()), [1,1]);
                end
                parent = this.PopoutHelpParent;
            else
                parent = this.HelpParent;
            end

            this.HelpPanel.Parent = parent;

            notify(this, "FilterHelpRequested")
        end

        function detachHelp(this)
            % stops the help being deleted when the figure is closed
            this.HelpPanel.Parent = [];
            notify(this, "FilterHelpClosed");
        end

        function updateCategoricalControls(this)
            if isempty(this.CategoricalVariables)
                this.ShowCategoriesButton.Enable = "off";
            else
                this.ShowCategoriesButton.Enable = "on";
            end

            this.CategoriesListBox.Items = string(this.CategoricalVariables);
        end
    end

    methods (Access = protected)
        function reactToFigureChanged(this)
            this.createPopout();
        end

        function update(this)
            this.FilterDropDown.Value = this.FilterValue;
        end

    end

    methods (Access = private)

        function createPopout(this)
            % Otherwise, create the popout
            delete(this.CategoriesPopout)
            this.CategoriesPopout = matlab.ui.container.internal.Popout(...
                "Target", this.ShowCategoriesButton, ...
                "Placement", "auto", ...
                "Position", [0, 0, 200, 200], ...
                "Trigger", "click");
            g = uigridlayout(this.CategoriesPopout, [1, 1], ...
                "Padding", 0);
            this.CategoriesListBox = uilistbox(g, "Items", "", ...
                "Value", [], ...
                "Multiselect", "off", ...
                "ValueChangedFcn", @onCategorySelected);

            function onCategorySelected(~, ~)
                this.FilterDropDown.Value = this.FilterDropDown.Value + ...
                    string(this.CategoriesListBox.Value);
                this.CategoriesPopout.close();
            end

        end

        function onFilterEdited(this, ~, ~)
            % Listen for this event, and pass a table into 
            % applyCurrentFilter
            this.FilterValue = this.FilterDropDown.Value;
            pause(0) % Required to make the filter value update on error
            notify(this, "FilterChanged");
        end

        function onClearHistoryButtonPushed(this, ~, ~)
            % Clear the filter history.

            f = ancestor(this, "figure");
            if isempty(f)
                return
            end

            response = uiconfirm(f, ...
                "Are you sure you want to clear the filter history?", ...
                "Clear Filter History", ...
                "Options", ["Clear History", "Cancel"], ...
                "DefaultOption", "Cancel", ...
                "CancelOption", "Cancel");
            if response == "Clear History"
                this.FilterDropDown.Items = "";
            end

        end

        function onSaveHistoryButtonPushed(this, ~, ~)
            % Save the filter history.

            f = ancestor(this, "figure");
            if isempty(f)
                return
            end

            [file, path] = uiputfile("*.mat", "Select a MAT-file", ...
                "FilterHistory.mat");
            figure(f)
            if isequal(file, 0)
                return
            end

            try
                filterHistory = this.FilterDropDown.Items;
                savePath = fullfile(path, file);
                save(savePath, "filterHistory")
            catch me
                uialert(f, me.message, "Save Error", ...
                    "Interpreter", "html")
            end
        end

        function onLoadHistoryButtonPushed(this, ~, ~)
            % Load a previously-saved filter history.
            f = ancestor(this, "figure");
            if isempty(f)
                return
            end

            [file, path] = uigetfile("*.mat", "Select a MAT-file");
            figure(f)
            if isequal(file, 0)
                return
            end

            try
                % Load the history and append the content to the dropdown
                % menu.
                matContent = load(fullfile(path, file));
                filterHistory = matContent.filterHistory;
                this.FilterDropDown.Items = ...
                    unique([this.FilterDropDown.Items, filterHistory], ...
                    "stable");
            catch me
                uialert(f, me.message, "Load Error", ...
                    "Interpreter", "html")
            end
        end

        function onDateSelected(this, ~, ~)
            % Place the selected date into the filter dropdown.
            this.FilterDropDown.Value = this.FilterDropDown.Value + ...
                string(this.Datepicker.Value, "dd-MMM-yyyy");
        end

    end

end