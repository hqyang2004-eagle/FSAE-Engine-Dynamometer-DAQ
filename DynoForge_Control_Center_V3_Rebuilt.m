function app = DynoForge_Control_Center_V3_Rebuilt(projectDir)
% DynoForge Control Center V3 - read-only desktop simulation explorer.
% Does not run Simulink, modify models, or access physical hardware.
if nargin < 1 || isempty(projectDir)
    projectDir = 'C:\DynoForge_Test';
end
assert(isfolder(projectDir),'Project directory not found.');
snapshotPath = fullfile(projectDir,'Results','ControlCenter_Data', ...
    'DynoForge_ControlCenter_Latest.mat');
assert(isfile(snapshotPath),'Saved snapshot missing.');
loaded = load(snapshotPath,'Snapshot');
assert(isfield(loaded,'Snapshot'),'Snapshot variable missing.');
S = loaded.Snapshot;
assert(isfield(S,'Data') && isfield(S.Data,'Signals'), ...
    'Invalid snapshot structure.');
assert(isfield(S,'DesktopSimulationOnly') && S.DesktopSimulationOnly, ...
    'Expected desktop simulation snapshot.');
assert(isfield(S,'HardwareVerified') && ~S.HardwareVerified, ...
    'This viewer only accepts unverified desktop data.');
D = S.Data;
names = fieldnames(D.Signals);
assert(numel(names)==39,'Expected 39 logged signals.');
root = fullfile(projectDir,'Results');
assert(isfolder(root),'Results directory missing.');
reportDir = locateReport(root);
[plotFiles,plotLabels] = locatePlots(reportDir);
assert(numel(plotFiles)>=60,'Expected at least 60 report PNGs.');

fig = uifigure('Name','DynoForge Control Center V3 | DESKTOP SIMULATION ONLY', ...
    'Position',[70 55 1380 810],'Color',[0.965 0.972 0.981]);
main = uigridlayout(fig,[2 2]);
main.RowHeight = {64,'1x'};
main.ColumnWidth = {205,'1x'};
main.Padding = [12 12 12 12];
main.RowSpacing = 9;
main.ColumnSpacing = 10;
header = uilabel(main,'Text','DynoForge  |  Control Center V3   -   DESKTOP SIMULATION ONLY', ...
    'FontSize',22,'FontWeight','bold');
header.Layout.Row = 1;
header.Layout.Column = [1 2];
nav = uipanel(main,'Title','NAVIGATION');
nav.Layout.Row = 2;
nav.Layout.Column = 1;
navGrid = uigridlayout(nav,[10 1]);
navGrid.RowHeight = [repmat({42},1,9),{'1x'}];
navGrid.Padding = [7 10 7 10];
navGrid.RowSpacing = 6;
pageNames = {'Overview','Engineering','Cooling','Safety & Alarms', ...
    'Calibration','39-Signal Explorer','60-Plot Explorer', ...
    'Data & Reports','Diagnostics'};
navButtons = gobjects(numel(pageNames),1);
for k=1:numel(pageNames)
    navButtons(k)=uibutton(navGrid,'Text',pageNames{k}, ...
        'ButtonPushedFcn',@(~,~)showPage(k));
