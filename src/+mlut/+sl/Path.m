classdef Path
    %PATH Utilities for Simulink-style slash-separated paths.

    methods (Static)
        function path = trimTrailingSlash(path)
            arguments
                path (1,1) string
            end

            while endsWith(path, "/")
                path = extractBefore(path, strlength(path));
            end
        end

        function path = join(parentPath, childName)
            arguments
                parentPath (1,1) string
                childName (1,1) string
            end

            parentPath = mlut.sl.Path.trimTrailingSlash(parentPath);
            childName = strip(childName, "left", "/");
            if parentPath == ""
                path = childName;
            elseif childName == ""
                path = parentPath;
            else
                path = parentPath + "/" + childName;
            end
        end

        function part = firstPart(path)
            arguments
                path (1,1) string
            end

            parts = split(string(path), "/");
            if isempty(parts)
                part = "";
            else
                part = parts(1);
            end
        end

        function part = lastPart(path)
            arguments
                path (1,1) string
            end

            path = string(path);
            if path == ""
                part = "";
                return
            end

            parts = split(mlut.sl.Path.trimTrailingSlash(path), "/");
            part = parts(end);
        end

        function blockPath = owningBlockPath(instancePath)
            arguments
                instancePath (1,1) string
            end

            parts = split(mlut.sl.Path.trimTrailingSlash(instancePath), "/");
            if isscalar(parts)
                blockPath = parts;
            else
                blockPath = join(parts(1:end-1), "/");
            end
        end

        function [parentPath, leafName] = splitLast(path)
            arguments
                path (1,1) string
            end

            parentPath = "";
            leafName = "";
            parts = split(mlut.sl.Path.trimTrailingSlash(path), "/");
            parts = parts(parts ~= "");
            if isempty(parts)
                return
            end

            leafName = parts(end);
            if numel(parts) > 1
                parentPath = join(parts(1:end-1), "/");
            end
        end

        function relPath = relativeToModel(blockPath, modelName)
            arguments
                blockPath (1,1) string
                modelName (1,1) string = ""
            end

            blockPath = string(blockPath);
            if modelName == ""
                modelName = string(bdroot(char(blockPath)));
            end

            prefix = modelName + "/";
            if startsWith(blockPath, prefix)
                relPath = extractAfter(blockPath, prefix);
            else
                relPath = string(get_param(char(blockPath), "Name"));
            end
        end

        function paths = portSignalPaths(basePath, portName)
            arguments
                basePath (1,1) string
                portName (1,1) string
            end

            basePath = mlut.sl.Path.trimTrailingSlash(basePath);
            paths = mlut.sl.Path.join(basePath, portName);
            if mlut.sl.Path.lastPart(basePath) == portName
                paths = [basePath, paths];
            end
            paths = unique(paths(paths ~= ""), "stable");
        end

        function paths = referencedPortSignalPaths(basePath, portName)
            arguments
                basePath (1,1) string
                portName (1,1) string
            end

            paths = unique([mlut.sl.Path.portSignalPaths(basePath, portName), portName], ...
                "stable");
            paths = paths(paths ~= "");
        end

        function [head, tail] = splitFirst(path)
            arguments
                path (1,1) string
            end

            parts = split(mlut.sl.Path.trimTrailingSlash(path), "/");
            if isempty(parts)
                head = "";
                tail = "";
                return
            end

            head = parts(1);
            if numel(parts) > 1
                tail = join(parts(2:end), "/");
            else
                tail = "";
            end
        end
    end
end
