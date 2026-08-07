classdef (Abstract) CacheSingleton < mlut.internal.Singleton
    %CACHESINGLETON Singleton base for time-expiring utility cached state.

    properties
        CacheTime (1,1) double = Inf
    end

    methods (Access = protected)
        function tf = cacheExpired(obj, cacheCreatedAt)
            arguments
                obj (1,1) mlut.internal.CacheSingleton
                cacheCreatedAt datetime
            end

            tf = isempty(cacheCreatedAt) ...
                || datetime("now") - cacheCreatedAt > seconds(obj.CacheTime);
        end
    end
end
