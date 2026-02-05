classdef TableStyle
    
    properties
        Style (1,1) matlab.ui.style.Style
        SelectionMode (1,1) gwidgets.internal.table.SelectionMode
        Target (1,1) string {mustBeMember(Target, ["table", "row", "column", "cell"])} = "table"  
    end

    properties %(Access = protected)
        TargetFunction (1,:) function_handle {mustBeScalarOrEmpty}
        TargetIndices (:,:) = []
        HasTargetIndices (1,1) logical = false;
    end
    
    methods
        function this = TableStyle(style, target, nvp)
            arguments
                style
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])} = "table"  
                nvp.TargetIndices (:,:) double
                nvp.TargetFunction (1,:) function_handle
                nvp.SelectionMode (1,1) gwidgets.internal.table.SelectionMode = gwidgets.internal.table.SelectionMode.Data
            end

            this.Style = style;
            this.Target = target;

            hasIndices = isfield(nvp, "TargetIndices");
            hasFunction = isfield(nvp, "TargetFunction");

            if hasIndices && ~hasFunction
                this.TargetFunction = @(varargin) nvp.TargetIndices;
            elseif hasFunction && ~hasIndices
                this.TargetFunction = nvp.TargetFunction;
            else
                error("Must supply target function xor target indices");
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

    end

end

