classdef SysON_SysMLv2_Analyse < handle
% =========================================================================
% SysON_SysMLv2_Analyse – MATLAB-Applikation zur modellbasierten Anforderungsanalyse
%
% Methodischer Ansatz zur Kopplung heterogener Modelle zur Risikoanalyse
% im Kontext innovativer Luftmobilität im urbanen Raum
%
% Institution : HAW Hamburg – Fakultät Technik und Informatik
% Betreuer/-in: Prof. Dr.-Ing. Jutta Abulawi, M.Sc. Timur Topal
% Projekt     : Holistic UAM (BWFGB)
%
% Beschreibung:
%   Die Applikation stellt eine API-basierte Kopplung zwischen SysML-v2-
%   Modellierungswerkzeugen (SysON) und MATLAB her. Über die standardisierte
%   OMG SysML v2 REST-API werden Modellelemente abgerufen und für eine
%   automatisierte Anforderungsanalyse aufbereitet.
%
% Funktionen:
%   - Abruf von Projekten, Commits und Modellelementen via REST-API
%   - Extraktion von PartUsage-Instanzen und deren Attributwerten
%   - Dynamische Darstellung von Anforderungen (RequirementUsage)
%     inkl. Anforderungsattributen, Assume- und Require-Constraints
%   - Automatisierte Prüfung der Constraints gegen Modellwerte
%   - Farbkodierte Ergebnisvisualisierung pro Anforderung
%
% Verwendung:
%   >> SysON_SysMLv2_AnalyseApp
%
% =========================================================================

    properties
        % Verbindungsparameter
        host     (1,1) string = "http://localhost:8080/api/rest"
        opts                   % weboptions ContentType='json'
        optsText               % weboptions ContentType='text' fuer jsondecode
        baseUrl  (1,1) string = ""

        % API-Daten
        Projects
        ProjectId  (1,1) string = ""
        Commits
        CommitId   (1,1) string = ""
        Elements
        ElementMap             % containers.Map: elementId -> Index
        tmpIds                 % Hilfsvariable fuer rekursive ID-Sammlung

        % Modelldaten (Tabellen)
        Telements  table       % Alle Modellelemente (flach)
        Tparts     table       % PartUsage-Instanzen
        Tattrs     table       % Attribute der PartUsage-Instanzen
        Treqs      table       % Anforderungen (RequirementUsage)

        % UI-Elemente
        Fig         matlab.ui.Figure
        HostField   matlab.ui.control.EditField
        BtnProjects matlab.ui.control.Button
        ProjectsDD  matlab.ui.control.DropDown
        BtnCommits  matlab.ui.control.Button
        CommitsDD   matlab.ui.control.DropDown
        BtnFetch    matlab.ui.control.Button
        Status      matlab.ui.control.TextArea
        PartsTable  matlab.ui.control.Table
        AttrTable   matlab.ui.control.Table
        ReqTable    matlab.ui.control.Table
        BtnRun      matlab.ui.control.Button
        Out         matlab.ui.control.TextArea
    end

    methods

        % -----------------------------------------------------------------
        % Initialisierung
        % -----------------------------------------------------------------
        function run(self)
            self.opts     = weboptions('ContentType','json','Timeout',30);
            self.optsText = weboptions('ContentType','text','Timeout',30);
            self.ElementMap = containers.Map();
            self.tmpIds   = {};
            self.buildUI();
        end

        % -----------------------------------------------------------------
        % Benutzeroberfläche aufbauen
        % -----------------------------------------------------------------
        function buildUI(self)
            self.Fig = uifigure('Name','SysON | SysML v2 – Modellanalyse', ...
                'Position',[40 40 1550 800]);

            % -- Verbindungsleiste --
            uilabel(self.Fig,'Text','Server-Adresse', ...
                'Position',[20 765 110 22],'FontWeight','bold');
            self.HostField = uieditfield(self.Fig,'text', ...
                'Position',[140 765 700 22],'Value',char(self.host));

            self.BtnProjects = uibutton(self.Fig,'Text','Projekte laden', ...
                'Position',[20 725 150 28], ...
                'ButtonPushedFcn',@(~,~) self.onGetProjects());
            self.ProjectsDD = uidropdown(self.Fig, ...
                'Position',[180 730 660 22],'Items',{}, ...
                'ValueChangedFcn',@(~,~) self.onPickProject());

            self.BtnCommits = uibutton(self.Fig,'Text','Commits laden', ...
                'Position',[20 683 150 28], ...
                'ButtonPushedFcn',@(~,~) self.onGetCommits());
            self.CommitsDD = uidropdown(self.Fig, ...
                'Position',[180 688 660 22],'Items',{}, ...
                'ValueChangedFcn',@(~,~) self.onPickCommit());

            self.BtnFetch = uibutton(self.Fig,'Text','Modelldaten abrufen', ...
                'Position',[20 640 150 28], ...
                'ButtonPushedFcn',@(~,~) self.onFetchModelData());

            % -- Linkes Panel --
            uilabel(self.Fig,'Text','Status / Log', ...
                'Position',[20 615 200 18],'FontWeight','bold');
            self.Status = uitextarea(self.Fig, ...
                'Position',[20 450 840 160],'Editable','off');

            uilabel(self.Fig,'Text','Systemarchitektur – PartUsage-Instanzen', ...
                'Position',[20 425 400 20],'FontWeight','bold');
            self.PartsTable = uitable(self.Fig,'Position',[20 20 840 400]);

            % -- Rechtes Panel --
            uilabel(self.Fig,'Text','Anforderungen', ...
                'Position',[870 775 640 20],'FontWeight','bold');
            self.ReqTable = uitable(self.Fig,'Position',[870 585 640 185]);

            uilabel(self.Fig,'Text','Attribute der PartUsage-Instanzen', ...
                'Position',[870 558 640 22],'FontWeight','bold');
            self.AttrTable = uitable(self.Fig,'Position',[870 355 640 198]);

            uilabel(self.Fig,'Text','Anforderungsanalyse', ...
                'Position',[870 328 640 22],'FontWeight','bold');
            self.BtnRun = uibutton(self.Fig,'Text','Analyse ausfuehren', ...
                'Position',[870 290 640 30], ...
                'ButtonPushedFcn',@(~,~) self.onRunAnalysis());

            uilabel(self.Fig,'Text','Ergebnisse', ...
                'Position',[870 263 640 22],'FontWeight','bold');
            self.Out = uitextarea(self.Fig, ...
                'Position',[870 20 640 238],'Editable','off');
        end

        % =================================================================
        % API-Kommunikation
        % =================================================================

        function onGetProjects(self)
            self.host = string(self.HostField.Value);
            try
                self.Projects = webread(self.host+"/projects", self.opts);
            catch ME
                self.log("Verbindungsfehler: "+ME.message); return;
            end
            items = self.formatProjectItems(self.Projects);
            self.ProjectsDD.Items = items;
            if ~isempty(items)
                self.ProjectsDD.Value = items{1};
                self.onPickProject();
            end
            self.log(sprintf("Projekte geladen: %d", numel(items)));
        end

        function onPickProject(self)
            v  = string(self.ProjectsDD.Value);
            id = extractBetween(v,"(",")")  ;
            if ~isempty(id), self.ProjectId = string(id(1)); end
            self.log("ProjectId = "+self.ProjectId);
        end

        function onGetCommits(self)
            self.host = string(self.HostField.Value);
            if strlength(self.ProjectId)==0, return; end
            try
                self.Commits = webread( ...
                    self.host+"/projects/"+self.ProjectId+"/commits", self.opts);
            catch ME
                self.log("Fehler: "+ME.message); return;
            end
            ids = self.extractCommitIds(self.Commits);
            self.CommitsDD.Items = cellstr(ids);
            if ~isempty(ids)
                self.CommitsDD.Value = char(ids(end));
                self.onPickCommit();
            end
            self.log(sprintf("Commits geladen: %d", numel(ids)));
        end

        function onPickCommit(self)
            self.CommitId = string(self.CommitsDD.Value);
            self.log("CommitId = "+self.CommitId);
        end

        % =================================================================
        % Modelldaten abrufen und verarbeiten
        % =================================================================
        function onFetchModelData(self)
            self.host = string(self.HostField.Value);
            if strlength(self.ProjectId)==0 || strlength(self.CommitId)==0
                self.log("Bitte zuerst Projekt und Commit waehlen."); return;
            end

            self.baseUrl = self.host+"/projects/"+self.ProjectId+ ...
                           "/commits/"+self.CommitId+"/elements";
            self.log("Abruf: "+self.baseUrl);
            try
            dlg = uiprogressdlg(self.Fig,'Title','Modelldaten werden geladen ...', ...
                'Indeterminate','on');
            cleanup = onCleanup(@() close(dlg));

            % Schritt 1: Alle Elemente laden
            try
                raw = webread(self.baseUrl, self.opts);
            catch ME
                self.log("Abruffehler: "+ME.message); return;
            end
            self.Elements = raw;
            n = numel(self.Elements);
            self.log(sprintf("Empfangen: %d Elemente", n));

            % Schritt 2: Elementindex aufbauen (O(1)-Lookup)
            self.ElementMap = containers.Map();
            for i = 1:n
                eid = self.readId(self.Elements{i});
                if strlength(eid) > 0
                    self.ElementMap(char(eid)) = i;
                end
            end

            % Schritt 3: Basistabelle erstellen
            names     = strings(n,1);
            ids_col   = strings(n,1);
            types     = strings(n,1);
            declShort = strings(n,1);
            docs      = strings(n,1);
            vals      = strings(n,1);
            ownerIds  = strings(n,1);
            unitHints = strings(n,1);

            for i = 1:n
                e            = self.Elements{i};
                names(i)     = self.readName(e);
                ids_col(i)   = self.readId(e);
                types(i)     = self.readType(e);
                declShort(i) = self.readField(e,"declaredShortName");
                ownerIds(i)  = self.readOwnerPartId(e);
                docs(i)      = self.readDocShort(e);
                unitHints(i) = self.unitFromElement(e);
            end

            self.Telements = table(names,ids_col,types,declShort, ...
                docs,vals,ownerIds,unitHints, ...
                'VariableNames', ...
                ["Name","Id","Type","DeclShortName","Doc","Value","OwnerId","UnitHint"]);

            % Schritt 4: Attributwerte extrahieren (V13-Methode via optsText)
            dlg.Indeterminate = 'off';
            isAttr = contains(self.Telements.Type,"Attribute","IgnoreCase",true);
            for i = 1:n
                if ~isAttr(i), continue; end
                v = self.extractAttrValue(self.Elements{i});
                if ~isnan(v)
                    self.Telements.Value(i) = string(v);
                end
                dlg.Value   = i/n;
                dlg.Message = sprintf("Verarbeite Element %d von %d ...", i, n);
                drawnow;
            end

            % Schritt 5: Tabellen befüllen
            isPart = self.Telements.Type == "PartUsage";
            self.Tparts = self.Telements(isPart, ["Name","Id","Type"]);
            self.PartsTable.Data = self.Tparts;

            self.buildAttrTable();
            self.buildReqTable();

            self.log(sprintf( ...
                "Abgeschlossen: %d Elemente | %d Parts | %d Attribute | %d Anforderungen", ...
                n, height(self.Tparts), height(self.Tattrs), height(self.Treqs)));
            catch ME
                self.log("Fehler beim Laden: "+ME.message);
            end
        end

        % =================================================================
        % Attributwerte extrahieren
        %
        % SysML v2 kodiert Zahlenwerte als OperatorExpression:
        %   AttributeUsage → ownedElement → OperatorExpression {operator:"["}
        %     → argument[0]: LiteralReal {value: 1.2}   <- Zahlenwert
        %     → argument[1]: Referenz auf SI-Einheit
        %
        % ContentType='text' + jsondecode: "@id" bleibt als UUID erkennbar
        % =================================================================
        function num = extractAttrValue(self, e)
            num = NaN;
            attrId = self.readId(e);
            if strlength(attrId) == 0, return; end
            try
                rawJson = webread(self.baseUrl+"/"+attrId, self.optsText);
                eFull   = jsondecode(rawJson);
            catch
                return;
            end
            num = self.resolveAttrValue(eFull);
        end

        function num = resolveAttrValue(self, attrElem)
            % Stufe 1: ownedElement-ID lesen (→ OperatorExpression)
            num = NaN;
            opExprId = self.refIdFromField(attrElem,'ownedElement');
            if strlength(opExprId)==0
                opExprId = self.refIdFromField(attrElem,'ownedMember');
            end
            if strlength(opExprId)==0, return; end

            % Stufe 2: OperatorExpression laden
            try
                rawOp = webread(self.baseUrl+"/"+opExprId, self.optsText);
                eOp   = jsondecode(rawOp);
            catch
                return;
            end

            v = self.readNumDirect(eOp);
            if ~isnan(v), num = v; return; end

            % Stufe 3: argument[0] = LiteralReal
            litId = self.firstArgId(eOp);
            if strlength(litId)==0
                litId = self.refIdFromField(eOp,'ownedElement');
            end
            if strlength(litId)==0, return; end

            try
                rawLit = webread(self.baseUrl+"/"+litId, self.optsText);
                eLit   = jsondecode(rawLit);
            catch
                return;
            end
            v = self.readNumDirect(eLit);
            if ~isnan(v), num = v; return; end

            % Stufe 4: Fallback – ownedElement von LiteralReal
            deepId = self.refIdFromField(eLit,'ownedElement');
            if strlength(deepId) > 0
                try
                    rawD = webread(self.baseUrl+"/"+deepId, self.optsText);
                    eD   = jsondecode(rawD);
                    num  = self.readNumDirect(eD);
                catch
                end
            end
        end

        function refId = refIdFromField(~, e, fieldName)
            refId = "";
            if ~isfield(e,fieldName), return; end
            v = e.(fieldName);
            if isempty(v), return; end
            if iscell(v) && ~isempty(v), v = v{1}; end
            if ~isstruct(v), return; end
            for fn = fieldnames(v)'
                sv = v.(fn{1});
                if (ischar(sv)||isstring(sv)) && strlength(string(sv))>10 ...
                        && contains(string(sv),'-')
                    refId = string(sv); return;
                end
            end
        end

        function argId = firstArgId(~, e)
            argId = "";
            if ~isfield(e,'argument'), return; end
            v = e.argument;
            if isempty(v), return; end
            if iscell(v) && ~isempty(v), v = v{1}; end
            if ~isstruct(v), return; end
            for fn = fieldnames(v)'
                sv = v.(fn{1});
                if (ischar(sv)||isstring(sv)) && strlength(string(sv))>10 ...
                        && contains(string(sv),'-')
                    argId = string(sv); return;
                end
            end
        end

        function num = readNumDirect(~, e)
            num = NaN;
            if ~isstruct(e), return; end
            for fn = {'value','real','integer','rational','numericValue','body','literal'}
                if isfield(e,fn{1}) && ~isempty(e.(fn{1}))
                    v = e.(fn{1});
                    if isnumeric(v)&&isscalar(v)&&~isnan(v)&&v>=0&&v<=1e6
                        num = v; return;
                    end
                    if ischar(v)||isstring(v)
                        n2 = str2double(strtrim(string(v)));
                        if ~isnan(n2)&&n2>=0&&n2<=1e6, num=n2; return; end
                    end
                end
            end
            skip = {'elementId','x_id','owner','owningMembership', ...
                    'owningNamespace','owningRelationship','owningType'};
            for fn = fieldnames(e)'
                if ismember(fn{1},skip), continue; end
                v = e.(fn{1});
                if isnumeric(v)&&isscalar(v)&&~isnan(v)&&v>=0&&v<=1e6
                    num = v; return;
                end
            end
        end

        % =================================================================
        % Attributtabelle aufbauen (nur PartUsage-Instanz-Attribute)
        % =================================================================
        function buildAttrTable(self)
            try
            isAttr = contains(self.Telements.Type,"Attribute","IgnoreCase",true);
            isPart = self.Telements.Type == "PartUsage";
            TAttr  = self.Telements(isAttr,:);
            TPart  = self.Telements(isPart,:);

            % Nur Attribute die direkt einem PartUsage gehören
            ownerIsPart = ismember(TAttr.OwnerId, TPart.Id);
            TAttr = TAttr(ownerIsPart,:);

            if height(TAttr) == 0
                self.Tattrs = table();
                self.AttrTable.Data = table();
                self.log("Keine Attribute zu PartUsage-Instanzen gefunden.");
                return;
            end

            nA        = height(TAttr);
            attrNames = strings(nA,1);
            partNames = strings(nA,1);
            attrVals  = strings(nA,1);
            attrUnits = strings(nA,1);

            for k = 1:nA
                attrNames(k) = TAttr.Name(k);

                % Wert formatieren
                raw   = strtrim(TAttr.Value(k));
                numV  = str2double(raw);
                if ~isnan(numV)
                    attrVals(k) = sprintf("%.4g", numV);
                elseif strlength(raw) > 0
                    attrVals(k) = raw;
                else
                    attrVals(k) = "–";
                end

                % Einheit (ISQ-Typ bevorzugt, Namensheuristik als Fallback)
                uh = strtrim(TAttr.UnitHint(k));
                if strlength(uh) > 0
                    attrUnits(k) = uh;
                else
                    attrUnits(k) = self.inferUnit(string(TAttr.Name(k)));
                end

                % Eltern-PartUsage-Name
                ownId = TAttr.OwnerId(k);
                pidx  = find(TPart.Id == ownId, 1);
                if ~isempty(pidx)
                    partNames(k) = TPart.Name(pidx);
                else
                    idx2 = find(self.Telements.Id == ownId, 1);
                    if ~isempty(idx2)
                        partNames(k) = self.Telements.Name(idx2);
                    end
                end
            end

            self.Tattrs = table(attrNames, partNames, attrVals, attrUnits, ...
                'VariableNames', ["Attributname","Part-Instanz","Wert","Einheit"]);
            self.AttrTable.Data = self.Tattrs;
            self.log(sprintf("Attribute geladen: %d", height(self.Tattrs)));
            catch ME
                self.log("Fehler in buildAttrTable: "+ME.message);
            end
        end

        % =================================================================
        % Anforderungstabelle aufbauen
        % =================================================================
        function buildReqTable(self)
            isReq = contains(self.Telements.Type,"Requirement","IgnoreCase",true);
            TReq  = self.Telements(isReq,:);

            % Nur Anforderungen mit DeclShortName (z.B. REQ1, REQ2)
            hasId = strlength(strtrim(TReq.DeclShortName)) > 0;
            TReq  = TReq(hasId,:);

            if height(TReq) == 0
                self.Treqs = table();
                self.ReqTable.Data = table();
                self.log("Keine Anforderungen mit ID gefunden.");
                return;
            end

            isConst   = contains(self.Telements.Type,"Constraint","IgnoreCase",true);
            TConst    = self.Telements(isConst,:);
            isAttrAll = contains(self.Telements.Type,"Attribute","IgnoreCase",true);

            nR         = height(TReq);
            reqId      = strings(nR,1);
            reqName    = strings(nR,1);
            reqDoc     = strings(nR,1);
            reqAttr    = strings(nR,1);
            reqAssume  = strings(nR,1);
            reqRequire = strings(nR,1);

            for k = 1:nR
                reqId(k)   = strtrim(TReq.DeclShortName(k));
                reqName(k) = TReq.Name(k);

                % Beschreibung per HTTP vollständig laden
                ownId  = TReq.Id(k);
                docTxt = "–";
                try
                    rawReq = webread(self.baseUrl+"/"+ownId, self.optsText);
                    eReq   = jsondecode(rawReq);
                    docTxt = self.extractDoc(eReq);
                catch
                end
                reqDoc(k) = docTxt;

                % Anforderungsattribute (nur mit konkretem Zahlenwert)
                myAttrs   = self.Telements(isAttrAll & self.Telements.OwnerId==ownId,:);
                attrParts = strings(0,1);
                for j = 1:height(myAttrs)
                    val  = strtrim(string(myAttrs.Value(j)));
                    numV = str2double(val);
                    % Wert per HTTP nachladen falls nicht gecacht
                    if isnan(numV)
                        eRef = self.lookupById(char(myAttrs.Id(j)));
                        if ~isempty(eRef)
                            numV = self.extractAttrValue(eRef);
                        end
                    end
                    if ~isnan(numV)
                        nm   = string(myAttrs.Name(j));
                        uh   = strtrim(string(myAttrs.UnitHint(j)));
                        if strlength(uh)>0; unit = uh; else; unit = self.inferUnit(nm); end
                        if strlength(unit) > 0
                            attrParts(end+1,1) = nm+" = "+sprintf("%.4g",numV)+" ["+unit+"]";
                        else
                            attrParts(end+1,1) = nm+" = "+sprintf("%.4g",numV);
                        end
                    end
                end
                if ~isempty(attrParts); reqAttr(k) = strjoin(attrParts,"; "); else; reqAttr(k) = "–"; end

                % Constraints klassifizieren (assume / require)
                myConsts     = TConst(TConst.OwnerId==ownId,:);
                isMembership = contains(myConsts.Type,"Membership","IgnoreCase",true);
                isUsageOnly  = contains(myConsts.Type,"ConstraintUsage","IgnoreCase",true) ...
                               & ~isMembership;
                myUsages     = myConsts(isUsageOnly,:);
                myMembers    = myConsts(isMembership,:);

                % kind-Feld der Memberships per HTTP lesen
                memberKinds = strings(height(myMembers),1);
                for jm = 1:height(myMembers)
                    mid = string(myMembers.Id(jm));
                    if strlength(mid)==0, continue; end
                    try
                        rawM = webread(self.baseUrl+"/"+mid, self.optsText);
                        eM   = jsondecode(rawM);
                        if isfield(eM,'kind') && ~isempty(eM.kind)
                            memberKinds(jm) = lower(strtrim(string(eM.kind)));
                        end
                    catch
                    end
                end

                assumeParts  = strings(0,1);
                requireParts = strings(0,1);
                usageIdx     = 0;

                for j = 1:height(myUsages)
                    nm = strtrim(string(myUsages.Name(j)));
                    if strlength(nm)==0
                        nm = strtrim(string(myUsages.DeclShortName(j)));
                    end
                    usageIdx = usageIdx + 1;
                    isInternal = ~isempty(regexp(nm,'^constraint\d*$','once','ignorecase'));

                    if ~isInternal
                        % Benannter Constraint: Heuristik auf Ausdrucks-String
                        if contains(nm,"<=") || contains(nm,">=")
                            requireParts(end+1,1) = nm; %#ok<AGROW>
                        elseif contains(nm,">") && ~contains(nm,"=")
                            assumeParts(end+1,1)  = nm; %#ok<AGROW>
                        elseif contains(nm,"<") && ~contains(nm,"=")
                            assumeParts(end+1,1)  = nm; %#ok<AGROW>
                        else
                            requireParts(end+1,1) = nm; %#ok<AGROW>
                        end
                    else
                        % Interner Name: kind aus Membership (Paarung per Reihenfolge)
                        kindForThis = "";
                        validIdx = 0;
                        for jm2 = 1:height(myMembers)
                            if strlength(memberKinds(jm2)) > 0
                                validIdx = validIdx + 1;
                                if validIdx == usageIdx
                                    kindForThis = memberKinds(jm2);
                                    break;
                                end
                            end
                        end
                        if contains(kindForThis,"assumption","IgnoreCase",true)
                            assumeParts(end+1,1)  = nm; %#ok<AGROW>
                        elseif contains(kindForThis,"requirement","IgnoreCase",true)
                            requireParts(end+1,1) = nm; %#ok<AGROW>
                        else
                            % Letzter Fallback: Operator per optsText
                            op = self.tryGetOperator(string(myUsages.Id(j)));
                            if strcmp(op,"<=") || strcmp(op,">=")
                                requireParts(end+1,1) = nm; %#ok<AGROW>
                            elseif strcmp(op,">") || strcmp(op,"<")
                                assumeParts(end+1,1)  = nm; %#ok<AGROW>
                            end
                        end
                    end
                end

                if ~isempty(assumeParts); reqAssume(k) = strjoin(unique(assumeParts)," | "); else; reqAssume(k) = "–"; end
                if ~isempty(requireParts); reqRequire(k) = strjoin(unique(requireParts)," | "); else; reqRequire(k) = "–"; end
            end

            self.Treqs = table(reqId,reqName,reqDoc,reqAttr,reqAssume,reqRequire, ...
                'VariableNames', ...
                ["ID","Name","Beschreibung","Anforderungsattribut", ...
                 "Assume Constraint","Require Constraint"]);
            self.ReqTable.Data = self.Treqs;
            self.log(sprintf("Anforderungen geladen: %d", height(self.Treqs)));
        end

        % =================================================================
        % Anforderungsanalyse
        % =================================================================
        function onRunAnalysis(self)
            try
                if isempty(self.Tattrs) || height(self.Tattrs)==0
                    self.Out.Value = { ...
                        'Keine Attributwerte gefunden.', ...
                        ' ', ...
                        'Bitte zuerst ein Projekt laden und Modelldaten abrufen.'};
                    return;
                end
                if isempty(self.Treqs) || height(self.Treqs)==0
                    self.Out.Value = { ...
                        'Keine Anforderungen im Modell gefunden.', ...
                        ' ', ...
                        'Bitte ein Modell mit Requirements (DeclShortName) laden.'};
                    return;
                end

                % Wertebasis aufbauen (Part-Attribute + REQ-Attribute)
                valueMap = containers.Map('KeyType','char','ValueType','double');
                for k = 1:height(self.Tattrs)
                    nm  = char(self.Tattrs.Attributname(k));
                    val = str2double(self.Tattrs.Wert(k));
                    if ~isnan(val) && ~isKey(valueMap,nm)
                        valueMap(nm) = val;
                    end
                end
                isAttr = contains(self.Telements.Type,"Attribute","IgnoreCase",true);
                TAtAll = self.Telements(isAttr,:);
                for k = 1:height(TAtAll)
                    nm  = char(TAtAll.Name(k));
                    val = str2double(TAtAll.Value(k));
                    if ~isnan(val) && ~isKey(valueMap,nm)
                        valueMap(nm) = val;
                    end
                end

                if valueMap.Count == 0
                    self.Out.Value = { ...
                        'Keine auswertbaren Attributwerte gefunden.', ...
                        ' ', ...
                        'Moegliche Ursachen:', ...
                        '  - Modelldaten noch nicht abgerufen', ...
                        '  - Keine Attribute mit Zahlenwerten im Modell'};
                    return;
                end

                self.log(sprintf("Wertebasis: %d Variablen", valueMap.Count));

                % Jede Anforderung prüfen
                outLines    = {};
                allErfuellt = true;

                for r = 1:height(self.Treqs)
                    reqId_r   = string(self.Treqs.ID(r));
                    reqName_r = string(self.Treqs.Name(r));
                    assume    = string(self.Treqs.("Assume Constraint")(r));
                    require   = string(self.Treqs.("Require Constraint")(r));

                    outLines{end+1} = sprintf("=== [%s] %s ===", reqId_r, reqName_r); %#ok<AGROW>
                    reqAttrStr = string(self.Treqs.Anforderungsattribut(r));
                    if strlength(strtrim(reqAttrStr))>0 && ~strcmp(reqAttrStr,"–")
                        outLines{end+1} = sprintf("  Anforderungsattribut: %s", reqAttrStr); %#ok<AGROW>
                    end

                    reqErfuellt = true;
                    allExprs    = self.collectExprs(assume, require);

                    for ei = 1:numel(allExprs)
                        ex = strtrim(string(allExprs{ei}));
                        [ok, lhsV, opS, rhsV, info] = self.evalConstraint(ex, valueMap);
                        isAssume = self.exprIsAssume(ex, assume);
                        if isAssume; prefix = "assume"; else; prefix = "require"; end
                        if ok == 1
                            outLines{end+1} = sprintf("  [OK] %s: %s  (%.4g %s %.4g)", ... %#ok<AGROW>
                                prefix, ex, lhsV, char(opS), rhsV);
                        elseif ok == 0
                            outLines{end+1} = sprintf("  [!!] %s VERLETZT: %s  (%.4g %s %.4g)", ... %#ok<AGROW>
                                prefix, ex, lhsV, char(opS), rhsV);
                            reqErfuellt = false;
                            allErfuellt = false;
                        else
                            outLines{end+1} = sprintf("  [?] %s: %s  (%s)", prefix, ex, char(info)); %#ok<AGROW>
                        end
                    end

                    if reqErfuellt
                        outLines{end+1} = sprintf("  --> %s: ERFUELLT [OK]", reqId_r); %#ok<AGROW>
                    else
                        outLines{end+1} = sprintf("  --> %s: VERLETZT [!!]", reqId_r); %#ok<AGROW>
                    end
                    outLines{end+1} = "  "+repmat("-",1,50); %#ok<AGROW>
                end

                if allErfuellt
                    outLines{end+1} = "=== GESAMTERGEBNIS: Alle Anforderungen erfuellt [OK] ===";
                else
                    outLines{end+1} = "=== GESAMTERGEBNIS: Mindestens eine Anforderung verletzt [!!] ===";
                end

                outLines = cellfun(@(x) char(string(x)), outLines, 'UniformOutput',false);
                self.Out.Value = outLines;
                self.log("Analyse abgeschlossen.");

                % Visualisierung
                numMask = arrayfun(@(x)~isnan(str2double(x)), self.Tattrs.Wert);
                if any(numMask)
                    self.plotAnalysis(self.Tattrs(numMask,:), valueMap);
                end

            catch ME
                self.Out.Value = { ...
                    sprintf('Analysefehler in Zeile %d:', ME.stack(1).line), ...
                    sprintf('Ursache: %s', ME.message), ...
                    ' ', ...
                    'Hinweis: Keine auswertbaren Werte gefunden.', ...
                    'Bitte Modell und Constraints pruefen.'};
            end
        end

        % =================================================================
        % Constraint auswerten (Strategie C: Regex-Parser + Wertebasis)
        % =================================================================
        function [ok, lhsV, op, rhsV, info] = evalConstraint(self, expr, valueMap)
            ok = -1; lhsV = NaN; op = ""; rhsV = NaN; info = "";
            exprClean = regexprep(char(expr), '\s*\[.*?\]', '');
            tok = regexp(strtrim(exprClean), ...
                '^([\w\.]+)\s*(<=|>=|<|>|==|!=)\s*([\w\.]+)$', 'tokens','once');
            if isempty(tok) || numel(tok) < 3
                info = sprintf("Ausdruck nicht parsebar: '%s'", strtrim(exprClean));
                return;
            end
            lhsStr = strtrim(string(tok{1}));
            op     = strtrim(string(tok{2}));
            rhsStr = strtrim(string(tok{3}));
            lhsV   = self.resolveValue(char(lhsStr), valueMap);
            rhsV   = self.resolveValue(char(rhsStr), valueMap);
            if isnan(lhsV), info = "Variable unbekannt: '"+lhsStr+"'"; return; end
            if isnan(rhsV), info = "Variable unbekannt: '"+rhsStr+"'"; return; end
            switch char(op)
                case "<=", result = lhsV <= rhsV;
                case ">=", result = lhsV >= rhsV;
                case "<",  result = lhsV <  rhsV;
                case ">",  result = lhsV >  rhsV;
                case "==", result = abs(lhsV-rhsV) < 1e-9;
                case "!=", result = abs(lhsV-rhsV) >= 1e-9;
                otherwise, info = "Unbekannter Operator: "+op; return;
            end
            ok = double(result);
        end

        function val = resolveValue(~, nameOrNum, valueMap)
            val = str2double(nameOrNum);
            if ~isnan(val), return; end
            if isKey(valueMap, nameOrNum), val = valueMap(nameOrNum); return; end
            for k = valueMap.keys()
                if strcmpi(k{1}, nameOrNum), val = valueMap(k{1}); return; end
            end
        end

        % =================================================================
        % Visualisierung: ein Subplot pro Anforderung
        % =================================================================
        function plotAnalysis(self, TAttr, valueMap)
            if isempty(self.Treqs) || height(self.Treqs)==0, return; end
            nReqs = height(self.Treqs);
            fig   = figure('Name','Anforderungsanalyse','NumberTitle','off', ...
                'Position',[80 60 520*nReqs 560]);
            lineColors = {'r','b','m','c','g'};

            for r = 1:nReqs
                reqId_r   = string(self.Treqs.ID(r));
                reqName_r = string(self.Treqs.Name(r));
                assume    = string(self.Treqs.("Assume Constraint")(r));
                require   = string(self.Treqs.("Require Constraint")(r));
                allExprs  = self.collectExprs(assume, require);

                % Relevante Attribute filtern
                reqVarNames = self.extractVarNames(assume, require);
                matchMask   = false(height(TAttr),1);
                for k=1:height(TAttr)
                    for v=1:numel(reqVarNames)
                        if strcmpi(char(TAttr.Attributname(k)), reqVarNames{v})
                            matchMask(k) = true;
                        end
                    end
                end
                TReq = TAttr(matchMask,:);
                if height(TReq)==0, TReq = TAttr; end

                nBars     = height(TReq);
                barVals   = arrayfun(@(x)str2double(x), TReq.Wert);
                barLabels = cellstr(TReq.Attributname);
                if nBars>0; unitStr = strtrim(string(TReq.Einheit(1))); else; unitStr = ""; end

                ax = subplot(1, nReqs, r, 'Parent', fig);
                b  = bar(ax, categorical(barLabels), barVals, 'FaceColor','flat');
                cmap = lines(max(nBars,1));
                for k=1:nBars, b.CData(k,:) = cmap(k,:); end
                hold(ax,'on');

                % Anforderungsattribut-Grenzlinie
                ci         = 0;
                reqAttrVal = NaN;
                reqAttrName = "";
                reqAttrStr = string(self.Treqs.Anforderungsattribut(r));
                tok = regexp(char(reqAttrStr),'=\s*([\d\.eE\+\-]+)','tokens','once');
                if ~isempty(tok)
                    reqAttrVal  = str2double(tok{1});
                    reqAttrName = strtrim(regexp(char(reqAttrStr),'^(\w+)','match','once'));
                end
                legendH = []; legendL = {};
                if ~isnan(reqAttrVal) && reqAttrVal > 0
                    ci = ci+1;
                    col = lineColors{mod(ci-1,numel(lineColors))+1};
                    hl  = yline(ax, reqAttrVal,'--','Color',col,'LineWidth',2);
                    legendH(end+1) = hl; legendL{end+1} = sprintf('%s = %.4g',char(reqAttrName),reqAttrVal);
                end

                % Constraint-Grenzlinien
                drawnLimits = [];
                for ei = 1:numel(allExprs)
                    exC  = regexprep(allExprs{ei},'\s*\[.*?\]','');
                    tok2 = regexp(exC,'^([\w\.]+)\s*(<=|>=|<|>|==)\s*([\w\.]+)$','tokens','once');
                    if isempty(tok2)||numel(tok2)<3, continue; end
                    lhsS = strtrim(string(tok2{1}));
                    opS  = strtrim(string(tok2{2}));
                    rhsS = strtrim(string(tok2{3}));
                    lhsV = self.resolveValue(char(lhsS),valueMap);
                    rhsV = self.resolveValue(char(rhsS),valueMap);
                    partN = cellstr(TReq.Attributname);
                    if any(strcmpi(char(lhsS),partN)) && ~isnan(rhsV)
                        limitVal = rhsV; limitLbl = sprintf('%s %s %.4g',char(lhsS),char(opS),rhsV);
                    elseif any(strcmpi(char(rhsS),partN)) && ~isnan(lhsV)
                        limitVal = lhsV; limitLbl = sprintf('%.4g %s %s',lhsV,char(opS),char(rhsS));
                    elseif ~isnan(rhsV)
                        limitVal = rhsV; limitLbl = sprintf('%s %s %.4g',char(lhsS),char(opS),rhsV);
                    elseif ~isnan(lhsV)
                        limitVal = lhsV; limitLbl = sprintf('%.4g %s %s',lhsV,char(opS),char(rhsS));
                    else
                        continue;
                    end
                    if any(abs(drawnLimits-limitVal)<1e-9), continue; end
                    drawnLimits(end+1) = limitVal; %#ok<AGROW>
                    ci = ci+1;
                    col = lineColors{mod(ci-1,numel(lineColors))+1};
                    hl  = yline(ax,limitVal,'--','Color',col,'LineWidth',1.5);
                    legendH(end+1) = hl; legendL{end+1} = char(limitLbl); %#ok<AGROW>
                end
                if ~isempty(legendH)
                    legend(ax,legendH,legendL,'Location','northeast','FontSize',8,'Box','on');
                end

                % Y-Achse mit Puffer
                allY = [barVals(:)', drawnLimits];
                if ~isnan(reqAttrVal) && reqAttrVal>0, allY=[allY,reqAttrVal]; end
                allY = allY(~isnan(allY));
                if ~isempty(allY)
                    pad = max(abs(max(allY)-min(allY))*0.18, abs(max(allY))*0.12);
                    ylim(ax, [min(allY)-pad, max(allY)+pad]);
                end

                % Titel einfärben
                reqErfuelltPlot = true;
                for ei=1:numel(allExprs)
                    [ok2,~,~,~,~] = self.evalConstraint(allExprs{ei},valueMap);
                    if ok2==0, reqErfuelltPlot=false; break; end
                end
                if reqErfuelltPlot; titleColor = [0.0 0.50 0.0]; else; titleColor = [0.80 0.0 0.0]; end
                title(ax, sprintf('[%s] %s', char(reqId_r), char(reqName_r)), ...
                    'FontSize',10,'FontWeight','bold','Color',titleColor);
                set(ax,'Color',[1 1 1]);

                % Ergebnisboxen an Grenzlinien positioniert
                resultLines      = {};
                resultColors     = {};
                resultLimitVals  = {};
                for ei=1:numel(allExprs)
                    [ok2,lhsV2,opS2,rhsV2,info2] = self.evalConstraint(allExprs{ei},valueMap);
                    exC2 = regexprep(allExprs{ei},'\s*\[.*?\]','');
                    tok3 = regexp(exC2,'^([\w\.]+)\s*(<=|>=|<|>|==)\s*([\w\.]+)$','tokens','once');
                    limY = NaN;
                    if ~isempty(tok3)&&numel(tok3)>=3
                        lR=self.resolveValue(char(strtrim(string(tok3{1}))),valueMap);
                        rR=self.resolveValue(char(strtrim(string(tok3{3}))),valueMap);
                        pN=cellstr(TReq.Attributname);
                        if any(strcmpi(char(strtrim(string(tok3{1}))),pN))&&~isnan(rR), limY=rR;
                        elseif any(strcmpi(char(strtrim(string(tok3{3}))),pN))&&~isnan(lR), limY=lR;
                        elseif ~isnan(rR), limY=rR;
                        elseif ~isnan(lR), limY=lR;
                        end
                    end
                    if ok2==1
                        resultLines{end+1}     = sprintf('[OK] %s  (%.4g %s %.4g)',allExprs{ei},lhsV2,char(opS2),rhsV2);
                        resultColors{end+1}    = [0.0 0.50 0.0];
                    elseif ok2==0
                        resultLines{end+1}     = sprintf('[!!] %s  (%.4g %s %.4g)',allExprs{ei},lhsV2,char(opS2),rhsV2);
                        resultColors{end+1}    = [0.85 0.0 0.0];
                    else
                        resultLines{end+1}     = sprintf('[?] %s  (%s)',allExprs{ei},char(info2));
                        resultColors{end+1}    = [0.5 0.5 0.5];
                    end
                    resultLimitVals{end+1} = limY;
                end

                xCenter = (nBars+1)/2;
                yl3     = ylim(ax);
                yRange3 = yl3(2)-yl3(1);
                for ei=1:numel(resultLines)
                    limY = resultLimitVals{ei};
                    if isnan(limY)
                        limY = yl3(2) - yRange3*(0.08+(ei-1)*0.12);
                    end
                    offset = yRange3 * 0.03;
                    bgCol  = resultColors{ei}*0.12 + [0.88 0.88 0.88]*0.88;
                    text(ax, xCenter, limY+offset, char(resultLines{ei}), ...
                        'FontSize',8,'FontWeight','bold', ...
                        'Color',          resultColors{ei}, ...
                        'VerticalAlignment',   'bottom', ...
                        'HorizontalAlignment', 'center', ...
                        'BackgroundColor', bgCol, ...
                        'EdgeColor',       resultColors{ei}*0.6, ...
                        'Margin', 3, 'Interpreter','none');
                end

                if strlength(unitStr)>0
                    ylabel(ax, sprintf('Wert [%s]', char(unitStr)));
                else
                    ylabel(ax,'Wert');
                end
                if nBars>0; partLabel = char(TReq.("Part-Instanz")(1)); else; partLabel = ""; end
                xlabel(ax, sprintf('Part-Attribut (%s)', partLabel));
                grid(ax,'on');
                xtickangle(ax,0);
            end
        end

        % =================================================================
        % Hilfsfunktionen – Constraint-Verarbeitung
        % =================================================================
        function allExprs = collectExprs(~, assume, require)
            allExprs = {};
            if strlength(strtrim(assume))>0 && ~strcmp(assume,"–") && ~strcmp(assume,"-")
                for ex = strsplit(assume," | "), allExprs{end+1}=char(strtrim(ex{1})); end
            end
            if strlength(strtrim(require))>0 && ~strcmp(require,"–") && ~strcmp(require,"-")
                for ex = strsplit(require," | "), allExprs{end+1}=char(strtrim(ex{1})); end
            end
        end

        function result = exprIsAssume(~, expr, assume)
            result = contains(assume, expr);
        end

        function varNames = extractVarNames(~, assume, require)
            varNames = {};
            all = strjoin({char(assume), char(require)}, " | ");
            toks = regexp(all, '([a-zA-Z_]\w*)', 'tokens');
            for k=1:numel(toks)
                nm = char(toks{k}{1});
                if ~ismember(nm, varNames), varNames{end+1} = nm; end
            end
        end

        function op = tryGetOperator(self, constId)
            op = "";
            if isempty(constId), return; end
            constId = strtrim(string(constId));
            if strlength(constId)~=36||sum(constId=="-")~=4, return; end
            try
                rawC = webread(self.baseUrl+"/"+constId, self.optsText);
                eC   = jsondecode(rawC);
                op   = self.scanForOperator(eC);
            catch
            end
        end

        function op = scanForOperator(self, e)
            op = "";
            if ~isstruct(e), return; end
            fns = fieldnames(e);
            for k=1:numel(fns)
                v = e.(fns{k});
                if strcmp(fns{k},'operator')&&(ischar(v)||isstring(v))
                    s = strtrim(string(v));
                    if ismember(s,["<","<=",">",">=","==","!="])
                        op=s; return;
                    end
                end
                if isstruct(v)
                    for j=1:numel(v)
                        r=self.scanForOperator(v(j));
                        if strlength(r)>0, op=r; return; end
                    end
                elseif iscell(v)
                    for j=1:numel(v)
                        if isstruct(v{j})
                            r=self.scanForOperator(v{j});
                            if strlength(r)>0, op=r; return; end
                        end
                    end
                end
            end
        end

        function collectMemberElemIds(self, e, ~)
            if ~isstruct(e), return; end
            fns = fieldnames(e);
            for k=1:numel(fns)
                v = e.(fns{k});
                if strcmp(fns{k},'memberElement')&&(ischar(v)||isstring(v))
                    s = string(v);
                    if strlength(s)==36&&sum(s=="-")==4
                        self.tmpIds{end+1} = char(s);
                    end
                end
                if isstruct(v)
                    for j=1:numel(v), self.collectMemberElemIds(v(j),{}); end
                elseif iscell(v)
                    for j=1:numel(v)
                        if isstruct(v{j}), self.collectMemberElemIds(v{j},{}); end
                    end
                end
            end
        end

        % =================================================================
        % Hilfsfunktionen – Einheiten
        % =================================================================
        function unit = unitFromElement(self, e)
            unit = "";
            if ~isstruct(e), return; end
            qn = "";
            if isfield(e,'qualifiedName')&&~isempty(e.qualifiedName)
                qn = lower(string(e.qualifiedName));
            end
            unit = self.isqQnToUnit(qn);
            if strlength(unit)>0, return; end
            unit = self.inferUnit(self.readName(e));
        end

        function unit = isqQnToUnit(~, qnLower)
            unit = "";
            if contains(qnLower,'energy')||contains(qnLower,'energie'), unit="J";  return; end
            if contains(qnLower,'mass')  ||contains(qnLower,'masse'),   unit="kg"; return; end
            if contains(qnLower,'length')||contains(qnLower,'laenge'),  unit="m";  return; end
            if contains(qnLower,'time')  ||contains(qnLower,'dauer'),   unit="s";  return; end
            if contains(qnLower,'frequency'), unit="Hz"; return; end
            if contains(qnLower,'power'),     unit="W";  return; end
            if contains(qnLower,'voltage'),   unit="V";  return; end
            if contains(qnLower,'current'),   unit="A";  return; end
            if contains(qnLower,'charge'),    unit="C";  return; end
            if contains(qnLower,'temperature'), unit="K"; return; end
        end

        function unit = inferUnit(~, nm)
            unit = "";
            n = lower(string(nm));
            if contains(n,{'masse','mass','weight','gewicht'}),        unit="kg"; return; end
            if contains(n,{'laenge','length','radius','hoehe','height', ...
                           'breite','width','reichweite','range'}),    unit="m";  return; end
            if contains(n,{'energie','energy','joule'}),               unit="J";  return; end
            if contains(n,'kapazitaet')||contains(n,'capacity')
                if contains(n,'elektr')||contains(n,'farad'); unit="F"; else; unit="J"; end; return;
            end
            if contains(n,{'frequenz','frequency'})&&~contains(n,'dbm'), unit="Hz"; return; end
            if contains(n,{'leistung','power'})&&~contains(n,'dbm'),     unit="W";  return; end
            if contains(n,{'spannung','voltage','volt'}), unit="V";   return; end
            if contains(n,{'strom','current','ampere'}),  unit="A";   return; end
            if contains(n,{'ladung','charge'}),           unit="C";   return; end
            if contains(n,{'zeit','time','dauer'}),        unit="s";   return; end
            if contains(n,'dbm'), unit="dBm"; return; end
        end

        % =================================================================
        % Hilfsfunktionen – Dokumentation
        % =================================================================
        function txt = extractDoc(self, e)
            txt = "–";
            if ~isfield(e,'documentation')||isempty(e.documentation), return; end
            v = e.documentation;
            if ischar(v)||isstring(v)
                s = strtrim(string(v));
                if strlength(s)>3&&~contains(s,'"')&&~contains(s,'{')
                    txt=s; return;
                end
            end
            if isstruct(v)
                for fn={'body','text','comment','value'}
                    if isfield(v,fn{1})&&~isempty(v(1).(fn{1}))
                        vv=v(1).(fn{1});
                        if (ischar(vv)||isstring(vv))
                            s=strtrim(string(vv));
                            if strlength(s)>3&&~contains(s,'"'), txt=s; return; end
                        end
                    end
                end
                if isfield(v,'x_id')&&~isempty(v.x_id)
                    try
                        eDoc=webread(self.baseUrl+"/"+string(v.x_id),self.opts);
                        for fn={'body','text','comment','value'}
                            if isfield(eDoc,fn{1})&&~isempty(eDoc.(fn{1}))
                                vv=eDoc.(fn{1});
                                if (ischar(vv)||isstring(vv))
                                    s=strtrim(string(vv));
                                    if strlength(s)>3&&~contains(s,'"')&&~contains(s,'{')
                                        txt=s; return;
                                    end
                                end
                            end
                        end
                    catch
                    end
                end
            end
        end

        function txt = readDocShort(~, e)
            txt = "";
            if ~isfield(e,'documentation')||isempty(e.documentation), return; end
            v = e.documentation;
            if ischar(v)||isstring(v)
                s=strtrim(string(v));
                if strlength(s)>3&&~contains(s,'"')&&~contains(s,'{'), txt=s; end
            end
        end

        % =================================================================
        % Hilfsfunktionen – Elementzugriff
        % =================================================================
        function e = lookupById(self, idStr)
            e = [];
            if isempty(idStr)||~self.ElementMap.isKey(idStr), return; end
            idx = self.ElementMap(idStr);
            if idx>=1 && idx<=numel(self.Elements)
                e = self.Elements{idx};
            end
        end

        function ownId = readOwnerPartId(~, e)
            ownId = "";
            for fn={'owningType','owningUsage','owner'}
                if ~isfield(e,fn{1})||isempty(e.(fn{1})), continue; end
                v=e.(fn{1});
                if isstruct(v)&&isfield(v,'x_id')&&~isempty(v.x_id)
                    ownId=string(v.x_id); return;
                end
            end
        end

        function out = readName(~, e)
            out = "";
            if isfield(e,'name')&&~isempty(e.name), out=string(e.name); return; end
            if isfield(e,'declaredName')&&~isempty(e.declaredName)
                out=string(e.declaredName);
            end
        end

        function out = readId(~, e)
            out = "";
            if ~isstruct(e), return; end
            for fn=fieldnames(e)'
                if strcmpi(fn{1},'x_id')||strcmpi(fn{1},'elementId')
                    v=e.(fn{1});
                    if ~isempty(v)&&(ischar(v)||isstring(v))&&strlength(v)>10
                        out=string(v); return;
                    end
                end
            end
        end

        function out = readType(~, e)
            out = "";
            for fn={'x_type','type','xtype'}
                if isfield(e,fn{1})&&~isempty(e.(fn{1}))
                    v=e.(fn{1});
                    if ischar(v)||isstring(v), out=string(v); return; end
                end
            end
        end

        function out = readField(~, e, f)
            out = "";
            if isfield(e,f)&&~isempty(e.(f))
                try, out=string(e.(f)); catch, end
            end
        end

        % =================================================================
        % Hilfsfunktionen – Projekt/Commit
        % =================================================================
        function ids = extractCommitIds(~, obj)
            ids = strings(0,1);
            if isempty(obj), return; end
            try
                if isstruct(obj)
                    fns=fieldnames(obj);
                    idfn=fns(contains(fns,'id','IgnoreCase',true));
                    if ~isempty(idfn), ids=string({obj.(idfn{1})})'; return; end
                else
                    ids=string(cellfun(@(x)x.x_id,obj,'UniformOutput',false))';
                end
            catch
            end
        end

        function items = formatProjectItems(~, projects)
            items = {};
            try
                if isstruct(projects), arr=num2cell(projects);
                else, arr=projects; end
                for i=1:numel(arr)
                    p=arr{i}; nm=string(p.name); id="";
                    fns=fieldnames(p);
                    idfn=fns(contains(fns,'id','IgnoreCase',true));
                    if ~isempty(idfn), id=string(p.(idfn{1})); end
                    items{end+1}=char(nm+" ("+id+")");
                end
            catch ME
                items={char("Fehler: "+ME.message)};
            end
        end

        % =================================================================
        % Hilfsfunktionen – Allgemein
        % =================================================================

        function log(self, msg)
            self.Status.Value = [self.Status.Value; {char(msg)}];
            drawnow;
        end

    end
end
