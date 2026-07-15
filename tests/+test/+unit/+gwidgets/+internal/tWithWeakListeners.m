classdef tWithWeakListeners < matlab.unittest.TestCase

    methods (Test)
        function tDispatchCallsMatchingHandler(testCase)
            source = test.unit.gwidgets.internal.WeakEventSource();
            receiver = test.unit.gwidgets.internal.WeakListenerReceiver();

            listenerObj = receiver.weaklistener(source, "Changed");
            testCase.addTeardown(@() delete(listenerObj));

            source.fireChanged();

            testCase.verifyEqual(receiver.Count, 1)
        end

        function tDeletedReceiverIsIgnored(testCase)
            source = test.unit.gwidgets.internal.WeakEventSource();
            receiver = test.unit.gwidgets.internal.WeakListenerReceiver();

            listenerObj = receiver.weaklistener(source, "Changed");
            testCase.addTeardown(@() delete(listenerObj));
            delete(receiver);

            testCase.verifyWarningFree(@() source.fireChanged())
        end
    end
end
