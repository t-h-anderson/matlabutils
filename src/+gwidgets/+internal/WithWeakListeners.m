classdef WithWeakListeners < handle
    % Allow registering of weak listeners that don't create a handle cycle
    % The event reponse must have signature: function on<<EventName>>(this,s,e)
    % and in a methods block tagged as
    % (Access = {?gwidgets.internal.WithWeakListeners})
    methods
        function listeners = weaklistener(this, observable, eventList)
            arguments
                this (1,1) gwidgets.internal.WithWeakListeners
                observable (1,1) {isvalid}
                eventList (1,:) string
            end

            weakObj = matlab.lang.WeakReference(this);

            listeners = event.listener.empty(1,0);
            for i = 1:numel(eventList)
                thisEvent = eventList(i);
                reaction = @(s, e)gwidgets.internal.WithWeakListeners.dispatchWeakEvent( ...
                    weakObj, thisEvent, s, e);
                listeners(i) = listener(observable, eventList(i), reaction);
            end
        end
    end

    methods (Static, Access = private)
        function dispatchWeakEvent(weakObj, eventName, source, eventData)
            strongObj = weakObj.Handle;
            if isempty(strongObj) || ~isvalid(strongObj)
                return
            end

            methodName = "on" + eventName;
            strongObj.(methodName)(source, eventData);
        end
    end
end
