classdef UITableBackend < gwidgets.internal.table.backend.TableBackend
    % UITableBackend adapts matlab.ui.control.Table to the table backend API.

    properties (Access = private)
        Grid (1,:) matlab.ui.container.GridLayout {mustBeScalarOrEmpty}
        GroupHeaderRows_ (1,:) double = zeros(1,0)
        GroupHeaderLevels_ (1,:) double = zeros(1,0)
    end

    methods
        function setup(this, owner, grid)
            arguments
                this (1,1) gwidgets.internal.table.backend.UITableBackend
                owner (1,1) gwidgets.UITable
                grid (1,1) matlab.ui.container.GridLayout
            end

            if this.isReady()
                return
            end

            this.Grid = grid;
            this.Component = uitable(grid);
            this.Component.UserData = struct("ViewId", char(this.Name), "ViewKind", char(this.Kind));
            this.Component.ClickedFcn = @(s, e)owner.Callback.onCellClicked(s, e);
            this.Component.DoubleClickedFcn = @(s, e)owner.Callback.onCellDoubleClicked(s, e);
            this.Component.CellSelectionCallback = @(s, e)owner.Callback.onSelection(s, e);
            this.Component.CellEditCallback = @(s, e)owner.Callback.onCellEdit(s, e);
            this.Component.DisplayDataChangedFcn = @(s, e)owner.Callback.onDisplayDataChanged(s, e);
        end

        function setupBridge(this, bridgeController)
            arguments
                this (1,1) gwidgets.internal.table.backend.UITableBackend
                bridgeController (1,1) gwidgets.internal.table.BridgeController
            end

            if isempty(this.Grid) || ~this.isReady()
                return
            end

            bridgeController.setup(this.Grid, this.Component);
        end

        function contextMenu = buildContextMenu(this, contextMenu, customItems, options, callbacks)
            arguments
                this (1,1) gwidgets.internal.table.backend.UITableBackend
                contextMenu
                customItems (1,:) matlab.ui.container.Menu
                options (1,1) struct
                callbacks (1,1) struct
            end

            contextMenu = gwidgets.internal.table.ContextMenuController.build( ...
                this.Component, contextMenu, customItems, options, callbacks);
        end

        function addStyle(this, style, target, index)
            arguments
                this (1,1) gwidgets.internal.table.backend.UITableBackend
                style (1,1) matlab.ui.style.Style
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])}
                index = []
            end

            this.Component.addStyle(style, target, index);
        end

        function removeStyle(this)
            arguments
                this (1,1) gwidgets.internal.table.backend.UITableBackend
            end

            this.Component.removeStyle();
        end
    end

    methods (Access = protected)
        function value = getBackendProperty(this, propertyName)
            arguments
                this (1,1) gwidgets.internal.table.backend.UITableBackend
                propertyName (1,1) string
            end

            switch propertyName
                case "GroupHeaderRows"
                    value = this.GroupHeaderRows_;
                case "GroupHeaderLevels"
                    value = this.GroupHeaderLevels_;
                otherwise
                    value = this.Component.(propertyName);
            end
        end

        function setBackendProperty(this, propertyName, value)
            arguments
                this (1,1) gwidgets.internal.table.backend.UITableBackend
                propertyName (1,1) string
                value
            end

            switch propertyName
                case "GroupHeaderRows"
                    this.GroupHeaderRows_ = reshape(double(value), 1, []);
                case "GroupHeaderLevels"
                    this.GroupHeaderLevels_ = reshape(double(value), 1, []);
                case "StyleConfigurations"
                    this.applyStyleConfigurations(value);
                case "Tooltip"
                    this.Component.Tooltip = "";
                otherwise
                    this.Component.(propertyName) = value;
            end
        end
    end

    methods (Access = private)
        function applyStyleConfigurations(this, configs)
            arguments
                this (1,1) gwidgets.internal.table.backend.UITableBackend
                configs (:,3) table
            end

            this.Component.removeStyle();
            if isempty(configs)
                return
            end

            for iStyle = 1:height(configs)
                this.Component.addStyle( ...
                    configs.Style(iStyle), ...
                    string(configs.Target(iStyle)), ...
                    configs.TargetIndex{iStyle});
            end
        end
    end
end
