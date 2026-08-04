classdef (Abstract) TableBackend < gwidgets.internal.table.view.TableView
    % TableBackend defines the rendering boundary for gwidgets.UITable.

    properties (Dependent)
        Data
        DisplayData
        ColumnName
        ColumnEditable
        ColumnSortable
        SelectionType
        Multiselect
        Selection
        ColumnWidth
        GroupHeaderRows
        GroupHeaderLevels
        StyleConfigurations
        Tooltip
        ContextMenu
    end

    methods
        function delete(this)
            if ~isempty(this.Component) && all(isvalid(this.Component))
                delete(this.Component);
            end
        end

        function tf = isReady(this)
            tf = ~isempty(this.Component) && all(isvalid(this.Component));
        end

        function value = get.Data(this)
            value = this.getBackendProperty("Data");
        end

        function set.Data(this, value)
            this.setBackendProperty("Data", value);
        end

        function value = get.DisplayData(this)
            value = this.getBackendProperty("DisplayData");
        end

        function value = get.ColumnName(this)
            value = this.getBackendProperty("ColumnName");
        end

        function set.ColumnName(this, value)
            this.setBackendProperty("ColumnName", value);
        end

        function value = get.ColumnEditable(this)
            value = this.getBackendProperty("ColumnEditable");
        end

        function set.ColumnEditable(this, value)
            this.setBackendProperty("ColumnEditable", value);
        end

        function value = get.ColumnSortable(this)
            value = this.getBackendProperty("ColumnSortable");
        end

        function set.ColumnSortable(this, value)
            this.setBackendProperty("ColumnSortable", value);
        end

        function value = get.SelectionType(this)
            value = this.getBackendProperty("SelectionType");
        end

        function set.SelectionType(this, value)
            this.setBackendProperty("SelectionType", value);
        end

        function value = get.Multiselect(this)
            value = this.getBackendProperty("Multiselect");
        end

        function set.Multiselect(this, value)
            this.setBackendProperty("Multiselect", value);
        end

        function value = get.Selection(this)
            value = this.getBackendProperty("Selection");
        end

        function set.Selection(this, value)
            this.setBackendProperty("Selection", value);
        end

        function value = get.ColumnWidth(this)
            value = this.getBackendProperty("ColumnWidth");
        end

        function set.ColumnWidth(this, value)
            this.setBackendProperty("ColumnWidth", value);
        end

        function value = get.GroupHeaderRows(this)
            value = this.getBackendProperty("GroupHeaderRows");
        end

        function set.GroupHeaderRows(this, value)
            this.setBackendProperty("GroupHeaderRows", value);
        end

        function value = get.GroupHeaderLevels(this)
            value = this.getBackendProperty("GroupHeaderLevels");
        end

        function set.GroupHeaderLevels(this, value)
            this.setBackendProperty("GroupHeaderLevels", value);
        end

        function value = get.StyleConfigurations(this)
            value = this.getBackendProperty("StyleConfigurations");
        end

        function set.StyleConfigurations(this, value)
            this.setBackendProperty("StyleConfigurations", value);
        end

        function value = get.Tooltip(this)
            value = this.getBackendProperty("Tooltip");
        end

        function set.Tooltip(this, value)
            this.setBackendProperty("Tooltip", value);
        end

        function value = get.ContextMenu(this)
            value = this.getBackendProperty("ContextMenu");
        end

        function set.ContextMenu(this, value)
            this.setBackendProperty("ContextMenu", value);
        end

        function setProperties(this, propertyValues)
            arguments
                this (1,1) gwidgets.internal.table.backend.TableBackend
                propertyValues (1,:) cell
            end

            for iProperty = 1:2:numel(propertyValues)
                this.setBackendProperty(string(propertyValues{iProperty}), propertyValues{iProperty+1});
            end
        end

        function token = beginStateUpdate(this)
            arguments
                this (1,1) gwidgets.internal.table.backend.TableBackend
            end

            unusedInput = this; %#ok<NASGU>
            token = [];
        end

        function cancelStateUpdate(this, token)
            arguments
                this (1,1) gwidgets.internal.table.backend.TableBackend
                token = []
            end

            unusedInputs = {this, token}; %#ok<NASGU>
        end

        function endStateUpdate(this, token)
            arguments
                this (1,1) gwidgets.internal.table.backend.TableBackend
                token = []
            end

            unusedInput = token; %#ok<NASGU>
            this.refresh();
        end

        function refresh(this)
            arguments
                this (1,1) gwidgets.internal.table.backend.TableBackend
            end

            if ~isvalid(this)
                return
            end
        end

    end

    methods (Abstract)
        setup(this, owner, grid)
        setupBridge(this, bridgeController)
        contextMenu = buildContextMenu(this, contextMenu, customItems, options, callbacks)
        addStyle(this, style, target, index)
        removeStyle(this)
    end

    methods (Abstract, Access = protected)
        value = getBackendProperty(this, propertyName)
        setBackendProperty(this, propertyName, value)
    end

    methods (Static)
        function configs = emptyStyleConfigurations()
            configs = table( ...
                categorical.empty(0,1), ...
                cell(0,1), ...
                matlab.ui.style.Style.empty(0,1), ...
                VariableNames=["Target", "TargetIndex", "Style"]);
        end
    end
end
