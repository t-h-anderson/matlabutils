classdef SortingController < handle
    % SortingController owns active row and group sorting transforms.

    methods
        function result = sort(this, filteredData, dataTable, groupedVisibleData, groupedDataVariables, ...
                groupingVariable, groups, groupHeaderRowIdx, groupedVisibleToDataMap, groupedDataToVisibleMap, ...
                dataColumnSortable, sortByDataColumn, sortDirection)
            arguments
                this (1,1) gwidgets.internal.table.SortingController
                filteredData (:,:) table
                dataTable (:,:) table
                groupedVisibleData (:,:) cell
                groupedDataVariables (1,:) string
                groupingVariable (1,:) string
                groups (1,:) string
                groupHeaderRowIdx (1,:) double
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

            if sortDirection == "None"
                result = this.createResult(data, dataToVisibleMap, visibleToDataMap, ...
                    sortedGroupHeaderRowIdx, sortedGroupValues);
                return
            end

            dataVars = groupedDataVariables;
            groupVars = groupingVariable;
            sortBy = sortByDataColumn;

            if isempty(dataColumnSortable) ...
                    || (isscalar(dataColumnSortable) && ~dataColumnSortable) ...
                    || (~isscalar(dataColumnSortable) && all(~dataColumnSortable))
                result = this.createResult(data, dataToVisibleMap, visibleToDataMap, ...
                    sortedGroupHeaderRowIdx, sortedGroupValues);
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

            for iGroupVar = 1:numel(sortByGroupVars)
                if iGroupVar > 1
                    warning("Multiple grouping not yet supported");
                    continue
                end

                groupData = [groupedVisibleData{groupHeaderRowIdx, 1}];
                [~, orderIdx] = sort(groupData, sortDirectionLower);

                groupIdxs = cell(1, numel(groupHeaderRowIdxs)-1);
                groupSize = NaN(1, numel(groupHeaderRowIdxs)-1);
                dataToVisibleMapGroup = cell(1, numel(groupHeaderRowIdxs)-1);
                for iGroup = 1:(numel(groupHeaderRowIdxs)-1)
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
            end

            result = this.createResult(data, dataToVisibleMap, visibleToDataMap, ...
                sortedGroupHeaderRowIdx, sortedGroupValues);
        end
    end

    methods (Access = private)
        function result = createResult(this, data, dataToVisibleMap, visibleToDataMap, ...
                groupHeaderRowIdx, groupValues)
            arguments
                this (1,1) gwidgets.internal.table.SortingController %#ok<INUSA>
                data (:,:) cell
                dataToVisibleMap (1,:) double
                visibleToDataMap (1,:) double
                groupHeaderRowIdx (1,:) double
                groupValues (1,:) string
            end

            result = struct( ...
                "SortedVisibleData", {data}, ...
                "SortedDataToVisibleMap", dataToVisibleMap, ...
                "SortedVisibleToDataMap", visibleToDataMap, ...
                "SortedGroupHeaderRowIdx", groupHeaderRowIdx, ...
                "SortedGroupValues", groupValues);
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
    end

end

