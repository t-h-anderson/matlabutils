classdef CastEnumStrategy < mlut.sl.wrapper.strategy.connectOutput.ConnectOutputStrategy
    methods (Static)

        function success = connectOutput(outHandle, wrapperName, index)

            % Determine if the port is a non-virtual bus
            name = get_param(outHandle, "Name");

            inTypes = string(get_param(outHandle, "OutDataTypeStr"));
            isEnum = contains(inTypes, "Enum:");

            if isEnum
                success = true;

                name = mlut.sl.escapeBlockName(name);

                % Need to convert input to integer before converting to enum
                c = add_block("simulink/Quick Insert/Signal Attributes/Cast", wrapperName + "/Convert" + name);
                set_param(c, "OutDataTypeStr", "int32");
                l = add_line(wrapperName, "mdl/" + index, "Convert" + name + "/1");

                in = add_block("built-in/Outport", wrapperName + "/" + name);
                set_param(in, "OutDataTypeStr", "int32");
                add_line(wrapperName, "Convert" + name + "/" + 1, name + "/1");

                set_param(l, "Name", name);

            else
                success = false;
            end

        end

    end

end

