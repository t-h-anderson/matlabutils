classdef (Abstract) Strategy < matlab.mixin.Heterogeneous

    properties (Abstract, Constant)
        AppliesTo (1,:) string {mustBeNonempty}
    end
    
    methods (Sealed)
        function varargout = runIfApplies(objs, functionName, varargin)
            arguments
                objs (1,:)
                functionName (1,1) string
            end
            arguments (Repeating)
                varargin
            end

            varargout = {};
            idx = arrayfun(@(x) ismember(functionName, x.AppliesTo), objs);
            strategies = objs(idx);

            for i = 1:numel(strategies)
                thenContinue = strategies(i).runStrategy(varargin{:});
                if ~thenContinue
                    break
                end
            end
            
        end

    end

    methods (Abstract)

        [thenContinue, varargout] = runStrategy(obj, varargin)

    end

end

