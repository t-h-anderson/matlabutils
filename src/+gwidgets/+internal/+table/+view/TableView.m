classdef (Abstract) TableView < handle
    % TableView is the internal rendering boundary for gwidgets.UITable.

    properties (SetAccess = private)
        Name (1,1) string = ""
        Kind (1,1) string = ""
    end

    properties (SetAccess = protected)
        Component
    end

    methods
        function setIdentity(this, name, kind)
            arguments
                this (1,1) gwidgets.internal.table.view.TableView
                name (1,1) string
                kind (1,1) string
            end

            this.Name = name;
            this.Kind = kind;
        end

        function applyState(this, state)
            arguments
                this (1,1) gwidgets.internal.table.view.TableView
                state (1,1) struct
            end

            propertyValues = gwidgets.internal.table.view.TableView.stateToPropertyValues(state);
            if isempty(propertyValues)
                return
            end

            this.setProperties(propertyValues);
        end
    end

    methods (Abstract)
        setup(this, owner, grid)
        setProperties(this, propertyValues)
        token = beginStateUpdate(this)
        cancelStateUpdate(this, token)
        endStateUpdate(this, token)
        refresh(this)
    end

    methods (Static)
        function propertyValues = stateToPropertyValues(state)
            arguments
                state (1,1) struct
            end

            propertyNames = [ ...
                "Data", ...
                "ColumnName", ...
                "ColumnEditable", ...
                "ColumnSortable", ...
                "SelectionType", ...
                "Multiselect", ...
                "Selection", ...
                "ColumnWidth", ...
                "GroupHeaderRows", ...
                "GroupHeaderLevels", ...
                "StyleConfigurations", ...
                "Tooltip", ...
                "ContextMenu"];

            propertyValues = cell(1, 2*numel(propertyNames));
            nValues = 0;
            for iProperty = 1:numel(propertyNames)
                propertyName = propertyNames(iProperty);
                if ~isfield(state, propertyName)
                    continue
                end

                nValues = nValues + 2;
                propertyValues(nValues-1:nValues) = {char(propertyName), state.(propertyName)};
            end

            propertyValues = propertyValues(1:nValues);
        end
    end
end
