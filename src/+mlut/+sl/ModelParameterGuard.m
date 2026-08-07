classdef ModelParameterGuard < handle
    %MODELPARAMETERGUARD Restore Simulink model parameters on cleanup.

    properties (SetAccess = private)
        ModelName (1,1) string = ""
        ParameterNames (1,:) string = strings(1,0)
        ParameterValues (1,:) string = strings(1,0)
    end

    properties (Access = private)
        IsRestored (1,1) logical = false
    end

    methods
        function obj = ModelParameterGuard(modelName, parameterNames)
            arguments
                modelName (1,1) string
                parameterNames (1,:) string
            end

            obj.ModelName = modelName;
            obj.ParameterNames = parameterNames;
            obj.ParameterValues = strings(size(parameterNames));

            for parameterIndex = 1:numel(parameterNames)
                obj.ParameterValues(parameterIndex) = string(get_param( ...
                    char(modelName), ...
                    char(parameterNames(parameterIndex))));
            end
        end

        function restore(obj)
            arguments
                obj (1,1) mlut.sl.ModelParameterGuard
            end

            if obj.IsRestored
                return
            end

            obj.IsRestored = true;

            for parameterIndex = 1:numel(obj.ParameterNames)
                set_param( ...
                    char(obj.ModelName), ...
                    char(obj.ParameterNames(parameterIndex)), ...
                    char(obj.ParameterValues(parameterIndex)));
            end
        end

        function delete(obj)
            obj.restore();
        end
    end
end
