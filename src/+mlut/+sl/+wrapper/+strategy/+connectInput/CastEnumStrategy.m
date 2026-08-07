classdef CastEnumStrategy < mlut.sl.wrapper.strategy.connectInput.ConnectInputStrategy
    methods (Static)

        function success = connectInput(inHandle, wrapperName, index)

            % Determine if the port is a non-virtual bus
            name = get_param(inHandle, "Name");

            inTypes = string(get_param(inHandle, "OutDataTypeStr"));
            isEnum = contains(inTypes, "Enum:");

            if isEnum
                success = true;
                % Port is a bus, so need to be exploded
                inOutSignals = get_param(inHandle, "PortHandles");
                inputSignals = get_param(inOutSignals.Outport, "SignalHierarchy");
                name = mlut.sl.escapeBlockName(name);

                % Need to convert input to integer before converting to enum
                c = add_block("simulink/Quick Insert/Signal Attributes/Cast", wrapperName + "/Convert" + name);
                set_param(c, "OutDataTypeStr", inTypes);
                l = add_line(wrapperName, "Convert" + name + "/1", "mdl/" + index);

                in = add_block("built-in/Inport", wrapperName + "/" + name);
                set_param(in, "OutDataTypeStr", "int32");
                add_line(wrapperName, name + "/1", "Convert" + name + "/" + 1);

                signalName = inputSignals.SignalName;
                set_param(l, "Name", signalName);

            else
                success = false;
            end

        end

    end

end

