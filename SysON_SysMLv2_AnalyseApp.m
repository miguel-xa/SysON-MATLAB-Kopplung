function SysON_SysMLv2_AnalyseApp
% SysON_SysMLv2_AnalyseApp
% Startet die SysON-SysML-v2-Modellanalyse-Applikation.
%
% Verwendung:
%   >> SysON_SysMLv2_AnalyseApp
%
% Voraussetzungen:
%   - SysON laeuft unter http://localhost:8080
%
    app = SysON_SysMLv2_Analyse();
    app.run();
end
