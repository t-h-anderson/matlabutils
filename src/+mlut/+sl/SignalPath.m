classdef SignalPath
    %SIGNALPATH Model signal endpoint with optional bus-field detail.
    %   InstancePath is the model-relative endpoint path, usually a block or
    %   port path. BusField names the leaf inside a bus signal; scalar
    %   signals use an empty BusField.

    properties (SetAccess = protected)
        InstancePath (1,1) string
        PortType (1,1) string = ""
        BusField (1,1) string = ""
    end

    methods
        function obj = SignalPath(instancePath, nvp)
            arguments
                instancePath (1,1) string = ""
                nvp.PortType (1,1) string = ""
                nvp.BusField (1,1) string = ""
            end

            obj.InstancePath = instancePath;
            obj.PortType = nvp.PortType;
            obj.BusField = nvp.BusField;
        end

        function path = fullPath(obj)
            %FULLPATH Uses dotted bus fields because mapping rules address bus leaves.
            arguments
                obj (1,1) mlut.sl.SignalPath
            end

            if obj.BusField == ""
                path = obj.InstancePath;
            else
                path = obj.InstancePath + "." + obj.BusField;
            end
        end
    end

    methods (Static)
        function signals = fromModelReferencePorts(refBlockPath, nvp)
            arguments
                refBlockPath (1,1) string
                nvp.ModelName (1,1) string = ""
                nvp.DataDictionary Simulink.data.Dictionary {mustBeScalarOrEmpty} = ...
                    Simulink.data.Dictionary.empty(1,0)
            end

            refPath = mlut.sl.Path.relativeToModel( ...
                refBlockPath, nvp.ModelName);
            inNames = mlut.sl.Port.nameList( ...
                get_param(char(refBlockPath), "InputPortNames"));
            inBuses = mlut.sl.Port.nameList( ...
                get_param(char(refBlockPath), "InputPortBusObjects"));
            outNames = mlut.sl.Port.nameList( ...
                get_param(char(refBlockPath), "OutputPortNames"));
            outBuses = mlut.sl.Port.nameList( ...
                get_param(char(refBlockPath), "OutputPortBusObjects"));

            fieldCache = dictionary(string.empty(1,0), cell.empty(1,0));
            chunks = cell(1,0);
            for i = 1:numel(inNames)
                [chunks{end+1}, fieldCache] = mlut.sl.SignalPath.fromPortWithFieldCache( ...
                    refPath + "/" + inNames(i), "Inport", inBuses(i), ...
                    nvp.DataDictionary, fieldCache); %#ok<AGROW>
            end
            for i = 1:numel(outNames)
                [chunks{end+1}, fieldCache] = mlut.sl.SignalPath.fromPortWithFieldCache( ...
                    refPath + "/" + outNames(i), "Outport", outBuses(i), ...
                    nvp.DataDictionary, fieldCache); %#ok<AGROW>
            end
            if isempty(chunks)
                signals = mlut.sl.SignalPath.empty(1,0);
                return
            end
            signals = [chunks{:}];
        end

        function signals = fromRootPorts(systemName, nvp)
            arguments
                systemName (1,1) string
                nvp.PortTypes (1,:) string {mustBeMember(nvp.PortTypes, ["Inport", "Outport"])} = ...
                    ["Inport", "Outport"]
            end

            chunks = cell(1,0);
            for i = 1:numel(nvp.PortTypes)
                blocks = find_system(char(systemName), ...
                    "SearchDepth", 1, "BlockType", char(nvp.PortTypes(i)));
                nBlocks = numel(blocks);
                cells = cell(1, nBlocks);
                for j = 1:nBlocks
                    name = string(get_param(blocks{j}, "Name"));
                    cells{j} = mlut.sl.SignalPath( ...
                        name, PortType=nvp.PortTypes(i));
                end
                if isempty(cells)
                    continue
                end
                chunks{end+1} = [cells{:}]; %#ok<AGROW>
            end
            if isempty(chunks)
                signals = mlut.sl.SignalPath.empty(1,0);
                return
            end
            signals = [chunks{:}];
        end

        function signals = fromPort(portPath, portType, busName, dd)
            arguments
                portPath (1,1) string
                portType (1,1) string
                busName (1,1) string = ""
                dd Simulink.data.Dictionary {mustBeScalarOrEmpty} = ...
                    Simulink.data.Dictionary.empty(1,0)
            end

            if busName == ""
                signals = mlut.sl.SignalPath( ...
                    portPath, PortType=portType);
                return
            end
            if isempty(dd)
                error("mlut:sl:busExpansionUnavailable", ...
                    "Cannot expand bus port '%s' because no data dictionary is available.", ...
                    portPath);
            end

            fields = mlut.sl.Bus.enumerateFields(busName, dd);
            if isempty(fields)
                error("mlut:sl:busDefinitionNotFound", ...
                    "Cannot expand bus port '%s' because bus '%s' was not found.", ...
                    portPath, busName);
            end

            cells = cell(1, numel(fields));
            for i = 1:numel(fields)
                cells{i} = mlut.sl.SignalPath( ...
                    portPath, PortType=portType, BusField=fields(i));
            end
            signals = [cells{:}];
        end

        function blockPath = owningBlockPath(instancePath)
            arguments
                instancePath (1,1) string
            end

            blockPath = mlut.sl.Path.owningBlockPath(instancePath);
        end

        function [modelReference, signalPath] = splitModelReferencePath(fullPath)
            arguments
                fullPath (1,1) string
            end

            [modelReference, signalPath] = mlut.sl.Path.splitFirst(fullPath);
            if signalPath == ""
                signalPath = modelReference;
                modelReference = "";
                return
            end
        end
    end

    methods (Static, Access = private)
        function [signals, fieldCache] = fromPortWithFieldCache(portPath, portType, busName, dd, fieldCache)
            arguments
                portPath (1,1) string
                portType (1,1) string
                busName (1,1) string
                dd Simulink.data.Dictionary {mustBeScalarOrEmpty}
                fieldCache (1,1) dictionary
            end

            if busName == ""
                signals = mlut.sl.SignalPath(portPath, PortType=portType);
                return
            end
            if isempty(dd)
                error("mlut:sl:busExpansionUnavailable", ...
                    "Cannot expand bus port '%s' because no data dictionary is available.", ...
                    portPath);
            end

            cacheKey = mlut.sl.Bus.objectName(busName);
            if cacheKey == ""
                cacheKey = strip(busName);
            end

            if fieldCache.isConfigured && isKey(fieldCache, cacheKey)
                cached = fieldCache(cacheKey);
                fields = cached{1};
            else
                fields = mlut.sl.Bus.enumerateFields(busName, dd);
                fieldCache(cacheKey) = {fields};
            end

            if isempty(fields)
                error("mlut:sl:busDefinitionNotFound", ...
                    "Cannot expand bus port '%s' because bus '%s' was not found.", ...
                    portPath, busName);
            end

            cells = cell(1, numel(fields));
            for i = 1:numel(fields)
                cells{i} = mlut.sl.SignalPath( ...
                    portPath, PortType=portType, BusField=fields(i));
            end
            signals = [cells{:}];
        end
    end
end
