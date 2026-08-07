classdef PortInfo
    %PORTINFO Metadata for a top-level Simulink inport or outport block.

    properties
        ModelName (1,1) string
        PortBlockName (1,1) string
        PortBlockHandle (1,1) double
        SID (1,1) string
        PortType (1,1) mlut.sl.PortType
        PortHandle (1,1) double
        PortConnectivity (1,:) struct
        PortDimension (:,:) double
        PortDataType (1,1) string
        BusName (1,1) string
        OutputAsStruct (1,1) string
        LineHandle (1,1) double
        LineName (1,1) string
        SignalName (1,1) string
        IsSigObj (1,1) logical
        SrcBlock (1,1) string
        SrcBlockHandle (1,1) double
        SrcBlockType (1,1) string
        SrcPortHandle (1,1) double
    end

    methods
        function obj = PortInfo(nvp)
            arguments
                nvp.?mlut.sl.PortInfo
            end

            fieldsToSet = string(fields(nvp));
            for i = 1:numel(fieldsToSet)
                fieldName = fieldsToSet(i);
                obj.(fieldName) = nvp.(fieldName);
            end
        end

        function tbl = table(objs)
            arguments
                objs (1,:) mlut.sl.PortInfo
            end

            if isempty(objs)
                tbl = table( ...
                    strings(0,1), zeros(0,1), strings(0,1), ...
                    mlut.sl.PortType.empty(0,1), zeros(0,1), cell(0,1), ...
                    strings(0,1), strings(0,1), strings(0,1), zeros(0,1), ...
                    strings(0,1), strings(0,1), false(0,1), strings(0,1), ...
                    zeros(0,1), strings(0,1), zeros(0,1), ...
                    VariableNames=["PortBlockName", "PortBlockHandle", "SID", "PortType", ...
                    "PortHandle", "PortDimension", "PortDataType", "BusName", ...
                    "OutputAsStruct", "LineHandle", "LineName", "SignalName", "IsSigObj", ...
                    "SrcBlock", "SrcBlockHandle", "SrcBlockType", "SrcPortHandle"]);
                return
            end

            portBlockName = [objs.PortBlockName]';
            portBlockHandle = [objs.PortBlockHandle]';
            sid = [objs.SID]';
            portType = [objs.PortType]';
            portHandle = [objs.PortHandle]';
            portDimension = {objs.PortDimension}';
            portDataType = [objs.PortDataType]';
            busName = [objs.BusName]';
            outputAsStruct = [objs.OutputAsStruct]';
            lineHandle = [objs.LineHandle]';
            lineName = [objs.LineName]';
            signalName = [objs.SignalName]';
            isSigObj = [objs.IsSigObj]';
            srcBlock = [objs.SrcBlock]';
            srcBlockHandle = [objs.SrcBlockHandle]';
            srcBlockType = [objs.SrcBlockType]';
            srcPortHandle = [objs.SrcPortHandle]';

            tbl = table( ...
                portBlockName, portBlockHandle, sid, portType, portHandle, ...
                portDimension, portDataType, busName, outputAsStruct, lineHandle, ...
                lineName, signalName, isSigObj, srcBlock, srcBlockHandle, srcBlockType, ...
                srcPortHandle, ...
                VariableNames=["PortBlockName", "PortBlockHandle", "SID", "PortType", ...
                "PortHandle", "PortDimension", "PortDataType", "BusName", ...
                "OutputAsStruct", "LineHandle", "LineName", "SignalName", "IsSigObj", ...
                "SrcBlock", "SrcBlockHandle", "SrcBlockType", "SrcPortHandle"]);
        end

        function objs = filter(objs, variable, value)
            arguments
                objs
                variable (1,1) string {mustBeMember(variable, ["PortBlockName", "SID"])}
                value (1,:)
            end

            idx = ismember([objs.(variable)], value);
            objs = objs(idx);
        end
    end

    methods (Static)
        function objs = create(portHandles)
            arguments
                portHandles (1,:) double
            end

            cells = cell(1, numel(portHandles));
            for i = 1:numel(portHandles)
                cells{i} = mlut.sl.PortInfo.fromBlock(portHandles(i));
            end

            if isempty(cells)
                objs = mlut.sl.PortInfo.empty(1,0);
            else
                objs = [cells{:}];
            end
        end
    end

    methods (Static, Access = private)
        function obj = fromBlock(portBlockHandle)
            blockType = string(get_param(portBlockHandle, "BlockType"));
            switch blockType
                case "Inport"
                    portType = mlut.sl.PortType.Inport;
                    blockPortField = "Outport";
                case "Outport"
                    portType = mlut.sl.PortType.Outport;
                    blockPortField = "Inport";
                otherwise
                    error("mlut:sl:unsupportedPortBlockType", ...
                        "Block type '%s' is not a supported root port type.", blockType);
            end

            portHandles = get_param(portBlockHandle, "PortHandles");
            portHandle = portHandles.(blockPortField);
            dataType = string(get_param(portBlockHandle, "OutDataTypeStr"));
            lineHandle = get_param(portHandle, "Line");
            signalName = string(get_param(portBlockHandle, "PortName"));
            if signalName == ""
                signalName = string(NaN);
            end

            [lineName, isSigObj, srcInfo] = lineInfo(portType, portBlockHandle, portHandle, lineHandle);

            obj = mlut.sl.PortInfo( ...
                ModelName=string(get_param(portBlockHandle, "Parent")), ...
                PortBlockName=string(get_param(portBlockHandle, "Name")), ...
                PortBlockHandle=portBlockHandle, ...
                SID=mlut.sl.getSID(portBlockHandle), ...
                PortType=portType, ...
                PortHandle=portHandle, ...
                PortConnectivity=srcInfo.PortConnectivity, ...
                PortDimension=parseDimension(get_param(portBlockHandle, "PortDimensions")), ...
                PortDataType=dataType, ...
                BusName=mlut.sl.Bus.objectName(dataType), ...
                OutputAsStruct=string(get_param(portBlockHandle, "BusOutputAsStruct")), ...
                LineHandle=lineHandle, ...
                LineName=lineName, ...
                SignalName=signalName, ...
                IsSigObj=isSigObj, ...
                SrcBlock=srcInfo.Block, ...
                SrcBlockHandle=srcInfo.BlockHandle, ...
                SrcBlockType=srcInfo.BlockType, ...
                SrcPortHandle=srcInfo.PortHandle);
        end
    end
