classdef Drawnow < handle

    properties
        IsEnabled (1,1) logical = false
        Total (1,1) double = 0
        Skipped (1,1) double = 0
        TicTocTime (1,1) double = 0
    end

    methods (Access = protected)
        function this = Drawnow()
        end
    end

    methods (Static)

        function toggleDrawnow(state)
            arguments
                state (1,:) logical {mustBeScalarOrEmpty} = logical.empty(1,0)
            end

            this = gwidgets.internal.Drawnow.make();

            if isempty(state)
                state = ~this.IsEnabled;
            end

            this.IsEnabled = state;
        end

        function run(varargin)
            gwidgets.internal.Drawnow.tickAndDraw(DrawnowArgs=varargin);
        end

        function runWithPause(varargin)
            gwidgets.internal.Drawnow.tickAndDraw(WithPause=true, DrawnowArgs=varargin);
        end

        function tf = isEnabled()
            this = gwidgets.internal.Drawnow.make();
            tf = this.IsEnabled;
        end

        function obj = make(clearflag)
            arguments
                clearflag = false
            end

            persistent sObj
            if isempty(sObj) || clearflag
                sObj = gwidgets.internal.Drawnow();
            end
            obj = sObj;
        end

    end

    methods (Static, Access = private)

        function tickAndDraw(nvp)
            arguments
                nvp.WithPause (1,1) logical = false
                nvp.DrawnowArgs (1,:) cell = cell.empty(1,0)
            end

            this = gwidgets.internal.Drawnow.make();
            if ~this.IsEnabled
                this.Skipped = this.Skipped + 1;
                return
            end
            tic
            if nvp.WithPause
                pause(0);
            end
            drawnow(nvp.DrawnowArgs{:});
            this.TicTocTime = this.TicTocTime + toc;
            this.Total = this.Total + 1;
        end

    end

end

