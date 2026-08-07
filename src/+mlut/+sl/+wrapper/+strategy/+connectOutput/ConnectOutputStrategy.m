classdef ConnectOutputStrategy < mlut.sl.wrapper.strategy.Strategy

    properties (Constant)
        AppliesTo = "connectOutput"
    end

    methods
        function thenContinue = runStrategy(obj, varargin)

            outHandle = varargin{1};
            wrapperName = varargin{2};
            i = varargin{3};
            success = obj.connectOutput(outHandle, wrapperName, i);

            if success
                thenContinue = false;
            else
                thenContinue = true;
            end
        end

    end

    methods (Abstract, Static)

        success = connectOutput(outHandle, wrapperName, index)

    end

end

