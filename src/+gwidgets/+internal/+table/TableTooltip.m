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
        Style (1,:) gwidgets.table.TooltipStyle {mustBeScalarOrEmpty}
        StyleFunction (1,:) function_handle {mustBeScalarOrEmpty}
        SelectionMode (1,1) gwidgets.table.SelectionMode
        Target (1,1) string {mustBeMember(Target, ["table", "row", "column", "cell"])} = "table"
        ContextShape (1,1) string {mustBeMember(ContextShape, ["Values", "Table"])} = "Values"
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
                nvp.SelectionMode (1,1) gwidgets.table.SelectionMode = gwidgets.table.SelectionMode.Data
                nvp.ContextShape (1,1) string {mustBeMember(nvp.ContextShape, ["Values", "Table"])} = gwidgets.internal.table.TableTooltip.defaultContextShape(target)
                nvp.Style = []
            end

            if isa(text, "function_handle")
                this.TextFunction = text;
                this.Text = "";
            else
                this.Text = string(text);
            end
            this.Target = target;

            if ~isempty(nvp.Style)
                if isa(nvp.Style, "function_handle")
                    this.StyleFunction = nvp.Style;
                elseif isa(nvp.Style, "gwidgets.table.TooltipStyle")
                    this.Style = nvp.Style;
                else
                    error("GraphicsWidgets:Table:TooltipStyleArg", ...
                        "Style must be a gwidgets.table.TooltipStyle or a function_handle returning one.");
                end
            end

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
            this.ContextShape = nvp.ContextShape;
        end

        function shape = defaultContextShapeFor(this)
            shape = gwidgets.internal.table.TableTooltip.defaultContextShape(this.Target);
        end

        function idx = indices(this, tbl)
            arguments
                this
                tbl = []
            end
            idx = this.TargetFunction(tbl);
        end

        function txt = textFor(this, ctx)
            % textFor returns the rendered tooltip string. The TextFunction
            % is called with a TooltipContext describing the hovered cell;
            % if no function is set, the static Text is returned.
            arguments
                this
                ctx (1,1) gwidgets.table.TooltipContext
            end
            if ~isempty(this.TextFunction)
                txt = string(this.TextFunction(ctx));
                if ~isscalar(txt)
                    txt = strjoin(txt, newline);
                end
            else
                txt = this.Text;
            end
        end

        function sty = styleFor(this, ctx)
            % styleFor resolves to a TooltipStyle (possibly empty if the
            % tooltip didn't set a Style). A StyleFunction is called with
            % the same TooltipContext as the TextFunction.
            arguments
                this
                ctx (1,1) gwidgets.table.TooltipContext
            end
            sty = gwidgets.table.TooltipStyle.empty;
            if ~isempty(this.StyleFunction)
                try
                    result = this.StyleFunction(ctx);
                    if isa(result, "gwidgets.table.TooltipStyle") && isscalar(result)
                        sty = result;
                    end
                catch
                    % swallow — caller uses the default style for this entry
                end
            elseif ~isempty(this.Style)
                sty = this.Style;
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

    methods (Static)
        function shape = defaultContextShape(target)
            % Per-target defaults: column values vector and a cell scalar
            % are the natural ergonomic forms; row and whole-table default
            % to "Table" so mixed-type data is always reachable.
            switch target
                case {"column", "cell"}
                    shape = "Values";
                otherwise % "row", "table"
                    shape = "Table";
            end
        end
    end

end
