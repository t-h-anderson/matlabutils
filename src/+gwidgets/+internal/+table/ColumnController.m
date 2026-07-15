classdef ColumnController < gwidgets.internal.table.TableController
    % ColumnController owns column-related table state.

    properties (Dependent)
        Width
        DataWidth
        DefaultWidths
        PixelDataWidths
        RelativeDataWidths
        DataWidthTypes
        PixelWidths
        RelativeWidths
        WidthTypes
        Editable
        DataEditable
        Sortable
        DataSortable
        Visible
        Names
        DataNames
        VisibleNames
        VisibleDataNames
        HiddenNames
        HiddenDataNames
    end

    properties (Access = private)
        Names_ (1,:) string
        Visible_ (1,:) logical
        DataEditable_ (1,:) logical
        DataSortable_ (1,:) logical
        PixelDataWidths_ (1,:) double
        RelativeDataWidths_ (1,:) string
        DataWidthTypes_ (1,:) string
        DefaultWidths_ (1,:) cell
    end

    methods
        function this = ColumnController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
        end

        function val = get.Width(this)
            val = this.buildMixedWidthCell(this.Visible);
        end

        function set.Width(this, val)
            val = gwidgets.internal.table.ColumnWidthController.normalizeColumnWidths(val);
            nData = this.nData();

            if isempty(val)
                if ~isempty(this.DefaultWidths_)
                    defaultVal = gwidgets.internal.table.ColumnWidthController.normalizeColumnWidths(this.DefaultWidths_);
                    this.setWidthStores(defaultVal, true(1, nData));
                else
                    this.resetToDefaultWidths();
                end
            else
                if isscalar(val)
                    val = repelem(val, 1, sum(this.Visible));
                end
                if numel(val) ~= sum(this.Visible)
                    error("GraphicsWidgets:Table:ColumnWidthSize", ...
                        "Size of ColumnWidth must match the number of visible columns, be scalar, or be empty (restore to default)");
                end
                this.setWidthStores(val, this.Visible);
            end

            this.requestUpdate("DataColumnWidth", "Interaction");
        end

        function val = get.DataWidth(this)
            val = this.buildMixedWidthCell(true(1, this.nData()));
        end

        function set.DataWidth(this, val)
            val = gwidgets.internal.table.ColumnWidthController.normalizeColumnWidths(val);
            nData = this.nData();
            if isscalar(val)
                val = repelem(val, 1, nData);
            end
            if ~isempty(val) && numel(val) ~= nData
                error("GraphicsWidgets:Table:DataColumnWidthSize", ...
                    "Size of DataColumnWidth must match the number of data columns, be scalar, or be empty (restore to default)");
            end
            this.setWidthStores(val, true(1, nData));
            this.requestUpdate("DataColumnWidth", "Interaction");
        end

        function val = get.DefaultWidths(this)
            val = this.DefaultWidths_;
            val = convertCharsToStrings(val);
            if ~iscell(val)
                val = num2cell(val);
            end
            val = gwidgets.internal.table.ColumnWidthController.normalizeColumnWidths(val);
        end

        function set.DefaultWidths(this, val)
            val = gwidgets.internal.table.ColumnWidthController.normalizeColumnWidths(val);
            if isscalar(val)
                val = repelem(val, 1, this.nData());
            end
            if ~isempty(val) && numel(val) ~= this.nData()
                error("GraphicsWidgets:Table:DefaultColumnWidthsSize", ...
                    "Size of DefaultColumnWidths must match the number of data columns, be scalar, or be empty");
            end
            this.DefaultWidths_ = val;
        end

        function val = get.PixelDataWidths(this)
            val = this.resolvedPixelWidths(true(1, this.nData()));
        end

        function val = get.RelativeDataWidths(this)
            val = this.resolvedRelativeWidths(true(1, this.nData()));
        end

        function val = get.DataWidthTypes(this)
            val = this.resolvedTypes(true(1, this.nData()));
        end

        function val = get.PixelWidths(this)
            val = this.resolvedPixelWidths(this.Visible);
        end

        function val = get.RelativeWidths(this)
            val = this.resolvedRelativeWidths(this.Visible);
        end

        function val = get.WidthTypes(this)
            val = this.resolvedTypes(this.Visible);
        end

        function val = get.Editable(this)
            val = this.DataEditable;
            val = val(this.Visible);
        end

        function set.Editable(this, val)
            if isscalar(val)
                val = repelem(val, 1, numel(this.VisibleNames));
            end
            if ~isempty(val) && numel(val) ~= numel(this.VisibleNames)
                error("GraphicsWidgets:Table:ColumnEditableSize", ...
                    "Size of column editable must match the visible table, be scalar (apply to all), or empty (restore to default)");
            end

            if isempty(val)
                this.DataEditable_ = val;
            else
                this.DataEditable_ = false(size(this.DataNames));
                this.DataEditable_(this.Visible) = val;
            end
            this.requestUpdate("DataColumnEditable", "Interaction");
        end

        function val = get.DataEditable(this)
            val = this.DataEditable_;
            if isempty(val)
                val = false(1, this.nData());
                this.DataEditable_ = val;
            end
        end

        function set.DataEditable(this, val)
            if isscalar(val)
                val = repelem(val, 1, this.nData());
            end
            if ~isempty(val) && numel(val) ~= this.nData()
                error("GraphicsWidgets:Table:DataColumnEditableSize", ...
                    "Size of data column editable must match the underlying data, be scalar (apply to all), or empty (restore to default)");
            end
            this.DataEditable_ = val;
            this.requestUpdate("DataColumnEditable", "Interaction");
        end

        function val = get.Sortable(this)
            val = this.DataSortable;
            val = val(this.Visible);
        end

        function set.Sortable(this, val)
            if isscalar(val)
                val = repelem(val, 1, numel(this.VisibleNames));
            end
            if ~isempty(val) && numel(val) ~= numel(this.VisibleNames)
                error("GraphicsWidgets:Table:ColumnSortableSize", ...
                    "Size of column sortable must match the visible table, be scalar (apply to all), or empty (restore to default)");
            end

            owner = this.owner();
            owner.addControllerUpdateSuppression("DataColumnSortable", Times=1);
            if isempty(val)
                this.DataSortable = val;
            else
                tmp = false(size(this.DataNames));
                tmp(this.Visible) = val;
                this.DataSortable = tmp;
            end

            this.requestUpdate("DataColumnSortable", "Interaction");
        end

        function val = get.DataSortable(this)
            val = this.DataSortable_;
            if isempty(val)
                val = false(1, this.nData());
                this.DataSortable_ = val;
            end
        end

        function set.DataSortable(this, val)
            if isscalar(val)
                val = repelem(val, 1, this.nData());
            end
            if ~isempty(val) && numel(val) ~= this.nData()
                error("GraphicsWidgets:Table:DataColumnSortableSize", ...
                    "Size of data column sortable must match the underlying data, be scalar (apply to all), or empty (restore to default)");
            end
            this.DataSortable_ = val;

            owner = this.owner();
            owner.addControllerUpdateSuppression("SortByColumn", Times=1);
            owner.Sort.By = [];

            this.requestUpdate("DataColumnSortable", "Interaction");
        end

        function val = get.Visible(this)
            val = this.Visible_;
            if isempty(val)
                val = true(1, this.nData());
            end
        end

        function set.Visible(this, val)
            if isscalar(val)
                val = repelem(val, this.nData());
            end
            if numel(val) ~= this.nData()
                error("GraphicsWidgets:Table:InvalidColumnVisibility", ...
                    "Column visibility must be specified for all columns.")
            end
            this.Visible_ = val;
            this.requestUpdate("ColumnVisible", "Display");
        end

        function val = get.Names(this)
            val = this.Names_;
            if isempty(val)
                val = this.DataNames;
                this.Names_ = val;
            end
        end

        function set.Names(this, val)
            if isempty(val)
                this.Names_ = string.empty(1,0);
                this.requestUpdate("ColumnNames", "Display");
                return
            end

            val = string(val);
            val(val == "") = [];
            if ~isempty(val) && numel(val) ~= this.nData()
                error("GraphicsWidgets:Table:InvalidColumnAliases", ...
                    "Number of column aliases must match number of columns");
            end

            this.Names_ = val;
            this.requestUpdate("ColumnNames", "Display");
        end

        function val = get.DataNames(this)
            owner = this.owner();
            val = string(owner.Data.Properties.VariableNames);
        end

        function val = get.VisibleNames(this)
            val = this.Names(this.Visible);
        end

        function set.VisibleNames(this, val)
            idx = ismember(this.Names, val);
            this.Visible = idx;
        end

        function val = get.VisibleDataNames(this)
            val = this.DataNames(this.Visible);
        end

        function set.VisibleDataNames(this, val)
            idx = ismember(this.DataNames, val);
            this.Visible = idx;
        end

        function val = get.HiddenNames(this)
            val = this.Names(~this.Visible);
        end

        function set.HiddenNames(this, val)
            idx = ismember(val, this.Names);
            if any(~idx)
                error("GraphicsWidgets:Table:NonexistentColumnName", "Columns not found: " + strjoin(val(~idx), ", "));
            end

            idx = ismember(this.Names, val);
            this.Visible = ~idx;
        end

        function val = get.HiddenDataNames(this)
            val = this.DataNames(~this.Visible);
        end

        function set.HiddenDataNames(this, val)
            idx = ismember(this.DataNames, val);
            this.Visible = ~idx;
        end

        function updateStoresFromBridgeWidths(this, pixelWidths)
            arguments
                this (1,1) gwidgets.internal.table.ColumnController
                pixelWidths (1,:) double
            end

            nData = this.nData();
            [stores, ~, countMatches] = gwidgets.internal.table.ColumnWidthController.updateFromBridge( ...
                pixelWidths, this.Visible, nData, this.widthStores());
            if ~countMatches
                this.owner().onColumnBridgeReattachNeeded();
                return
            end
            this.applyWidthStores(stores);
        end

        function changed = didBridgeWidthsChange(this, incomingPx)
            arguments
                this (1,1) gwidgets.internal.table.ColumnController
                incomingPx (1,:) double
            end

            changed = gwidgets.internal.table.ColumnWidthController.didBridgeWidthsChange( ...
                incomingPx, this.Visible, this.nData(), this.widthStores());
        end

        function result = dataToAliases(this, inputs)
            arguments
                this (1,1) gwidgets.internal.table.ColumnController
                inputs (1,:) string
            end

            result = gwidgets.internal.table.ColumnController.translateNames(inputs, this.DataNames, this.Names);
        end

        function result = aliasesToData(this, inputs)
            arguments
                this (1,1) gwidgets.internal.table.ColumnController
                inputs (1,:) string
            end

            result = gwidgets.internal.table.ColumnController.translateNames(inputs, this.Names, this.DataNames);
        end

        function names = namesAt(this, idx)
            arguments
                this (1,1) gwidgets.internal.table.ColumnController
                idx (1,:) double = []
            end

            names = this.Names;
            if ~isempty(idx)
                names = names(idx);
            end
        end

        function names = dataNamesAt(this, idx)
            arguments
                this (1,1) gwidgets.internal.table.ColumnController
                idx (1,:) double = []
            end

            names = this.DataNames;
            if ~isempty(idx)
                names = names(idx);
            end
        end

        function val = buildMixedWidthCell(this, mask)
            arguments
                this (1,1) gwidgets.internal.table.ColumnController
                mask (1,:) logical
            end

            val = gwidgets.internal.table.ColumnWidthController.buildMixedCell( ...
                mask, this.nData(), this.widthStores());
        end
    end

    methods (Static)
        function result = translateNames(inputs, srcNames, destNames)
            arguments
                inputs (1,:) string
                srcNames (1,:) string
                destNames (1,:) string
            end

            if numel(srcNames) ~= numel(destNames)
                error("GraphicsWidgets:Table:NameTranslation", ...
                    "For translation, mapping must exist for each value");
            end

            idx = ismember(inputs, srcNames);
            result = inputs;
            d = dictionary(srcNames, destNames);
            result(idx) = d(inputs(idx));
        end
    end

    methods (Access = private)
        function n = nData(this)
            n = numel(this.DataNames);
        end

        function requestUpdate(this, propertyName, startFrom)
            arguments
                this (1,1) gwidgets.internal.table.ColumnController
                propertyName (1,1) string
                startFrom (1,1) string
            end

            owner = this.owner();
            if owner.doControllerUpdate(propertyName)
                owner.requestControllerUpdate(StartFrom=startFrom);
            end
        end

        function stores = widthStores(this)
            stores = struct( ...
                "Types", this.DataWidthTypes_, ...
                "Pixel", this.PixelDataWidths_, ...
                "Relative", this.RelativeDataWidths_);
        end

        function applyWidthStores(this, stores)
            this.DataWidthTypes_ = stores.Types;
            this.PixelDataWidths_ = stores.Pixel;
            this.RelativeDataWidths_ = stores.Relative;
        end

        function setWidthStores(this, val, mask)
            stores = gwidgets.internal.table.ColumnWidthController.setStores( ...
                val, mask, this.nData(), this.widthStores());
            this.applyWidthStores(stores);
        end

        function resetToDefaultWidths(this)
            stores = gwidgets.internal.table.ColumnWidthController.defaultStores(this.nData());
            this.applyWidthStores(stores);
        end

        function val = resolvedPixelWidths(this, mask)
            val = gwidgets.internal.table.ColumnWidthController.resolvedPixel( ...
                mask, this.nData(), this.widthStores());
        end

        function val = resolvedRelativeWidths(this, mask)
            val = gwidgets.internal.table.ColumnWidthController.resolvedRelative( ...
                mask, this.nData(), this.widthStores());
        end

        function val = resolvedTypes(this, mask)
            val = gwidgets.internal.table.ColumnWidthController.resolvedTypes( ...
                mask, this.nData(), this.widthStores());
        end
    end
end


