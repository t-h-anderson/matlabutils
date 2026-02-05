classdef ( Hidden, Sealed ) FigureData < event.EventData
    % FigureData  Event data for FigureChanged on FigureObserver
    
    %  Copyright 2009-2020 The MathWorks, Inc.
    
    properties( SetAccess = private )
        OldFigure % old figure
        NewFigure % new figure
    end
    
    methods( Access = ?gwidgets.internal.FigureObserver )
        
        function obj = FigureData( oldFigure, newFigure )
            % FigureData  Create event data
            %
            %  d = FigureData(oldFigure,newFigure)
            
            obj.OldFigure = oldFigure;
            obj.NewFigure = newFigure;
            
        end % constructor
        
    end % methods
    
end % classdef