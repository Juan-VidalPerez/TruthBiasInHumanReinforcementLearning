function plot_swarm_summary(data, x, xlabels, colors, x_label, y_label, show_swarm)
% PLOT_SWARM_SUMMARY
%
% Plots participant-level observations together with group means and SEM.
%
% INPUTS
%   data       - nParticipant x nCondition matrix.
%
%   x          - 1 x nCondition vector specifying x-axis positions.
%
%   xlabels    - Cell array containing x-axis labels.
%
%   colors     - nCondition x 3 RGB matrix specifying point colors.
%                If empty, black is used for all conditions.
%
%   x_label    - x-axis label. Use '' for no label.
%
%   y_label    - y-axis label. Use '' for no label.
%
%   show_swarm - Logical indicating whether participant-level observations
%                should be shown using swarmchart.
%
% OUTPUT
%   None. The function plots into the current axes.
%
% NOTES
%   Group error bars represent the standard error of the mean (SEM),
%   calculated across non-missing participants.


%% Defaults

if isempty(colors)
    colors = zeros(size(data,2),3);
end

if isempty(x)
    x = 1:size(data,2);
end

if nargin < 7
    show_swarm = true;
end


%% Participant-level observations

if show_swarm

    for p = 1:size(data,2)

        values = data(:,p);

        swarmchart( ...
            repmat(x(p), size(values)), ...
            values, ...
            5, ...
            colors(p,:), ...
            'filled', ...
            'XJitterWidth', 0.3, ...
            'MarkerFaceAlpha', 0.5, ...
            'MarkerEdgeAlpha', 0.5);

        hold on
    end

end


%% Group means and SEM

for p = 1:size(data,2)

    values = data(:,p);

    m = mean(values, 'omitnan');
    sem = std(values, 'omitnan') / sqrt(sum(~isnan(values)));

    errorbar( ...
        x(p), m, sem, ...
        'Color', 'k', ...
        'LineWidth', 1, ...
        'CapSize', 12);

    hold on

    plot( ...
        x(p), m, 'o', ...
        'Color', colors(p,:), ...
        'LineWidth', 1, ...
        'MarkerSize', 8, ...
        'MarkerFaceColor', colors(p,:), ...
        'MarkerEdgeColor', 'k');

end


%% Axes

[x_sorted, idx] = sort(x);

xticks(x_sorted)
xticklabels(xlabels(idx))

if ~isempty(x_label)
    xlabel(x_label)
end

if ~isempty(y_label)
    ylabel(y_label)
end

xlim([min(x)-0.5, max(x)+0.5])

end