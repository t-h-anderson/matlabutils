classdef MetricDefinition
    % MetricDefinition describes a built-in or custom table metric.

    properties
        Name (1,1) string = ""
        Label (1,1) string = ""
        AppliesTo (1,:) string {mustBeMember(AppliesTo, ...
            ["all", "numeric", "logical", "text", "categorical", "datetime", "duration"])} = "all"
        Function (1,:) function_handle {mustBeScalarOrEmpty}
        Formatter (1,:) function_handle {mustBeScalarOrEmpty}
        Visible (1,1) logical = true
    end

    methods
        function this = MetricDefinition(nvp)
            arguments
                nvp.Name (1,1) string = ""
                nvp.Label (1,1) string = ""
                nvp.AppliesTo (1,:) string {mustBeMember(nvp.AppliesTo, ...
                    ["all", "numeric", "logical", "text", "categorical", "datetime", "duration"])} = "all"
                nvp.Function (1,:) function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
                nvp.Formatter (1,:) function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
                nvp.Visible (1,1) logical = true
            end

            this.Name = nvp.Name;
            this.Label = nvp.Label;
            if this.Label == ""
                this.Label = this.Name;
            end
            this.AppliesTo = nvp.AppliesTo;
            this.Function = nvp.Function;
            this.Formatter = nvp.Formatter;
            this.Visible = nvp.Visible;
        end

        function tf = appliesTo(this, variableType)
            arguments
                this (1,1) gwidgets.table.MetricDefinition
                variableType (1,1) string
            end

            tf = this.Visible && (any(this.AppliesTo == "all") || any(this.AppliesTo == variableType));
        end
    end
end
