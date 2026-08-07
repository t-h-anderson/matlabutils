classdef MATLABFunctionBlockCache < mlut.internal.CacheSingleton
    %MATLABFUNCTIONBLOCKCACHE Singleton cache for MATLAB Function block metadata.

    properties (Access = private)
        CacheCreatedAt
        Values
    end

    methods (Access = private)
        function obj = MATLABFunctionBlockCache()
            obj.clearImpl();
        end

        function clearImpl(obj)
            obj.CacheCreatedAt = datetime.empty(1,0);
            obj.Values = dictionary(string.empty(1,0), cell.empty(1,0));
        end

        function expireIfNeeded(obj)
            if obj.cacheExpired(obj.CacheCreatedAt)
                obj.clearImpl();
                obj.CacheCreatedAt = datetime("now");
            end
        end

        function [value, found] = getImpl(obj, cacheKey)
            arguments
                obj (1,1) mlut.sl.internal.MATLABFunctionBlockCache
                cacheKey (1,1) string
            end

            value = [];
            found = false;
            if cacheKey == ""
                return
            end

            obj.expireIfNeeded();
            if obj.Values.isConfigured && isKey(obj.Values, cacheKey)
                cached = obj.Values(cacheKey);
                value = cached{1};
                found = true;
            end
        end

        function setImpl(obj, cacheKey, value)
            arguments
                obj (1,1) mlut.sl.internal.MATLABFunctionBlockCache
                cacheKey (1,1) string
                value
            end

            if cacheKey == ""
                return
            end

            obj.expireIfNeeded();
            obj.Values(cacheKey) = {value};
        end
    end

    methods (Static)
        function [value, found] = get(kind, keyParts)
            arguments
                kind (1,1) string
                keyParts (1,:) string
            end

            manager = mlut.sl.internal.MATLABFunctionBlockCache.make();
            [value, found] = manager.getImpl( ...
                mlut.sl.internal.MATLABFunctionBlockCache.key(kind, keyParts));
        end

        function set(kind, keyParts, value)
            arguments
                kind (1,1) string
                keyParts (1,:) string
                value
            end

            manager = mlut.sl.internal.MATLABFunctionBlockCache.make();
            manager.setImpl( ...
                mlut.sl.internal.MATLABFunctionBlockCache.key(kind, keyParts), value);
        end

        function clear()
            mlut.sl.internal.MATLABFunctionBlockCache.make().clearImpl();
        end

        function manager = make(reset)
            arguments
                reset (1,1) logical = false
            end

            factory = @() mlut.sl.internal.MATLABFunctionBlockCache();
            manager = mlut.internal.Singleton.instanceFor( ...
                "mlut.sl.internal.MATLABFunctionBlockCache", reset, factory, nargout > 0);
        end
    end

    methods (Static, Access = private)
        function cacheKey = key(kind, keyParts)
            arguments
                kind (1,1) string
                keyParts (1,:) string
            end

            cacheKey = strjoin([kind, keyParts], newline);
        end
    end
end
