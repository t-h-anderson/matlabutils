classdef ColumnWidthController
    % ColumnWidthController owns column-width store calculations.

    methods (Static)
        function val = normalizeColumnWidths(val)
            val = convertCharsToStrings(val);
            if isempty(val)
                val = {};
            elseif ~iscell(val)
                val = num2cell(val);
            else
                val = cellfun(@(x)convertCharsToStrings(x), val, UniformOutput=false);
            end

            if isscalar(val) && isstring(val{1}) && val{1} == ""
                val = {};
            end

            isAuto = cellfun( ...
                @(v)isstring(v) && isscalar(v) && v == "auto", ...
                val);
            if any(isAuto)
                val(isAuto) = {"1x"};
            end
        end

        function stores = setStores(val, mask, nData, current)
            arguments
                val (1,:) cell
                mask (1,:) logical
                nData (1,1) double
                current (1,1) struct
            end

            types = gwidgets.internal.table.ColumnWidthController.extendStore( ...
                current.Types, "Relative", nData);
            px = gwidgets.internal.table.ColumnWidthController.extendStore( ...
                current.Pixel, NaN, nData);
            rel = gwidgets.internal.table.ColumnWidthController.extendStore( ...
                current.Relative, "1x", nData);

            maskIdxs = find(mask);
            if isempty(val)
                types(mask) = "Relative";
                px(mask) = NaN;
                rel(mask) = "1x";
            else
                for k = 1:numel(val)
                    i = maskIdxs(k);
                    v = val{k};
                    if isnumeric(v) && isscalar(v) && v > 0
                        types(i) = "Pixel";
                        px(i) = v;
                        rel(i) = string(missing);
                    elseif isstring(v) && isscalar(v) && lower(v) == "fit"
                        types(i) = "Fit";
                        px(i) = NaN;
                        rel(i) = string(missing);
                    else
                        types(i) = "Relative";
                        px(i) = NaN;
                        rel(i) = string(v);
                    end
                end
            end

            stores = struct("Types", types, "Pixel", px, "Relative", rel);
        end

        function stores = defaultStores(nData)
            arguments
                nData (1,1) double
            end

            stores = struct( ...
                "Types", repelem("Relative", 1, nData), ...
                "Pixel", nan(1, nData), ...
                "Relative", repelem("1x", 1, nData));
        end

        function [stores, changed, countMatches] = updateFromBridge(pixelWidths, visibleMask, nData, current)
            arguments
                pixelWidths (1,:) double
                visibleMask (1,:) logical
                nData (1,1) double
                current (1,1) struct
            end

            if numel(pixelWidths) ~= sum(visibleMask)
                stores = current;
                changed = false;
                countMatches = false;
                return
            end

            countMatches = true;
            visIdxs = find(visibleMask);
            px = gwidgets.internal.table.ColumnWidthController.extendStore(current.Pixel, NaN, nData);
            rel = gwidgets.internal.table.ColumnWidthController.extendStore(current.Relative, "1x", nData);

            for k = 1:numel(pixelWidths)
                px(visIdxs(k)) = pixelWidths(k);
            end

            g = gwidgets.internal.table.ColumnWidthController.gcdPixelWidths(px);
            for i = 1:nData
                if ~isnan(px(i)) && px(i) > 0
                    rel(i) = string(round(px(i)/g)) + "x";
                end
            end

            changed = ~isequaln(px, current.Pixel) || ~isequaln(rel, current.Relative);
            stores = struct("Types", current.Types, "Pixel", px, "Relative", rel);
        end

        function [stores, changed, countMatches] = updateFromBridgeResize( ...
                pixelWidths, visibleMask, resizedMask, startPixelWidth, nData, current)
            arguments
                pixelWidths (1,:) double
                visibleMask (1,:) logical
                resizedMask (1,:) logical
                startPixelWidth (1,1) double
                nData (1,1) double
                current (1,1) struct
            end

            if numel(pixelWidths) ~= sum(visibleMask) || numel(resizedMask) ~= nData || sum(resizedMask) ~= 1
                stores = current;
                changed = false;
                countMatches = false;
                return
            end

            countMatches = true;
            types = gwidgets.internal.table.ColumnWidthController.extendStore(current.Types, "Relative", nData);
            px = gwidgets.internal.table.ColumnWidthController.extendStore(current.Pixel, NaN, nData);
            rel = gwidgets.internal.table.ColumnWidthController.extendStore(current.Relative, "1x", nData);
            visIdxs = find(visibleMask);
            resizedIdx = find(resizedMask, 1);
            resizedVisibleIdx = find(visIdxs == resizedIdx, 1);
            if isempty(resizedVisibleIdx)
                stores = current;
                changed = false;
                countMatches = false;
                return
            end

            for k = 1:numel(pixelWidths)
                iData = visIdxs(k);
                if resizedMask(iData) || types(iData) ~= "Pixel"
                    px(iData) = pixelWidths(k);
                end
            end

            if types(resizedIdx) == "Relative"
                targetPixelWidth = pixelWidths(resizedVisibleIdx);
                rel(resizedIdx) = gwidgets.internal.table.ColumnWidthController.resizedRelativeWidth( ...
                    rel(resizedIdx), targetPixelWidth, startPixelWidth);
            end

            changed = ~isequaln(types, current.Types) || ~isequaln(px, current.Pixel) || ...
                ~isequaln(rel, current.Relative);
            stores = struct("Types", types, "Pixel", px, "Relative", rel);
        end

        function val = buildMixedCell(mask, nData, current)
            arguments
                mask (1,:) logical
                nData (1,1) double
                current (1,1) struct
            end

            nResult = sum(mask);
            if nResult == 0
                val = {};
                return
            end

            types = gwidgets.internal.table.ColumnWidthController.extendStore(current.Types, "Relative", nData);
            px = gwidgets.internal.table.ColumnWidthController.extendStore(current.Pixel, NaN, nData);
            rel = gwidgets.internal.table.ColumnWidthController.extendStore(current.Relative, "1x", nData);
            maskIdxs = find(mask);
            val = cell(1, nResult);
            for k = 1:nResult
                i = maskIdxs(k);
                if types(i) == "Pixel"
                    val{k} = px(i);
                elseif types(i) == "Fit"
                    val{k} = "fit";
                else
                    r = rel(i);
                    if ismissing(r) || r == ""
                        val{k} = "1x";
                    else
                        val{k} = r;
                    end
                end
            end
        end

        function val = resolvedPixel(mask, nData, current)
            arguments
                mask (1,:) logical
                nData (1,1) double
                current (1,1) struct
            end

            px = gwidgets.internal.table.ColumnWidthController.extendStore(current.Pixel, NaN, nData);
            val = px(mask);
        end

        function val = resolvedRelative(mask, nData, current)
            arguments
                mask (1,:) logical
                nData (1,1) double
                current (1,1) struct
            end

            rel = gwidgets.internal.table.ColumnWidthController.extendStore(current.Relative, "1x", nData);
            val = rel(mask);
        end

        function val = resolvedTypes(mask, nData, current)
            arguments
                mask (1,:) logical
                nData (1,1) double
                current (1,1) struct
            end

            types = gwidgets.internal.table.ColumnWidthController.extendStore(current.Types, "Relative", nData);
            val = types(mask);
        end

        function changed = didBridgeWidthsChange(pixelWidths, visibleMask, nData, current)
            arguments
                pixelWidths (1,:) double
                visibleMask (1,:) logical
                nData (1,1) double
                current (1,1) struct
            end

            if numel(pixelWidths) ~= sum(visibleMask)
                changed = false;
                return
            end

            visIdxs = find(visibleMask);
            px = gwidgets.internal.table.ColumnWidthController.extendStore(current.Pixel, NaN, nData);
            for k = 1:numel(pixelWidths)
                stored = px(visIdxs(k));
                if isnan(stored) || abs(stored - pixelWidths(k)) > 1
                    changed = true;
                    return
                end
            end
            changed = false;
        end
    end

    methods (Static, Access = private)
        function store = extendStore(store, defaultVal, nData)
            n = numel(store);
            if n == nData
                return
            elseif n == 0
                if isnumeric(defaultVal)
                    store = repelem(defaultVal, 1, nData);
                else
                    store = repelem(string(defaultVal), 1, nData);
                end
            elseif n < nData
                if isnumeric(defaultVal)
                    store = [store, repelem(defaultVal, 1, nData - n)];
                else
                    store = [store, repelem(string(defaultVal), 1, nData - n)];
                end
            else
                store = store(1:nData);
            end
        end

        function g = gcdPixelWidths(px)
            finitePx = px(isfinite(px) & px > 0);
            if isempty(finitePx)
                g = 1;
                return
            end

            finitePx = round(finitePx);
            g = finitePx(1);
            for k = 2:numel(finitePx)
                g = gcd(g, finitePx(k));
            end

            if g <= 0
                g = 1;
            end
        end

        function value = resizedRelativeWidth(currentValue, targetPixelWidth, startPixelWidth)
            currentWeight = gwidgets.internal.table.ColumnWidthController.relativeWeight(currentValue);
            if ~isfinite(startPixelWidth) || startPixelWidth <= 0
                startPixelWidth = targetPixelWidth/currentWeight;
            end

            newWeight = currentWeight*targetPixelWidth/startPixelWidth;
            value = gwidgets.internal.table.ColumnWidthController.formatRelativeWeight(newWeight);
        end

        function weight = relativeWeight(value)
            text = lower(strtrim(string(value)));
            if ismissing(text) || text == ""
                weight = 1;
                return
            end

            if endsWith(text, "x")
                text = extractBefore(text, strlength(text));
            end
            weight = str2double(text);
            if ~isfinite(weight) || weight <= 0
                weight = 1;
            end
        end

        function value = formatRelativeWeight(weight)
            if ~isfinite(weight) || weight <= 0
                weight = 1;
            end

            text = regexprep(sprintf("%.6f", weight), "0+$", "");
            text = regexprep(text, "\.$", "");
            value = string(text) + "x";
        end
    end

end

