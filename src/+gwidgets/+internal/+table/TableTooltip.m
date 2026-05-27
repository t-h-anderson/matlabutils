classdef TableTooltip
    % TableTooltip mirrors TableStyle for the tooltip system.
    %
    % A TableTooltip pairs a string of hover text with a target scope
    % ("table", "row", "column", or "cell") plus either a static set of
    % target indices or a function that produces them when queried.

    properties
        Text (1,1) string = ""
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
                text (1,1) string
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])} = "table"
                nvp.TargetIndices (:,:) double
                nvp.TargetFunction (1,:) function_handle
                nvp.SelectionMode (1,1) gwidgets.internal.table.SelectionMode = gwidgets.internal.table.SelectionMode.Data
            end

            this.Text = text;
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
