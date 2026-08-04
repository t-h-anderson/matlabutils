classdef GroupingController < handle
    % GroupingController owns active grouping and folding transforms.

    methods
        function result = group(this, data, filteredData, filteredDataToVisibleMap, ...
                filteredVisibleToDataMap, groupingVariable, openGroups, hiddenGroups)
            arguments
                this (1,1) gwidgets.internal.table.GroupingController
                data (:,:) table
                filteredData (:,:) table
                filteredDataToVisibleMap (1,:) double
                filteredVisibleToDataMap (1,:) double
                groupingVariable (1,:) string
                openGroups (1,:) string
                hiddenGroups (1,:) string
            end

            groupColumnIdx = ismember(string(data.Properties.VariableNames), groupingVariable);
            allGroupKeys = data(:, groupingVariable);

            if height(allGroupKeys) == 0
                groupIdxs = zeros(1,0);
                groupKeys = allGroupKeys;
            else
                [groupIdxs, groupKeys] = findgroups(allGroupKeys);
            end

            groupNames = this.groupLabels(groupKeys);
            openGroups = openGroups(ismember(openGroups, groupNames));
            hiddenGroups = hiddenGroups(ismember(hiddenGroups, groupNames));

            filteredGroupKeys = filteredData(:, groupingVariable);

            tmpData = filteredData;
            idx = ismember(string(tmpData.Properties.VariableNames), groupingVariable);
            groupedDataVariables = string(tmpData.Properties.VariableNames(~idx));
            tmpData(:, idx) = [];
            tmpData = table2cell(tmpData);

            nGroups = height(groupKeys);
            allGroupCount = accumarray(groupIdxs(:), 1, [nGroups 1], @sum, 0);
            if height(filteredGroupKeys) == 0
                groupFilteredCount = zeros(nGroups, 1);
                filteredRowIdxByGroup = cell(nGroups, 1);
                [filteredRowIdxByGroup{:}] = deal(zeros(1,0));
            else
                [~, filteredToAllGroupIdx] = ismember(filteredGroupKeys, groupKeys, "rows");
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
                thisGroup = groupNames(iGroup);
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

            groupHeaderDataRows = cell(1, nGroups);
            for iGroup = 1:nGroups
                groupHeaderDataRows{iGroup} = find(groupIdxs == iGroup);
            end

            result = struct( ...
                "GroupedVisibleData", {groupedData}, ...
                "GroupedDataVariables", groupedDataVariables, ...
                "Groups", groupNames, ...
                "GroupKeys", groupKeys, ...
                "GroupHeaderRowIdx", find(headerIdx), ...
                "GroupHeaderLevels", zeros(1, nGroups), ...
                "GroupHeaderDataRows", {groupHeaderDataRows}, ...
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
                "VisibleGroupHeaderLevels", zeros(1, nnz(idxVisibleHeaderRowMask)), ...
                "FoldedVisibleToDataMap", visibleToDataMap, ...
                "FoldedDataToVisibleMap", dataToVisibleMap);
        end

        function result = groupNested(this, data, filteredData, filteredDataToVisibleMap, ...
                filteredVisibleToDataMap, groupingVariable, openGroups, hiddenGroups)
            arguments
                this (1,1) gwidgets.internal.table.GroupingController
                data (:,:) table
                filteredData (:,:) table
                filteredDataToVisibleMap (1,:) double
                filteredVisibleToDataMap (1,:) double
                groupingVariable (1,:) string
                openGroups (1,:) string
                hiddenGroups (1,:) string
            end

            groupColumnIdx = ismember(string(data.Properties.VariableNames), groupingVariable);
            tmpData = filteredData;
            groupedDataVariables = string(tmpData.Properties.VariableNames);
            groupedDataVariables(ismember(groupedDataVariables, groupingVariable)) = [];
            tmpData(:, ismember(string(tmpData.Properties.VariableNames), groupingVariable)) = [];
            tmpData = table2cell(tmpData);

            nDataCols = size(tmpData, 2);
            if nDataCols == 0
                nDataCols = 1;
            end

            state = struct( ...
                "Rows", {cell(1,0)}, ...
                "Groups", string.empty(1,0), ...
                "GroupKeys", table.empty(0,0), ...
                "HeaderRows", zeros(1,0), ...
                "HeaderLevels", zeros(1,0), ...
                "HeaderDataRows", {cell(1,0)}, ...
                "FilteredCount", zeros(1,0), ...
                "GroupIdxs", zeros(1, height(data)), ...
                "DataToVisibleMap", NaN(size(filteredDataToVisibleMap)), ...
                "VisibleToDataMap", NaN(1, height(filteredData)), ...
                "VisibleRowCount", 0);

            if ~isempty(groupingVariable)
                state = this.appendNestedGroups( ...
                    state, data, tmpData, filteredVisibleToDataMap, groupingVariable, ...
                    1, 1:height(data), 1:height(filteredData), strings(1,0), nDataCols);
            end

            groupedData = vertcat(state.Rows{:});
            if isempty(groupedData)
                groupedData = cell(0, nDataCols);
            end

            openGroups = openGroups(ismember(openGroups, state.Groups));
            hiddenGroups = hiddenGroups(ismember(hiddenGroups, state.Groups));

            result = struct( ...
                "GroupedVisibleData", {groupedData}, ...
                "GroupedDataVariables", groupedDataVariables, ...
                "Groups", state.Groups, ...
                "GroupKeys", state.GroupKeys, ...
                "GroupHeaderRowIdx", state.HeaderRows, ...
                "GroupHeaderLevels", state.HeaderLevels, ...
                "GroupHeaderDataRows", {state.HeaderDataRows}, ...
                "GroupColumnIdx", groupColumnIdx, ...
                "GroupFilteredCount", state.FilteredCount, ...
                "GroupIdxs", state.GroupIdxs, ...
                "OpenGroups", openGroups, ...
                "HiddenGroups", hiddenGroups, ...
                "GroupedDataToVisibleMap", state.DataToVisibleMap, ...
                "GroupedVisibleToDataMap", state.VisibleToDataMap);
        end

        function result = foldNested(this, sortedVisibleData, sortedGroupHeaderRowIdx, sortedGroupValues, ...
                sortedGroupHeaderLevels, sortedVisibleToDataMap, sortedDataToVisibleMap, groupFilteredCount, ...
                groupingVariable, openGroups, showEmptyGroups, dataVariableNames)
            arguments
                this (1,1) gwidgets.internal.table.GroupingController
                sortedVisibleData (:,:) cell
                sortedGroupHeaderRowIdx (1,:) double
                sortedGroupValues (1,:) string
                sortedGroupHeaderLevels (1,:) double
                sortedVisibleToDataMap (1,:) double
                sortedDataToVisibleMap (1,:) double
                groupFilteredCount (1,:) double
                groupingVariable (1,:) string
                openGroups (1,:) string
                showEmptyGroups (1,1) logical
                dataVariableNames (1,:) string
            end

            groupedData = sortedVisibleData;
            idxsHeaderRow = sortedGroupHeaderRowIdx;
            idxVisibleHeaderRowMask = false(1, size(groupedData, 1));
            idxVisibleHeaderRowMask(idxsHeaderRow) = true;

            visRowToRemove = false(1, size(groupedData, 1));
            isHiddenGroup = ~showEmptyGroups & groupFilteredCount == 0;
            isOpenGroup = ismember(sortedGroupValues, openGroups);

            for iGroup = numel(idxsHeaderRow):-1:1
                idxHeaderRow = idxsHeaderRow(iGroup);
                idxGroupData = (idxHeaderRow + 1):(this.nextSiblingHeader( ...
                    idxsHeaderRow, sortedGroupHeaderLevels, iGroup, size(groupedData, 1)) - 1);

                if ~isHiddenGroup(iGroup) && ~isOpenGroup(iGroup)
                    groupedData{idxHeaderRow, 1} = this.headerPrefix(sortedGroupHeaderLevels(iGroup), false) ...
                        + groupedData{idxHeaderRow, 1};
                    visRowToRemove(idxGroupData) = true;
                elseif ~isHiddenGroup(iGroup)
                    groupedData{idxHeaderRow, 1} = this.headerPrefix(sortedGroupHeaderLevels(iGroup), true) ...
                        + groupedData{idxHeaderRow, 1};
                else
                    visRowToRemove(idxGroupData) = true;
                    visRowToRemove(idxHeaderRow) = true;
                end
            end

            hiddenGroups = sortedGroupValues(isHiddenGroup);
            hiddenGroups = hiddenGroups(end:-1:1);

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
            end

            visibleData = cell2table(groupedData, VariableNames=vars);
            headerRemoved = false(size(sortedGroupValues));
            if ~isempty(idxsHeaderRow)
                headerRemoved = visRowToRemove(idxsHeaderRow);
            end

            result = struct( ...
                "VisibleData", visibleData, ...
                "DisplayGroups", sortedGroupValues(~headerRemoved), ...
                "HiddenGroups", hiddenGroups, ...
                "VisibleGroupHeaderRowIdx", find(idxVisibleHeaderRowMask), ...
                "VisibleGroupHeaderLevels", sortedGroupHeaderLevels(~headerRemoved), ...
                "FoldedVisibleToDataMap", visibleToDataMap, ...
                "FoldedDataToVisibleMap", dataToVisibleMap);
        end
    end

    methods (Access = private)
        function state = appendNestedGroups(this, state, data, tmpData, filteredVisibleToDataMap, groupingVariable, ...
                level, allRows, filteredRows, parentParts, nDataCols)
            groupKeys = data(allRows, groupingVariable(level));
            if height(groupKeys) == 0
                return
            end

            [groupIdxs, keys] = findgroups(groupKeys);
            labels = this.groupLabels(keys);

            for iGroup = 1:numel(labels)
                allSubRows = allRows(groupIdxs == iGroup);
                filteredRawRows = filteredVisibleToDataMap(filteredRows);
                filteredSubRows = filteredRows(ismember(filteredRawRows, allSubRows));

                pathParts = [parentParts, labels(iGroup)];
                groupPath = join(pathParts, "|");
                state.Groups(end+1) = groupPath;
                state.GroupKeys = [state.GroupKeys; this.pathKeyTable(groupingVariable, pathParts)];
                state.HeaderRows(end+1) = state.VisibleRowCount + 1;
                state.HeaderLevels(end+1) = level;
                state.HeaderDataRows{end+1} = allSubRows;
                state.FilteredCount(end+1) = numel(filteredSubRows);

                state.VisibleRowCount = state.VisibleRowCount + 1;
                state.VisibleToDataMap(state.VisibleRowCount) = NaN;
                header = cell(1, nDataCols);
                header{1} = groupingVariable(level) + ": " + labels(iGroup) ...
                    + " (" + numel(filteredSubRows) + "/" + numel(allSubRows) + ")";
                state.Rows{end+1} = header;

                if level < numel(groupingVariable)
                    state = this.appendNestedGroups( ...
                        state, data, tmpData, filteredVisibleToDataMap, groupingVariable, ...
                        level + 1, allSubRows, filteredSubRows, pathParts, nDataCols);
                    continue
                end

                nFilteredRows = numel(filteredSubRows);
                if size(tmpData, 2) > 0 && nFilteredRows > 0
                    visibleRows = state.VisibleRowCount + (1:nFilteredRows);
                    rawRows = filteredVisibleToDataMap(filteredSubRows);
                    state.DataToVisibleMap(rawRows) = visibleRows;
                    state.VisibleToDataMap(visibleRows) = rawRows;
                    state.VisibleRowCount = state.VisibleRowCount + nFilteredRows;
                    state.Rows{end+1} = tmpData(filteredSubRows, :);
                end

                leafIdx = find(state.Groups == groupPath, 1);
                state.GroupIdxs(allSubRows) = leafIdx;
            end
        end

        function nextHeaderRow = nextSiblingHeader(this, headerRows, headerLevels, groupIdx, nRows)
            arguments
                this (1,1) gwidgets.internal.table.GroupingController %#ok<INUSA>
                headerRows (1,:) double
                headerLevels (1,:) double
                groupIdx (1,1) double
                nRows (1,1) double
            end

            nextIdx = find(headerLevels((groupIdx+1):end) <= headerLevels(groupIdx), 1);
            if isempty(nextIdx)
                nextHeaderRow = nRows + 1;
                return
            end

            nextHeaderRow = headerRows(groupIdx + nextIdx);
        end

        function prefix = headerPrefix(this, level, isOpen)
            arguments
                this (1,1) gwidgets.internal.table.GroupingController %#ok<INUSA>
                level (1,1) double
                isOpen (1,1) logical
            end

            marker = "⮞ ";
            if isOpen
                marker = "⮟ ";
            end
            if level <= 1
                prefix = marker;
                return
            end

            prefix = string(repmat(char(160), 1, 4*(level - 1))) + marker;
        end
    end

    methods (Static, Access = private)
        function keyTable = pathKeyTable(groupingVariable, pathParts)
            arguments
                groupingVariable (1,:) string
                pathParts (1,:) string
            end

            values = strings(1, numel(groupingVariable));
            values(1:numel(pathParts)) = pathParts;
            keyTable = array2table(values, VariableNames=groupingVariable);
        end

        function labels = groupLabels(groupKeys)
            arguments
                groupKeys (:,:) table
            end

            if height(groupKeys) == 0
                labels = string.empty(1,0);
                return
            end

            groupLabelParts = strings(height(groupKeys), width(groupKeys));
            for iKey = 1:width(groupKeys)
                groupLabelParts(:, iKey) = gwidgets.internal.table.GroupingController.escapeGroupValue( ...
                    string(groupKeys{:, iKey}));
            end

            labels = reshape(join(groupLabelParts, "|", 2), 1, []);
        end

        function values = escapeGroupValue(values)
            arguments
                values (:,1) string
            end

            values = replace(values, "\", "\\");
            values = replace(values, "|", "\|");
        end
    end

end

