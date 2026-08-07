classdef VectorToBusStrategy < mlut.sl.wrapper.strategy.connectInput.ConnectInputStrategy

    methods (Static)

        function success = connectInput(inHandle, wrapperName, index)

            % Determine if the port is a non-virtual bus
            inTypes = string(get_param(inHandle, "OutDataTypeStr"));

            isBus = mlut.sl.Bus.isBusType(inTypes);

            % Port is a bus, so need to be exploded
            inOutSignals = get_param(inHandle, "PortHandles");
            inputSignals = get_param(inOutSignals{1}.Outport, "SignalHierarchy");

            name = string(get_param(inHandle, "Parent"));

            if isBus
                success = true;
                if isempty(inputSignals.BusObject)
                    error("mlut:sl:wrapper:missingBusDefinition", ...
                        "Bus definition %s was not found for input port %d.", inTypes, index);
                end

                creatorName = "creator" + index;
                fromName = name;
                toName = "mdl/" + index;

                mlut.sl.wrapper.vectorToBus(inputSignals, wrapperName, fromName, toName, creatorName, 0, true);

            else
                success = false;
            end
        end

    end

end
