classdef Drawnow < handle

    properties
        IsEnabled (1,1) logical = true
        Total (1,1) double = 0
        Skipped (1,1) double = 0
        TicTocTime (1,1) double = 0
    end % properties

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
            this = gwidgets.internal.Drawnow.make();
            if this.IsEnabled
                tic
                drawnow(varargin{:});
                this.TicTocTime = this.TicTocTime + toc;
                this.Total = this.Total + 1;
            else
                this.Skipped = this.Skipped + 1;
            end
        end

        function runWithPause(varargin)
            this = gwidgets.internal.Drawnow.make();
            if this.IsEnabled
                tic
                pause(0);
                drawnow(varargin{:});
                this.TicTocTime = this.TicTocTime + toc;
                this.Total = this.Total + 1;
            else
                this.Skipped = this.Skipped + 1;
            end
        end

    end

    methods (Static)

        function obj = make(clearflag)
            arguments
                clearflag = false
            end

            persistent sObj
            if isempty(sObj) || clearflag
                sObj = gwidgets.internal.Drawnow();
            end % if
            obj = sObj;
        end % function makeObj

    end % methods (Static)

end % classdef

