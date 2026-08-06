classdef FilterController < gwidgets.internal.table.TableController
    % FilterController wraps the reusable filter UI component for tables.

    properties (Dependent)
        FilterValue (1,1) string
        CategoricalVariables
        FilterDropDown (1,:) matlab.ui.control.DropDown
    end

    properties (Access = private)
        Component (1,:) gwidgets.internal.FilterController {mustBeScalarOrEmpty}
        FilterValue_ (1,1) string = ""
        CategoricalVariables_ = []
        ComponentListeners (1,:) event.listener
    end

    events
        FilterChanged
        FilterHelpRequested
        FilterHelpClosed
    end

    methods
        function this = FilterController(owner, component)
            %FILTERCONTROLLER Adapt a reusable filter component to UITable events.
            arguments
                owner (1,:) gwidgets.UITable = gwidgets.UITable.empty(1,0)
                component (1,:) gwidgets.internal.FilterController = gwidgets.internal.FilterController.empty(1,0)
            end

            this@gwidgets.internal.table.TableController(owner);
            if ~isempty(component)
                this.attachComponent(component);
            end
        end

        function delete(this)
            delete(this.Component);
        end

        function setup(this, parent, helpParent)
            arguments
                this (1,1) gwidgets.internal.table.FilterController
                parent (1,1) matlab.ui.container.GridLayout
                helpParent (1,1) matlab.ui.container.GridLayout
            end

            component = gwidgets.internal.FilterController( ...
                Parent=parent, ...
                HelpParent=helpParent, ...
                FilterValue=this.FilterValue_, ...
                CategoricalVariables=this.CategoricalVariables_);
            this.attachComponent(component);
        end

        function attachComponent(this, component)
            arguments
                this (1,1) gwidgets.internal.table.FilterController
                component (1,1) gwidgets.internal.FilterController
            end

            this.Component = component;
            this.Component.FilterValue = this.FilterValue_;
            if ~isempty(this.CategoricalVariables_)
                this.Component.CategoricalVariables = this.CategoricalVariables_;
            end
            this.ComponentListeners = this.weaklistener(component, ...
                ["FilterChanged", "FilterHelpRequested", "FilterHelpClosed"]);
        end

        function setLayout(this, column, row)
            arguments
                this (1,1) gwidgets.internal.table.FilterController
                column (1,1) double
                row (1,1) double
            end

            this.Component.Layout.Column = column;
            this.Component.Layout.Row = row;
        end

        function expand(this, value)
            arguments
                this (1,1) gwidgets.internal.table.FilterController
                value (1,1) logical = true
            end

            this.Component.expand(value);
        end

        function [data, idx, status] = applyFilter(this, data, filter)
            arguments
                this (1,1) gwidgets.internal.table.FilterController
                data (:,:) table
                filter (1,1) string = this.FilterValue
            end

            [data, idx, status] = this.Component.applyFilter(data, filter);
        end

        function val = get.FilterValue(this)
            if isempty(this.Component)
                val = this.FilterValue_;
                return
            end

            val = this.Component.FilterValue;
        end

        function set.FilterValue(this, val)
            previousFilter = this.FilterValue;
            owner = this.owner();
            if ~isempty(owner)
                requestEvent = owner.emitTableEvent("FilterChangeRequested", ...
                    gwidgets.table.TableEventData( ...
                    Action="change", ...
                    Filter=val, ...
                    PreviousFilter=previousFilter, ...
                    Value=val, ...
                    PreviousValue=previousFilter));
                if requestEvent.Cancel
                    return
                end
                if requestEvent.HasReplacementValue
                    val = string(requestEvent.ReplacementValue);
                end
            end

            this.FilterValue_ = val;
            if ~isempty(this.Component)
                this.Component.FilterValue = val;
            end

            if ~isempty(owner) && owner.doControllerUpdate("Filter")
                owner.requestControllerUpdate(StartFrom="Filtering");
                this.emitFilterChanged(previousFilter);
            end
        end

        function val = get.CategoricalVariables(this)
            if isempty(this.Component)
                val = this.CategoricalVariables_;
                return
            end

            val = this.Component.CategoricalVariables;
        end

        function set.CategoricalVariables(this, val)
            this.CategoricalVariables_ = val;
            if ~isempty(this.Component)
                this.Component.CategoricalVariables = val;
            end
        end

        function val = get.FilterDropDown(this)
            if isempty(this.Component)
                val = matlab.ui.control.DropDown.empty(1,0);
                return
            end

            val = this.Component.FilterDropDown;
        end
    end

    methods (Access = {?gwidgets.internal.WithWeakListeners})
        function onFilterChanged(this, ~, ~)
            previousFilter = this.FilterValue_;
            this.FilterValue_ = this.FilterValue;
            notify(this, "FilterChanged");
            this.emitFilterChanged(previousFilter);
        end

        function onFilterHelpRequested(this, ~, ~)
            notify(this, "FilterHelpRequested");
        end

        function onFilterHelpClosed(this, ~, ~)
            notify(this, "FilterHelpClosed");
        end
    end

    methods (Access = private)
        function emitFilterChanged(this, previousFilter)
            owner = this.owner();
            if isempty(owner) || string(previousFilter) == this.FilterValue
                return
            end

            owner.emitTableEvent("FilterChanged", gwidgets.table.TableEventData( ...
                Action="changed", ...
                Filter=this.FilterValue, ...
                PreviousFilter=previousFilter, ...
                RowFilterIndices=reshape(owner.Data.RowFilterIndices, 1, [])));
        end
    end
end
