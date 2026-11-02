function app = DynoForge_Launcher(projectDir)
% DynoForge_Launcher - Portable desktop-simulation entry point.
% STEP 13.1. Does not run Simulink or access hardware.
% Usage: app = DynoForge_Launcher();
%        app = DynoForge_Launcher('C:\DynoForge_Test');

fprintf('\n===== DYNOfORGE LAUNCHER | STEP 13.1 =====\n');
if nargin < 1 || isempty(projectDir)
    projectDir = fileparts(mfilename('fullpath'));
end
projectDir = char(projectDir);
assert(isfolder(projectDir), 'DynoForge:MissingProject', ...
    'Project directory not found: %s', projectDir);

v3File = fullfile(projectDir,'DynoForge_Control_Center_V3_Rebuilt.m');
assert(isfile(v3File), 'DynoForge:MissingV3', ...
    'V3 GUI source missing: %s', v3File);

snapshotFile = fullfile(projectDir,'Results','ControlCenter_Data', ...
    'DynoForge_ControlCenter_Latest.mat');
assert(isfile(snapshotFile), 'DynoForge:MissingSnapshot', ...
    'Desktop simulation snapshot missing: %s', snapshotFile);

fprintf('PASS | PROJECT_DIRECTORY | %s\n', projectDir);
fprintf('PASS | V3_SOURCE_FOUND\n');
fprintf('PASS | SNAPSHOT_FOUND\n');

snapshotVars = whos('-file',snapshotFile);
assert(any(strcmp({snapshotVars.name},'Snapshot')), ...
    'DynoForge:InvalidSnapshot', 'Snapshot variable not found in MAT file.');
S = load(snapshotFile,'Snapshot');
snap = S.Snapshot;
assert(isstruct(snap) && isfield(snap,'Data') && ...
    isfield(snap.Data,'Signals') && isstruct(snap.Data.Signals), ...
    'DynoForge:InvalidSnapshot', 'Snapshot.Data.Signals is missing.');
assert(numel(fieldnames(snap.Data.Signals)) == 39, ...
    'DynoForge:SignalCount', 'Expected 39 desktop simulation signals.');
assert(isfield(snap,'DesktopSimulationOnly') && ...
    isequal(snap.DesktopSimulationOnly,true), ...
    'DynoForge:ModeNotVerified', ...
    'Snapshot is not explicitly marked desktop simulation only.');
assert(isfield(snap,'HardwareVerified') && ...
    isequal(snap.HardwareVerified,false), ...
    'DynoForge:ModeNotVerified', ...
    'Launcher only accepts hardware-unverified simulation snapshots.');

reportRoot = fullfile(projectDir,'Results');
assert(isfolder(reportRoot), 'DynoForge:MissingResults', ...
    'Results directory missing: %s', reportRoot);
reportFolders = dir(fullfile(reportRoot,'DynoForge_60Plots_*'));
reportFolders = reportFolders([reportFolders.isdir]);
assert(~isempty(reportFolders), 'DynoForge:MissingReports', ...
    'No DynoForge_60Plots_* report folder found.');
[~,order] = sort([reportFolders.datenum],'descend');
foundReport = false;
for k = order
    folder = fullfile(reportFolders(k).folder,reportFolders(k).name);
    pngs = dir(fullfile(folder,'**','*.png'));
    if numel(pngs)==61
        foundReport = true;
        fprintf('PASS | REPORT_FOLDER | %s\n',folder);
        break;
    end
end
assert(foundReport,'DynoForge:MissingReports', ...
    'No report folder with 61 PNG files was found.');

% Preserve the caller's MATLAB search path; no model or hardware actions.
oldPath = path;
pathCleanup = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(projectDir,'-begin');
rehash;
assert(~isempty(which('DynoForge_Control_Center_V3_Rebuilt')), ...
    'DynoForge:UnrecognizedV3', 'MATLAB cannot resolve V3 source.');

fprintf('PASS | SNAPSHOT_SIMULATION_ONLY | 39 signals\n');
fprintf('INFO | Starting V3 GUI (desktop simulation only)...\n');
try
    app = DynoForge_Control_Center_V3_Rebuilt(projectDir);
catch ME
    fprintf(2,'FAIL | V3_LAUNCH | %s\n',ME.message);
    rethrow(ME);
end
assert(isstruct(app) && isfield(app,'Figure') && isvalid(app.Figure), ...
    'DynoForge:InvalidGUI', 'V3 did not return a valid GUI handle.');
assert(isfield(app,'GetState') && isa(app.GetState,'function_handle'), ...
    'DynoForge:InvalidGUI', 'V3 GetState API missing.');
state = app.GetState();
assert(state.SignalCount==39 && state.PlotCount==61 && ...
    state.DesktopSimulationOnly && ~state.HardwareVerified, ...
    'DynoForge:StateMismatch', 'V3 startup state verification failed.');
fprintf('PASS | V3_GUI_OPENED\n');
fprintf('PASS | V3_STATE | 39 signals / 61 PNG\n');
fprintf('Hardware accessed: NO\n');
fprintf('Simulink executed: NO\n');
fprintf('===== STEP 13.1 PASS =====\n');
end
