classdef (Abstract) Reparentable < matlab.ui.componentcontainer.ComponentContainer ...
        & gwidgets.internal.WithWeakListeners

    properties (Access = private)
        FigureChangedListener
        FigureObserver
    end

    methods
        function this = Reparentable(varargin)
            this@matlab.ui.componentcontainer.ComponentContainer("Parent", [], ...
                 "Units", "normalized", ...
                 "Position", [0, 0, 1, 1]);

            this.FigureObserver = gwidgets.internal.FigureObserver( this );
            this.FigureChangedListener = this.weaklistener(this.FigureObserver, "FigureChanged");
        end
    end

    methods (Access = {?gwidgets.internal.WithWeakListeners})
        function onFigureChanged(this, ~, e)
            f = e.NewFigure;
            if isempty( f )
                this.reactToFigureRemoved();
            else
                this.reactToFigureChanged();
            end
        end
    end

    methods (Access = protected)
        function reactToFigureRemoved(this)
            % By default, do nothing. Overload to customise behaviour.
        end

        function reactToFigureChanged(this)
            % By default, do nothing. Overload to customise behaviour.
        end

    end
end