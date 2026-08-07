classdef DefaultStrategy < mlut.sl.wrapper.strategy.connectOutput.ConnectOutputStrategy
    methods (Static)

        function success = connectOutput(outHandle, wrapperName, index)
            success = true;

            name = get_param(outHandle, "Name");

            outInputSignals = get_param(outHandle, "PortHandles");
            outputSignals = get_param(outInputSignals.Inport, "SignalHierarchy");

            name = mlut.sl.escapeBlockName(name);
            add_block("built-in/Outport", wrapperName + "/" + name);
            l = add_line(wrapperName, "mdl/" + index, name + "/1");

            signalName = outputSignals.SignalName;
            set_param(l, "Name", signalName);
        end

    end

end

