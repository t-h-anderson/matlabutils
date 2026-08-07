classdef BusToSignalStrategy < mlut.sl.wrapper.strategy.connectOutput.ConnectOutputStrategy
    methods (Static)

        function success = connectOutput(outHandle, wrapperName, index)

            outTypes = string(get_param(outHandle, "OutDataTypeStr"));

            isBus = mlut.sl.Bus.isBusType(outTypes);
            
            model = string(get_param(outHandle, "Parent"));
            name = string(get_param(outHandle, "Name"));

            if isBus
                success = true;
                
                bus = mlut.sl.DataDictionary.busObjectForModel( ...
                    model, outTypes, Optional=true);

                selectorName = "selector" + index;
                toName = name;
                fromName = "mdl/" + index;

                mlut.sl.wrapper.busToSignals(bus, wrapperName, fromName, toName, selectorName);
            else
                success = false;
            end
        end

    end

end
