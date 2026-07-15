classdef GroupingController < handle
    % GroupingController owns active grouping and folding transforms.

    methods
        function result = group(this, data, filteredData, filteredDataToVisibleMap, ...
                filteredVisibleToDataMap, groupingVariable, openGroups, hiddenGroups)
            arguments
                this (1,1) gwidgets.internal.table.GroupingController %#ok<INUSA>
                data (:,:) table
                filteredData (:,:) table
                filteredDataToVisibleMap (1,:) double
                filteredVisibleToDataMap (1,:) double
                groupingVariable (1,:) string
                openGroups (1,:) string
                hiddenGroups (1,:) string
            end

            groupColumnIdx = ismember(string(data.Properties.VariableNames), groupingVariable);

            if numel(groupingVariable) > 1
                allGroupVars = arrayfun(@(name) data.(name), groupingVariable, UniformOutput=false);
                allGroupVars = cellfun(@string, allGroupVars, UniformOutput=false);
                allGroupVars = join([allGroupVars{:}], "|", 2);
            else
                allGroupVars = data.(groupingVariable);
            end

            if isempty(allGroupVars)
                groupIdxs = zeros(1,0);
                allGroups = allGroupVars;
            else
                [groupIdxs, allGroups] = findgroups(allGroupVars);
            end

            groupNames = reshape(string(allGroups), 1, []);
            openGroups = openGroups(ismember(openGroups, groupNames));
            hiddenGroups = hiddenGroups(ismember(hiddenGroups, groupNames));

            if numel(groupingVariable) > 1
                filteredGroupVars = arrayfun(@(name) filteredData.(name), groupingVariable, UniformOutput=false);
                filteredGroupVars = cellfun(@string, filteredGroupVars, UniformOutput=false);
                filteredGroupVars = join([filteredGroupVars{:}], "|", 2);
            else
                filteredGroupVars = filteredData.(groupingVariable);
            end

            tmpData = filteredData;
            idx = ismember(string(tmpData.Properties.VariableNames), groupingVariable);
            groupedDataVariables = string(tmpData.Properties.VariableNames(~idx));
            tmpData(:, idx) = [];
            tmpData = table2cell(tmpData);

            nGroups = numel(allGroups);
            allGroupCount = accumarray(groupIdxs(:), 1, [nGroups 1], @sum, 0);
            if isempty(filteredGroupVars)
                groupFilteredCount = zeros(nGroups, 1);
                filteredRowIdxByGroup = cell(nGroups, 1);
                [filteredRowIdxByGroup{:}] = deal(zeros(1,0));
            else
                [~, filteredToAllGroupIdx] = ismember(filteredGroupVars, allGroups);
                filteredToAllGroupIdx = filteredToAllGroupIdx(:);
                groupFilteredCount = accumarray(filteredToAllGroupIdx, 1, [nGroups 1], @sum, 0);
                filteredRowIdxByGroup = accumarray(filteredToAllGroupIdx, ...
                    (1:size(tmpData, 1)).', [nGroups 1], ...
                    @(rows) {rows(:).'}, {zeros(1,0)});
            end

            groupedData = cell(1, 2*nGroups);
            headerIdx = false(1, nGroups + (size(tmpData, 2) > 0)*size(tmpData, 1));

            dataToVisibleMap = filteredDataToVisibleMap;
            dataToVisibleIdx = find(~ismissing(dataToVisibleMap));
            visibleToDataMap = filteredVisibleToDataMap;
            updatedVisibleToDataMap = NaN(1, nGroups + size(tmpData, 1));

            nVisibleRows = 0;
            headerPos = 1;

            for iGroup = 1:nGroups
                thisGroup = allGroups(iGroup);
                rowIdxs = filteredRowIdxByGroup{iGroup};
                nInGroup = groupFilteredCount(iGroup);
                thisGroupDisp = tmpData(rowIdxs, :);

                nVisibleRows = nVisibleRows + 1;
                visibleRowIdxs = nVisibleRows + (1:nInGroup);
                dataToVisibleMap(dataToVisibleIdx(rowIdxs)) = visibleRowIdxs;

                updatedVisibleToDataMap((nVisibleRows+1):(nVisibleRows+nInGroup)) = visibleToDataMap(rowIdxs);
                nVisibleRows = nVisibleRows + nInGroup;

                nAll = allGroupCount(iGroup);
                thisGroupHeading = cell(1, size(thisGroupDisp, 2));
                thisGroupHeading{1} = string(thisGroup) + " (" + nInGroup + "/" + nAll + ")";
                thisGroupData = thisGroupDisp;

                if size(thisGroupData, 2) == 0
                    nInGroup = 0;
                end

                groupedData{2*iGroup-1} = thisGroupHeading;
                groupedData{2*iGroup} = thisGroupData;

                headerIdx(headerPos) = true;
                headerPos = headerPos + 1 + nInGroup;
            end

            groupedData = vertcat(groupedData{:});

            if isempty(groupedData)
                groupedData = tmpData;
            end

            result = struct( ...
                "GroupedVisibleData", {groupedData}, ...
                "GroupedDataVariables", groupedDataVariables, ...
                "Groups", groupNames, ...
                "GroupHeaderRowIdx", find(headerIdx), ...
                "GroupColumnIdx", groupColumnIdx, ...
                "GroupFilteredCount", reshape(groupFilteredCount, 1, []), ...
                "GroupIdxs", reshape(groupIdxs, 1, []), ...
                "OpenGroups", openGroups, ...
                "HiddenGroups", hiddenGroups, ...
                "GroupedDataToVisibleMap", dataToVisibleMap, ...
                "GroupedVisibleToDataMap", updatedVisibleToDataMap);
        end

        function result = fold(this, sortedVisibleData, sortedGroupHeaderRowIdx, sortedGroupValues, ...
                sortedVisibleToDataMap, sortedDataToVisibleMap, groupFilteredCount, groupingVariable, ...
                groups, openGroups, showEmptyGroups, dataVariableNames)
            arguments
                this (1,1) gwidgets.internal.table.GroupingController %#ok<INUSA>
                sortedVisibleData (:,:) cell
                sortedGroupHeaderRowIdx (1,:) double
                sortedGroupValues (1,:) string
                sortedVisibleToDataMap (1,:) double
                sortedDataToVisibleMap (1,:) double
                groupFilteredCount (1,:) double
                groupingVariable (1,:) string
                groups (1,:) string
                openGroups (1,:) string
                showEmptyGroups (1,1) logical
                dataVariableNames (1,:) string
            end

            groupedData = sortedVisibleData;
            idxsHeaderRow = sortedGroupHeaderRowIdx;
            idxHeading = [sortedGroupHeaderRowIdx, size(groupedData, 1)+1];

            idxVisibleHeaderRowMask = false(1, size(groupedData, 1));
            idxVisibleHeaderRowMask(idxsHeaderRow) = true;

            visRowToRemove = false(1, size(groupedData, 1));

            displayGroups = sortedGroupValues;
            isHiddenGroup = ~showEmptyGroups & groupFilteredCount == 0;
            isOpenGroup = ismember(displayGroups, openGroups);
            hiddenGroups = displayGroups(isHiddenGroup);
            hiddenGroups = hiddenGroups(end:-1:1);

            for iGroup = numel(idxsHeaderRow):-1:1
                idxHeaderRow = idxsHeaderRow(iGroup);
                idxGroupData = (idxHeading(iGroup) + 1):(idxHeading(iGroup+1) - 1);

                if ~isHiddenGroup(iGroup) && ~isOpenGroup(iGroup)
                    groupedData{idxHeaderRow, 1} = "⮞ " + groupedData{idxHeaderRow, 1};
                    visRowToRemove(idxGroupData) = true;
                elseif ~isHiddenGroup(iGroup)
                    groupedData{idxHeaderRow, 1} = "⮟ " + groupedData{idxHeaderRow, 1};
                else
                    visRowToRemove(idxGroupData) = true;
                    visRowToRemove(idxHeaderRow) = true;
                end
            end

            displayGroups(isHiddenGroup) = [];

            groupedData(visRowToRemove, :) = [];
            idxVisibleHeaderRowMask(visRowToRemove) = [];

            visibleToDataMap = sortedVisibleToDataMap;
            visibleToDataMap(visRowToRemove) = [];

            dataToVisibleMap = sortedDataToVisibleMap;
            validMapIdx = ~isnan(dataToVisibleMap);
            if any(visRowToRemove) && any(validMapIdx)
                visibleRowIdx = dataToVisibleMap(validMapIdx);
                isRemovedRow = visRowToRemove(visibleRowIdx);
                removedBeforeRow = cumsum(visRowToRemove);

                visibleRowIdx(~isRemovedRow) = visibleRowIdx(~isRemovedRow) - ...
                    removedBeforeRow(visibleRowIdx(~isRemovedRow));
                visibleRowIdx(isRemovedRow) = NaN;
                dataToVisibleMap(validMapIdx) = visibleRowIdx;
            end

            vars = dataVariableNames;
            vars(ismember(vars, groupingVariable)) = [];
            if isempty(vars) && ~isempty(groupingVariable)
                vars = "Groups";
                if size(groupedData, 2) == 0
                    groupedData = num2cell(groups).';
                end
            end

            visibleData = cell2table(groupedData, VariableNames=vars);

            result = struct( ...
                "VisibleData", visibleData, ...
                "DisplayGroups", displayGroups, ...
                "HiddenGroups", hiddenGroups, ...
                "VisibleGroupHeaderRowIdx", find(idxVisibleHeaderRowMask), ...
                "FoldedVisibleToDataMap", visibleToDataMap, ...
                "FoldedDataToVisibleMap", dataToVisibleMap);
        end
    end

end

