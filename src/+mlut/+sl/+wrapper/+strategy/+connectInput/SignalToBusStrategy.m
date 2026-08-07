classdef SignalToBusStrategy < mlut.sl.wrapper.strategy.connectInput.ConnectInputStrategy

    methods (Static)

        function success = connectInput(inHandle, wrapperName, index)

            % Determine if the port is a non-virtual bus
            inTypes = string(get_param(inHandle, "OutDataTypeStr"));

            isBus = mlut.sl.Bus.isBusType(inTypes);

            % Port is a bus, so need to be exploded
            inOutSignals = get_param(inHandle, "PortHandles");
            inputSignals = get_param(inOutSignals{1}.Outport, "SignalHierarchy");

            name = get_param(inHandle, "Name");

            if isBus
                success = true;
                if isempty(inputSignals.BusObject)
                    error("mlut:sl:wrapper:missingBusDefinition", ...
                        "Bus definition %s was not found for input port %s.", inTypes, name);
                end

                creatorName = "creator" + index;
                fromName = name;
                toName = "mdl/" + index;

                mlut.sl.wrapper.signalsToBus(inputSignals, wrapperName, fromName, toName, creatorName);
            else
                success = false;
            end
        end

    end

end
