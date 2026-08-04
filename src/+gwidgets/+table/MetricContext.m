classdef MetricContext
    % MetricContext is passed to custom table metric functions.

    properties
        Data (:,:) table = table.empty(0,0)
        ColumnData = []
        VariableName (1,1) string = ""
        VariableLabel (1,1) string = ""
        VariableType (1,1) string = ""
        Scope (1,1) string {mustBeMember(Scope, ["Overall", "Group"])} = "Overall"
        GroupLabel (1,1) string = ""
        GroupRows (1,:) double = double.empty(1,0)
        DisplayRow (1,1) double = NaN
        DisplayColumn (1,1) double = NaN
        MetricName (1,1) string = ""
        MetricLabel (1,1) string = ""
    end
end
