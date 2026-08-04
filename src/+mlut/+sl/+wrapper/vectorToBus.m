function [ports, idx, idxRange] = vectorToBus(signalInput, mdl, fromName, toName, creatorName, idx, terminate)
arguments
    signalInput
    mdl
    fromName
    toName
    creatorName
    idx = 0
    terminate (1,1) logical = false
end

busDef = mlut.sl.loadBus(mdl, signalInput.BusObject);
if isempty(busDef)
    error("mlut:sl:wrapper:vectorToBus:BusNotFound", ...
        "Bus definition %s not found in model %s.", signalInput.BusObject, mdl);
end

busCreator = add_block("built-in/BusCreator", mdl + "/" + creatorName);
lineHandle = add_line(mdl, creatorName + "/1", toName);
set_param(lineHandle, "Name", signalInput.SignalName)

busElements = busDef.Elements;
set_param(busCreator, "Inputs", string(numel(busElements)));
ports = [];
idxRange = string.empty(1, 0);

for j = 1:numel(busElements)
    element = busElements(j);
    portName = fromName + "_" + element.Name;

    if ~contains(element.DataType, "Bus:")
        ports(end + 1) = iAddCastBlock(mdl, portName, element.DataType); %#ok<AGROW>

        if contains(element.DataType, "Enum:")
            ports(end) = iAddCastBlock(mdl, portName + "_toInt", "int32");
            add_line(mdl, portName + "_toInt/1", portName + "/1");
        end

        dimensions = iDimensions(element);
        if all(dimensions ~= 1)
            reshape = add_block("simulink/Math Operations/Reshape", mdl + "/" + portName + "Reshape");
            add_line(mdl, portName + "/1", portName + "Reshape/1");
            set_param(reshape, "OutputDimensionality", "Customize");
            set_param(reshape, "OutputDimensions", "[" + strjoin(string(dimensions), ", ") + "]");

            here = portName + "Reshape";
            idxRange(end + 1) = (idx + 1) + ":" + (idx + prod(dimensions));
            idx = idx + prod(dimensions);
        else
            idx = idx + 1;
            here = portName;
            idxRange(end + 1) = string(idx);
        end

        signalLine = add_line(mdl, here + "/1", creatorName + "/" + j);
        set_param(signalLine, "Name", element.Name);
    else
        elementCreatorName = creatorName + "_" + j;
        elementToName = creatorName + "/" + j;
        [childPorts, idx, childIdxRange] = mlut.sl.wrapper.vectorToBus( ...
            signalInput.Children(j), mdl, portName, elementToName, elementCreatorName, idx);
        ports = [ports, childPorts]; %#ok<AGROW>
        idxRange = [idxRange, childIdxRange]; %#ok<AGROW>
    end
end

set_param(busCreator, "OutDataTypeStr", "Bus: " + signalInput.BusObject);

if terminate
    inport = add_block("built-in/Inport", mdl + "/" + fromName);
    set_param(inport, "OutDataTypeStr", "single");

    for i = 1:numel(ports)
        selector = add_block( ...
            "simulink/Signal Routing/Selector", ...
            mdl + "/" + portName + "select", ...
            "MakeNameUnique", "on");
        selectorName = string(get_param(selector, "Name"));

        set_param(selector, ...
            "InputPortWidth", string(idx), ...
            "IndexParamArray", cellstr(idxRange(i)));

        add_line(mdl, get_param(inport, "Name") + "/1", selectorName + "/1");
        add_line(mdl, selectorName + "/1", string(get_param(ports(i), "Name")) + "/1");
    end
end
end

function block = iAddCastBlock(mdl, name, outType)
block = add_block("simulink/Signal Attributes/Data Type Conversion", mdl + "/" + name);
set_param(block, "OutDataTypeStr", outType);
end

function dimensions = iDimensions(element)
dimensions = element.Dimensions;
if isempty(dimensions)
    dimensions = 1;
end
end
