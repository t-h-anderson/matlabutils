function sigs = busToVector(busOutput, mdl, fromName, toName, selectorName, terminate)
arguments
    busOutput
    mdl
    fromName
    toName
    selectorName
    terminate (1,1) logical = false
end

sigs = [];
busDef = mlut.sl.loadBus(mdl, busOutput.Description);
busElements = busOutput.Elements;

selector = add_block("built-in/BusSelector", mdl + "/" + selectorName);
set_param(selector, "OutputSignals", strjoin(string({busElements.Name}), ","));
add_line(mdl, fromName, selectorName + "/1");

for j = 1:numel(busElements)
    element = busElements(j);
    portName = toName + "_" + element.Name;

    if ~contains(element.DataType, "Bus:")
        sigs(end + 1) = iAddCastBlock(mdl, portName, "single"); %#ok<AGROW>
        add_line(mdl, selectorName + "/" + j, portName + "/1");

        dimensions = iDimensions(element);
        if all(dimensions ~= 1)
            sigs(end) = add_block("simulink/Math Operations/Reshape", mdl + "/" + portName + "Reshape");
            add_line(mdl, portName + "/1", portName + "Reshape/1");
        end
    else
        childBus = mlut.sl.loadBus(mdl, element.DataType);
        childSignals = mlut.sl.wrapper.busToVector(childBus, mdl, selectorName + "/" + j, portName, selectorName + "_" + j);
        sigs = [sigs, childSignals]; %#ok<AGROW>
    end
end

vectorConcat = add_block("simulink/Signal Routing/Vector Concatenate", mdl + "/ToVector", "MakeNameUnique", "on");
vectorName = string(get_param(vectorConcat, "Name"));
set_param(vectorConcat, "NumInputs", string(numel(sigs)));

for i = 1:numel(sigs)
    add_line(mdl, string(get_param(sigs(i), "Name")) + "/1", vectorName + "/" + i);
end

if terminate
    add_block("built-in/Outport", mdl + "/" + toName);
    add_line(mdl, vectorName + "/1", toName + "/1");
    sigs = [];
else
    sigs = vectorConcat;
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
