classdef ModelInterface
    %MODELINTERFACE Top-level Simulink model ports and compiled port metadata.

    properties
        ModelName (1,1) string
        Ports (1,:) mlut.sl.PortInfo = mlut.sl.PortInfo.empty(1,0)
    end

    properties (Access = private, Hidden)
        ModelCleanup (1,:) onCleanup = onCleanup.empty(1,0)
    end

    methods
        function obj = ModelInterface(modelName, ports, cleanupObj)
            arguments
                modelName (1,1) string
                ports (1,:) mlut.sl.PortInfo = mlut.sl.PortInfo.empty(1,0)
                cleanupObj (1,:) onCleanup = onCleanup.empty(1,0)
            end

            obj.ModelName = modelName;
            obj.Ports = ports;
            obj.ModelCleanup = cleanupObj;
        end

        function outports = compiledOutports(obj)
            arguments
                obj (1,1) mlut.sl.ModelInterface
            end

            if isempty(obj.Ports)
                outports = mlut.sl.CompiledOutportInfo.empty(1,0);
                return
            end

            isOutport = [obj.Ports.PortType] == mlut.sl.PortType.Outport;
            outportHandles = [obj.Ports(isOutport).PortBlockHandle];
            outports = mlut.sl.ModelInterface.compiledOutportsForHandles(outportHandles, obj.ModelName);
        end
    end

    methods (Static)
        function obj = fromModel(modelName)
            arguments
                modelName (1,1) string
            end

            [~, cleanupObj] = mlut.sl.Model.open(modelName);
            depth = Simulink.FindOptions(SearchDepth=1);
            inports = Simulink.findBlocksOfType(modelName, "Inport", depth)';
            outports = Simulink.findBlocksOfType(modelName, "Outport", depth)';
            ports = mlut.sl.PortInfo.create([inports, outports]);
            obj = mlut.sl.ModelInterface(modelName, ports, cleanupObj);
        end
    end

    methods (Static, Access = private)
        function objs = compiledOutportsForHandles(outportHandles, modelName)
            arguments
                outportHandles (1,:) double
                modelName (1,1) string
            end

            if isempty(outportHandles)
                objs = mlut.sl.CompiledOutportInfo.empty(1,0);
                return
            end

            sourceHandles = sourceBlocksForOutports(outportHandles);
            srcOutportHandles = outportsForSourceBlocks(sourceHandles);
            if isempty(srcOutportHandles)
                objs = mlut.sl.CompiledOutportInfo.empty(1,0);
                return
            end

            cleanupObj = compileModel(modelName); %#ok<NASGU>
            cells = cell(1, numel(srcOutportHandles));
            for i = 1:numel(srcOutportHandles)
                srcPortHandle = srcOutportHandles(i);
                cells{i} = mlut.sl.CompiledOutportInfo( ...
                    Name="virt_" + strrep(string(srcPortHandle), ".", "_"), ...
                    SrcPortHandle=srcPortHandle, ...
                    CompiledBusType=string(get_param(srcPortHandle, "CompiledBusType")));
            end
            objs = [cells{:}];
        end
    end
end

function sourceHandles = sourceBlocksForOutports(outportHandles)
sourceHandles = NaN(1, numel(outportHandles));
for i = 1:numel(outportHandles)
    portConnectivity = get_param(outportHandles(i), "PortConnectivity");
    sourceHandles(i) = portConnectivity.SrcBlock;
end
sourceHandles = sourceHandles(~isnan(sourceHandles) & sourceHandles > 0);
sourceHandles = unique(sourceHandles, "stable");
end

function srcOutportHandles = outportsForSourceBlocks(sourceHandles)
chunks = cell(1, numel(sourceHandles));
for i = 1:numel(sourceHandles)
    portHandles = get_param(sourceHandles(i), "PortHandles");
    chunks{i} = portHandles.Outport;
end

if isempty(chunks)
    srcOutportHandles = double.empty(1,0);
else
    srcOutportHandles = [chunks{:}];
end
end

function cleanupObj = compileModel(modelName)
simulationStatus = string(get_param(modelName, "SimulationStatus"));
if simulationStatus == "paused"
    cleanupObj = onCleanup.empty(1,0);
    return
end

variantsCleanup = mlut.sl.setVariantWarningsTemporarily("off"); %#ok<NASGU>
feval(modelName, [], [], [], "compile");
cleanupObj = onCleanup(@() feval(modelName, [], [], [], "term"));
end
