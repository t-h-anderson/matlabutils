classdef ConfigSet
    %CONFIGSET Utilities for resolving Simulink configuration sets.

    methods (Static)
        function [activeConfigSet, cleanupObj] = activeForModel(modelOrPath)
            arguments
                modelOrPath (1,1) string
            end

            cleanupObj = onCleanup.empty(1,0);
            modelName = mlut.sl.Model.nameFromInput(modelOrPath);
            if nargout > 1
                [~, cleanupObj] = mlut.sl.Model.open(modelOrPath);
            else
                mlut.sl.Model.open(modelOrPath);
            end

            activeConfigSet = getActiveConfigSet(modelName);
            activeConfigSet = mlut.sl.ConfigSet.resolveReference(activeConfigSet);
        end

        function configSet = resolveReference(configSet)
            arguments
                configSet {mustBeScalarOrEmpty} = []
            end

            if isempty(configSet) || ~isa(configSet, "Simulink.ConfigSetRef")
                return
            end

            try
                configSet = getRefConfigSet(configSet);
            catch
                % Leave unresolved references untouched so callers can report them.
            end
        end

        function tf = isReference(configSet)
            arguments
                configSet {mustBeScalarOrEmpty} = []
            end

            tf = isa(configSet, "Simulink.ConfigSetRef");
        end

        function template = ertCustomFileTemplate(configSet)
            arguments
                configSet {mustBeScalarOrEmpty} = []
            end

            template = string(NaN);
            if isempty(configSet)
                return
            end

            try
                template = string(get_param(configSet, "ERTCustomFileTemplate"));
            catch
                % Some configuration sets do not expose code-generation parameters.
            end
        end

        function sourceName = sourceName(configSet)
            arguments
                configSet {mustBeScalarOrEmpty} = []
            end

            sourceName = string(NaN);
            if isempty(configSet)
                return
            end

            try
                sourceName = string(get_param(configSet, "SourceName"));
            catch
                % Inline config sets and malformed references may not expose SourceName.
            end
        end
    end
end
