classdef BusToVectorStrategy < mlut.sl.wrapper.strategy.connectOutput.ConnectOutputStrategy
    methods (Static)

        function success = connectOutput(outHandle, wrapperName, index)

            outTypes = string(get_param(outHandle, "OutDataTypeStr"));

            isBus = mlut.sl.Bus.isBusType(outTypes);

            name = string(get_param(outHandle, "Name"));
            model = string(get_param(outHandle, "Parent"));

            if isBus
                success = true;
                bus = mlut.sl.DataDictionary.busObjectForModel( ...
                    model, outTypes, Optional=true);

                selectorName = "selector" + index;
                toName = name;
                fromName = "mdl/" + index;

                mlut.sl.wrapper.busToVector(bus, wrapperName, fromName, toName, selectorName, true);
            else
                success = false;
            end
        end

    end

end
