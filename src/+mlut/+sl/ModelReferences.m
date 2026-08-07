classdef ModelReferences
    %MODELREFERENCES Utilities for querying Simulink model references.

    methods (Static)
        function [modelRefBlocks, modelRefNames] = find(modelName)
            % Find referenced model names and Model Reference block paths.
            arguments
                modelName (1,1) string
            end

            if ~isMATLABReleaseOlderThan("R2024a")
                cleanupObj = mlut.sl.setVariantWarningsTemporarily("off"); %#ok<NASGU>
                [modelRefNames, modelRefBlocks] = find_mdlrefs( ...
                    modelName, ...
                    "MatchFilter", @Simulink.match.allVariants);
                return
            end

            [modelRefNames, modelRefBlocks] = find_mdlrefs(modelName);
        end

        function modelRefBlocks = findBlocksByNamePrefix(modelName, prefixes)
            % Find Model Reference blocks whose block names start with any prefix.
            arguments
                modelName (1,1) string
                prefixes (1,:) string
            end

            modelRefBlocks = string(find_system(char(modelName), ...
                "LookUnderMasks", "all", ...
                "BlockType", "ModelReference"));
            modelRefBlocks = mlut.sl.ModelReferences.filterBlocksByNamePrefix( ...
                modelRefBlocks, prefixes);
        end

        function modelRefBlocks = filterBlocksByNamePrefix(modelRefBlocks, prefixes)
            % Keep Model Reference blocks whose block names start with any prefix.
            arguments
                modelRefBlocks (1,:) string
                prefixes (1,:) string
            end

            modelRefBlocks = reshape(modelRefBlocks, 1, []);
            prefixes = lower(strip(reshape(prefixes, 1, [])));
            prefixes(prefixes == "") = [];

            if isempty(modelRefBlocks) || isempty(prefixes)
                modelRefBlocks = string.empty(1,0);
                return
            end

            nameMatches = false(size(modelRefBlocks));
            for modelRefIdx = 1:numel(modelRefBlocks)
                blockName = lower(string(get_param(char(modelRefBlocks(modelRefIdx)), "Name")));
                nameMatches(modelRefIdx) = any(startsWith(blockName, prefixes));
            end

            modelRefBlocks = modelRefBlocks(nameMatches);
        end
    end
end
