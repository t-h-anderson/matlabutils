classdef ConnectInputStrategy < mlut.sl.wrapper.strategy.Strategy

    properties (Constant)
        AppliesTo = "connectInput"
    end

    methods 
        function thenContinue = runStrategy(obj, varargin)

            inHandle = varargin{1};
            wrapperName = varargin{2};
            i = varargin{3};
            success = obj.connectInput(inHandle, wrapperName, i);

            if success
                thenContinue = false;
            else
                thenContinue = true;
            end

        end

    end

    methods (Abstract, Static)

        success = connectInput(inh, wrapperName, i)

    end

end

