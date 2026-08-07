classdef DefaultStrategy < mlut.sl.wrapper.strategy.connectInput.ConnectInputStrategy
    methods (Static)

        function success = connectInput(inHandle, wrapperName, index)
            success = true;
            name = get_param(inHandle, "Name");

            inOutSignals = get_param(inHandle, "PortHandles");
            inputSignals = get_param(inOutSignals.Outport, "SignalHierarchy");

            % Add the inport and connect it up
            name = mlut.sl.escapeBlockName(name);
            add_block("built-in/Inport", wrapperName + "/" + name);
            l = add_line(wrapperName, name + "/1", "mdl/" + index);

            signalName = inputSignals.SignalName;
            set_param(l, "Name", signalName);

        end

    end

end

