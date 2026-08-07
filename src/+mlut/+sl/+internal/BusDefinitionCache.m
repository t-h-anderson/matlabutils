classdef BusDefinitionCache < mlut.internal.CacheSingleton
    %BUSDEFINITIONCACHE Singleton cache for Simulink.Bus objects.

    properties (Access = private)
        CacheCreatedAt
        Values
    end

    methods (Access = private)
        function obj = BusDefinitionCache()
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

        function [busObj, found] = getImpl(obj, cacheKey)
            arguments
                obj (1,1) mlut.sl.internal.BusDefinitionCache
                cacheKey (1,1) string
            end

            busObj = [];
            found = false;
            if cacheKey == ""
                return
            end

            obj.expireIfNeeded();
            if obj.Values.isConfigured && isKey(obj.Values, cacheKey)
                cached = obj.Values(cacheKey);
                busObj = cached{1};
                found = true;
            end
        end

        function setImpl(obj, cacheKey, busObj)
            arguments
                obj (1,1) mlut.sl.internal.BusDefinitionCache
                cacheKey (1,1) string
                busObj
            end

            if cacheKey == ""
                return
            end

            obj.expireIfNeeded();
            obj.Values(cacheKey) = {busObj};
        end
    end

    methods (Static)
        function [busObj, found] = get(cacheKey)
            arguments
                cacheKey (1,1) string
            end

            manager = mlut.sl.internal.BusDefinitionCache.make();
            [busObj, found] = manager.getImpl(cacheKey);
        end

        function set(cacheKey, busObj)
            arguments
                cacheKey (1,1) string
                busObj
            end

            manager = mlut.sl.internal.BusDefinitionCache.make();
            manager.setImpl(cacheKey, busObj);
        end

        function clear()
            mlut.sl.internal.BusDefinitionCache.make().clearImpl();
        end

        function manager = make(reset)
            arguments
                reset (1,1) logical = false
            end

            factory = @() mlut.sl.internal.BusDefinitionCache();
            manager = mlut.internal.Singleton.instanceFor( ...
                "mlut.sl.internal.BusDefinitionCache", reset, factory, nargout > 0);
        end
    end
end