end

function [lineName, isSigObj, srcInfo] = lineInfo(portType, portBlockHandle, portHandle, lineHandle)
lineName = string(NaN);
isSigObj = false;
srcInfo = struct( ...
    PortConnectivity=struct.empty(), ...
    Block=string(NaN), ...
    BlockHandle=NaN, ...
    BlockType=string(NaN), ...
    PortHandle=NaN);

if lineHandle == -1
    return
end

lineName = string(get_param(lineHandle, "Name"));
mustResolve = "off";
if portType == mlut.sl.PortType.Inport
    mustResolve = string(get_param(portHandle, "MustResolveToSignalObject"));
else
    srcInfo.PortHandle = get_param(lineHandle, "SrcPortHandle");
    srcInfo.Block = string(get_param(srcInfo.PortHandle, "Parent"));
    srcInfo.BlockHandle = get_param(srcInfo.Block, "Handle");
    srcInfo.BlockType = string(get_param(srcInfo.Block, "BlockType"));
    srcInfo.PortConnectivity = get_param(portBlockHandle, "PortConnectivity");

    sourcePortHandles = get_param(srcInfo.PortConnectivity.SrcBlock, "PortHandles");
    sourceOutports = sourcePortHandles.Outport;
    portBlockName = string(get_param(portBlockHandle, "Name"));
    for i = 1:numel(sourceOutports)
        if strcmpi(get_param(sourceOutports(i), "Name"), portBlockName)
            mustResolve = string(get_param(sourceOutports(i), "MustResolveToSignalObject"));
            break
        end
    end
end

isSigObj = mustResolve == "on";
end

function dimension = parseDimension(dimensionValue)
parts = erase(strsplit(string(dimensionValue), [",", " "], "CollapseDelimiters", true), ["[", "]"]);
parts(parts == "") = [];
dimension = str2double(parts);
if isempty(dimension)
    dimension = NaN;
end
end
