function app = DynoForge_LIVE30_Live_Monitor_V1()
% LIVE-29 independent real-time GUI V1
% Arduino synthetic data; sensors NOT verified.
fig = uifigure('Name','DynoForge LIVE-30 | SYNTHETIC DATA', ...
    'Position',[100 70 1200 780]);
main = uigridlayout(fig,[3 1]);
main.RowHeight = {55,110,'1x'};
main.Padding = [15 15 15 15];

top = uigridlayout(main,[1 4]);
top.ColumnWidth = {'1x',110,110,170};
uilabel(top,'Text','DynoForge | LIVE-30 Monitor', ...
    'FontSize',22,'FontWeight','bold');
startBtn = uibutton(top,'Text','START', ...
    'ButtonPushedFcn',@startLive);
stopBtn = uibutton(top,'Text','STOP', ...
    'ButtonPushedFcn',@stopLive);
stopBtn.Enable = 'off';
statusLabel = uilabel(top,'Text','DISCONNECTED', ...
    'FontWeight','bold');

cards = uigridlayout(main,[1 4]);
cards.ColumnWidth = {'1x','1x','1x','1x'};
names = {'RPM','TORQUE (N m)','TEMP (C)','FLOW (L/min)'};
values = gobjects(1,4);
for k = 1:4
    panel = uipanel(cards,'Title',names{k});
    values(k) = uilabel(panel,'Text','--', ...
        'FontSize',26,'FontWeight','bold', ...
        'Position',[20 15 200 45]);
end

plots = uigridlayout(main,[2 2]);
plots.RowHeight = {'1x','1x'};
plots.ColumnWidth = {'1x','1x'};
ax = gobjects(1,4);
lineH = gobjects(1,4);
units = {'RPM','N m','C','L/min'};
for k = 1:4
    ax(k) = uiaxes(plots);
    title(ax(k),names{k});
    xlabel(ax(k),'Time (s)');
    ylabel(ax(k),units{k});
    grid(ax(k),'on');
    lineH(k) = plot(ax(k),nan,nan,'LineWidth',1.5);
end

refreshTimer = timer('ExecutionMode','fixedSpacing', ...
    'Period',0.2,'BusyMode','drop', ...
    'TimerFcn',@refreshLive);
fig.CloseRequestFcn = @closeLive;
app = struct('Figure',fig,'Timer',refreshTimer);

    function startLive(~,~)
        try
            st = DynoForge_LIVE29_Serial_Module('start');
            if st.Running
                start(refreshTimer);
                startBtn.Enable = 'off';
                stopBtn.Enable = 'on';
                statusLabel.Text = 'CONNECTED | SYNTHETIC';
            end
        catch ME
            statusLabel.Text = 'CONNECTION FAILED';
            uialert(fig,ME.message,'Serial Error');
        end
    end

    function stopLive(~,~)
        if strcmp(refreshTimer.Running,'on')
            stop(refreshTimer);
        end
        startBtn.Enable = 'off';
        stopBtn.Enable = 'off';
        try
            st = DynoForge_LIVE29_Serial_Module('stop');
            statusLabel.Text = 'STOPPED | SAVING';
            drawnow;
            result = DynoForge_LIVE30_Export(st);
            statusLabel.Text = sprintf('SAVED | %d frames',result.Rows);
            fprintf('LIVE30 CSV: %s\n',result.CSV);
            fprintf('LIVE30 MAT: %s\n',result.MAT);
        catch ME
            statusLabel.Text = 'STOPPED | EXPORT ERROR';
            uialert(fig,ME.message,'LIVE-30 Export Error');
        end
        startBtn.Enable = 'on';
    end

    function refreshLive(~,~)
        if ~isvalid(fig)
            return;
        end
        st = DynoForge_LIVE29_Serial_Module('get');
        if isempty(st.Data)
            return;
        end
        d = st.Data;
        latest = d(end,2:5);
        for j = 1:4
            values(j).Text = sprintf('%.1f',latest(j));
            set(lineH(j),'XData',d(:,1), ...
                'YData',d(:,j+1));
        end
        statusLabel.Text = sprintf( ...
            'LIVE | %d frames',st.ValidFrames);
    end

    function closeLive(~,~)
        if strcmp(refreshTimer.Running,'on')
            stop(refreshTimer);
        end
        try
            DynoForge_LIVE29_Serial_Module('stop');
        catch
        end
        delete(refreshTimer);
        delete(fig);
    end
end
