function busToSignals(busOutput, mdl, fromName, toName, selectorName)
selector = add_block("built-in/BusSelector", mdl + "/" + selectorName);
busElements = busOutput.Elements;
signals = string({busElements.Name});

add_line(mdl, fromName, selectorName + "/1");
set_param(selector, "OutputSignals", strjoin(signals, ","));

for j = 1:numel(busElements)
    element = busElements(j);
    portName = toName + "_" + element.Name;

    children = mlut.sl.loadBus(mdl, element.DataType);
    if isempty(children)
        nextBlock = selectorName + "/" + j;

        if startsWith(element.DataType, "Enum: ")
            castBlock = iAddCastBlock(mdl, "Convert" + portName, "int32"); %#ok<NASGU>
            add_line(mdl, selectorName + "/" + j, "Convert" + portName + "/1");
            nextBlock = "Convert" + portName + "/1";
        end

        outport = add_block("built-in/Outport", mdl + "/" + portName); %#ok<NASGU>
        add_line(mdl, nextBlock, portName + "/1");
    else
        mlut.sl.wrapper.busToSignals(children, mdl, selectorName + "/" + j, portName, selectorName + "_" + j)
    end
end
end

function block = iAddCastBlock(mdl, name, outType)
block = add_block("simulink/Signal Attributes/Data Type Conversion", mdl + "/" + name);
set_param(block, "OutDataTypeStr", outType);
end
