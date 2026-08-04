classdef GraphicsController < gwidgets.internal.table.TableController
    % GraphicsController owns table UI handle creation and layout state.

    properties (SetAccess = private)
        Grid (1,:) matlab.ui.container.GridLayout {mustBeScalarOrEmpty}
        GroupLabel (1,:) matlab.ui.control.Label {mustBeScalarOrEmpty}
        HelpPanel (1,:) matlab.ui.container.Panel {mustBeScalarOrEmpty}
        FilterComponent (1,:) gwidgets.internal.FilterController {mustBeScalarOrEmpty}
    end

    properties (Dependent, SetAccess = private)
        Backend
        DisplayTable
    end

    properties (Access = private)
        BackendName (1,1) string {mustBeMember(BackendName, ["UITable", "JavaScript"])} = "UITable"
        ViewRegistry (1,:) gwidgets.internal.table.view.TableViewRegistry {mustBeScalarOrEmpty}
        FilterHelpListener (1,:) event.listener
    end

    methods
        function this = GraphicsController(owner, nvp)
            arguments
                owner (1,:) gwidgets.UITable = gwidgets.UITable.empty(1,0)
                nvp.Backend (1,1) string {mustBeMember(nvp.Backend, ["UITable", "JavaScript"])} = "UITable"
            end

            this@gwidgets.internal.table.TableController(owner);
            this.ViewRegistry = gwidgets.internal.table.view.TableViewRegistry();
            this.BackendName = nvp.Backend;
        end

        function initialize(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            owner = this.owner();
            if isempty(owner)
                return
            end

            this.FilterHelpListener = this.weaklistener(owner.Filter, ...
                ["FilterHelpRequested", "FilterHelpClosed"]);
        end

        function configureBackend(this, backendName, owner)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                backendName (1,1) string {mustBeMember(backendName, ["UITable", "JavaScript"])}
                owner (1,:) gwidgets.UITable = gwidgets.UITable.empty(1,0)
            end

            this.BackendName = backendName;
            if isempty(owner)
                owner = this.owner();
            end
            if isempty(owner) || isempty(this.Grid)
                return
            end

            this.ensurePrimaryView(owner);
        end

        function setup(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                owner (1,1) gwidgets.UITable
            end

            if isempty(this.Grid) || ~isvalid(this.Grid)
                this.Grid = uigridlayout(owner, ...
                    RowHeight={"fit", 0, "1x", 2}, ColumnWidth={"1x", 0}, Padding=0);
            end

            this.HelpPanel = uipanel(Parent=this.Grid);
            this.HelpPanel.Layout.Column = 2;
            this.HelpPanel.Layout.Row = [1 3];

            helpParent = uigridlayout(this.HelpPanel, [1,1], Padding=0);
            % The reusable filter component owns its internal graphics; this
            % controller only places it inside the table layout.
            this.FilterComponent = gwidgets.internal.FilterController( ...
                Parent=this.Grid, ...
                HelpParent=helpParent);
            this.FilterComponent.Layout.Column = 1;
            this.FilterComponent.Layout.Row = 1;

            this.GroupLabel = uilabel(Parent=this.Grid);
            this.GroupLabel.Layout.Column = 1;
            this.GroupLabel.Layout.Row = 2;

            this.ensurePrimaryView(owner);
        end

        function val = get.Backend(this)
            val = this.primaryView();
        end

        function val = get.DisplayTable(this)
            backend = this.primaryView();
            if isempty(backend)
                val = [];
            else
                val = backend.Component;
            end
        end
    end

    methods (Hidden)
        function view = attachView(this, name, kind, parent)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                name (1,1) string
                kind (1,1) string
                parent = []
            end

            owner = this.owner();
            if isempty(owner)
                error("GraphicsWidgets:Table:ViewOwner", ...
                    "A table view cannot be attached before the graphics controller has an owner.");
            end

            if isempty(parent)
                parent = this.Grid;
            end
            if isempty(parent)
                error("GraphicsWidgets:Table:ViewParent", ...
                    "A table view cannot be attached before the table graphics are set up.");
            end

            kind = gwidgets.internal.table.GraphicsController.normalizeBackendName(kind);
            this.detachView(name);
            view = gwidgets.internal.table.GraphicsController.createBackend(kind);
            view.setIdentity(name, kind);
            this.ViewRegistry.attach(name, view, Primary=this.isPrimaryViewName(name));
            view.setup(owner, parent);
            this.syncView(view, owner);
            this.refreshMenusForAttachedView(owner);
        end

        function detachView(this, name)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                name (1,1) string
            end

            this.ViewRegistry.deleteView(name);
        end

        function names = views(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            names = this.ViewRegistry.names();
        end

        function view = view(this, name)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                name (1,1) string
            end

            view = this.ViewRegistry.view(name);
        end

        function view = primaryView(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            view = this.ViewRegistry.primaryView();
        end
    end

    methods
        function broadcastState(this, state)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                state (1,1) struct
            end

            this.ViewRegistry.apply(@(view, ~)view.applyState(state));
        end

        function setViewProperties(this, propertyValues)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                propertyValues (1,:) cell
            end

            if isempty(propertyValues)
                return
            end

            this.ViewRegistry.apply(@(view, ~)view.setProperties(propertyValues));
        end

        function token = beginStateUpdate(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            viewNames = this.ViewRegistry.names();
            viewList = this.ViewRegistry.views();
            tokens = cell(1, numel(viewList));
            for iView = 1:numel(viewList)
                tokens{iView} = viewList{iView}.beginStateUpdate();
            end

            token = struct("Names", viewNames, "Tokens", {tokens});
        end

        function cancelStateUpdate(this, token)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                token (1,1) struct
            end

            this.finishStateUpdate(token, "cancel");
        end

        function endStateUpdate(this, token)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                token (1,1) struct
            end

            this.finishStateUpdate(token, "end");
        end

        function refreshViews(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            this.ViewRegistry.apply(@(view, ~)view.refresh());
        end

        function setupBridge(this, bridgeController)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                bridgeController (1,1) gwidgets.internal.table.BridgeController
            end

            backend = this.primaryView();
            if isempty(backend)
                return
            end

            backend.setupBridge(bridgeController);
        end

        function contextMenu = buildContextMenus(this, contextMenu, customItems, options, callbacks)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                contextMenu
                customItems (1,:) matlab.ui.container.Menu
                options (1,1) struct
                callbacks (1,1) struct
            end

            primary = this.primaryView();
            contextMenu = this.buildContextMenuForView(primary, contextMenu, customItems, options, callbacks);
            viewList = this.ViewRegistry.views();
            for iView = 1:numel(viewList)
                view = viewList{iView};
                if isempty(view) || ~isvalid(view) || isequal(view, primary)
                    continue
                end

                this.buildContextMenuForView(view, view.ContextMenu, ...
                    matlab.ui.container.Menu.empty(1,0), options, callbacks);
            end
        end

        function addStyle(this, style, target, index)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                style (1,1) matlab.ui.style.Style
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])}
                index = []
            end

            this.ViewRegistry.apply(@(view, ~)view.addStyle(style, target, index));
        end

        function removeStyle(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            this.ViewRegistry.apply(@(view, ~)view.removeStyle());
        end

        function setRowFilterVisible(this, state)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                state (1,1) logical
            end

            if state
                this.Grid.RowHeight{1} = "fit";
            else
                this.Grid.RowHeight{1} = 0;
            end
        end

        function showFilterHelp(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            this.Grid.ColumnWidth = {"1x", "1x"};
        end

        function hideFilterHelp(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            this.Grid.ColumnWidth = {"1x", 0};
        end
    end

    methods (Access = private)
        function ensurePrimaryView(this, owner)
            backend = this.primaryView();
            if isempty(backend) || ~this.isCurrentBackend()
                this.detachView("primary");
                backend = gwidgets.internal.table.GraphicsController.createBackend(this.BackendName);
                backend.setIdentity("primary", this.BackendName);
                this.ViewRegistry.attach("primary", backend, Primary=true);
            end
            backend.setup(owner, this.Grid);
            this.syncView(backend, owner);
        end

        function tf = isCurrentBackend(this)
            backend = this.primaryView();
            if isempty(backend)
                tf = false;
                return
            end

            switch this.BackendName
                case "UITable"
                    tf = isa(backend, "gwidgets.internal.table.backend.UITableBackend");
                case "JavaScript"
                    tf = isa(backend, "gwidgets.internal.table.backend.JSTableBackend");
                otherwise
                    tf = false;
            end
        end

        function finishStateUpdate(this, token, mode)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                token (1,1) struct
                mode (1,1) string {mustBeMember(mode, ["cancel", "end"])}
            end

            if ~isfield(token, "Names") || ~isfield(token, "Tokens")
                return
            end

            names = reshape(string(token.Names), 1, []);
            tokens = token.Tokens;
            nViews = min(numel(names), numel(tokens));
            for iView = 1:nViews
                view = this.ViewRegistry.view(names(iView));
                if isempty(view) || ~isvalid(view)
                    continue
                end

                if mode == "cancel"
                    view.cancelStateUpdate(tokens{iView});
                else
                    view.endStateUpdate(tokens{iView});
                end
            end
        end

        function contextMenu = buildContextMenuForView(this, view, contextMenu, customItems, options, callbacks)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController %#ok<INUSA>
                view
                contextMenu
                customItems (1,:) matlab.ui.container.Menu
                options (1,1) struct
                callbacks (1,1) struct
            end

            if isempty(view) || ~isvalid(view)
                return
            end

            contextMenu = view.buildContextMenu(contextMenu, customItems, options, callbacks);
        end

        function syncView(this, view, owner)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController %#ok<INUSA>
                view (1,1) gwidgets.internal.table.view.TableView
                owner (1,1) gwidgets.UITable
            end

            if isempty(owner.Display) || isempty(owner.Selection) || isempty(owner.Style) || isempty(owner.Tooltip)
                return
            end

            view.applyState(owner.Display.renderState());
        end

        function tf = isPrimaryViewName(this, name)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                name (1,1) string
            end

            tf = name == "primary" || isempty(this.ViewRegistry.names());
        end

        function refreshMenusForAttachedView(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController %#ok<INUSA>
                owner (1,1) gwidgets.UITable
            end

            menu = owner.Menu;
            if isempty(menu) || ~isvalid(menu)
                return
            end

            menu.refresh();
        end
    end

    methods (Static, Access = private)
        function backend = createBackend(backendName)
            arguments
                backendName (1,1) string {mustBeMember(backendName, ["UITable", "JavaScript"])}
            end

            switch backendName
                case "JavaScript"
                    backend = gwidgets.internal.table.backend.JSTableBackend();
                otherwise
                    backend = gwidgets.internal.table.backend.UITableBackend();
            end
        end

        function backendName = normalizeBackendName(backendName)
            arguments
                backendName (1,1) string
            end

            switch lower(strtrim(backendName))
                case {"uitable", "matlab"}
                    backendName = "UITable";
                case {"javascript", "js"}
                    backendName = "JavaScript";
                otherwise
                    error("GraphicsWidgets:Table:Backend", ...
                        "Unsupported table backend: %s", backendName);
            end
        end
    end

    methods (Access = {?gwidgets.internal.WithWeakListeners})
        function onFilterHelpRequested(this, ~, ~)
            this.showFilterHelp();
        end

        function onFilterHelpClosed(this, ~, ~)
            this.hideFilterHelp();
        end
    end
end
