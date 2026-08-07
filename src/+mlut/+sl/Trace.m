classdef Trace
    %TRACE Generic Simulink traversal primitives.

    methods (Static)
        function n = portIndex(blockPath, prop, portName)
            % Find a named Simulink port index from a block port-name parameter.
            arguments
                blockPath (1,1) string
                prop (1,1) string
                portName (1,1) string
            end

            names = mlut.sl.Port.nameList(get_param(char(blockPath), char(prop)));
            n = find(names == portName, 1);
            if isempty(n)
                n = 0;
            end
        end

        function blockType = blockType(blockPath)
            % Return the Simulink BlockType for a block path.
            arguments
                blockPath (1,1) string
            end

            blockType = string(get_param(char(blockPath), "BlockType"));
        end

        function [nextPort, nextField] = backwardsThroughBusSelector(blockPath, srcPort, field)
            % Map a Bus Selector output leaf back to the selector input bus field.
            arguments
                blockPath (1,1) string
                srcPort (1,1) double {mustBeInteger, mustBeNonnegative}
                field (1,1) string
            end

            nextPort = 0;
            nextField = "";

            names = mlut.sl.Trace.busSelectorOutputs(blockPath);
            if srcPort > numel(names)
                return
            end

            nextPort = 1;
            nextField = mlut.sl.Trace.qualifyField(names(srcPort), field);
        end

        function [nextPort, nextField] = forwardsThroughBusSelector(blockPath, field)
            % Map a bus field forward through the matching Bus Selector output.
            arguments
                blockPath (1,1) string
                field (1,1) string
            end

            nextPort = 0;
            nextField = "";

            [head, tail] = mlut.sl.Trace.splitTopField(field);
            if head == ""
                return
            end

            names = mlut.sl.Trace.busSelectorOutputs(blockPath);
            idx = find(names == head, 1);
            if isempty(idx)
                return
            end

            nextPort = idx;
            nextField = tail;
        end

        function [nextPort, nextField] = backwardsThroughBusCreator(blockPath, field)
            % Map a bus field backward through the matching Bus Creator input.
            arguments
                blockPath (1,1) string
                field (1,1) string
            end

            nextPort = 0;
            nextField = "";

            [head, tail] = mlut.sl.Trace.splitTopField(field);
            if head == ""
                return
            end

            topFields = mlut.sl.Trace.busCreatorTopFields(blockPath);
            idx = find(topFields == head, 1);
            if isempty(idx)
                return
            end

            nextPort = idx;
            nextField = tail;
        end

        function [nextPort, nextField] = forwardsThroughBusCreator(blockPath, dstPort, field)
            % Map a Bus Creator input field forward to the combined output bus field.
            arguments
                blockPath (1,1) string
                dstPort (1,1) double {mustBeInteger, mustBeNonnegative}
                field (1,1) string
            end

            nextPort = 0;
            nextField = "";

            topFields = mlut.sl.Trace.busCreatorTopFields(blockPath);
            if dstPort > numel(topFields)
                return
            end

            nextPort = 1;
            nextField = mlut.sl.Trace.qualifyField(topFields(dstPort), field);
        end

        function fullName = qualifyField(prefix, name)
            % Join a parent bus field and child field with dotted mapping syntax.
            arguments
                prefix (1,1) string
                name (1,1) string
            end

            if prefix == ""
                fullName = name;
            elseif name == ""
                fullName = prefix;
            else
                fullName = prefix + "." + name;
            end
        end

        function [parentSub, portNum] = crossBoundary(portBlock)
            % Resolve a subsystem port block to the parent subsystem port number.
            arguments
                portBlock (1,1) string
            end

            parentSub = string(get_param(char(portBlock), "Parent"));
            portNum = mlut.sl.Trace.blockPortNumber(portBlock);
        end

        function [refModel, openedModelCleanupObjs] = loadReferencedModel(refBlock)
            % Open the model referenced by a Model Reference block.
            arguments
                refBlock (1,1) string
            end

            openedModelCleanupObjs = onCleanup.empty(1,0);
            refModel = string(get_param(char(refBlock), "ModelName"));
            if refModel ~= ""
                [~, openedModelCleanupObjs] = mlut.sl.Model.open(refModel);
            end
        end

        function blockPath = rootPortBlock(modelName, blockType, portNum)
            % Find a root Inport or Outport block by port number.
            arguments
                modelName (1,1) string
                blockType (1,1) string {mustBeMember(blockType, ["Inport", "Outport"])}
                portNum (1,1) double {mustBeInteger, mustBePositive}
            end

            blockPath = "";
            blocks = find_system(char(modelName), "SearchDepth", 1, ...
                "BlockType", char(blockType));
            for blockIdx = 1:numel(blocks)
                candidate = string(blocks{blockIdx});
                if mlut.sl.Trace.blockPortNumber(candidate) == portNum
                    blockPath = candidate;
                    return
                end
            end
        end

        function portNum = blockPortNumber(blockPath)
            % Read a port block number, defaulting missing Simulink values to one.
            arguments
                blockPath (1,1) string
            end

            portNum = str2double(string(get_param(char(blockPath), "Port")));
            if isnan(portNum)
                portNum = 1;
            end
        end

        function tf = isModelRootPort(blockPath)
            % Test whether a port block belongs directly to its model root.
            arguments
                blockPath (1,1) string
            end

            parent = string(get_param(char(blockPath), "Parent"));
            tf = parent == string(bdroot(char(blockPath)));
        end

        function tf = isTopModelRootPort(blockPath, topModelName)
            % Test whether a port block is on the original top model boundary.
            arguments
                blockPath (1,1) string
                topModelName (1,1) string
            end

            tf = mlut.sl.Trace.isModelRootPort(blockPath) ...
                && string(bdroot(char(blockPath))) == topModelName;
        end

        function name = subsystemPortName(blockPath, portType, portNum)
            % Find the visible port name for a subsystem input or output number.
            arguments
                blockPath (1,1) string
                portType (1,1) string {mustBeMember(portType, ["Inport", "Outport"])}
                portNum (1,1) double {mustBeInteger, mustBePositive}
            end

            inner = find_system(char(blockPath), "SearchDepth", 1, ...
                "BlockType", char(portType), "Port", num2str(portNum));
            if isempty(inner)
                name = portType + string(portNum);
            else
                name = string(get_param(inner{1}, "Name"));
            end
        end

        function [signalPath, ok] = terminalSignalPath(blockPath, portNum, portType, field)
            % Convert a terminal block or subsystem port into a SignalPath.
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBePositive}
                portType (1,1) string {mustBeMember(portType, ["Inport", "Outport"])}
                field (1,1) string
            end

            signalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;

            blockName = string(get_param(char(blockPath), "Name"));
            switch mlut.sl.Trace.blockType(blockPath)
                case "SubSystem"
                    portName = mlut.sl.Trace.subsystemPortName(blockPath, portType, portNum);
                    instancePath = blockName + "/" + portName;
                case {"Constant", "Inport", "Outport"}
                    instancePath = blockName;
                otherwise
                    return
            end

            signalPath = mlut.sl.SignalPath(instancePath, BusField=field);
            ok = true;
        end

        function [blockPath, portNum] = signalPort(modelName, signalPath)
            % Resolve a model-relative SignalPath to its owning block port number.
            arguments
                modelName (1,1) string
                signalPath (1,1) mlut.sl.SignalPath
            end

            blockPath = "";
            portNum = 0;
            [relativeBlockPath, portName] = mlut.sl.Path.splitLast(signalPath.InstancePath);
            if relativeBlockPath == ""
                return
            end

            switch signalPath.PortType
                case "Inport"
                    portNamesProperty = "InputPortNames";
                case "Outport"
                    portNamesProperty = "OutputPortNames";
                otherwise
                    return
            end

            blockPath = mlut.sl.Path.join(modelName, relativeBlockPath);
            portNum = mlut.sl.Trace.portIndex(blockPath, portNamesProperty, portName);
        end

        function [terminalPath, ok, openedModelCleanupObjs] = toTerminal(modelName, signalPath, nvp)
            % Trace a model-relative signal to the first terminal reached by wiring traversal.
            %
            %   This is deliberately domain-neutral: a terminal is the root
            %   port, subsystem boundary, or source/sink reached after
            %   crossing routing and translation blocks. Callers decide
            %   what that terminal means in their domain.
            arguments
                modelName (1,1) string
                signalPath (1,1) mlut.sl.SignalPath
                nvp.AmbiguousTraceIdentifier (1,1) string = "mlut:sl:Trace:ambiguousTerminal"
                nvp.OpenedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
                nvp.OpenModel (1,1) logical = true
            end

            terminalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;
            openedModelCleanupObjs = nvp.OpenedModelCleanupObjs;

            if signalPath.PortType ~= "Inport" && signalPath.PortType ~= "Outport"
                return
            end

            if nvp.OpenModel
                [~, modelCleanup] = mlut.sl.Model.open(modelName);
                openedModelCleanupObjs = [openedModelCleanupObjs, modelCleanup];
            end

            [blockPath, portNum] = mlut.sl.Trace.signalPort(modelName, signalPath);
            if blockPath == ""
                terminalPath = signalPath;
                ok = true;
                return
            end

            switch signalPath.PortType
                case "Inport"
                    % An input endpoint consumes data, so its terminal is upstream.
                    [terminalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwardsToTerminal( ...
                        blockPath, portNum, signalPath.BusField, ...
                        TopModelName=modelName, ...
                        OpenedModelCleanupObjs=openedModelCleanupObjs, ...
                        AmbiguousTraceIdentifier=nvp.AmbiguousTraceIdentifier);
                case "Outport"
                    % An output endpoint produces data, so its terminal is downstream.
                    [terminalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwardsToTerminal( ...
                        blockPath, portNum, signalPath.BusField, ...
                        TopModelName=modelName, ...
                        OpenedModelCleanupObjs=openedModelCleanupObjs, ...
                        AmbiguousTraceIdentifier=nvp.AmbiguousTraceIdentifier);
                otherwise
                    % PortType validation above makes this branch unreachable.
            end
        end

        function [signalPath, ok, openedModelCleanupObjs] = backwardsToTerminal(blockPath, portNum, field, nvp)
            % Trace backward through Simulink connectivity to a terminal signal path.
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBeNonnegative}
                field (1,1) string
                nvp.TopModelName (1,1) string = string(bdroot(char(blockPath)))
                nvp.ModelReferenceStack (1,:) string = string.empty(1,0)
                nvp.AmbiguousTraceIdentifier (1,1) string = "mlut:sl:Trace:ambiguousTerminal"
                nvp.OpenedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwards( ...
                blockPath, portNum, field, nvp.ModelReferenceStack, ...
                nvp.TopModelName, nvp.AmbiguousTraceIdentifier, nvp.OpenedModelCleanupObjs);
        end

        function [signalPath, ok, openedModelCleanupObjs] = forwardsToTerminal(blockPath, portNum, field, nvp)
            % Trace forward through Simulink connectivity to a terminal signal path.
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBeNonnegative}
                field (1,1) string
                nvp.TopModelName (1,1) string = string(bdroot(char(blockPath)))
                nvp.ModelReferenceStack (1,:) string = string.empty(1,0)
                nvp.AmbiguousTraceIdentifier (1,1) string = "mlut:sl:Trace:ambiguousTerminal"
                nvp.OpenedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwards( ...
                blockPath, portNum, field, nvp.ModelReferenceStack, ...
                nvp.TopModelName, nvp.AmbiguousTraceIdentifier, nvp.OpenedModelCleanupObjs);
        end

        function linkedPath = forwardsToEndpoint(blockPath, portNum, field, endpoints, modelName, nvp)
            % Trace forward until a downstream input matches one of the endpoint paths.
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBeNonnegative}
                field (1,1) string
                endpoints (1,:) string
                modelName (1,1) string
                nvp.AmbiguousTraceIdentifier (1,1) string = "mlut:sl:Trace:ambiguousEndpoint"
            end

            linkedPath = "";
            if portNum == 0
                return
            end

            [linkedPath, fastPathSupported] = mlut.sl.Trace.forwardsToEndpointFast( ...
                blockPath, portNum, field, endpoints, modelName, nvp.AmbiguousTraceIdentifier);
            if fastPathSupported
                return
            end

            traceResult = mlut.sl.Trace.sltraceGraph(blockPath, "Destination", portNum);
            candidates = mlut.sl.Trace.inputEndpointCandidates( ...
                traceResult.TraceGraph, endpoints, modelName, field, blockPath, portNum);

            if isempty(candidates)
                return
            end
            if numel(candidates) > 1
                error(nvp.AmbiguousTraceIdentifier, ...
                    "Signal '%s' fans out to multiple endpoints: %s", ...
                    blockPath, strjoin(candidates, ", "));
            end
            linkedPath = candidates(1);
        end

        function traceResult = sltraceGraph(blockPath, direction, portNum, field)
            % Run sltrace for one block port, falling back when bus element metadata is absent.
            arguments
                blockPath (1,1) string
                direction (1,1) string {mustBeMember(direction, ["Source", "Destination"])}
                portNum (1,1) double {mustBeInteger, mustBePositive}
                field (1,1) string = ""
            end

            if field == ""
                [traceResult, found] = mlut.sl.internal.TraceGraphCache.get( ...
                    direction, blockPath, portNum);
                if found
                    return
                end

                traceResult = sltrace(blockPath, direction, Port=portNum, TraceAll="on");
                mlut.sl.internal.TraceGraphCache.set( ...
                    direction, blockPath, portNum, traceResult);
                return
            end

            try
                traceResult = sltrace( ...
                    blockPath, direction, Port=portNum, Element=field, TraceAll="on");
            catch err
                if ~mlut.sl.Trace.isInvalidBusElementTraceError(err)
                    rethrow(err)
                end
                traceResult = mlut.sl.Trace.sltraceGraph(blockPath, direction, portNum);
            end
        end

        function tf = isInvalidBusElementTraceError(err)
            % Classify sltrace failures caused by an inapplicable bus element selector.
            arguments
                err (1,1) MException
            end

            traceErrorIds = [
                "Simulink:Commands:InvSimulinkObjectName"
                "Simulink:HiliteTool:InvalidBusElement"];
            tf = any(err.identifier == traceErrorIds) ...
                || contains(lower(string(err.message)), "bus element");
        end
    end

    methods (Static, Access = private)
        function [linkedPath, supported] = forwardsToEndpointFast( ...
                blockPath, portNum, field, endpoints, topModelName, ambiguousTraceId)
            % Fast path for endpoint tracing through routing/bus topology.
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBeNonnegative}
                field (1,1) string
                endpoints (1,:) string
                topModelName (1,1) string
                ambiguousTraceId (1,1) string
            end

            linkedPath = "";
            supported = true;
            if portNum == 0
                return
            end

            queueBlocks = blockPath;
            queuePorts = portNum;
            queueFields = field;
            visited = strings(1,0);
            nextIdx = 1;

            while nextIdx <= numel(queueBlocks)
                layerEnd = numel(queueBlocks);
                layerCandidates = strings(1,0);
                while nextIdx <= layerEnd
                    currentBlock = queueBlocks(nextIdx);
                    currentPort = queuePorts(nextIdx);
                    currentField = queueFields(nextIdx);
                    stateKey = mlut.sl.Trace.endpointTraceStateKey( ...
                        currentBlock, currentPort, currentField);
                    nextIdx = nextIdx + 1;
                    if any(visited == stateKey)
                        continue
                    end
                    visited(end+1) = stateKey; %#ok<AGROW>

                    [dstBlocks, dstPorts] = mlut.sl.Connection.downstreamOf( ...
                        currentBlock, currentPort);
                    if isempty(dstBlocks)
                        continue
                    end

                    for destinationIdx = 1:numel(dstBlocks)
                        [candidate, nextBlocks, nextPorts, nextFields, transitionSupported] = ...
                            mlut.sl.Trace.forwardEndpointTransition( ...
                            dstBlocks(destinationIdx), dstPorts(destinationIdx), ...
                            currentField, endpoints, topModelName);
                        if ~transitionSupported
                            linkedPath = "";
                            supported = false;
                            return
                        end

                        if candidate ~= "" && ~any(layerCandidates == candidate)
                            layerCandidates(end+1) = candidate; %#ok<AGROW>
                        end

                        if ~isempty(nextBlocks)
                            queueBlocks = [queueBlocks, nextBlocks]; %#ok<AGROW>
                            queuePorts = [queuePorts, nextPorts]; %#ok<AGROW>
                            queueFields = [queueFields, nextFields]; %#ok<AGROW>
                        end
                    end
                end

                if isempty(layerCandidates)
                    continue
                end
                if numel(layerCandidates) > 1
                    error(ambiguousTraceId, ...
                        "Signal '%s' fans out to multiple endpoints: %s", ...
                        blockPath, strjoin(layerCandidates, ", "));
                end
                linkedPath = layerCandidates(1);
                return
            end
        end

        function [candidate, nextBlocks, nextPorts, nextFields, supported] = ...
                forwardEndpointTransition(dstBlock, dstPort, field, endpoints, topModelName)
            % Resolve one destination block to either an endpoint or next traversal states.
            arguments
                dstBlock (1,1) string
                dstPort (1,1) double {mustBeInteger, mustBePositive}
                field (1,1) string
                endpoints (1,:) string
                topModelName (1,1) string
            end

            nextBlocks = string.empty(1,0);
            nextPorts = zeros(1,0);
            nextFields = string.empty(1,0);
            supported = true;

            candidate = mlut.sl.Trace.matchedEndpointAtInput( ...
                dstBlock, dstPort, field, endpoints, topModelName);
            if candidate ~= ""
                return
            end

            blockType = mlut.sl.Trace.blockType(dstBlock);
            switch blockType
                case "SubSystem"
                    innerInport = mlut.sl.Trace.rootPortBlock(dstBlock, "Inport", dstPort);
                    if innerInport == ""
                        return
                    end
                    nextBlocks = innerInport;
                    nextPorts = 1;
                    nextFields = field;
                case "Outport"
                    [nextBlock, nextPort, nextField, supported] = ...
                        mlut.sl.Trace.forwardThroughOutportForEndpoint( ...
                        dstBlock, field, topModelName);
                    if nextBlock == ""
                        return
                    end
                    nextBlocks = nextBlock;
                    nextPorts = nextPort;
                    nextFields = nextField;
                case "BusSelector"
                    [nextPort, nextField] = mlut.sl.Trace.forwardsThroughBusSelector(dstBlock, field);
                    if nextPort == 0
                        return
                    end
                    nextBlocks = dstBlock;
                    nextPorts = nextPort;
                    nextFields = nextField;
                case "BusCreator"
                    [nextPort, nextField] = mlut.sl.Trace.forwardsThroughBusCreator(dstBlock, dstPort, field);
                    if nextPort == 0
                        return
                    end
                    nextBlocks = dstBlock;
                    nextPorts = nextPort;
                    nextFields = nextField;
                case "Goto"
                    fromBlocks = mlut.sl.Connection.fromBlocksForGoto(dstBlock);
                    nextBlocks = fromBlocks;
                    nextPorts = ones(1, numel(fromBlocks));
                    nextFields = repmat(field, 1, numel(fromBlocks));
                otherwise
                    if mlut.sl.MATLABFunctionBlock.isBlock(dstBlock)
                        fieldMap = mlut.sl.MATLABFunctionBlock.fieldMap(dstBlock);
                        outputField = mlut.sl.Trace.reverseLookup(fieldMap, field);
                        if outputField == ""
                            return
                        end
                        nextBlocks = dstBlock;
                        nextPorts = 1;
                        nextFields = outputField;
                    else
                        supported = false;
                    end
            end
        end

        function endpoint = matchedEndpointAtInput(blockPath, portNum, field, endpoints, topModelName)
            % Match a destination input boundary against extracted endpoints.
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBePositive}
                field (1,1) string
                endpoints (1,:) string
                topModelName (1,1) string
            end

            endpoint = "";
            blockType = mlut.sl.Trace.blockType(blockPath);
            switch blockType
                case "ModelReference"
                    portNames = mlut.sl.Port.nameList( ...
                        get_param(char(blockPath), "InputPortNames"));
                    if portNum > numel(portNames)
                        return
                    end
                    basePath = mlut.sl.Path.join( ...
                        mlut.sl.Path.relativeToModel(blockPath, topModelName), ...
                        portNames(portNum));
                case "Inport"
                    if ~mlut.sl.Trace.isTopModelRootPort(blockPath, topModelName)
                        return
                    end
                    basePath = string(get_param(char(blockPath), "Name"));
                case "SubSystem"
                    portName = mlut.sl.Trace.subsystemPortName(blockPath, "Inport", portNum);
                    basePath = mlut.sl.Path.join( ...
                        mlut.sl.Path.relativeToModel(blockPath, topModelName), ...
                        portName);
                otherwise
                    return
            end

            candidate = mlut.sl.Trace.qualifyField(basePath, field);
            if any(endpoints == candidate)
                endpoint = candidate;
                return
            end

            if field ~= "" && any(endpoints == basePath)
                endpoint = basePath;
            end
        end

        function [nextBlock, nextPort, nextField, supported] = ...
                forwardThroughOutportForEndpoint(portBlock, field, topModelName)
            % Cross a subsystem Outport boundary while endpoint tracing forward.
            arguments
                portBlock (1,1) string
                field (1,1) string
                topModelName (1,1) string
            end

            nextBlock = "";
            nextPort = 0;
            nextField = field;
            supported = true;

            if mlut.sl.Trace.isTopModelRootPort(portBlock, topModelName)
                return
            end

            if mlut.sl.Trace.isModelRootPort(portBlock)
                supported = false;
                return
            end

            [nextBlock, nextPort] = mlut.sl.Trace.crossBoundary(portBlock);
        end

        function key = endpointTraceStateKey(blockPath, portNum, field)
            % Build a stable key for endpoint-trace traversal state.
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBeNonnegative}
                field (1,1) string
            end

            key = blockPath + "|" + string(portNum) + "|" + field;
        end

        function [signalPath, ok, openedModelCleanupObjs] = backwards( ...
                blockPath, portNum, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs)
            % Trace a block input backward through upstream Simulink connectivity.
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBeNonnegative}
                field (1,1) string
                refStack (1,:) string
                topModelName (1,1) string
                ambiguousTraceId (1,1) string
                openedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            signalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;
            if portNum == 0
                return
            end

            [srcBlock, srcPort] = mlut.sl.Connection.upstreamOf(blockPath, portNum);
            if srcBlock == ""
                return
            end

            blockType = mlut.sl.Trace.blockType(srcBlock);
            switch blockType
                case "Inport"
                    [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwardsThroughInport( ...
                        srcBlock, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                    return
                case "ModelReference"
                    [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwardsThroughModelReference( ...
                        srcBlock, srcPort, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                    return
                case "BusSelector"
                    [nextPort, nextField] = mlut.sl.Trace.backwardsThroughBusSelector(srcBlock, srcPort, field);
                    if nextPort == 0
                        return
                    end
                    [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwards( ...
                        srcBlock, nextPort, nextField, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                    return
                case "BusCreator"
                    [nextPort, nextField] = mlut.sl.Trace.backwardsThroughBusCreator(srcBlock, field);
                    if nextPort == 0
                        return
                    end
                    [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwards( ...
                        srcBlock, nextPort, nextField, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                    return
                case "From"
                    gotoBlock = mlut.sl.Connection.gotoBlockForFrom(srcBlock);
                    if gotoBlock == ""
                        return
                    end
                    [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwards( ...
                        gotoBlock, 1, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                    return
            end

            if mlut.sl.MATLABFunctionBlock.isBlock(srcBlock)
                fieldMap = mlut.sl.MATLABFunctionBlock.fieldMap(srcBlock);
                if ~isKey(fieldMap, field)
                    return
                end
                [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwards( ...
                    srcBlock, 1, fieldMap(field), refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                return
            end

            [signalPath, ok] = mlut.sl.Trace.terminalSignalPath(srcBlock, srcPort, "Outport", field);
        end

        function [signalPath, ok, openedModelCleanupObjs] = forwards( ...
                blockPath, portNum, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs)
            % Trace a block output forward through downstream Simulink connectivity.
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBeNonnegative}
                field (1,1) string
                refStack (1,:) string
                topModelName (1,1) string
                ambiguousTraceId (1,1) string
                openedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            signalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;
            if portNum == 0
                return
            end

            [dstBlocks, dstPorts] = mlut.sl.Connection.downstreamOf(blockPath, portNum);
            if isempty(dstBlocks)
                return
            end

            if isscalar(dstBlocks)
                [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwardsToDestination( ...
                    dstBlocks(1), dstPorts(1), field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                return
            end

            [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.resolveForwardBranches( ...
                blockPath, dstBlocks, dstPorts, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
        end

        function [signalPath, ok, openedModelCleanupObjs] = resolveForwardBranches( ...
                blockPath, dstBlocks, dstPorts, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs)
            % Collapse fan-out branches to one unique terminal or report ambiguity.
            arguments
                blockPath (1,1) string
                dstBlocks (1,:) string
                dstPorts (1,:) double
                field (1,1) string
                refStack (1,:) string
                topModelName (1,1) string
                ambiguousTraceId (1,1) string
                openedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            signalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;
            candidatePaths = strings(1,0);
            candidate = mlut.sl.SignalPath.empty(1,0);
            for destinationIdx = 1:numel(dstBlocks)
                [nextSignalPath, nextOk, openedModelCleanupObjs] = mlut.sl.Trace.forwardsToDestination( ...
                    dstBlocks(destinationIdx), dstPorts(destinationIdx), field, refStack, ...
                    topModelName, ambiguousTraceId, openedModelCleanupObjs);
                if ~nextOk
                    continue
                end
                nextPath = nextSignalPath.fullPath();
                if any(candidatePaths == nextPath)
                    continue
                end
                candidatePaths(end+1) = nextPath; %#ok<AGROW>
                candidate = nextSignalPath;
            end

            if isempty(candidatePaths)
                return
            end
            if numel(candidatePaths) > 1
                error(ambiguousTraceId, ...
                    "Signal '%s' fans out to multiple terminals: %s", ...
                    blockPath, strjoin(candidatePaths, ", "));
            end

            signalPath = candidate;
            ok = true;
        end

        function [signalPath, ok, openedModelCleanupObjs] = forwardsToDestination( ...
                dstBlock, dstPort, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs)
            % Trace through one downstream destination block during forward traversal.
            arguments
                dstBlock (1,1) string
                dstPort (1,1) double {mustBeInteger, mustBePositive}
                field (1,1) string
                refStack (1,:) string
                topModelName (1,1) string
                ambiguousTraceId (1,1) string
                openedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            signalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;

            blockType = mlut.sl.Trace.blockType(dstBlock);
            switch blockType
                case "Outport"
                    [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwardsThroughOutport( ...
                        dstBlock, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                    return
                case "ModelReference"
                    [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwardsThroughModelReference( ...
                        dstBlock, dstPort, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                    return
                case "BusSelector"
                    [nextPort, nextField] = mlut.sl.Trace.forwardsThroughBusSelector(dstBlock, field);
                    if nextPort == 0
                        return
                    end
                    [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwards( ...
                        dstBlock, nextPort, nextField, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                    return
                case "BusCreator"
                    [nextPort, nextField] = mlut.sl.Trace.forwardsThroughBusCreator(dstBlock, dstPort, field);
                    if nextPort == 0
                        return
                    end
                    [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwards( ...
                        dstBlock, nextPort, nextField, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                    return
                case "Goto"
                    fromBlocks = mlut.sl.Connection.fromBlocksForGoto(dstBlock);
                    [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.resolveForwardSources( ...
                        dstBlock, fromBlocks, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                    return
            end

            if mlut.sl.MATLABFunctionBlock.isBlock(dstBlock)
                fieldMap = mlut.sl.MATLABFunctionBlock.fieldMap(dstBlock);
                outputField = mlut.sl.Trace.reverseLookup(fieldMap, field);
                if outputField == ""
                    return
                end
                [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwards( ...
                    dstBlock, 1, outputField, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                return
            end

            [signalPath, ok] = mlut.sl.Trace.terminalSignalPath(dstBlock, dstPort, "Inport", field);
        end

        function [signalPath, ok, openedModelCleanupObjs] = resolveForwardSources( ...
                blockPath, srcBlocks, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs)
            % Collapse Goto/From source branches to one unique terminal.
            arguments
                blockPath (1,1) string
                srcBlocks (1,:) string
                field (1,1) string
                refStack (1,:) string
                topModelName (1,1) string
                ambiguousTraceId (1,1) string
                openedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            signalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;
            candidatePaths = strings(1,0);
            candidate = mlut.sl.SignalPath.empty(1,0);
            for sourceIdx = 1:numel(srcBlocks)
                [nextSignalPath, nextOk, openedModelCleanupObjs] = mlut.sl.Trace.forwards( ...
                    srcBlocks(sourceIdx), 1, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
                if ~nextOk
                    continue
                end
                nextPath = nextSignalPath.fullPath();
                if any(candidatePaths == nextPath)
                    continue
                end
                candidatePaths(end+1) = nextPath; %#ok<AGROW>
                candidate = nextSignalPath;
            end

            if isempty(candidatePaths)
                return
            end
            if numel(candidatePaths) > 1
                error(ambiguousTraceId, ...
                    "Signal '%s' fans out to multiple terminals: %s", ...
                    blockPath, strjoin(candidatePaths, ", "));
            end

            signalPath = candidate;
            ok = true;
        end

        function [signalPath, ok, openedModelCleanupObjs] = backwardsThroughInport( ...
                portBlock, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs)
            % Cross an Inport boundary while tracing backward.
            arguments
                portBlock (1,1) string
                field (1,1) string
                refStack (1,:) string
                topModelName (1,1) string
                ambiguousTraceId (1,1) string
                openedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            signalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;

            if mlut.sl.Trace.isTopModelRootPort(portBlock, topModelName)
                [signalPath, ok] = mlut.sl.Trace.terminalSignalPath(portBlock, 1, "Inport", field);
                return
            end

            if mlut.sl.Trace.isModelRootPort(portBlock)
                if isempty(refStack)
                    return
                end
                portNum = mlut.sl.Trace.blockPortNumber(portBlock);
                [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwards( ...
                    refStack(end), portNum, field, refStack(1:end-1), topModelName, ...
                    ambiguousTraceId, openedModelCleanupObjs);
                return
            end

            [parentSub, portNum] = mlut.sl.Trace.crossBoundary(portBlock);
            [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwards( ...
                parentSub, portNum, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
        end

        function [signalPath, ok, openedModelCleanupObjs] = forwardsThroughOutport( ...
                portBlock, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs)
            % Cross an Outport boundary while tracing forward.
            arguments
                portBlock (1,1) string
                field (1,1) string
                refStack (1,:) string
                topModelName (1,1) string
                ambiguousTraceId (1,1) string
                openedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            signalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;

            if mlut.sl.Trace.isTopModelRootPort(portBlock, topModelName)
                [signalPath, ok] = mlut.sl.Trace.terminalSignalPath(portBlock, 1, "Outport", field);
                return
            end

            if mlut.sl.Trace.isModelRootPort(portBlock)
                if isempty(refStack)
                    return
                end
                portNum = mlut.sl.Trace.blockPortNumber(portBlock);
                [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwards( ...
                    refStack(end), portNum, field, refStack(1:end-1), topModelName, ...
                    ambiguousTraceId, openedModelCleanupObjs);
                return
            end

            [parentSub, portNum] = mlut.sl.Trace.crossBoundary(portBlock);
            [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwards( ...
                parentSub, portNum, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs);
        end

        function [signalPath, ok, openedModelCleanupObjs] = backwardsThroughModelReference( ...
                refBlock, portNum, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs)
            % Enter a referenced model through its root Outport while tracing backward.
            arguments
                refBlock (1,1) string
                portNum (1,1) double {mustBeInteger, mustBePositive}
                field (1,1) string
                refStack (1,:) string
                topModelName (1,1) string
                ambiguousTraceId (1,1) string
                openedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            signalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;

            [refModel, refCleanup] = mlut.sl.Trace.loadReferencedModel(refBlock);
            openedModelCleanupObjs = [openedModelCleanupObjs, refCleanup];
            innerOutport = mlut.sl.Trace.rootPortBlock(refModel, "Outport", portNum);
            if innerOutport == ""
                return
            end

            [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.backwards( ...
                innerOutport, 1, field, [refStack, refBlock], topModelName, ...
                ambiguousTraceId, openedModelCleanupObjs);
        end

        function [signalPath, ok, openedModelCleanupObjs] = forwardsThroughModelReference( ...
                refBlock, portNum, field, refStack, topModelName, ambiguousTraceId, openedModelCleanupObjs)
            % Enter a referenced model through its root Inport while tracing forward.
            arguments
                refBlock (1,1) string
                portNum (1,1) double {mustBeInteger, mustBePositive}
                field (1,1) string
                refStack (1,:) string
                topModelName (1,1) string
                ambiguousTraceId (1,1) string
                openedModelCleanupObjs (1,:) onCleanup = onCleanup.empty(1,0)
            end

            signalPath = mlut.sl.SignalPath.empty(1,0);
            ok = false;

            [refModel, refCleanup] = mlut.sl.Trace.loadReferencedModel(refBlock);
            openedModelCleanupObjs = [openedModelCleanupObjs, refCleanup];
            innerInport = mlut.sl.Trace.rootPortBlock(refModel, "Inport", portNum);
            if innerInport == ""
                return
            end

            [signalPath, ok, openedModelCleanupObjs] = mlut.sl.Trace.forwards( ...
                innerInport, 1, field, [refStack, refBlock], topModelName, ...
                ambiguousTraceId, openedModelCleanupObjs);
        end

        function outputField = reverseLookup(fieldMap, inputField)
            % Find the output field that maps to a given input field.
            arguments
                fieldMap
                inputField (1,1) string
            end

            outputField = "";
            outputFields = keys(fieldMap);
            for outputFieldIdx = 1:numel(outputFields)
                if fieldMap(outputFields(outputFieldIdx)) == inputField
                    outputField = outputFields(outputFieldIdx);
                    return
                end
            end
        end

        function candidates = inputEndpointCandidates( ...
                traceGraph, endpoints, modelName, field, sourceBlockPath, sourcePort)
            % Find extracted input endpoints represented by sltrace graph nodes.
            arguments
                traceGraph (1,1) digraph
                endpoints (1,:) string
                modelName (1,1) string
                field (1,1) string
                sourceBlockPath (1,1) string
                sourcePort (1,1) double {mustBeInteger, mustBePositive}
            end

            candidates = strings(1,0);
            candidateDistances = zeros(1,0);
            nodes = traceGraph.Nodes;
            nodeDistances = mlut.sl.Trace.traceNodeDistances( ...
                traceGraph, sourceBlockPath, sourcePort);
            reachableNodes = find(isfinite(nodeDistances));
            for nodeIdx = reshape(reachableNodes, 1, [])
                if nodes.PortType(nodeIdx) ~= "inport"
                    continue
                end

                blockPath = mlut.sl.Trace.blockPathFromTraceNode(nodes.Block(nodeIdx));
                candidate = mlut.sl.Trace.endpointAtInput( ...
                    blockPath, nodes.PortNumber(nodeIdx), field, endpoints, modelName);
                if candidate == "" && field ~= ""
                    candidate = mlut.sl.Trace.endpointAtInput( ...
                        blockPath, nodes.PortNumber(nodeIdx), "", endpoints, modelName);
                end
                if candidate == ""
                    continue
                end

                existingIdx = find(candidates == candidate, 1);
                if isempty(existingIdx)
                    candidates(end+1) = candidate; %#ok<AGROW>
                    candidateDistances(end+1) = nodeDistances(nodeIdx); %#ok<AGROW>
                else
                    candidateDistances(existingIdx) = min( ...
                        candidateDistances(existingIdx), nodeDistances(nodeIdx));
                end
            end

            if isempty(candidates)
                return
            end

            % Cyclic traces can reach feedback endpoints after the direct
            % sink; the requested forward endpoint is the nearest match.
            minDistance = min(candidateDistances);
            candidates = candidates(candidateDistances == minDistance);
        end

        function nodeDistances = traceNodeDistances(traceGraph, sourceBlockPath, sourcePort)
            % Return distances from the requested source output port.
            arguments
                traceGraph (1,1) digraph
                sourceBlockPath (1,1) string
                sourcePort (1,1) double {mustBeInteger, mustBePositive}
            end

            nodes = traceGraph.Nodes;
            sourceNodes = zeros(1,0);
            for k = 1:height(nodes)
                if nodes.PortType(k) ~= "outport" || nodes.PortNumber(k) ~= sourcePort
                    continue
                end
                blockPath = mlut.sl.Trace.blockPathFromTraceNode(nodes.Block(k));
                if blockPath == sourceBlockPath
                    sourceNodes(end+1) = k; %#ok<AGROW>
                end
            end
            if isempty(sourceNodes)
                nodeDistances = inf(1, height(nodes));
                return
            end

            graphDistances = distances(traceGraph, sourceNodes);
            nodeDistances = min(graphDistances, [], 1);
        end

        function blockPath = blockPathFromTraceNode(block)
            % Convert an sltrace graph block value to a Simulink block path.
            arguments
                block
            end

            if isa(block, "Simulink.BlockPath")
                blockPath = string(block.getBlock(1));
            else
                blockPath = string(getfullname(block));
            end
        end

        function endpoint = endpointAtInput(blockPath, portNum, field, endpoints, modelName)
            % Return the endpoint represented by a block input port.
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBePositive}
                field (1,1) string
                endpoints (1,:) string
                modelName (1,1) string
            end

            endpoint = "";
            switch mlut.sl.Trace.blockType(blockPath)
                case "ModelReference"
                    portNames = mlut.sl.Port.nameList( ...
                        get_param(char(blockPath), "InputPortNames"));
                    if portNum > numel(portNames)
                        return
                    end
                    candidate = mlut.sl.Path.join( ...
                        mlut.sl.Path.relativeToModel(blockPath, modelName), ...
                        portNames(portNum));
                case "Inport"
                    candidate = string(get_param(char(blockPath), "Name"));
                otherwise
                    return
            end

            candidate = mlut.sl.Trace.qualifyField(candidate, field);
            if any(endpoints == candidate)
                endpoint = candidate;
            end
        end

        function names = busSelectorOutputs(blockPath)
            % Read the configured Bus Selector output field names.
            arguments
                blockPath (1,1) string
            end

            names = split(string(get_param(char(blockPath), "OutputSignals")), ",");
            names = strip(names);
            names = names(names ~= "");
        end

        function fields = busCreatorTopFields(blockPath)
            % Resolve the top-level output bus fields for a Bus Creator block.
            arguments
                blockPath (1,1) string
            end

            fields = string.empty(1,0);
            busName = mlut.sl.Bus.objectName( ...
                string(get_param(char(blockPath), "OutDataTypeStr")));
            if busName == ""
                return
            end

            fields = mlut.sl.Bus.topLevelFieldsForModel( ...
                busName, string(bdroot(char(blockPath))));
        end

        function [head, tail] = splitTopField(field)
            % Split a dotted bus field into the first segment and remaining tail.
            arguments
                field (1,1) string
            end

            head = "";
            tail = "";
            parts = split(string(field), ".");
            parts = parts(parts ~= "");
            if isempty(parts)
                return
            end

            head = parts(1);
            if numel(parts) > 1
                tail = strjoin(parts(2:end), ".");
            end
        end
    end
end
