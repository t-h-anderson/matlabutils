classdef Port
    %PORT Utilities for Simulink port metadata.

    methods (Static)
        function names = nameList(value)
            %NAMELIST Normalise a get_param port-list value to a string row.

            arguments
                value
            end

            if isstruct(value)
                f = string(fieldnames(value));
                nums = double(regexprep(f, "\D", ""));
                [~, order] = sort(nums);
                f = f(order);
                names = strings(1, numel(f));
                for k = 1:numel(f)
                    names(k) = string(value.(f(k)));
                end
            else
                names = reshape(string(value), 1, []);
            end
        end
    end
end
