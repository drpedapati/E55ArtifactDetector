function resultTable = detectE55ArtifactV2(EEG, threshold, outDir)
% detectExcessiveICAComponent identifies an excessive ICA component at electrode E55,
% computes its z-score, spatial correlation to a Gaussian template centered at E55,
% and saves a vertically arranged figure showing the bar plot and two topographies.
%
% USAGE:
%   resultTable = detectExcessiveICAComponent(EEG)
%   resultTable = detectExcessiveICAComponent(EEG, threshold)
%   resultTable = detectExcessiveICAComponent(EEG, threshold, outDir)
%
% INPUT:
%   EEG       - EEGLAB structure with fields 'chanlocs', 'icawinv', and 'filename'
%   threshold - cutoff for max z-score (default = 5)
%   outDir    - directory for saving the figure (default = current folder)
%
% OUTPUT:
%   resultTable - a table with columns: Filename, ExcessiveClassifier, MaxZScore,
%                 CutoffThreshold, TemplateMatching, FigureFile

if nargin < 2 || isempty(threshold)
    threshold = 5;
end
if nargin < 3 || isempty(outDir)
    outDir = pwd;
end

% Validate required fields.
if ~isfield(EEG, 'chanlocs') || ~isfield(EEG, 'icawinv')
    error('EEG structure must contain ''chanlocs'' and ''icawinv'' fields.');
end
if ~isfield(EEG, 'filename') || isempty(EEG.filename)
    EEG.filename = 'UnknownEEG.set';
end

% Locate electrode 'E55'
electrodeLabel = 'E55';
electrode_idx = find(strcmp({EEG.chanlocs.labels}, electrodeLabel), 1);
if isempty(electrode_idx)
    error('Electrode %s not found.', electrodeLabel);
end

% Extract ICA weights at E55 and compute z-scores.
absWeights = abs(EEG.icawinv(electrode_idx, :));
mu = mean(absWeights);
sigma = std(absWeights);
if sigma == 0, sigma = eps; end
zScores = (absWeights - mu) / sigma;
[maxZ, maxIdx] = max(zScores);
excessiveFlag = maxZ > threshold;

% Create a Gaussian template with a smaller sigma for tighter fit around E55.
if ~isfield(EEG.chanlocs, 'X') || ~isfield(EEG.chanlocs, 'Y')
    error('EEG.chanlocs must contain fields ''X'' and ''Y''.');
end
X = [EEG.chanlocs.X];
Y = [EEG.chanlocs.Y];
centerX = EEG.chanlocs(electrode_idx).X;
centerY = EEG.chanlocs(electrode_idx).Y;
dists = sqrt((X - centerX).^2 + (Y - centerY).^2);
sigmaTemplate = max(dists) / 10;  % Reduced sigma for a more centered, less diffuse template
if sigmaTemplate == 0, sigmaTemplate = eps; end
gaussTemplate = exp(-(dists.^2) / (2 * sigmaTemplate^2));

% Compute spatial correlation between the component topography and the Gaussian template.
compTopomap = EEG.icawinv(:, maxIdx);
R = corrcoef(compTopomap, gaussTemplate');
spatialCorr = R(1,2);

% Create a vertically arranged figure with three subplots.
fig = figure('Name', 'Excessive ICA Component Analysis', 'NumberTitle', 'off');

% Subplot 1: Bar plot of absolute ICA weights at E55.
subplot(2,2,[1 2]);
bar(absWeights, 'FaceColor', [0.2 0.2 0.8]);
hold on;
plot(maxIdx, absWeights(maxIdx), 'r*', 'MarkerSize', 10);
xlabel('Component'); ylabel('Absolute Weight at E55');
title(sprintf('ICA Weights at E55 (Max IC %d)', maxIdx));
grid on;

% Subplot 2: Topoplot of the excessive component.
subplot(2,2,3);
if isfield(EEG, 'chaninfo')
    topoplot(compTopomap, EEG.chanlocs, 'chaninfo', EEG.chaninfo, 'electrodes', 'on');
else
    topoplot(compTopomap, EEG.chanlocs, 'electrodes', 'on');
end
title(sprintf('Component %d (z=%.2f, corr=%.2f)', maxIdx, maxZ, spatialCorr));
axis square;

% Subplot 3: Topoplot of the Gaussian template.
subplot(2,2,4);
if isfield(EEG, 'chaninfo')
    topoplot(gaussTemplate, EEG.chanlocs, 'chaninfo', EEG.chaninfo, 'electrodes', 'on');
else
    topoplot(gaussTemplate, EEG.chanlocs, 'electrodes', 'on');
end
title(sprintf('Gaussian Template Centered at %s', electrodeLabel));
axis square;

% Save the figure using the EEG filename basename.
[~, baseName, ~] = fileparts(EEG.filename);
figFile = fullfile(outDir, [baseName '_ExcessiveICAComponentAnalysis.png']);
saveas(fig, figFile);

% Create output table.
resultTable = table({EEG.filename}, excessiveFlag, maxZ, maxIdx, threshold, spatialCorr, {figFile}, ...
    'VariableNames', {'Filename', 'ExcessiveClassifier', 'MaxZScore', 'MaxIC', 'CutoffThreshold', 'TemplateMatching', 'FigureFile'});
end
