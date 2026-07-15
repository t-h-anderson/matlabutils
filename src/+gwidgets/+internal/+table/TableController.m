classdef TableController < gwidgets.internal.WithWeakListeners
    % TableController stores a weak reference to a gwidgets.UITable owner.

    properties (Access = protected)
        OwnerRef (1,:) matlab.lang.WeakReference {mustBeScalarOrEmpty}
    end

    methods
        function this = TableController(owner)
            arguments
                owner (1,:) gwidgets.UITable = gwidgets.UITable.empty(1,0)
            end

            if ~isempty(owner)
                this.OwnerRef = matlab.lang.WeakReference(owner);
            end
        end
    end

    methods (Access = protected)
        function owner = owner(this)
            arguments
                this (1,1) gwidgets.internal.table.TableController
            end

            owner = gwidgets.UITable.empty(1,0);
            if isempty(this.OwnerRef)
                return
            end

            owner = this.OwnerRef.Handle;
            if isempty(owner) || ~isvalid(owner)
                owner = gwidgets.UITable.empty(1,0);
            end
        end
    end
end

