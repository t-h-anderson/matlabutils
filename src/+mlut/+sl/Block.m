classdef Block
    %BLOCK Utilities for loaded Simulink block paths and navigation.

    methods (Static)
        function tf = isLoaded(blockPath)
            %ISLOADED True when a block path resolves in a loaded Simulink model.

            arguments
                blockPath (1,1) string
            end

            tf = getSimulinkBlockHandle(char(blockPath)) ~= -1;
        end

        function [resolvedPath, found] = resolveLoadedPath(blockPath)
            %RESOLVELOADEDPATH Nearest loaded block at or above a requested path.

            arguments
                blockPath (1,1) string
            end

            found = false;
            resolvedPath = "";
            rootPath = extractBefore(blockPath + "/", "/");
            while blockPath ~= ""
                if blockPath == rootPath
                    break
                end
                if mlut.sl.Block.isLoaded(blockPath)
                    resolvedPath = blockPath;
                    found = true;
                    return
                end

                lastSlash = find(char(blockPath) == '/', 1, "last");
                if isempty(lastSlash)
                    break
                end
                blockPath = extractBefore(blockPath, lastSlash);
            end
        end

        function openAndHighlight(blockPath)
            %OPENANDHIGHLIGHT Open the owning model and highlight a loaded block.

            arguments
                blockPath (1,1) string
            end

            rootModel = bdroot(char(blockPath));
            open_system(char(rootModel));
            hilite_system(char(blockPath), "find");
        end
    end
end
