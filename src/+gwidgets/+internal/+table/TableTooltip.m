classdef TableTooltip
    % TableTooltip mirrors TableStyle for the tooltip system.
    %
    % A TableTooltip pairs hover content (either a static string or a
    % function that maps the hovered cell value to a string) with a
    % target scope ("table", "row", "column", or "cell") plus either a
    % static set of target indices or a function that produces them
    % when queried.

    properties
        Text (1,1) string = ""
        TextFunction (1,:) function_handle {mustBeScalarOrEmpty}
        SelectionMode (1,1) gwidgets.internal.table.SelectionMode
        Target (1,1) string {mustBeMember(Target, ["table", "row", "column", "cell"])} = "table"
    end

    properties
        TargetFunction (1,:) function_handle {mustBeScalarOrEmpty}
        TargetIndices (:,:) = []
    end

    methods
        function this = TableTooltip(text, target, nvp)
            arguments
                text % string scalar OR function_handle (value) -> string
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])} = "table"
                nvp.TargetIndices (:,:) double
                nvp.TargetFunction (1,:) function_handle
                nvp.SelectionMode (1,1) gwidgets.internal.table.SelectionMode = gwidgets.internal.table.SelectionMode.Data
            end

            if isa(text, "function_handle")
                this.TextFunction = text;
                this.Text = "";
            else
                this.Text = string(text);
            end
            this.Target = target;

            hasIndices = isfield(nvp, "TargetIndices");
            hasFunction = isfield(nvp, "TargetFunction");

            if target == "table"
                % "table" target ignores indices entirely
                this.TargetFunction = @(varargin) [];
            elseif hasIndices && ~hasFunction
                this.TargetFunction = @(varargin) nvp.TargetIndices;
            elseif hasFunction && ~hasIndices
                this.TargetFunction = nvp.TargetFunction;
            else
                error("GraphicsWidgets:Table:TooltipTargetIndices", ...
                    "Must supply target function xor target indices for non-table targets.");
            end

            this.SelectionMode = nvp.SelectionMode;
        end

        function idx = indices(this, tbl)
            arguments
                this
                tbl = []
            end
            idx = this.TargetFunction(tbl);
        end

        function txt = textFor(this, cellValue)
            % textFor returns the rendered tooltip string. If a TextFunction
            % is set, it's called with the hovered cell's value; otherwise
            % the static Text is returned.
            if ~isempty(this.TextFunction)
                txt = string(this.TextFunction(cellValue));
                if ~isscalar(txt)
                    txt = strjoin(txt, newline);
                end
            else
                txt = this.Text;
            end
        end

        function tf = matches(this, displayRow, displayColumn)
            % matches returns true when this tooltip applies to the given
            % display cell. Callers must have already converted Target
            % indices to display coordinates.
            arguments
                this
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            switch this.Target
                case "table"
                    tf = true;
                case "row"
                    idx = this.TargetIndices;
                    tf = ~isempty(idx) && ismember(displayRow, idx);
                case "column"
                    idx = this.TargetIndices;
                    tf = ~isempty(idx) && ismember(displayColumn, idx);
                case "cell"
                    idx = this.TargetIndices;
                    if isempty(idx) || size(idx, 2) ~= 2
                        tf = false;
                    else
                        tf = any(idx(:,1) == displayRow & idx(:,2) == displayColumn);
                    end
            end
        end
    end

end
