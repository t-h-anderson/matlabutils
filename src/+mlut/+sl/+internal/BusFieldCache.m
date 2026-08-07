classdef BusFieldCache < mlut.internal.CacheSingleton
    %BUSFIELDCACHE Singleton cache for resolved Simulink.Bus field lists.

    properties (Access = private)
        CacheCreatedAt
        Values
    end

    methods (Access = private)
        function obj = BusFieldCache()
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

        function [fields, found] = getImpl(obj, cacheKey)
            arguments
                obj (1,1) mlut.sl.internal.BusFieldCache
                cacheKey (1,1) string
            end

            fields = string.empty(1,0);
            found = false;
            if cacheKey == ""
                return
            end

            obj.expireIfNeeded();
            if obj.Values.isConfigured && isKey(obj.Values, cacheKey)
                cached = obj.Values(cacheKey);
                fields = cached{1};
                found = true;
            end
        end

        function setImpl(obj, cacheKey, fields)
            arguments
                obj (1,1) mlut.sl.internal.BusFieldCache
                cacheKey (1,1) string
                fields (1,:) string
            end

            if cacheKey == ""
                return
            end

            obj.expireIfNeeded();
            obj.Values(cacheKey) = {fields};
        end
    end

    methods (Static)
        function [fields, found] = get(cacheKey)
            arguments
                cacheKey (1,1) string
            end

            manager = mlut.sl.internal.BusFieldCache.make();
            [fields, found] = manager.getImpl(cacheKey);
        end

        function set(cacheKey, fields)
            arguments
                cacheKey (1,1) string
                fields (1,:) string
            end

            manager = mlut.sl.internal.BusFieldCache.make();
            manager.setImpl(cacheKey, fields);
        end

        function clear()
            mlut.sl.internal.BusFieldCache.make().clearImpl();
        end

        function manager = make(reset)
            arguments
                reset (1,1) logical = false
            end

            factory = @() mlut.sl.internal.BusFieldCache();
            manager = mlut.internal.Singleton.instanceFor( ...
                "mlut.sl.internal.BusFieldCache", reset, factory, nargout > 0);
        end
    end
end
