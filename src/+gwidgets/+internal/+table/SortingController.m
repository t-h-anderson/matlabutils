classdef SortingController < handle
    % SortingController owns active row and group sorting transforms.

    methods
        function result = sort(this, filteredData, dataTable, groupedVisibleData, groupedDataVariables, ...
                groupingVariable, groups, groupKeys, groupHeaderRowIdx, groupFilteredCount, ...
                groupedVisibleToDataMap, groupedDataToVisibleMap, dataColumnSortable, sortByDataColumn, ...
                sortDirection)
            arguments
                this (1,1) gwidgets.internal.table.SortingController
                filteredData (:,:) table
                dataTable (:,:) table
                groupedVisibleData (:,:) cell
                groupedDataVariables (1,:) string
                groupingVariable (1,:) string
                groups (1,:) string
                groupKeys (:,:) table
                groupHeaderRowIdx (1,:) double
                groupFilteredCount (1,:) double
                groupedVisibleToDataMap (1,:) double
                groupedDataToVisibleMap (1,:) double
                dataColumnSortable (1,:) logical
                sortByDataColumn (1,:) string
                sortDirection (1,1) string {mustBeMember(sortDirection, ["Ascend", "Descend", "None"])}
            end

            data = groupedVisibleData;
            dataToVisibleMap = groupedDataToVisibleMap;
            visibleToDataMap = groupedVisibleToDataMap;
            sortedGroupHeaderRowIdx = groupHeaderRowIdx;
            sortedGroupValues = groups;
            sortedGroupKeys = groupKeys;
            sortedGroupFilteredCount = groupFilteredCount;

            if sortDirection == "None"
                result = this.createResult(data, dataToVisibleMap, visibleToDataMap, ...
                    sortedGroupHeaderRowIdx, sortedGroupValues, sortedGroupKeys, sortedGroupFilteredCount);
                return
            end

            dataVars = groupedDataVariables;
            groupVars = groupingVariable;
            sortBy = sortByDataColumn;

            if isempty(dataColumnSortable) ...
                    || (isscalar(dataColumnSortable) && ~dataColumnSortable) ...
                    || (~isscalar(dataColumnSortable) && all(~dataColumnSortable))
                result = this.createResult(data, dataToVisibleMap, visibleToDataMap, ...
                    sortedGroupHeaderRowIdx, sortedGroupValues, sortedGroupKeys, sortedGroupFilteredCount);
                return
            elseif ~isscalar(dataColumnSortable)
                vars = string(dataTable.Properties.VariableNames);
                sortableVars = vars(dataColumnSortable);
                sortBy = sortBy(ismember(sortBy, sortableVars));
            end

            sortByGroupVars = sortBy(ismember(sortBy, groupVars));
            sortByDataVars = sortBy(ismember(sortBy, dataVars));
            [isDataSortVar, dataColIdx] = ismember(sortByDataVars, dataVars);
            dataColIdx = dataColIdx(isDataSortVar);

            sortDirectionLower = lower(sortDirection);
            groupHeaderRowIdxs = groupHeaderRowIdx;

            if isempty(groupHeaderRowIdxs)
                groupHeaderRowIdxs = 0;
            end

            groupHeaderRowIdxs = [groupHeaderRowIdxs, size(data, 1)+1];

            if ~isempty(sortByDataVars)
                [typedSortColumns, canUseTypedSort] = this.buildTypedSortColumns(filteredData, sortByDataVars);
                typedSortFailure = MException.empty(1,0);
                for iGroup = 1:(numel(groupHeaderRowIdxs)-1)
                    dataStartIdx = groupHeaderRowIdxs(iGroup) + 1;
                    dataEndIdx = groupHeaderRowIdxs(iGroup+1) - 1;

                    groupIdxs = dataStartIdx:dataEndIdx;
                    groupDataRowIdx = visibleToDataMap(groupIdxs);

                    if canUseTypedSort
                        try
                            orderIdx = this.orderRowsByTypedColumns( ...
                                groupDataRowIdx, typedSortColumns, sortDirectionLower);
                        catch ME
                            typedSortFailure = ME;
                            canUseTypedSort = false;
                        end
                    end

                    if ~canUseTypedSort
                        try
                            subData = data(groupIdxs, dataColIdx);
                            subData = cell2table(subData, VariableNames=sortByDataVars);
                            [~, orderIdx] = sortrows(subData, sortByDataVars, sortDirectionLower);
                        catch fallbackME
                            if ~isempty(typedSortFailure)
                                fallbackME = addCause(fallbackME, typedSortFailure);
                            end
                            rethrow(fallbackME);
                        end
                    end

                    groupIdxsReordered = groupIdxs(orderIdx);
                    data(groupIdxs, :) = data(groupIdxsReordered, :);

                    tmp = dataToVisibleMap(groupDataRowIdx);
                    tmp(orderIdx) = tmp;
                    dataToVisibleMap(groupDataRowIdx) = tmp;

                    visibleToDataMap(groupIdxs) = groupDataRowIdx(orderIdx);
                end
            end

            if ~isempty(sortByGroupVars) && ~isempty(groupHeaderRowIdx)
                orderIdx = this.orderGroupsByVariables( ...
                    sortedGroupKeys, sortByGroupVars, sortDirectionLower);

                [data, dataToVisibleMap, visibleToDataMap, sortedGroupHeaderRowIdx, sortedGroupValues, ...
                    sortedGroupKeys, sortedGroupFilteredCount] = ...
                    this.reorderGroups( ...
                    data, dataToVisibleMap, visibleToDataMap, groupHeaderRowIdxs, sortedGroupValues, ...
                    sortedGroupKeys, sortedGroupFilteredCount, orderIdx);
            end

            result = this.createResult(data, dataToVisibleMap, visibleToDataMap, ...
                sortedGroupHeaderRowIdx, sortedGroupValues, sortedGroupKeys, sortedGroupFilteredCount);
        end
    end

    methods (Access = private)
        function result = createResult(this, data, dataToVisibleMap, visibleToDataMap, ...
                groupHeaderRowIdx, groupValues, groupKeys, groupFilteredCount)
            arguments
                this (1,1) gwidgets.internal.table.SortingController %#ok<INUSA>
                data (:,:) cell
                dataToVisibleMap (1,:) double
                visibleToDataMap (1,:) double
                groupHeaderRowIdx (1,:) double
                groupValues (1,:) string
                groupKeys (:,:) table
                groupFilteredCount (1,:) double
            end

            result = struct( ...
                "SortedVisibleData", {data}, ...
                "SortedDataToVisibleMap", dataToVisibleMap, ...
                "SortedVisibleToDataMap", visibleToDataMap, ...
                "SortedGroupHeaderRowIdx", groupHeaderRowIdx, ...
                "SortedGroupValues", groupValues, ...
                "SortedGroupKeys", groupKeys, ...
                "SortedGroupFilteredCount", groupFilteredCount);
        end

        function [typedSortColumns, canUseTypedSort] = buildTypedSortColumns(this, filteredData, sortByDataVars)
            arguments
                this (1,1) gwidgets.internal.table.SortingController %#ok<INUSA>
                filteredData (:,:) table
                sortByDataVars (1,:) string
            end

            nFilteredRows = height(filteredData);
            typedSortColumns = cell(1, numel(sortByDataVars));
            canUseTypedSort = true;

            for iSort = 1:numel(sortByDataVars)
                varData = filteredData.(sortByDataVars(iSort));

                if size(varData, 1) ~= nFilteredRows || size(varData, 2) ~= 1
                    canUseTypedSort = false;
                    typedSortColumns = {};
                    return
                end

                if iscellstr(varData)
                    typedSortColumns{iSort} = string(varData);
                elseif isnumeric(varData) || islogical(varData) ...
                        || isstring(varData) || iscategorical(varData) ...
                        || isdatetime(varData) || isduration(varData) ...
                        || iscalendarDuration(varData)
                    typedSortColumns{iSort} = varData;
                else
                    canUseTypedSort = false;
                    typedSortColumns = {};
                    return
                end
            end
        end

        function orderIdx = orderRowsByTypedColumns(this, filteredRowIdx, typedSortColumns, sortDirection)
            arguments
                this (1,1) gwidgets.internal.table.SortingController %#ok<INUSA>
                filteredRowIdx (1,:) double
                typedSortColumns (1,:) cell
                sortDirection (1,1) string
            end

            orderIdx = 1:numel(filteredRowIdx);

            for iSort = numel(typedSortColumns):-1:1
                values = typedSortColumns{iSort}(filteredRowIdx(orderIdx), :);
                [~, idx] = sort(values, sortDirection);
                orderIdx = orderIdx(idx);
            end
        end

        function orderIdx = orderGroupsByVariables(this, groupKeys, sortByGroupVars, sortDirection)
            arguments
                this (1,1) gwidgets.internal.table.SortingController
                groupKeys (:,:) table
                sortByGroupVars (1,:) string
                sortDirection (1,1) string
            end

            orderIdx = 1:height(groupKeys);

            groupVars = string(groupKeys.Properties.VariableNames);
            sortByGroupVars = sortByGroupVars(ismember(sortByGroupVars, groupVars));
            if isempty(orderIdx) || isempty(sortByGroupVars)
                return
            end

            sortColumns = cell(1, numel(sortByGroupVars));
            for iKey = 1:numel(sortByGroupVars)
                sortColumns{iKey} = this.sortableGroupKeyValues(groupKeys.(sortByGroupVars(iKey)));
            end

            orderIdx = this.orderRowsByTypedColumns(orderIdx, sortColumns, sortDirection);
        end

        function [data, dataToVisibleMap, visibleToDataMap, sortedGroupHeaderRowIdx, sortedGroupValues, ...
                sortedGroupKeys, sortedGroupFilteredCount] = reorderGroups(this, data, dataToVisibleMap, ...
                visibleToDataMap, groupHeaderRowIdxs, sortedGroupValues, sortedGroupKeys, ...
                sortedGroupFilteredCount, orderIdx)
            arguments
                this (1,1) gwidgets.internal.table.SortingController %#ok<INUSA>
                data (:,:) cell
                dataToVisibleMap (1,:) double
                visibleToDataMap (1,:) double
                groupHeaderRowIdxs (1,:) double
                sortedGroupValues (1,:) string
                sortedGroupKeys (:,:) table
                sortedGroupFilteredCount (1,:) double
                orderIdx (1,:) double
            end

            nGroups = numel(groupHeaderRowIdxs) - 1;
            groupIdxs = cell(1, nGroups);
            groupSize = zeros(1, nGroups);
            dataToVisibleMapGroup = cell(1, nGroups);

            for iGroup = 1:nGroups
                groupStartIdx = groupHeaderRowIdxs(iGroup);
                groupEndIdx = groupHeaderRowIdxs(iGroup+1) - 1;
                groupIdxs{iGroup} = groupStartIdx:groupEndIdx;

                groupSize(iGroup) = numel(groupIdxs{iGroup}) - 1;

                idx = ismember(dataToVisibleMap, groupIdxs{iGroup});
                tmp = dataToVisibleMap;
                tmp = tmp - sum(groupSize(1:iGroup-1)) - iGroup;
                dataToVisibleMapGroup{iGroup} = tmp .* idx;
            end

            groupSize = groupSize(orderIdx);
            groupIdxs = groupIdxs(orderIdx);
            groupIdxs = [groupIdxs{:}];
            dataToVisibleMapGroup = dataToVisibleMapGroup(orderIdx);

            data = data(groupIdxs, :);
            visibleToDataMap = visibleToDataMap(groupIdxs);

            dataToVisibleMap = 0*dataToVisibleMap;
            cumSize = 1;
            for iGroup = 1:numel(dataToVisibleMapGroup)
                dataToVisibleMap = dataToVisibleMap + dataToVisibleMapGroup{iGroup} + ...
                    (dataToVisibleMapGroup{iGroup} ~= 0)*cumSize;
                cumSize = cumSize + groupSize(iGroup) + 1;
            end

            newGroupHeaderIdxs = [0, cumsum(groupSize)] + (1:(numel(groupSize)+1));
            sortedGroupHeaderRowIdx = newGroupHeaderIdxs(1:end-1);
            sortedGroupValues = sortedGroupValues(orderIdx);
            sortedGroupKeys = sortedGroupKeys(orderIdx, :);
            sortedGroupFilteredCount = sortedGroupFilteredCount(orderIdx);
        end

        function values = sortableGroupKeyValues(this, values)
            arguments
                this (1,1) gwidgets.internal.table.SortingController %#ok<INUSA>
                values
            end

            if iscellstr(values)
                values = string(values);
            elseif ~(isnumeric(values) || islogical(values) ...
                    || isstring(values) || iscategorical(values) ...
                    || isdatetime(values) || isduration(values) ...
                    || iscalendarDuration(values))
                values = string(values);
            end
        end
    end

end