end
workspace = uipanel(main,'Title','Overview');
workspace.Layout.Row = 2;
workspace.Layout.Column = 2;
pageGrid = uigridlayout(workspace,[2 1]);
pageGrid.RowHeight = {75,'1x'};
pageGrid.Padding = [15 12 15 12];
summary = uitextarea(pageGrid,'Editable','off','FontSize',13);
summary.Layout.Row = 1;
body = uigridlayout(pageGrid,[1 1]);
body.Layout.Row = 2;
body.Padding = [0 0 0 0];
currentPage = 1;
currentPlot = 1;
currentSignal = names{1};
showPage(1);
app = struct('Figure',fig,'NavigationButtons',navButtons, ...
    'ShowPage',@showPage,'GetState',@getState, ...
    'RefreshReports',@refreshReports,'Snapshot',S, ...
    'SignalNames',{names},'ReportFolder',reportDir);

    function st = getState()
        st = struct('Page',pageNames{currentPage},'SignalCount',numel(names), ...
            'PlotCount',numel(plotFiles),'ReportFolder',reportDir, ...
            'SelectedSignal',currentSignal,'SelectedPlot',currentPlot, ...
            'DesktopSimulationOnly',true,'HardwareVerified',false);
    end

    function refreshReports()
        reportDir = locateReport(root);
        [plotFiles,plotLabels] = locatePlots(reportDir);
        currentPlot = min(max(1,currentPlot),numel(plotFiles));
        showPage(currentPage);
    end

    function clearBody()
        delete(body.Children);
        body.RowHeight = {'1x'};
        body.ColumnWidth = {'1x'};
    end

    function showPage(idx)
        if ~(isscalar(idx) && isnumeric(idx) && idx>=1 && idx<=numel(pageNames))
            error('Invalid page index.');
        end
        currentPage = idx;
        workspace.Title = pageNames{idx};
        clearBody();
        for j=1:numel(navButtons)
            if j==idx
                navButtons(j).FontWeight='bold';
            else
                navButtons(j).FontWeight='normal';
            end
        end
        switch idx
            case 1
                summary.Value = {sprintf('Source: %s  |  Signals: %d  |  PNG files: %d', ...
                    char(D.Source),numel(names),numel(plotFiles)), ...
                    sprintf('Alarm Code: %g   Alarm Level: %g   Calibration Complete: %g', ...
                    last('ALM_Code'),last('ALM_Level'),last('CAL_Calibration_Complete')), ...
                    'HARDWARE NOT VERIFIED  |  READ-ONLY DESKTOP DATA'};
                renderTable({'Metric','Latest value'}, {
                    'Engine RPM',last('ENG_RPM');
                    'Torque (N m)',last('ENG_Torque_Nm');
                    'Power (kW)',last('ENG_Power_kW');
                    'Flow (L/min)',last('ENG_Flow_Lmin');
                    'Alarm Code',last('ALM_Code');
                    'Alarm Level',last('ALM_Level');
                    'Calibration Complete',last('CAL_Calibration_Complete')});
            case 2
                summary.Value={'ENGINEERING | Values are from saved desktop simulation.', ...
                    'No engine or load cell measurements have been hardware-verified.'};
                renderSignalGroup({'ENG_RPM','ENG_Torque_Nm','ENG_Power_kW','ENG_Force_N'});
            case 3
                summary.Value={'COOLING | Saved desktop simulation values only.', ...
                    'Flow and temperature sensor calibration is not verified.'};
                renderSignalGroup({'ENG_Flow_Lmin','ENG_Temp_In_C', ...
                    'ENG_Temp_Out_C','ENG_Delta_T_C','ENG_Cooling_Power_kW'});
            case 4
                summary.Value={sprintf('ALARM CODE: %g  |  LEVEL: %g', ...
                    last('ALM_Code'),last('ALM_Level')), ...
                    'Displayed shutdown/alarm states are SIMULATED, not hardware safety actions.'};
                renderSignalGroup({'ALM_Active','ALM_Code','ALM_Level', ...
                    'ALM_Sensor','ALM_Calibration','ALM_Shutdown', ...
                    'SQ_All_Sensors_OK','SQ_Quality_Fault_Code'});
            case 5
                summary.Value={'CALIBRATION | A zero means incomplete/not valid in this test.', ...
                    'Do not interpret simulated flags as physical calibration evidence.'};
                renderSignalGroup({'CAL_Calibration_Complete', ...
                    'CAL_All_Params_Valid','CAL_Calibration_Fault_Code', ...
                    'CAL_LoadCell_Param_OK','CAL_RPM_Param_OK', ...
                    'CAL_Flow_Param_OK','CAL_Temp_In_Param_OK', ...
                    'CAL_Temp_Out_Param_OK'});
            case 6
                summary.Value={'39-SIGNAL EXPLORER | Choose a logged timeseries.', ...
                    'Time and signal values come from the saved MAT snapshot.'};
                renderSignalExplorer();
            case 7
                summary.Value={sprintf('REPORT EXPLORER | %d PNG files (60 plots + dashboard expected)',numel(plotFiles)), ...
                    'Some original plots may contain N/A; see Plot_Manifest.csv.'};
                renderPlotExplorer();
            case 8
                summary.Value={'DATA & REPORTS | Local, read-only source locations.', ...
                    'Snapshot reload occurs when you reopen V3.'};
                renderText({['Snapshot: ' snapshotPath], ...
                    ['Report folder: ' reportDir], ...
                    sprintf('Signals: %d',numel(names)), ...
                    sprintf('PNG images: %d',numel(plotFiles)), ...
                    'Report manifest: check 07_Test_Report and report subfolders'});
            case 9
                summary.Value={'DIAGNOSTICS | Snapshot and report discovery.', ...
                    'No model edits, simulations, or hardware I/O are performed.'};
                renderText({sprintf('Signal count: %d',numel(names)), ...
                    sprintf('PNG count: %d',numel(plotFiles)), ...
                    sprintf('Alarm Code: %g',last('ALM_Code')), ...
                    sprintf('Alarm Level: %g',last('ALM_Level')), ...
                    sprintf('Calibration complete: %g',last('CAL_Calibration_Complete')), ...
                    'DesktopSimulationOnly: TRUE', ...
                    'HardwareVerified: FALSE', ...
                    'SensorCalibrationVerified: FALSE'});
        end
    end

    function val = last(name)
        assert(isfield(D.Signals,name),['Missing signal: ' name]);
        vals=D.Signals.(name).Value;
        assert(~isempty(vals),['Empty signal: ' name]);
        val=double(vals(end));
    end

    function renderTable(cols,rows)
        tbl=uitable(body,'Data',rows,'ColumnName',cols, ...
            'ColumnWidth',{'auto','auto'});
        tbl.Layout.Row=1;
        tbl.Layout.Column=1;
    end

    function renderSignalGroup(group)
        rows=cell(numel(group),3);
        for i=1:numel(group)
            name=group{i};
            rows{i,1}=name;
            if isfield(D.Signals,name)
                rows{i,2}=last(name);
                rows{i,3}=numel(D.Signals.(name).Value);
            else
                rows{i,2}=NaN;
                rows{i,3}=0;
            end
        end
        renderTable({'Signal','Latest value','Samples'},rows);
    end

    function renderText(lines)
        t=uitextarea(body,'Editable','off','Value',lines,'FontSize',14);
        t.Layout.Row=1;
        t.Layout.Column=1;
    end

    function renderSignalExplorer()
        clearBody();
        body.RowHeight={42,'1x'};
        dd=uidropdown(body,'Items',names,'Value',currentSignal);
        dd.Layout.Row=1;
        ax=uiaxes(body);
        ax.Layout.Row=2;
        plotSignal(ax,currentSignal);
        dd.ValueChangedFcn=@(~,~)plotSignal(ax,dd.Value);
    end

    function plotSignal(ax,name)
        currentSignal=name;
        sig=D.Signals.(name);
        t=double(sig.Time_s(:));
        v=double(sig.Value(:));
        assert(numel(t)==numel(v),'Signal time/value mismatch.');
        plot(ax,t,v,'LineWidth',1.8);
        grid(ax,'on');
        title(ax,strrep(name,'_','\_'));
        xlabel(ax,'Time (s)');
        ylabel(ax,'Logged value');
    end

    function renderPlotExplorer()
        clearBody();
        body.RowHeight={42,'1x'};
        bar=uigridlayout(body,[1 4]);
        bar.Layout.Row=1;
        bar.ColumnWidth={75,75,'1x',85};
        prev=uibutton(bar,'Text','Previous','ButtonPushedFcn',@(~,~)movePlot(-1));
        prev.Layout.Column=1;
        next=uibutton(bar,'Text','Next','ButtonPushedFcn',@(~,~)movePlot(1));
        next.Layout.Column=2;
        chooser=uidropdown(bar,'Items',plotLabels,'Value',plotLabels{currentPlot});
        chooser.Layout.Column=3;
        refresh=uibutton(bar,'Text','Rescan','ButtonPushedFcn',@(~,~)refreshReports());
        refresh.Layout.Column=4;
        imageView=uiimage(body,'ScaleMethod','fit');
        imageView.Layout.Row=2;
        displayPlot();
        chooser.ValueChangedFcn=@(~,~)choosePlot();
        function movePlot(step)
            currentPlot=mod(currentPlot-1+step,numel(plotFiles))+1;
            chooser.Value=plotLabels{currentPlot};
            displayPlot();
        end
        function choosePlot()
            currentPlot=find(strcmp(plotLabels,chooser.Value),1);
            displayPlot();
        end
        function displayPlot()
            imageView.ImageSource=plotFiles{currentPlot};
        end
    end
end

function folder = locateReport(resultsRoot)
items=dir(fullfile(resultsRoot,'DynoForge_60Plots_*'));
items=items([items.isdir]);
assert(~isempty(items),'No DynoForge 60-plot report folder found.');
[~,idx]=max([items.datenum]);
folder=fullfile(items(idx).folder,items(idx).name);
end

function [paths,labels] = locatePlots(folder)
items=dir(fullfile(folder,'**','*.png'));
assert(~isempty(items),'No report PNG files found.');
paths=cell(numel(items),1);
labels=cell(numel(items),1);
for k=1:numel(items)
    paths{k}=fullfile(items(k).folder,items(k).name);
    relative=erase(items(k).folder,[folder filesep]);
    labels{k}=sprintf('%02d | %s | %s',k,relative,items(k).name);
end
end
