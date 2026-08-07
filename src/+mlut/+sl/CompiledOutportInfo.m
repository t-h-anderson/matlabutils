classdef CompiledOutportInfo
    %COMPILEDOUTPORTINFO Compiled bus metadata for a source outport.

    properties
        Name (1,1) string
        SrcPortHandle (1,1) double
        CompiledBusType (1,1) string
    end

    methods
        function obj = CompiledOutportInfo(nvp)
            arguments
                nvp.?mlut.sl.CompiledOutportInfo
            end

            fieldsToSet = string(fields(nvp));
            for i = 1:numel(fieldsToSet)
                fieldName = fieldsToSet(i);
                obj.(fieldName) = nvp.(fieldName);
            end
        end

        function tbl = table(objs)
            arguments
                objs (1,:) mlut.sl.CompiledOutportInfo
            end

            if isempty(objs)
                tbl = table( ...
                    strings(0,1), zeros(0,1), strings(0,1), ...
                    VariableNames=["Name", "SrcPortHandle", "CompiledBusType"]);
                return
            end

            name = [objs.Name]';
            srcPortHandle = [objs.SrcPortHandle]';
            compiledBusType = [objs.CompiledBusType]';
            tbl = table(name, srcPortHandle, compiledBusType, ...
                VariableNames=["Name", "SrcPortHandle", "CompiledBusType"]);
        end

        function objs = filter(objs, variable, value)
            arguments
                objs
                variable (1,1) string {mustBeMember(variable, ["Name", "SrcPortHandle", "CompiledBusType"])}
                value
            end

            idx = [objs.(variable)] == value;
            objs = objs(idx);
        end
    end
end
