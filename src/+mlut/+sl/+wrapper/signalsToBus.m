function signalsToBus(signalInput, mdl, fromName, toName, creatorName)
busDef = mlut.sl.loadBus(mdl, signalInput.BusObject);
busElements = busDef.Elements;

busCreator = add_block("built-in/BusCreator", mdl + "/" + creatorName);
set_param(busCreator, "Inputs", string(numel(busElements)));
set_param(busCreator, "OutDataTypeStr", "Bus: " + signalInput.BusObject);

for j = 1:numel(busElements)
    element = busElements(j);
    portName = fromName + "_" + element.Name;

    if ~contains(element.DataType, "Bus:")
        inport = add_block("built-in/Inport", mdl + "/" + portName); %#ok<NASGU>
        nextBlock = creatorName + "/" + j;

        if startsWith(element.DataType, "Enum: ")
            castBlock = iAddCastBlock(mdl, "Convert" + portName, element.DataType);
            signalLine = add_line(mdl, "Convert" + portName + "/1", creatorName + "/" + j);
            set_param(signalLine, "Name", element.Name);
            nextBlock = "Convert" + portName + "/1";
            set_param(mdl + "/" + portName, "OutDataTypeStr", "int32");
        end

        signalLine = add_line(mdl, portName + "/1", nextBlock);
        set_param(signalLine, "Name", element.Name);
    else
        elementCreatorName = creatorName + "_" + j;
        elementToName = creatorName + "/" + j;
        mlut.sl.wrapper.signalsToBus( ...
            signalInput.Children(j), mdl, portName, elementToName, elementCreatorName);
    end
end

lineHandle = add_line(mdl, creatorName + "/1", toName);
set_param(lineHandle, "Name", signalInput.SignalName)
end

function block = iAddCastBlock(mdl, name, outType)
block = add_block("simulink/Signal Attributes/Data Type Conversion", mdl + "/" + name);
set_param(block, "OutDataTypeStr", outType);
end
