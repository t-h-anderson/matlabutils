classdef TraceGraphCache < mlut.internal.CacheSingleton
    %TRACEGRAPHCACHE Singleton cache for expensive sltrace graph results.

    properties (Access = private)
        CacheCreatedAt
        Values
    end

    methods (Access = private)
        function obj = TraceGraphCache()
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

        function [traceResult, found] = getImpl(obj, cacheKey)
            arguments
                obj (1,1) mlut.sl.internal.TraceGraphCache
                cacheKey (1,1) string
            end

            traceResult = [];
            found = false;
            if cacheKey == ""
                return
            end

            obj.expireIfNeeded();
            if obj.Values.isConfigured && isKey(obj.Values, cacheKey)
                cached = obj.Values(cacheKey);
                traceResult = cached{1};
                found = true;
            end
        end

        function setImpl(obj, cacheKey, traceResult)
            arguments
                obj (1,1) mlut.sl.internal.TraceGraphCache
                cacheKey (1,1) string
                traceResult
            end

            if cacheKey == ""
                return
            end

            obj.expireIfNeeded();
            obj.Values(cacheKey) = {traceResult};
        end
    end

    methods (Static)
        function [traceResult, found] = get(direction, blockPath, portNum)
            arguments
                direction (1,1) string
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBePositive}
            end

            manager = mlut.sl.internal.TraceGraphCache.make();
            [traceResult, found] = manager.getImpl( ...
                mlut.sl.internal.TraceGraphCache.key(direction, blockPath, portNum));
        end

        function set(direction, blockPath, portNum, traceResult)
            arguments
                direction (1,1) string
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBePositive}
                traceResult
            end

            manager = mlut.sl.internal.TraceGraphCache.make();
            manager.setImpl( ...
                mlut.sl.internal.TraceGraphCache.key(direction, blockPath, portNum), ...
                traceResult);
        end

        function clear()
            mlut.sl.internal.TraceGraphCache.make().clearImpl();
        end

        function manager = make(reset)
            arguments
                reset (1,1) logical = false
            end

            factory = @() mlut.sl.internal.TraceGraphCache();
            manager = mlut.internal.Singleton.instanceFor( ...
                "mlut.sl.internal.TraceGraphCache", reset, factory, nargout > 0);
        end
    end

    methods (Static, Access = private)
        function cacheKey = key(direction, blockPath, portNum)
            arguments
                direction (1,1) string
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBePositive}
            end

            cacheKey = strjoin([direction, blockPath, string(portNum)], newline);
        end
    end
end
