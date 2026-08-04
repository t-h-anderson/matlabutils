classdef GraphicsLeakFixture < matlab.unittest.fixtures.Fixture
    % GraphicsLeakFixture fails a test that leaves graphics objects behind.

    properties (Access = private)
        Before
    end

    methods
        function setup(fixture)
            fixture.Before = fixtures.GraphicsLeakFixture.enumerate();
        end

        function teardown(fixture)
            after = fixtures.GraphicsLeakFixture.enumerate();
            added = fixtures.GraphicsLeakFixture.difference(after, fixture.Before);
            removed = fixtures.GraphicsLeakFixture.difference(fixture.Before, after);

            if isempty(added) && isempty(removed)
                return
            end

            cleanupObj = onCleanup(@()fixtures.GraphicsLeakFixture.deleteValid(added));
            message = fixtures.GraphicsLeakFixture.failureMessage(added, removed);
            delete(cleanupObj);
            error("MLUT:Test:GraphicsLeak", "%s", message);
        end
    end

    methods (Static)
        function handles = enumerate()
            handles = findall(groot());
            handles = handles(fixtures.GraphicsLeakFixture.isValid(handles));
            rootObj = groot();
            handles = handles(handles ~= rootObj);
        end
    end

    methods (Static, Access = private)
        function result = difference(left, right)
            isNew = false(size(left));
            for iHandle = 1:numel(left)
                isNew(iHandle) = ~fixtures.GraphicsLeakFixture.contains(right, left(iHandle));
            end
            result = left(isNew);
        end

        function tf = contains(handles, query)
            tf = false;
            if ~fixtures.GraphicsLeakFixture.isValid(query)
                return
            end

            handles = handles(fixtures.GraphicsLeakFixture.isValid(handles));
            for iHandle = 1:numel(handles)
                if handles(iHandle) == query
                    tf = true;
                    return
                end
            end
        end

        function tf = isValid(handles)
            tf = false(size(handles));
            for iHandle = 1:numel(handles)
                try
                    tf(iHandle) = isvalid(handles(iHandle));
                catch
                    tf(iHandle) = false;
                end
            end
        end

        function deleteValid(handles)
            for iHandle = 1:numel(handles)
                if ~fixtures.GraphicsLeakFixture.isValid(handles(iHandle))
                    continue
                end

                try
                    delete(handles(iHandle));
                catch
                    % Best effort cleanup after reporting a failed leak check.
                end
            end
        end

        function message = failureMessage(added, removed)
            newlineText = string(newline);
            parts = strings(0,1);
            if ~isempty(added)
                parts(end+1,1) = "Leaked graphics objects:" + newlineText + ...
                    fixtures.GraphicsLeakFixture.describe(added);
            end
            if ~isempty(removed)
                parts(end+1,1) = "Pre-existing graphics objects were removed:" + newlineText + ...
                    fixtures.GraphicsLeakFixture.describe(removed);
            end

            message = "Graphics object set changed during test." + newlineText + ...
                strjoin(parts, newlineText + newlineText);
        end

        function text = describe(handles)
            lines = strings(numel(handles), 1);
            for iHandle = 1:numel(handles)
                lines(iHandle) = "  " + fixtures.GraphicsLeakFixture.describeOne(handles(iHandle));
            end
            text = strjoin(lines, newline);
        end

        function text = describeOne(handle)
            if ~fixtures.GraphicsLeakFixture.isValid(handle)
                text = "<invalid " + class(handle) + ">";
                return
            end

            details = [
                "class=" + string(class(handle))
                "Type=" + fixtures.GraphicsLeakFixture.propertyText(handle, "Type")
                "Tag=" + fixtures.GraphicsLeakFixture.propertyText(handle, "Tag")
                "Name=" + fixtures.GraphicsLeakFixture.propertyText(handle, "Name")
                "Visible=" + fixtures.GraphicsLeakFixture.propertyText(handle, "Visible")
                ]';
            text = strjoin(details(details ~= ""), ", ");
        end

        function value = propertyText(handle, propertyName)
            value = "";
            if ~isprop(handle, propertyName)
                return
            end

            try
                rawValue = handle.(propertyName);
                if isempty(rawValue)
                    value = propertyName + "=<empty>";
                else
                    value = propertyName + "=" + string(rawValue);
                end
            catch
                value = propertyName + "=<unavailable>";
            end
        end
    end
end
