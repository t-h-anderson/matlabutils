classdef ClipboardController < gwidgets.internal.table.TableController
    %CLIPBOARDCONTROLLER Copy table selections as tab-separated text.

    properties
        WriteFcn (1,1) function_handle = @(value) clipboard("copy", char(value))
    end

    properties (Access = private)
        Menus (1,:) matlab.ui.container.Menu = matlab.ui.container.Menu.empty(1,0)
    end

    methods
        function this = ClipboardController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end
            this@gwidgets.internal.table.TableController(owner);
        end

        function initialize(this)
            arguments
                this (1,1) gwidgets.internal.table.ClipboardController
            end
            owner = this.owner();
            if isempty(owner) || ~isempty(this.Menus)
                return
            end
            selected = uimenu(Parent=[], Text="Copy selection", Tag="CopyTableSelection", ...
                MenuSelectedFcn=@(~,~) this.copySelection());
            visible = uimenu(Parent=[], Text="Copy visible table", Tag="CopyVisibleTable", ...
                MenuSelectedFcn=@(~,~) this.copySelection(AllVisible=true, IncludeHeaders=true));
            this.Menus = [selected, visible];
            owner.Menu.setClipboardItems(this.Menus);
        end

        function delete(this)
            delete(this.Menus);
        end

        function text = selectionText(this, nvp)
            %SELECTIONTEXT Format selected or visible data without writing the clipboard.
            arguments
                this (1,1) gwidgets.internal.table.ClipboardController
                nvp.AllVisible (1,1) logical = false
                nvp.IncludeHeaders (1,1) logical = false
            end
            text = "";
            owner = this.owner();
            if isempty(owner)
                return
            end
            rows = owner.Data.FoldedVisibleToDataMap;
            rows = rows(rows > 0);
            columns = find(owner.Column.Visible);
            selection = owner.Selection.Value;
            selectionType = string(owner.Selection.Type);
            if ~nvp.AllVisible
                if isempty(selection)
                    return
                end
                switch selectionType
                    case "row"
                        rows = rows(ismember(rows, selection));
                    case "column"
                        columns = columns(ismember(columns, selection));
                    case "cell"
                        rows = rows(ismember(rows, selection(:,1)));
                        columns = columns(ismember(columns, selection(:,2)));
                end
            end
            if isempty(columns) || (isempty(rows) && ~nvp.IncludeHeaders)
                return
            end
            cells = table2cell(owner.Data.Table(rows, columns));
            values = strings(size(cells));
            for index = 1:numel(cells)
                parts = string(cells{index});
                parts(ismissing(parts)) = "";
                values(index) = strjoin(reshape(parts, 1, []), " ");
            end
            if ~nvp.AllVisible && selectionType == "cell"
                [dataRows, dataColumns] = ndgrid(rows, columns);
                selected = ismember([dataRows(:), dataColumns(:)], selection, "rows");
                values(~reshape(selected, size(values))) = "";
            end
            if nvp.IncludeHeaders
                values = [owner.Column.Names(columns); values];
            end
            quoted = contains(values, [string(char(9)), newline, string(char(13)), '"']);
            values(quoted) = '"' + replace(values(quoted), '"', '""') + '"';
            lines = strings(size(values, 1), 1);
            for row = 1:size(values, 1)
                lines(row) = strjoin(values(row, :), string(char(9)));
            end
            text = strjoin(lines, newline);
        end

        function text = copySelection(this, nvp)
            %COPYSELECTION Write selected or visible table data to the clipboard.
            arguments
                this (1,1) gwidgets.internal.table.ClipboardController
                nvp.AllVisible (1,1) logical = false
                nvp.IncludeHeaders (1,1) logical = false
            end
            text = this.selectionText(AllVisible=nvp.AllVisible, IncludeHeaders=nvp.IncludeHeaders);
            if strlength(text) > 0
                this.WriteFcn(text);
            end
        end
        function handleKeyPress(this, key, modifier)
            arguments
                this (1,1) gwidgets.internal.table.ClipboardController
                key (1,1) string
                modifier (1,:) string
            end
            if strcmpi(key, "c") && any(ismember(lower(modifier), ["control", "command"]))
                this.copySelection();
            end
        end
    end
end
