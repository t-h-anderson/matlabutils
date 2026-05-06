classdef Drawnow < handle

    properties
        IsEnabled (1,1) logical = true
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
            gwidgets.internal.Drawnow.tickAndDraw(false, varargin{:});
        end

        function runWithPause(varargin)
            gwidgets.internal.Drawnow.tickAndDraw(true, varargin{:});
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

        function tickAndDraw(withPause, varargin)
            this = gwidgets.internal.Drawnow.make();
            if ~this.IsEnabled
                this.Skipped = this.Skipped + 1;
                return
            end
            tic
            if withPause
                pause(0);
            end
            drawnow(varargin{:});
            this.TicTocTime = this.TicTocTime + toc;
            this.Total = this.Total + 1;
        end

    end

end

